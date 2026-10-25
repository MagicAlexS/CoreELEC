#!/usr/bin/env bash
set -o pipefail

if [[ "${MTWITHLOCKS:-}" == "yes" ]]; then
  echo "Kodi dependency checkpoint requires CoreELEC's sequential build mode." >&2
  exit 2
fi

export PROJECT="${PROJECT:-Amlogic-ce}"
export DEVICE="${DEVICE:-Amlogic-ng}"
export ARCH="${ARCH:-arm}"

# Sourcing options loads Kodi's package.mk and runs configure_package(), which
# is where this baseline appends target dependencies for the selected device.
. config/options kodi

read -r -a dependencies <<< "${PKG_DEPENDS_TARGET:-}"
if [[ "${#dependencies[@]}" -eq 0 ]]; then
  echo "CoreELEC did not resolve any Kodi target dependencies." >&2
  exit 2
fi

parent_pkg="${PKG_NAME}:target"
printf 'Resolved Kodi target dependencies (%d): %s\n' \
  "${#dependencies[@]}" "${dependencies[*]}"

for dependency in "${dependencies[@]}"; do
  printf '\n=== Build dependency %s (parent %s) ===\n' "${dependency}" "${parent_pkg}"
  if ./scripts/build "${dependency}" "${parent_pkg}"; then
    continue
  else
    status=$?
    echo "Dependency build failed: ${dependency} (status ${status})" >&2
    exit "${status}"
  fi
done

printf '\nAll Kodi target dependencies built successfully.\n'
