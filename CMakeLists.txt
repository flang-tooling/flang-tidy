cmake_minimum_required(VERSION 3.20)
project(flang-tidy LANGUAGES C CXX)

# Convenience for versioned distro layouts, e.g. -DLLVM_ROOT=/usr/lib/llvm-23.
# Set LLVM_DIR / MLIR_DIR / Clang_DIR / Flang_DIR directly instead if you like.
if(LLVM_ROOT)
  foreach(pkg LLVM MLIR Clang Flang)
    string(TOLOWER ${pkg} _dir)
    set(${pkg}_DIR "${LLVM_ROOT}/lib/cmake/${_dir}" CACHE PATH "" FORCE)
  endforeach()
endif()

# Order matters: FlangTargets.cmake exports the FIR and Lower libraries, whose
# interfaces reference Clang and MLIR imported targets.
find_package(LLVM  REQUIRED CONFIG)
find_package(MLIR  REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)
find_package(Flang REQUIRED CONFIG)

message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION} from ${LLVM_DIR}")

# C++17: Flang's Evaluate/expression.h does not compile under C++20.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND "${LLVM_DEFINITIONS}")
add_definitions(${LLVM_DEFINITIONS_LIST})

# Distributions ship LLVM's shared libraries under a versioned prefix that is
# not on the loader's default search path, and CMake clears RPATH on install.
# Record it, or the installed binary cannot find libMLIR.so.
set(CMAKE_INSTALL_RPATH "${LLVM_LIBRARY_DIR}")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

# One executable rather than the in-tree per-category static libraries, so the
# module registrations in FlangTidyForceLinker.h cannot be stripped.
file(GLOB FLANG_TIDY_SOURCES CONFIGURE_DEPENDS
  src/*.cpp
  src/utils/*.cpp
  src/tool/*.cpp
  src/bugprone/*.cpp
  src/modernize/*.cpp
  src/openmp/*.cpp
  src/performance/*.cpp
  src/readability/*.cpp)

if(NOT FLANG_TIDY_SOURCES)
  message(FATAL_ERROR
    "No sources found under ${CMAKE_CURRENT_SOURCE_DIR}/src -- configure the "
    "repository root, not the build files on their own.")
endif()

add_executable(flang-tidy ${FLANG_TIDY_SOURCES})

target_include_directories(flang-tidy PRIVATE src)
target_include_directories(flang-tidy SYSTEM PRIVATE
  ${FLANG_INCLUDE_DIRS}
  ${CLANG_INCLUDE_DIRS}
  ${MLIR_INCLUDE_DIRS}   # flang/Frontend/CompilerInvocation.h includes mlir/Support/Timing.h
  ${LLVM_INCLUDE_DIRS})

if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(flang-tidy PRIVATE -fno-rtti)
endif()

target_link_libraries(flang-tidy PRIVATE
  FortranSupport
  FortranParser
  FortranEvaluate
  FortranSemantics
  flangFrontend
  flangFrontendTool
  clangTooling
  clangDriver
  clangFrontend
  clangBasic)

install(TARGETS flang-tidy RUNTIME DESTINATION bin)
