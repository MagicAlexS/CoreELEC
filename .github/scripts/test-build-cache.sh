#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cache_script="${repo}/.github/scripts/build-cache.py"
tmp="$(mktemp -d /tmp/build-cache-fixture.XXXXXX)"
case "${tmp}" in /tmp/build-cache-fixture.*) ;; *) echo "unsafe temp path" >&2; exit 2;; esac
trap 'rm -rf -- "${tmp}"' EXIT

build=build.CoreELEC-Amlogic-ng.arm-21
kodi_sha=acc0fc66bc6af69c31a93c5d17e36900343263b7
mkdir -p "${tmp}/bin" "${tmp}/full/${build}/toolchain/sysroot" \
  "${tmp}/full/${build}/.stamps/kodi" "${tmp}/full/${build}/.stamps/kodi-platform" \
  "${tmp}/full/${build}/.stamps/openssl" \
  "${tmp}/full/${build}/install_pkg/kodi-${kodi_sha}/usr/bin" \
  "${tmp}/full/${build}/install_pkg/kodi-platform-1/usr/lib" \
  "${tmp}/full/${build}/install_pkg/openssl-1/usr/lib" \
  "${tmp}/full/${build}/.ccache" "${tmp}/full/${build}/.ccache-local" \
  "${tmp}/full/sources"
printf toolchain > "${tmp}/full/${build}/toolchain/sysroot/toolchain.txt"
printf bad-stamp > "${tmp}/full/${build}/.stamps/kodi/build_target"
printf platform-stamp > "${tmp}/full/${build}/.stamps/kodi-platform/build_target"
printf dep-stamp > "${tmp}/full/${build}/.stamps/openssl/build_target"
printf old-kodi > "${tmp}/full/${build}/install_pkg/kodi-${kodi_sha}/usr/bin/kodi.bin"
printf kodi-platform > "${tmp}/full/${build}/install_pkg/kodi-platform-1/usr/lib/libkodiplatform.so"
printf dep-output > "${tmp}/full/${build}/install_pkg/openssl-1/usr/lib/libssl.so"
printf ccache-a > "${tmp}/full/${build}/.ccache/cache-object"
printf ccache-b > "${tmp}/full/${build}/.ccache-local/cache-object"
printf download > "${tmp}/full/sources/foo.tar.gz"
head -c 8192 /dev/urandom > "${tmp}/full/${build}/toolchain/sysroot/random.bin"

if command -v zstd >/dev/null 2>&1; then
  echo "Using real zstd: $(command -v zstd)"
else
  echo 'zstd CLI missing; using gzip shim to exercise tar stream and cache boundaries'
  cat > "${tmp}/bin/zstd" <<'PY'
#!/usr/bin/env python3
import gzip, sys
args = sys.argv[1:]
if "-d" in args:
    sys.stdout.buffer.write(gzip.decompress(open(args[-1], "rb").read()))
else:
    output = args[args.index("-o") + 1]
    with open(output, "wb") as stream:
        stream.write(gzip.compress(sys.stdin.buffer.read(), compresslevel=1))
PY
  chmod +x "${tmp}/bin/zstd"
  export PATH="${tmp}/bin:${PATH}"
fi
export COREELEC_BUILD_DIR="${build}" KODI_SOURCE_SHA="${kodi_sha}" CCACHE_MAXSIZE=1G
export COREELEC_CACHE_MAX_BYTES=1048576 GITHUB_WORKSPACE="${tmp}/full"
export GITHUB_OUTPUT="${tmp}/full-output"

python3 "${cache_script}" pack --archive "${tmp}/full/full.tar.zst"
grep -Fxq 'save=true' "${GITHUB_OUTPUT}"
grep -Fxq 'mode=full' "${GITHUB_OUTPUT}"
mkdir -p "${tmp}/full-restore"
GITHUB_WORKSPACE="${tmp}/full-restore" python3 "${cache_script}" restore --archive "${tmp}/full/full.tar.zst"
test -f "${tmp}/full-restore/${build}/toolchain/sysroot/toolchain.txt"
test -f "${tmp}/full-restore/${build}/.stamps/openssl/build_target"
test -f "${tmp}/full-restore/${build}/install_pkg/openssl-1/usr/lib/libssl.so"
test -f "${tmp}/full-restore/${build}/install_pkg/kodi-platform-1/usr/lib/libkodiplatform.so"
test -f "${tmp}/full-restore/${build}/.stamps/kodi-platform/build_target"
test -f "${tmp}/full-restore/${build}/.ccache/cache-object"
test -f "${tmp}/full-restore/sources/foo.tar.gz"
test ! -e "${tmp}/full-restore/${build}/.stamps/kodi/build_target"
test ! -e "${tmp}/full-restore/${build}/install_pkg/kodi-${kodi_sha}/usr/bin/kodi.bin"
echo 'PASS full snapshot excludes Kodi stamp/install and restores dependencies'

export COREELEC_CACHE_MAX_BYTES=512 GITHUB_OUTPUT="${tmp}/ccache-output"
python3 "${cache_script}" pack --archive "${tmp}/full/ccache-only.tar.zst"
grep -Fxq 'mode=ccache-only' "${GITHUB_OUTPUT}"
mkdir -p "${tmp}/ccache-restore"
GITHUB_WORKSPACE="${tmp}/ccache-restore" python3 "${cache_script}" restore --archive "${tmp}/full/ccache-only.tar.zst"
test -f "${tmp}/ccache-restore/${build}/.ccache/cache-object"
test -f "${tmp}/ccache-restore/${build}/.ccache-local/cache-object"
test ! -e "${tmp}/ccache-restore/${build}/toolchain"
echo 'PASS over-budget snapshot falls back to ccache-only'

mkdir -p "${tmp}/bad/${build}/.stamps/kodi" "${tmp}/bad-restore"
printf bad > "${tmp}/bad/${build}/.stamps/kodi/build_target"
tar -cf "${tmp}/bad.tar" -C "${tmp}/bad" "${build}/.stamps/kodi"
zstd -q -3 -T0 -f -o "${tmp}/bad.tar.zst" < "${tmp}/bad.tar"
restore_log="$(GITHUB_WORKSPACE="${tmp}/bad-restore" python3 "${cache_script}" restore --archive "${tmp}/bad.tar.zst")"
printf '%s\n' "${restore_log}"
grep -Fq 'archive contains excluded Kodi output' <<< "${restore_log}"
test ! -e "${tmp}/bad-restore/${build}"
echo 'PASS restore rejects cached Kodi stamps before extraction'
