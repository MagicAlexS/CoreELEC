#!/usr/bin/env python3
"""Collect the Kodi binary installed by scripts/build kodi."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
from datetime import datetime, timezone


COREELEC_BASELINE = "8ae70e7c26a5e6ae59ae6a47f5846bd633ac9f56"
KODI_VERSION = "acc0fc66bc6af69c31a93c5d17e36900343263b7"
PATCH_PATH = Path(
    "projects/Amlogic-ce/devices/Amlogic-ng/patches/kodi/"
    "kodi-90-dvd-external-subtitle-visibility.patch"
)
PATCH_SHA256 = "567336a6fdfcf802f02cf8b0b1295801ed5abfca20a35f13ca1b319b006de127"
PATCH_FILENAME = PATCH_PATH.name
ARTWORK_PATCH_PATH = Path("projects/Amlogic-ce/devices/Amlogic-ng/patches/kodi/kodi-91-playback-state-artwork.patch")
ARTWORK_PATCH_SHA256 = "d4be75db321788a567eaa212dcdc7e73f79b34f7603ab1fbc318827498f9bd0d"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts"))
    args = parser.parse_args()

    root = Path.cwd()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    patch = root / PATCH_PATH
    if not patch.is_file() or sha256(patch) != PATCH_SHA256:
        raise RuntimeError("The expected DVD subtitle patch is missing or changed.")

    artwork_patch = root / ARTWORK_PATCH_PATH
    if not artwork_patch.is_file() or sha256(artwork_patch) != ARTWORK_PATCH_SHA256:
        raise RuntimeError("The expected playback artwork patch is missing or changed.")

    build_log = output_dir / "build.log"
    if not build_log.is_file() or PATCH_FILENAME not in build_log.read_text(errors="replace"):
        raise RuntimeError("Build log does not confirm that the device patch was applied.")

    if ARTWORK_PATCH_PATH.name not in build_log.read_text(errors="replace"):
        raise RuntimeError("Build log does not confirm the playback artwork patch was applied.")

    pattern = f"build.CoreELEC-Amlogic-ng.arm-*/install_pkg/kodi-{KODI_VERSION}/usr/lib/kodi/kodi.bin"
    candidates = sorted(root.glob(pattern))
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected one Kodi binary matching {pattern!r}; found {len(candidates)}."
        )

    source = candidates[0]
    if not source.is_file() or source.stat().st_size == 0:
        raise RuntimeError(f"Kodi binary is missing or empty: {source}")
    with source.open("rb") as handle:
        header = handle.read(20)
    if (len(header) != 20 or header[:6] != b"\x7fELF\x01\x01" or
            struct.unpack("<H", header[18:20])[0] != 40):
        raise RuntimeError("Expected a little-endian 32-bit ARM ELF Kodi executable")

    binary = output_dir / "kodi.bin"
    shutil.copy2(source, binary)
    binary_sha256 = sha256(binary)
    manifest = {
        "artifact": binary.name,
        "artifact_size_bytes": binary.stat().st_size,
        "artifact_sha256": binary_sha256,
        "coreelec_baseline": COREELEC_BASELINE,
        "coreelec_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True
        ).strip(),
        "kodi_source_revision": KODI_VERSION,
        "patch_path": PATCH_PATH.as_posix(),
        "patch_sha256": PATCH_SHA256,
        "artwork_patch_path": ARTWORK_PATCH_PATH.as_posix(),
        "artwork_patch_sha256": ARTWORK_PATCH_SHA256,
        "project": "Amlogic-ce",
        "device": "Amlogic-ng",
        "arch": "arm",
        "built_at_utc": datetime.now(timezone.utc).isoformat(),
        "runner_os": os.environ.get("ImageOS", "ubuntu-22.04"),
        "source_artifact_path": source.relative_to(root).as_posix(),
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (output_dir / "SHA256SUMS").write_text(
        f"{binary_sha256}  kodi.bin\n", encoding="utf-8"
    )
    print(f"Collected {binary} ({binary.stat().st_size} bytes)")
    print(f"SHA256: {binary_sha256}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Artifact collection failed: {exc}", file=sys.stderr)
        sys.exit(1)
