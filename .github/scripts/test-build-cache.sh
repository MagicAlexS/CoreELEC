#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cache_script="${repo}/.github/scripts/build-cache.py"
tmp="$(mktemp -d /tmp/build-cache-fixture.XXXXXX)"
case "${tmp}" in /tmp/build-cache-fixture.*) ;; *) echo "unsafe temp path" >&2; exit 2;; esac
trap 'rm -rf -- "${tmp}"' EXIT

build=build.CoreELEC-Amlogic-ng.arm-21
kodi_sha=acc0fc66bc6af69c31a93c5d17e36900343263b7
target_name=armv8a-libreelec-linux-gnueabihf
mkdir -p "${tmp}/bin" "${tmp}/full/${build}/toolchain/bin" \
  "${tmp}/full/${build}/toolchain/${target_name}/sysroot/usr/include" \
  "${tmp}/full/${build}/toolchain/${target_name}/sysroot/usr/lib" \
  "${tmp}/full/${build}/.stamps/kodi" "${tmp}/full/${build}/.stamps/kodi-platform" \
  "${tmp}/full/${build}/.stamps/openssl" \
  "${tmp}/full/${build}/install_pkg/kodi-${kodi_sha}/usr/bin" \
  "${tmp}/full/${build}/install_pkg/kodi-platform-1/usr/lib" \
  "${tmp}/full/${build}/install_pkg/openssl-1/usr/lib" \
  "${tmp}/full/${build}/.ccache" "${tmp}/full/${build}/.ccache-local" \
  "${tmp}/full/sources"
for compiler in host-gcc host-g++ "${target_name}-gcc"; do
  printf '#!/bin/sh\nexit 0\n' > "${tmp}/full/${build}/toolchain/bin/${compiler}"
  chmod +x "${tmp}/full/${build}/toolchain/bin/${compiler}"
done
printf bad-stamp > "${tmp}/full/${build}/.stamps/kodi/build_target"
printf platform-stamp > "${tmp}/full/${build}/.stamps/kodi-platform/build_target"
printf dep-stamp > "${tmp}/full/${build}/.stamps/openssl/build_target"
printf old-kodi > "${tmp}/full/${build}/install_pkg/kodi-${kodi_sha}/usr/bin/kodi.bin"
printf kodi-platform > "${tmp}/full/${build}/install_pkg/kodi-platform-1/usr/lib/libkodiplatform.so"
printf dep-output > "${tmp}/full/${build}/install_pkg/openssl-1/usr/lib/libssl.so"
printf ccache-a > "${tmp}/full/${build}/.ccache/cache-object"
printf ccache-b > "${tmp}/full/${build}/.ccache-local/cache-object"
printf download > "${tmp}/full/sources/foo.tar.gz"
printf 'https://example.invalid/foo.tar.gz\n' > "${tmp}/full/sources/foo.tar.gz.url"
sha256sum "${tmp}/full/sources/foo.tar.gz" | awk '{print $1}' > "${tmp}/full/sources/foo.tar.gz.sha256"
mkdir -p "${tmp}/full/sources/rtmpdump" \
  "${tmp}/full/sources/badarchive" \
  "${tmp}/full/sources/unmarked" \
  "${tmp}/full/sources/gitpkg/gitpkg-abcdef/.git"
printf '<html>mirror error</html>' > "${tmp}/full/sources/rtmpdump/rtmpdump.tar.gz"
printf 'not the expected digest' > "${tmp}/full/sources/badarchive/bad.tar.xz"
printf 'https://example.invalid/bad.tar.xz\n' > "${tmp}/full/sources/badarchive/bad.tar.xz.url"
printf '%064d\n' 0 > "${tmp}/full/sources/badarchive/bad.tar.xz.sha256"
printf 'unmarked partial download' > "${tmp}/full/sources/unmarked/partial.tar.zst"
printf 'git archive stored in a Git checkout' > "${tmp}/full/sources/gitpkg/gitpkg-abcdef/archive.tar.gz"
head -c 8192 /dev/urandom > "${tmp}/full/${build}/toolchain/${target_name}/sysroot/usr/lib/random.bin"

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
test -x "${tmp}/full-restore/${build}/toolchain/bin/host-gcc"
test -d "${tmp}/full-restore/${build}/toolchain/${target_name}/sysroot/usr/include"
test -f "${tmp}/full-restore/${build}/.stamps/openssl/build_target"
test -f "${tmp}/full-restore/${build}/install_pkg/openssl-1/usr/lib/libssl.so"
test -f "${tmp}/full-restore/${build}/install_pkg/kodi-platform-1/usr/lib/libkodiplatform.so"
test -f "${tmp}/full-restore/${build}/.stamps/kodi-platform/build_target"
test -f "${tmp}/full-restore/${build}/.ccache/cache-object"
test -f "${tmp}/full-restore/sources/foo.tar.gz"
test -f "${tmp}/full-restore/sources/foo.tar.gz.url"
test -f "${tmp}/full-restore/sources/foo.tar.gz.sha256"
test ! -e "${tmp}/full-restore/sources/rtmpdump/rtmpdump.tar.gz"
test ! -e "${tmp}/full-restore/sources/badarchive/bad.tar.xz"
test ! -e "${tmp}/full-restore/sources/badarchive/bad.tar.xz.url"
test ! -e "${tmp}/full-restore/sources/badarchive/bad.tar.xz.sha256"
test ! -e "${tmp}/full-restore/sources/unmarked/partial.tar.zst"
test -f "${tmp}/full-restore/sources/gitpkg/gitpkg-abcdef/archive.tar.gz"
test ! -e "${tmp}/full-restore/${build}/.stamps/kodi/build_target"
test ! -e "${tmp}/full-restore/${build}/install_pkg/kodi-${kodi_sha}/usr/bin/kodi.bin"
echo 'PASS full snapshot excludes Kodi stamp/install and restores dependencies'

mkdir -p "${tmp}/bad-marker/${build}/toolchain" "${tmp}/bad-marker-restore"
printf incomplete > "${tmp}/bad-marker/${build}/toolchain/partial"
tar -cf "${tmp}/bad-marker.tar" -C "${tmp}/bad-marker" "${build}/toolchain"
zstd -q -3 -T0 -f -o "${tmp}/bad-marker.tar.zst" < "${tmp}/bad-marker.tar"
marker_log="$(GITHUB_WORKSPACE="${tmp}/bad-marker-restore" python3 "${cache_script}" restore --archive "${tmp}/bad-marker.tar.zst")"
printf '%s\n' "${marker_log}"
grep -Fq 'full cache missing toolchain marker' <<< "${marker_log}"
test ! -e "${tmp}/bad-marker-restore/${build}"
echo 'PASS restore rejects snapshots with an incomplete toolchain'

mkdir -p "${tmp}/incomplete/${build}/toolchain" \
  "${tmp}/incomplete/${build}/.ccache" "${tmp}/incomplete-restore"
printf partial > "${tmp}/incomplete/${build}/toolchain/partial"
printf ccache > "${tmp}/incomplete/${build}/.ccache/object"
export GITHUB_WORKSPACE="${tmp}/incomplete" GITHUB_OUTPUT="${tmp}/incomplete-output"
python3 "${cache_script}" pack --archive "${tmp}/incomplete/incomplete.tar.zst"
grep -Fxq 'save=true' "${GITHUB_OUTPUT}"
grep -Fxq 'mode=ccache-only' "${GITHUB_OUTPUT}"
GITHUB_WORKSPACE="${tmp}/incomplete-restore" python3 "${cache_script}" restore --archive "${tmp}/incomplete/incomplete.tar.zst"
test -f "${tmp}/incomplete-restore/${build}/.ccache/object"
test ! -e "${tmp}/incomplete-restore/${build}/toolchain"
echo 'PASS incomplete toolchain falls back to a ccache-only checkpoint'

export COREELEC_CACHE_MAX_BYTES=512 GITHUB_WORKSPACE="${tmp}/full" GITHUB_OUTPUT="${tmp}/ccache-output"
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
