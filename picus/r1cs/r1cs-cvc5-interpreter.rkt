#lang racket
; this interprets r1cs commands into z3 constraints
(require
    (prefix-in tokamak: "../tokamak.rkt")
    (prefix-in utils: "../utils.rkt")
    (prefix-in config: "../config.rkt")
    (prefix-in r1cs: "./r1cs-grammar.rkt")
)
(provide (rename-out
    [interpret-r1cs interpret-r1cs]
))

(define (make-format-op op)
    (define (format-op x y)
        (cond
            ; [(and (null? x) (null? y)) (tokamak:exit "x and y can't both be null")]
            [(and (null? x) (null? y)) ""]
            [(null? x) y]
            [(null? y) x]
            [else (format "(~a ~a ~a)" op x y)]
        )
    )
    ; return a function
    format-op
)

(define (interpret-r1cs arg-r1cs)
    (match arg-r1cs

        ; command level
        [(r1cs:rcmds vs) (for/list ([v vs]) (interpret-r1cs v))]

        [(r1cs:rraw v) (format "~a" v)]
        [(r1cs:rlogic v) (format "(set-logic ~a)" v)]
        [(r1cs:rdef v t) (format "(declare-const ~a ~a)" (interpret-r1cs v) (interpret-r1cs t))]
        [(r1cs:rassert v) (format "(assert ~a)" (interpret-r1cs v))]
        [(r1cs:rcmt v) (format "; ~a" v)]
        [(r1cs:rsolve ) "(check-sat)\n(get-model)"]

        ; sub-command level
        [(r1cs:req lhs rhs) (format "(= ~a ~a)" (interpret-r1cs lhs) (interpret-r1cs rhs))]
        [(r1cs:rneq lhs rhs) (format "(not (= ~a ~a))" (interpret-r1cs lhs) (interpret-r1cs rhs))]

        [(r1cs:rand vs) (foldr (make-format-op "and") null (for/list ([v vs]) (interpret-r1cs v)))]
        [(r1cs:ror vs) (foldr (make-format-op "or") null (for/list ([v vs]) (interpret-r1cs v)))]
        [(r1cs:rimp lhs rhs) (format "(=> ~a ~a)" (interpret-r1cs lhs) (interpret-r1cs rhs))]

        [(r1cs:rint v) (format "#f~am~a" v config:p)]
        [(r1cs:rvar v) (format "~a" v)]
        [(r1cs:rtype v) (format "~a" v)]

        [(r1cs:radd vs) (foldr (make-format-op "ff.add") null (for/list ([v vs]) (interpret-r1cs v)))]
        [(r1cs:rmul vs) (foldr (make-format-op "ff.mul") null (for/list ([v vs]) (interpret-r1cs v)))]
        [(r1cs:rmod v mod) (tokamak:exit "cvc5 doesn't support mod")]

        [else (tokamak:exit "not supported: ~a" arg-r1cs)]
    )
)