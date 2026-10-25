#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
builder="${repo}/.github/scripts/build-kodi-dependencies.sh"
tmp="$(mktemp -d /tmp/build-kodi-dependencies-fixture.XXXXXX)"
case "${tmp}" in /tmp/build-kodi-dependencies-fixture.*) ;; *) echo "unsafe temp path" >&2; exit 2;; esac
trap 'rm -rf -- "${tmp}"' EXIT

mkdir -p "${tmp}/config" "${tmp}/scripts"
cat > "${tmp}/config/options" <<'SH'
PKG_NAME=kodi
PKG_DEPENDS_TARGET="toolchain base-library"
configure_package() {
  PKG_DEPENDS_TARGET+=" device-library:host"
}
configure_package
SH
cat > "${tmp}/scripts/build" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >> "${BUILD_CALL_LOG}"
SH
chmod +x "${tmp}/scripts/build"

export BUILD_CALL_LOG="${tmp}/calls.log"
(
  cd "${tmp}"
  PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=arm MTWITHLOCKS=no bash "${builder}"
)
printf 'toolchain|kodi:target\nbase-library|kodi:target\ndevice-library:host|kodi:target\n' > "${tmp}/expected.log"
cmp -s "${tmp}/expected.log" "${BUILD_CALL_LOG}"
echo 'PASS dependency wrapper reads configured package dependencies in order'

cat > "${tmp}/scripts/build" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >> "${BUILD_CALL_LOG}"
[[ "$1" == "base-library" ]] && exit 9
exit 0
SH
chmod +x "${tmp}/scripts/build"
: > "${BUILD_CALL_LOG}"
if (
  cd "${tmp}"
  PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=arm MTWITHLOCKS=no bash "${builder}"
); then
  echo 'dependency wrapper unexpectedly ignored build failure' >&2
  exit 1
fi
printf 'toolchain|kodi:target\nbase-library|kodi:target\n' > "${tmp}/expected-failure.log"
cmp -s "${tmp}/expected-failure.log" "${BUILD_CALL_LOG}"
echo 'PASS dependency wrapper stops after the first failed package'

if (
  cd "${tmp}"
  PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=arm MTWITHLOCKS=yes bash "${builder}"
); then
  echo 'dependency wrapper unexpectedly accepted concurrent build mode' >&2
  exit 1
fi
echo 'PASS dependency wrapper refuses concurrent build mode'
