#===----------------------------------------------------------------------===//
# Build and smoke-test flang-tidy against a packaged LLVM/Flang.
#
#   docker build -t flang-tidy .
#   docker run --rm -v "$PWD:/work" flang-tidy -checks=bugprone-* /work/foo.f90
#===----------------------------------------------------------------------===//
ARG BASE_IMAGE=debian:bookworm
FROM ${BASE_IMAGE}

ARG LLVM_VERSION=23
ENV DEBIAN_FRONTEND=noninteractive

# zlib/zstd/curl/edit/xml2/ffi: LLVMSupport is built against these, so the
# final link fails on undefined symbols without the -dev packages.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates gnupg wget \
        build-essential cmake ninja-build \
        zlib1g-dev libzstd-dev libcurl4-openssl-dev libedit-dev \
        libxml2-dev libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# Released versions live in llvm-toolchain-<codename>-<N>, the in-development
# one in the unsuffixed repository. Probe rather than guess.
RUN . /etc/os-release && \
    wget -qO /usr/share/keyrings/llvm.asc https://apt.llvm.org/llvm-snapshot.gpg.key && \
    for suffix in "-${LLVM_VERSION}" ""; do \
      if wget -q --spider "http://apt.llvm.org/${VERSION_CODENAME}/dists/llvm-toolchain-${VERSION_CODENAME}${suffix}/Release"; then \
        echo "deb [signed-by=/usr/share/keyrings/llvm.asc] http://apt.llvm.org/${VERSION_CODENAME}/ llvm-toolchain-${VERSION_CODENAME}${suffix} main" \
            > /etc/apt/sources.list.d/llvm.list; \
        echo "using llvm-toolchain-${VERSION_CODENAME}${suffix}"; break; \
      fi; \
    done; \
    test -s /etc/apt/sources.list.d/llvm.list || { \
      echo "ERROR: apt.llvm.org has no repository for ${VERSION_CODENAME} / LLVM ${LLVM_VERSION}"; exit 1; }

# libclang-dev and libmlir-dev are required even though little is used from
# them: FlangTargets.cmake references their imported targets.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        llvm-${LLVM_VERSION}-dev \
        libclang-${LLVM_VERSION}-dev \
        libmlir-${LLVM_VERSION}-dev \
        libflang-${LLVM_VERSION}-dev \
        flang-${LLVM_VERSION} \
        clang-${LLVM_VERSION} && \
    rm -rf /var/lib/apt/lists/*

ENV LLVM_ROOT=/usr/lib/llvm-${LLVM_VERSION}

# The LLVM packages export imported targets for MLIR tool binaries they do not
# ship, and CMake rejects the export file when an imported executable is
# missing.  flang-tidy links libraries only and never runs these generators, so
# stub the absent ones; they exit non-zero if anything does try to run one.
#
# Export files reference tools through ${_IMPORT_PREFIX} rather than as
# absolute paths, so match on the /bin/<name> tail of any quoted path.
RUN set -eu; \
    for f in "${LLVM_ROOT}"/lib/cmake/*/*.cmake; do \
      [ -f "$f" ] || continue; \
      grep -hoE '"[^"]*/bin/[A-Za-z0-9_.+-]+"' "$f" || true; \
    done | sed 's|.*/bin/||; s|"||' | sort -u | while read -r name; do \
      tool="${LLVM_ROOT}/bin/$name"; \
      if [ ! -e "$tool" ]; then \
        printf '#!/bin/sh\necho "$0: stub, not shipped by the LLVM packages" >&2\nexit 1\n' > "$tool"; \
        chmod +x "$tool"; \
        echo "stubbed $tool"; \
      fi; \
    done

COPY . /src

RUN cmake -G Ninja -S /src -B /build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-${LLVM_VERSION} \
        -DCMAKE_CXX_COMPILER=clang++-${LLVM_VERSION} \
        -DLLVM_ROOT="${LLVM_ROOT}" && \
    cmake --build /build && \
    cmake --install /build && \
    rm -rf /build

# Smoke test: a check that needs no module files must fire on known-bad input.
RUN printf 'subroutine s\n  x = 1.0\nend subroutine\n' > /tmp/smoke.f90 && \
    flang-tidy -checks=bugprone-implicit-declaration /tmp/smoke.f90 2>&1 \
      | tee /tmp/out && grep -q "warning:" /tmp/out && \
    echo "smoke test passed"

WORKDIR /work
ENTRYPOINT ["flang-tidy"]
CMD ["--help"]
