#lang racket
; this implements the binary lemma (similar to Ecne Rule 2a):
;   if (x-a)*(x-b)=0, then x \in {a,b}; namely if {a,b}={0,1}, then x \in {0,1}
; this requires p1cnsts
; (note) this lemma currently only applies to {a,b}={0,1}, add support for other values if necessary later
; (note) this lemma requires ab0 optimization first, applies on p1cnsts
(require
    (prefix-in config: "../../config.rkt")
    (prefix-in tokamak: "../../tokamak.rkt")
    (prefix-in r1cs: "../../r1cs/r1cs-grammar.rkt")
)
(provide (rename-out
    [apply-lemma apply-lemma]
))

; recursively apply linear lemma
(define (apply-lemma ks us p1cnsts range-vec)
    (printf "  # propagation (binary01 lemma): ")
    (define new-ks (list->set (set->list ks)))
    (define new-us (list->set (set->list us)))

    (process p1cnsts range-vec)

    ; for signals with only 1 value, they are already unique
    ; (note) but we also need to check for signals that have no valid values, which may be compilation error
    (for ([sid (range (vector-length range-vec))])
        (when (set? (vector-ref range-vec sid))
            (cond
                [(equal? 0 (set-count (vector-ref range-vec sid)))
                    (tokamak:exit "range-vec has 0 candidate values, got ~a for signal ~a" (vector-ref range-vec sid) sid)
                ]
                ; (fixme) is this valid?
                [(equal? 1 (set-count (vector-ref range-vec sid)))
                    ; good, this is unique
                    (set! new-ks (set-add new-ks sid))
                    (set! new-us (set-remove new-us sid))
                ]
                [else (void)] ; else do nothing
            )
        )
    )
    (let ([s0 (set-subtract new-ks ks)])
        (if (set-empty? s0)
            (printf "none.\n")
            (printf "~a added.\n" s0)
        )
    )
    ; apply once is enough, return
    (values new-ks new-us)
)

(define (override!-range range-vec sid rng)
    (cond
        [(equal? 'bottom (vector-ref range-vec sid))
            ; bottom, update the range
            (vector-set! range-vec sid rng)
        ]
        [(set? (vector-ref range-vec sid))
            ; a set, get interssection
            (vector-set! range-vec sid (set-intersect (vector-ref range-vec sid) rng))
        ]
        [else (tokamak:exit "unsupported range-vec value, got: ~a\n" (vector-ref range-vec sid))]
    )
)

(define (extract-signal-id x) (string->number (substring x 1)))

; actual matching funtion of the lemma
; we are looking for expanded forms of (x-0)(x-1)=0 (also: x*(x+p1)=0), which is e.g.,:
;   - (assert (= (rem (+ (* ps1 y639) (* y639 y639)) p) zero))  --> not captured by ab0
;   - (assert (or (= zero (ff.add ps1 x701)) (= zero x701)))    --> captured by ab0
; need to consider grammar of finite field and non finite field
(define (process arg-r1cs range-vec)
    (define vs (r1cs:rcmds-vs arg-r1cs))
    (for ([i (range (length vs))])
        (define obj (list-ref vs i))
        (match obj

            ; ==================================
            ; ==== non finite field version ====
            ; ==================================

            ; - (assert (= (rem (+ (* ps1 y639) (* y639 y639)) p) zero))
            [(r1cs:rassert (r1cs:req
                (r1cs:rmod
                    (r1cs:radd (list-no-order
                        (r1cs:rmul (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        (r1cs:rmul (list (r1cs:rvar x1) (r1cs:rvar x1)))
                    ))
                    _
                )
                (r1cs:rvar "zero")
             ))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#1
            [(r1cs:rassert (r1cs:req
                (r1cs:rvar "zero")
                (r1cs:rmod
                    (r1cs:radd (list-no-order
                        (r1cs:rmul (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        (r1cs:rmul (list (r1cs:rvar x1) (r1cs:rvar x1)))
                    ))
                    _
                )
             ))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]

            ; (assert (or (= zero (ff.add ps1 x701)) (= zero x701)))
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rmod
                        (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        _
                    )
                )
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rvar x1)
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#1
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rmod
                        (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        _
                    )
                )
                (r1cs:req
                    (r1cs:rvar x1)
                    (r1cs:rvar "zero")
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#2
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rmod
                        (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        _
                    )
                    (r1cs:rvar "zero")
                )
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rvar x1)
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#3
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rmod
                        (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                        _
                    )
                    (r1cs:rvar "zero")
                )
                (r1cs:req
                    (r1cs:rvar x1)
                    (r1cs:rvar "zero")
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]

            ; ==============================
            ; ==== finite field version ====
            ; ==============================

            ; - (assert (= (rem (+ (* ps1 y639) (* y639 y639)) p) zero))
            [(r1cs:rassert (r1cs:req
                (r1cs:radd (list-no-order
                    (r1cs:rmul (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                    (r1cs:rmul (list (r1cs:rvar x1) (r1cs:rvar x1)))
                ))
                (r1cs:rvar "zero")
             ))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#1
            [(r1cs:rassert (r1cs:req
                (r1cs:rvar "zero")
                (r1cs:radd (list-no-order
                    (r1cs:rmul (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                    (r1cs:rmul (list (r1cs:rvar x1) (r1cs:rvar x1)))
                ))
             ))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]

            ; (assert (or (= zero (ff.add ps1 x701)) (= zero x701)))
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                )
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rvar x1)
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#1
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                )
                (r1cs:req
                    (r1cs:rvar x1)
                    (r1cs:rvar "zero")
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#2
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                    (r1cs:rvar "zero")
                )
                (r1cs:req
                    (r1cs:rvar "zero")
                    (r1cs:rvar x1)
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]
            ; flip#3
            [(r1cs:rassert (r1cs:ror (list-no-order
                (r1cs:req
                    (r1cs:radd (list-no-order (r1cs:rvar "ps1") (r1cs:rvar x0)))
                    (r1cs:rvar "zero")
                )
                (r1cs:req
                    (r1cs:rvar x1)
                    (r1cs:rvar "zero")
                )
             )))
                ; signal x is bounded to {0,1}, extract signal number
                (when (equal? x0 x1)
                    ; (printf "binary01 add: ~a\n" x0)
                    (override!-range range-vec (extract-signal-id x0) (list->set (list 0 1)))
                )
            ]

            ; otherwise, do not rewrite
            [_ (void)]
        )
    )
)