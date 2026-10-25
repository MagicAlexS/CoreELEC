#!/usr/bin/env python3
"""Bounded cache snapshot support for the pinned CoreELEC Kodi build."""

from __future__ import annotations

import argparse
import os
import posixpath
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path, PurePosixPath


BUILD_ROOT_NAME = os.environ.get(
    "COREELEC_BUILD_DIR", "build.CoreELEC-Amlogic-ng.arm-21"
)
KODI_SOURCE_VERSION = os.environ.get(
    "KODI_SOURCE_SHA", "acc0fc66bc6af69c31a93c5d17e36900343263b7"
)
MAX_SNAPSHOT_BYTES = int(os.environ.get("COREELEC_CACHE_MAX_BYTES", 7 * 1024**3))
CCACHE_LIMIT = os.environ.get("CCACHE_MAXSIZE", "1G")
ARCHIVE_DEFAULT = Path(".coreelec-build-cache.tar.zst")


def log(message: str) -> None:
    print(f"[build-cache] {message}", flush=True)


def github_output(**values: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as stream:
        for key, value in values.items():
            stream.write(f"{key}={value}\n")


def workspace() -> Path:
    return Path(os.environ.get("GITHUB_WORKSPACE", os.getcwd())).resolve()


def build_root(root: Path) -> Path:
    return root / BUILD_ROOT_NAME


def selected_paths(root: Path, mode: str) -> list[str]:
    build = BUILD_ROOT_NAME
    if mode == "ccache":
        candidates = [f"{build}/.ccache", f"{build}/.ccache-local"]
    else:
        candidates = [
            f"{build}/toolchain",
            f"{build}/.stamps",
            f"{build}/install_pkg",
            f"{build}/.ccache",
            f"{build}/.ccache-local",
            "sources",
        ]
    return [name for name in candidates if (root / name).exists()]


def tar_excludes() -> list[str]:
    build = BUILD_ROOT_NAME
    return [
        f"{build}/.stamps/kodi",
        f"{build}/.stamps/kodi/*",
        f"{build}/install_pkg/kodi-{KODI_SOURCE_VERSION}",
        f"{build}/install_pkg/kodi-{KODI_SOURCE_VERSION}/**",
    ]


def run_tar_zstd(root: Path, paths: list[str], output: Path) -> None:
    zstd = shutil.which("zstd")
    tar = shutil.which("tar")
    if not zstd or not tar:
        raise RuntimeError("tar or zstd is unavailable; cache snapshot skipped")
    command = [tar, "--create", "--file=-", "--directory", str(root)]
    for pattern in tar_excludes():
        command.extend(("--exclude", pattern))
    command.extend(("--", *paths))
    tmp = output.with_name(output.name + ".tmp")
    tmp.unlink(missing_ok=True)
    tar_proc = subprocess.Popen(command, stdout=subprocess.PIPE)
    assert tar_proc.stdout is not None
    zstd_proc = subprocess.run(
        [zstd, "-q", "-3", "-T0", "-f", "-o", str(tmp)],
        stdin=tar_proc.stdout,
        check=False,
    )
    tar_proc.stdout.close()
    tar_status = tar_proc.wait()
    if zstd_proc.returncode != 0 or tar_status != 0:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(
            f"snapshot command failed (tar={tar_status}, zstd={zstd_proc.returncode})"
        )
    os.replace(tmp, output)


def is_under(path: str, root: str) -> bool:
    return path == root or path.startswith(root + "/")


def allowed_roots() -> tuple[str, ...]:
    b = BUILD_ROOT_NAME
    return (
        f"{b}/toolchain",
        f"{b}/.stamps",
        f"{b}/install_pkg",
        f"{b}/.ccache",
        f"{b}/.ccache-local",
        "sources",
    )


def is_forbidden(path: str) -> bool:
    b = BUILD_ROOT_NAME
    if is_under(path, f"{b}/.stamps/kodi"):
        return True
    return is_under(path, f"{b}/install_pkg/kodi-{KODI_SOURCE_VERSION}")


def normalized_member_name(name: str) -> str:
    while name.startswith("./"):
        name = name[2:]
    path = PurePosixPath(name)
    if not name or path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"unsafe archive path: {name!r}")
    return path.as_posix()


def validate_target(target: str) -> str:
    target = target.replace("\\", "/")
    if target.startswith("/"):
        root = workspace().as_posix().rstrip("/")
        if not target.startswith(root + "/"):
            raise ValueError(f"archive link escapes workspace: {target!r}")
        target = target[len(root) + 1 :]
    else:
        target = posixpath.normpath(target)
    if target in ("", ".") or target.startswith("../") or target == "..":
        raise ValueError(f"unsafe archive link target: {target!r}")
    target = PurePosixPath(target).as_posix()
    if not any(is_under(target, allowed) for allowed in allowed_roots()):
        raise ValueError(f"archive link leaves cached roots: {target!r}")
    if is_forbidden(target):
        raise ValueError(f"archive link targets excluded Kodi output: {target!r}")
    return target


def inspect_archive(archive: Path) -> tuple[str, int]:
    zstd = shutil.which("zstd")
    if not zstd:
        raise RuntimeError("zstd is unavailable; cache restore skipped")
    process = subprocess.Popen(
        [zstd, "-q", "-d", "-c", str(archive)], stdout=subprocess.PIPE
    )
    assert process.stdout is not None
    names: set[str] = set()
    roots_seen: set[str] = set()
    try:
        with tarfile.open(fileobj=process.stdout, mode="r|") as tar:
            for member in tar:
                name = normalized_member_name(member.name)
                if not any(is_under(name, root) for root in allowed_roots()):
                    raise ValueError(f"archive path outside cache allowlist: {name!r}")
                if is_forbidden(name):
                    raise ValueError(f"archive contains excluded Kodi output: {name!r}")
                if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                    raise ValueError(f"unsupported archive entry type: {name!r}")
                if member.issym() or member.islnk():
                    link_base = posixpath.dirname(name) if member.issym() else ""
                    target = posixpath.normpath(posixpath.join(link_base, member.linkname))
                    validate_target(target)
                names.add(name)
                for allowed in allowed_roots():
                    if is_under(name, allowed):
                        roots_seen.add(allowed)
                        break
        process.stdout.close()
        if process.wait() != 0:
            raise ValueError("zstd could not decode the full cache archive")
    except Exception:
        process.kill()
        process.wait()
        raise
    if not names:
        raise ValueError("cache archive is empty")
    mode = "full" if f"{BUILD_ROOT_NAME}/toolchain" in roots_seen else "ccache-only"
    return mode, len(names)


def safe_extract(archive: Path, root: Path) -> None:
    zstd = shutil.which("zstd")
    tar = shutil.which("tar")
    if not zstd or not tar:
        raise RuntimeError("tar or zstd is unavailable; cache restore skipped")
    # Refuse to merge into pre-existing build roots: hosted runners should be clean.
    for rel in (BUILD_ROOT_NAME, "sources"):
        candidate = root / rel
        if candidate.is_symlink():
            raise ValueError(f"refusing cache restore through symlink: {rel}")
        if candidate.exists():
            if candidate.is_dir() and not any(candidate.iterdir()):
                candidate.rmdir()
            else:
                raise ValueError(f"refusing cache restore into existing path: {rel}")
    cmd = [zstd, "-q", "-d", "-c", str(archive)]
    zproc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    assert zproc.stdout is not None
    tar_proc = subprocess.run(
        [
            tar,
            "--extract",
            "--file=-",
            "--directory",
            str(root),
            "--no-same-owner",
            "--no-same-permissions",
        ],
        stdin=zproc.stdout,
        check=False,
    )
    zproc.stdout.close()
    zstd_status = zproc.wait()
    if tar_proc.returncode != 0 or zstd_status != 0:
        for rel in (BUILD_ROOT_NAME, "sources"):
            candidate = root / rel
            if candidate.is_symlink():
                candidate.unlink(missing_ok=True)
            elif candidate.is_dir():
                shutil.rmtree(candidate, ignore_errors=True)
            elif candidate.exists():
                candidate.unlink(missing_ok=True)
        raise RuntimeError(
            f"restore extraction failed (tar={tar_proc.returncode}, zstd={zstd_status})"
        )


def restore(archive: Path) -> int:
    archive = archive.resolve()
    if not archive.is_file():
        log("cache miss; starting from clean build paths")
        return 0
    try:
        mode, entry_count = inspect_archive(archive)
        safe_extract(archive, workspace())
    except Exception as exc:
        log(f"snapshot rejected or unreadable; ignoring cache: {exc}")
        archive.unlink(missing_ok=True)
        return 0
    size = archive.stat().st_size
    log(f"restored mode={mode}, compressed_size={size} bytes, entries={entry_count}")
    archive.unlink(missing_ok=True)
    return 0


def ccache_binary(root: Path) -> str | None:
    found = shutil.which("ccache")
    if found:
        return found
    for candidate in (build_root(root) / "toolchain/bin/ccache",):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def trim_ccache() -> int:
    root = workspace()
    binary = ccache_binary(root)
    if not binary:
        log("ccache binary not found yet; CCACHE_MAXSIZE=1G remains set for the build")
        return 0
    for cache_dir in (build_root(root) / ".ccache", build_root(root) / ".ccache-local"):
        if not cache_dir.is_dir():
            continue
        env = os.environ.copy()
        env["CCACHE_DIR"] = str(cache_dir)
        env["CCACHE_MAXSIZE"] = CCACHE_LIMIT
        result = subprocess.run([binary, "--cleanup"], env=env, check=False)
        if result.returncode:
            log(f"ccache cleanup failed for {cache_dir}; build continues")
        subprocess.run([binary, "--show-stats"], env=env, check=False)
    log(f"ccache limit applied per directory: {CCACHE_LIMIT}")
    return 0


def pack(archive: Path) -> int:
    root = workspace()
    archive = (root / archive).resolve() if not archive.is_absolute() else archive.resolve()
    archive.parent.mkdir(parents=True, exist_ok=True)
    archive.unlink(missing_ok=True)
    modes = (("full", selected_paths(root, "full")), ("ccache-only", selected_paths(root, "ccache")))
    zstd = shutil.which("zstd")
    if not zstd:
        log("zstd is unavailable; not saving build cache")
        github_output(save="false", mode="skipped", size_bytes="0")
        return 0
    for mode, paths in modes:
        if not paths or (mode == "full" and f"{BUILD_ROOT_NAME}/toolchain" not in paths):
            log(f"mode={mode} unavailable; trying smaller cache")
            continue
        try:
            run_tar_zstd(root, paths, archive)
        except Exception as exc:
            log(f"mode={mode} pack failed: {exc}; trying smaller cache")
            archive.unlink(missing_ok=True)
            continue
        size = archive.stat().st_size
        try:
            archive_mode, entry_count = inspect_archive(archive)
            if archive_mode != mode:
                raise ValueError(f"snapshot mode mismatch: expected {mode}, got {archive_mode}")
        except Exception as exc:
            log(f"mode={mode} snapshot validation failed: {exc}; trying smaller cache")
            archive.unlink(missing_ok=True)
            continue
        log(
            f"mode={mode}, compressed_size={size} bytes, entries={entry_count}, "
            f"limit={MAX_SNAPSHOT_BYTES} bytes"
        )
        if size <= MAX_SNAPSHOT_BYTES:
            github_output(save="true", mode=mode, size_bytes=str(size))
            return 0
        archive.unlink(missing_ok=True)
        if mode == "full":
            log("full snapshot exceeds the configured budget; falling back to ccache-only")
    log("no cache snapshot fits the configured budget; build result is still retained as an artifact")
    github_output(save="false", mode="skipped", size_bytes="0")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("restore", "pack", "trim-ccache"))
    parser.add_argument("--archive", type=Path, default=ARCHIVE_DEFAULT)
    args = parser.parse_args()
    if args.mode == "restore":
        return restore(args.archive)
    if args.mode == "pack":
        return pack(args.archive)
    return trim_ccache()


if __name__ == "__main__":
    raise SystemExit(main())
