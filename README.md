<div align="left">
  <h1>
    <img src="./resources/picus-white.png" width=50>
  	Picus
  </h1>
</div>

Picus is an implementation of the $\mathsf{QED}^2$ tool, which checks the uniqueness property (under-constrained signals) of ZKP circuits.

If you are looking for the documentation for the artifact evaluation of $\mathsf{QED}^2$, please switch to the [artifact branch](https://github.com/chyanju/Picus/tree/pldi23-research-artifact).

## Getting Started Guide

This section provides basic instructions on how to test out the tool for the kick-the-tires phase. We provide pre-built docker image, which is recommended.

### Building from Docker (Recommended)

```bash
docker build -t picus:v0 .
docker run -it --memory=10g picus:v0 bash
```

> Note: you should adjust the total memory limit (10g) to a suitable value according to your machine configuration. Adding the memory restriction would prevent some benchmarks from jamming docker due to large consumption of the memory. Usually 8g memory is recommended since some benchmarks could be large.

### Building from Source

You can skip this section if you build the tool from Docker.

Building from source is not recommended if you just want to quickly run and check the results. Some dependencies require manual building and configuration, which is system specific. One only needs to make sure the following dependencies are satisfied before the tool / basic testing instructions can be executed.

#### Dependencies

- Racket (8.0+): https://racket-lang.org/
  - Rosette (4.0+): https://github.com/emina/rosette
    - `raco pkg install --auto rosette`
  - csv-reading: https://www.neilvandyke.org/racket/csv-reading/
    - `raco pkg install --auto csv-reading`
  - graph-lib: [https://pkgs.racket-lang.org/package/graph-lib](https://pkgs.racket-lang.org/package/graph-lib)
    - `raco pkg install --auto graph`
  - math-lib: [https://pkgs.racket-lang.org/package/math-lib](https://pkgs.racket-lang.org/package/math-lib)
    - `raco pkg install --auto math-lib`
- Rust: https://www.rust-lang.org/
  - for circom parser
- Node.js: https://nodejs.org/en/
  - for circom parser
- Circom (2.0.6 Required): https://docs.circom.io/
  - older version may touch buggy corner cases

- z3 solver (4.10.2+ Required): [https://github.com/Z3Prover/z3](https://github.com/Z3Prover/z3)
  - older version may touch buggy corner cases

- cvc5-ff: [https://github.com/alex-ozdemir/CVC4/tree/ff](https://github.com/alex-ozdemir/CVC4/tree/ff)
  - see installation instructions [here](./NOTES.md#installing-cvc5-ff)

### Basic Testing Instructions

First change the directory to the repo's root path:

```bash
cd Picus/
```

Then run the script to compile the basic benchmarks:

```bash
./scripts/prepare-circomlib.sh
```

This compiles all the "circomlib-utils" benchmarks, and won't throw any error if the environment is configured successfully.

Then test some benchmarks, e.g., the `Decoder` benchmark, run:

```bash
racket ./picus-dpvl-uniqueness.rkt --solver cvc5 --timeout 5000 --weak --r1cs ./benchmarks/circomlib-cff5ab6/Decoder@multiplexer.r1cs
```

A successful run will output logging info ***similar*** to the following (note that actual counter-example could be different due to potential stochastic search strategy in dependant libraries):

```
# r1cs file: ./benchmarks/circomlib-cff5ab6/Decoder@multiplexer.r1cs
# timeout: 5000
# solver: cvc5
# selector: counter
# precondition: ()
# propagation: #t
# smt: #f
# weak: #t
# map: #f
# number of wires: 5
# number of constraints: 4
# field size (how many bytes): 32
# inputs: (0 4).
# outputs: (1 2 3).
# targets: #<set: 1 2 3>.
# parsing original r1cs...
# xlist: (x0 x1 x2 x3 x4).
# alt-xlist (x0 y1 y2 y3 x4).
# parsing alternative r1cs...
# configuring precondition...
# unique: #<set:>.
# initial known-set #<set: 0 4>
# initial unknown-set #<set: 1 2 3>
# refined known-set: #<set: 0 4>
# refined unknown-set: #<set: 1 2 3>
  # propagation (linear lemma): none.
  # propagation (binary01 lemma): none.
  # propagation (basis2 lemma): none.
  # propagation (aboz lemma): none.
  # propagation (aboz lemma): none.
  # checking: (x1 y1), sat.
# final unknown set #<set: 1 2 3>.
# weak uniqueness: unsafe.
# counter-example:
  #hash((one . 1) (p . 0) (ps1 . 21888242871839275222246405745257275088548364400416034343698204186575808495616) (ps2 . 21888242871839275222246405745257275088548364400416034343698204186575808495615) (ps3 . 21888242871839275222246405745257275088548364400416034343698204186575808495614) (ps4 . 21888242871839275222246405745257275088548364400416034343698204186575808495613) (ps5 . 21888242871839275222246405745257275088548364400416034343698204186575808495612) (x0 . 0) (x1 . 1) (x2 . 0) (x3 . 1) (x4 . 0) (y1 . 0) (y2 . 0) (y3 . 0) (zero . 0)).
```

If you see this, it means the environment that you are operating on is configured successfully.

## Reusability Instructions

### Quick Problem Solving for New Circuits/Benchmarks

We also provide easy API to compile and solve for any new benchmarks created. First you can use the following script to compile arbitrary benchmark:

```bash
./picus-compile.sh <path-to-your-circom-file>
```

This will generate a `*.r1cs` file in the same path as your provided `*.circom` file. Then, use the following script to solve for the benchmark:

```bash
./picus-solve.sh <path-to-your-r1cs-file>
```

This will automatically invoke the tool and output the result.

### More Options and APIs of the Tool

The following lists out all available options for running the tool.

```bash
usage: picus-dpvl-uniqueness.rkt [ <option> ... ]

<option> is one of

  --r1cs <p-r1cs>
     path to target r1cs
  --timeout <p-timeout>
     timeout for every small query (default: 5000ms)
  --solver <p-solver>
     solver to use: z3 | cvc4 | cvc5 (default: z3)
  --selector <p-selector>
     selector to use: first | counter (default: counter)
  --precondition <p-precondition>
     path to precondition json (default: null)
  --noprop
     disable propagation (default: false / propagation on)
  --smt
     show path to generated smt files (default: false)
  --weak
     only check weak safety, not strong safety  (default: false)
  --map
     map the r1cs signals of model to its circom variable (default: true)
  --help, -h
     Show this help
  --
     Do not treat any remaining argument as a switch (at this level)

 Multiple single-letter switches can be combined after
 one `-`. For example, `-h-` is the same as `-h --`.
```

## Citations

If you find our work and this tool useful in your research, please consider citing:

```
@ARTICLE{pldi23-picus,
  title     = "Automated Detection of {Under-Constrained} Circuits in
               {Zero-Knowledge} Proofs",
  author    = "Pailoor, Shankara and Chen, Yanju and Wang, Franklyn and
               Rodr{\'\i}guez, Clara and Van Geffen, Jacob and Morton, Jason
               and Chu, Michael and Gu, Brian and Feng, Yu and Dillig, I{\c
               s}{\i}l",
  journal   = "Proc. ACM Program. Lang.",
  publisher = "Association for Computing Machinery",
  volume    =  7,
  number    = "PLDI",
  month     =  jun,
  year      =  2023,
  address   = "New York, NY, USA",
  keywords  = "SNARKs, program verification, zero-knowledge proofs"
}
```
