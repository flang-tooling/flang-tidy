# flang-tidy

A linting and static-analysis framework for Fortran, built on LLVM Flang.

Checks run after Flang has finished name and type resolution, so they see
resolved symbols, `KIND` parameters, procedure interfaces, use-association
chains, and attributes such as `INTENT`, `PURE` and `TARGET`. That reaches
diagnostics syntactic tools cannot express — for instance knowing a variable in
a logical expression is `OPTIONAL` when its declaration lives in a separately
compiled module.

## Building

```sh
sudo apt install llvm-23-dev libclang-23-dev libmlir-23-dev libflang-23-dev

cmake -G Ninja -S . -B build -DLLVM_ROOT=/usr/lib/llvm-23
cmake --build build
```

Clang and MLIR are needed because Flang exports its FIR and Lower targets in
the same `FlangTargets.cmake`, which references their imported targets.

flang-tidy uses Flang's internal C++ API, which changes between releases build it against the LLVM version it targets.

## Usage

```sh
flang-tidy -checks=bugprone-* file.f90
flang-tidy -checks=readability-unused-use -fix file.f90
```

Checks are grouped into `bugprone`, `performance`, `readability`, `modernize`
and `openmp`; several can rewrite the source with `-fix`. Full list in
[docs/checks/list.rst](docs/checks/list.rst).

Cross-module resolution means the `.mod` files of everything a source uses must
already be built, so flang-tidy is normally driven from the build system rather
than pointed at raw sources.

## Layout

```
src/     framework and checks, one directory per category
test/    lit tests
docs/    per-check documentation
```

