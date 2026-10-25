#!/usr/bin/env bash
set -Eeuo pipefail

readonly EXPECTED_BRANCH="codex/fix-playback-state-artwork"
readonly EXPECTED_COREELEC_BASELINE="8ae70e7c26a5e6ae59ae6a47f5846bd633ac9f56"
readonly EXPECTED_KODI_VERSION="acc0fc66bc6af69c31a93c5d17e36900343263b7"
readonly EXPECTED_PATCH_SHA256="567336a6fdfcf802f02cf8b0b1295801ed5abfca20a35f13ca1b319b006de127"
readonly KODI_PACKAGE="projects/Amlogic-ce/packages/mediacenter/kodi/package.mk"
readonly PATCH_PATH="projects/Amlogic-ce/devices/Amlogic-ng/patches/kodi/kodi-90-dvd-external-subtitle-visibility.patch"

branch="${GITHUB_REF_NAME:-$(git branch --show-current)}"
if [[ "${branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "Refusing to build branch '${branch}'; expected '${EXPECTED_BRANCH}'." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "${EXPECTED_COREELEC_BASELINE}" HEAD; then
  echo "This branch must descend from CoreELEC ${EXPECTED_COREELEC_BASELINE}." >&2
  exit 1
fi

if [[ "${PROJECT:-}" != "Amlogic-ce" || "${DEVICE:-}" != "Amlogic-ng" || "${ARCH:-}" != "arm" ]]; then
  echo "Unexpected target: PROJECT=${PROJECT:-} DEVICE=${DEVICE:-} ARCH=${ARCH:-}" >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "The CoreELEC build must run as the non-root runner account." >&2
  exit 1
fi

python3 - <<'PY'
import os
import shutil
import sys

workspace = os.environ.get("GITHUB_WORKSPACE", os.getcwd())
free_bytes = shutil.disk_usage(workspace).free
free_gib = free_bytes / (1024 ** 3)
print(f"Free space before build: {free_gib:.1f} GiB")
if free_bytes < 50 * (1024 ** 3):
    print("At least 50 GiB must remain free before building Kodi.", file=sys.stderr)
    sys.exit(1)
PY

if [[ ! -f "${KODI_PACKAGE}" || ! -f "${PATCH_PATH}" ]]; then
  echo "Required Kodi package metadata or device patch is missing." >&2
  exit 1
fi

if ! grep -Fxq "PKG_VERSION=\"${EXPECTED_KODI_VERSION}\"" "${KODI_PACKAGE}"; then
  echo "Kodi package version in ${KODI_PACKAGE} does not match the verified baseline." >&2
  exit 1
fi

actual_patch_sha256="$(sha256sum "${PATCH_PATH}" | awk '{print $1}')"
if [[ "${actual_patch_sha256}" != "${EXPECTED_PATCH_SHA256}" ]]; then
  echo "DVD subtitle patch SHA256 mismatch: ${actual_patch_sha256}" >&2
  exit 1
fi

printf 'CoreELEC HEAD: %s\n' "$(git rev-parse HEAD)"
printf 'Kodi source: %s\n' "${EXPECTED_KODI_VERSION}"
printf 'Patch SHA256: %s  %s\n' "${actual_patch_sha256}" "${PATCH_PATH}"
printf 'Target: %s / %s / %s\n' "${PROJECT}" "${DEVICE}" "${ARCH}"

readonly ARTWORK_PATCH_PATH="projects/Amlogic-ce/devices/Amlogic-ng/patches/kodi/kodi-91-playback-state-artwork.patch"
readonly ARTWORK_PATCH_SHA256="d4be75db321788a567eaa212dcdc7e73f79b34f7603ab1fbc318827498f9bd0d"
if [[ ! -f "${ARTWORK_PATCH_PATH}" ]] || [[ "$(sha256sum "${ARTWORK_PATCH_PATH}" | awk '{print $1}')" != "${ARTWORK_PATCH_SHA256}" ]]; then
  echo "Playback state artwork patch is missing or changed." >&2
  exit 1
fi
printf 'Artwork patch SHA256: %s  %s\n' "${ARTWORK_PATCH_SHA256}" "${ARTWORK_PATCH_PATH}"

# Preserve the original source version/checksum while replacing its dead host.
readonly RTMPDUMP_RECIPE="packages/multimedia/rtmpdump/package.mk"
readonly RTMPDUMP_RECIPE_SHA256="43b1c66dd5785ef031ef50d397cc57aa6800d0e0482ec1572462c26005e787fe"
if [[ "$(sha256sum "${RTMPDUMP_RECIPE}" | awk '{print $1}')" != "${RTMPDUMP_RECIPE_SHA256}" ]]; then
  echo "The verified rtmpdump source override changed." >&2
  exit 1
fi
printf 'rtmpdump recipe SHA256: %s\n' "${RTMPDUMP_RECIPE_SHA256}"

readonly MUSIC_PATCH_PATH="projects/Amlogic-ce/devices/Amlogic-ng/patches/kodi/kodi-92-paplayer-stop-on-error.patch"
readonly MUSIC_PATCH_SHA256="9c618be2fc50456f8883122684cdd340e19b77aa8b213e97e57653c196099ad3"
if [[ ! -f "${MUSIC_PATCH_PATH}" ]] || [[ "$(sha256sum "${MUSIC_PATCH_PATH}" | awk '{print $1}')" != "${MUSIC_PATCH_SHA256}" ]]; then
  echo "Music stop patch from the reviewed pull request is missing or changed." >&2
  exit 1
fi
printf 'Music stop patch SHA256: %s  %s\n' "${MUSIC_PATCH_SHA256}" "${MUSIC_PATCH_PATH}"
