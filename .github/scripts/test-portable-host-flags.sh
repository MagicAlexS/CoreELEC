#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

check_flags() (
  local policy="$1"
  local expected_host_arch="$2"
  local target_input="-O2 -march=armv8-a -mfloat-abi=hard"
  local project_flags="-fstack-protector-strong"
  local expected_target="${target_input} -Wall -pipe ${project_flags}"

  export TOOLCHAIN="/tmp/coreelec-test-toolchain"
  export SYSROOT_PREFIX="/tmp/coreelec-test-sysroot"
  export HOST_LIBDIR="/tmp/coreelec-test-host-libdir"
  export TARGET_CFLAGS="${target_input}"
  export TARGET_LDFLAGS="-Wl,--no-undefined"
  export PROJECT_CFLAGS="${project_flags}"
  export CONCURRENCY_MAKE_LEVEL=1
  if [[ "${policy}" == "unset" ]]; then
    unset COREELEC_HOST_PORTABLE
  else
    export COREELEC_HOST_PORTABLE="${policy}"
  fi

  # Source the actual CoreELEC configuration. HOST_LIBDIR bypasses only the
  # unrelated local multiarch probe while keeping host/target flag logic real.
  . "${ROOT}/config/optimize"

  [[ "${HOST_CFLAGS}" == *"${expected_host_arch}"* ]] || {
    echo "Expected host architecture flag ${expected_host_arch}; got ${HOST_CFLAGS}" >&2
    exit 1
  }
  [[ "${HOST_CXXFLAGS}" == *"${expected_host_arch}"* ]] || {
    echo "Expected C++ host architecture flag ${expected_host_arch}; got ${HOST_CXXFLAGS}" >&2
    exit 1
  }
  [[ "${TARGET_CFLAGS}" == "${expected_target}" ]] || {
    echo "Target CFLAGS changed unexpectedly: ${TARGET_CFLAGS}" >&2
    exit 1
  }
  [[ "${TARGET_CXXFLAGS}" == "${expected_target}" ]] || {
    echo "Target CXXFLAGS changed unexpectedly: ${TARGET_CXXFLAGS}" >&2
    exit 1
  }
  [[ "${TARGET_LDFLAGS}" == "-Wl,--no-undefined -Wl,--as-needed" ]] || {
    echo "Target LDFLAGS changed unexpectedly: ${TARGET_LDFLAGS}" >&2
    exit 1
  }
  [[ "${HOST_CFLAGS}" != *"-march=armv8-a"* && "${HOST_CFLAGS}" != *"-mfloat-abi=hard"* ]] || {
    echo "ARM target flags leaked into host CFLAGS: ${HOST_CFLAGS}" >&2
    exit 1
  }
  [[ "${TARGET_CFLAGS}" != *"-march=x86-64"* && "${TARGET_CFLAGS}" != *"-mtune=generic"* && "${TARGET_CFLAGS}" != *"-march=native"* ]] || {
    echo "Host architecture flags leaked into target CFLAGS: ${TARGET_CFLAGS}" >&2
    exit 1
  }
  if [[ "${policy}" == "1" ]]; then
    [[ "${HOST_CFLAGS}" != *"-march=native"* ]] || {
      echo "Portable CI host CFLAGS still include -march=native: ${HOST_CFLAGS}" >&2
      exit 1
    }
  else
    [[ "${HOST_CFLAGS}" != *"-march=x86-64"* && "${HOST_CFLAGS}" != *"-mtune=generic"* ]] || {
      echo "Default host CFLAGS unexpectedly use portable policy: ${HOST_CFLAGS}" >&2
      exit 1
    }
  fi
  printf 'PASS policy=%s host=%s target=%s\n' "${policy}" "${HOST_CFLAGS}" "${TARGET_CFLAGS}"
)

check_flags 1 "-march=x86-64 -mtune=generic"
check_flags unset "-march=native"
