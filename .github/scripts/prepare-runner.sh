#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  echo "The CoreELEC build must run as the non-root runner account." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]] || ! grep -qE '^VERSION_ID="22\.04"$' /etc/os-release; then
  echo "This workflow expects the GitHub-hosted Ubuntu 22.04 runner." >&2
  exit 1
fi

# These are fixed paths for SDKs preinstalled on GitHub's Ubuntu runner and
# unused by this cross-build. Do not broaden this list to general system paths.
for sdk_path in /usr/local/lib/android /usr/share/dotnet /opt/ghc \
                /usr/local/.ghcup /usr/local/swift /usr/share/swift \
                /usr/local/share/boost /usr/local/share/powershell; do
  if [[ -d "${sdk_path}" && ! -L "${sdk_path}" ]]; then
    echo "Removing unused runner SDK: ${sdk_path}"
    sudo rm -rf -- "${sdk_path}"
  fi
done

python3 - <<'PY'
import os
import shutil
import sys

workspace = os.environ.get("GITHUB_WORKSPACE", os.getcwd())
free_bytes = shutil.disk_usage(workspace).free
free_gib = free_bytes / (1024 ** 3)
required_bytes = 50 * (1024 ** 3)
print(f"Workspace free space after safe SDK cleanup: {free_gib:.1f} GiB")
if free_bytes < required_bytes:
    print("At least 50 GiB free space is required before building Kodi.", file=sys.stderr)
    sys.exit(1)
PY

echo "Runner preflight passed for $(id -un)."
