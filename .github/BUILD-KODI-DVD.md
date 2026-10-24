# CoreELEC 21.3: DVD external subtitle visibility candidate

This branch builds a candidate fix for the existing CoreELEC 21.3
`Amlogic-ng.arm` runtime. It does not migrate the device to CoreELEC 22.

Pinned baselines:

- CoreELEC build system: `8ae70e7c26a5e6ae59ae6a47f5846bd633ac9f56`
- Kodi source: `acc0fc66bc6af69c31a93c5d17e36900343263b7`
- Target: `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=arm`

The source fix separates the visibility of external TEXT/DEMUX_SUB subtitles
from DVD navigator SPU state. Native DVD subtitles keep the existing navigator
path. The patch also accounts for asynchronous subtitle loading and the cached
selection when switching back to native DVD subtitles.

The workflow runs only on `codex/fix-dvd-external-subtitles` pushes or a manual
dispatch of that branch. It checks the pinned Kodi package and patch digest,
prepares the Ubuntu 22.04 runner, and calls `./scripts/build kodi` as a non-root
user. There is no device deployment, release publication, or automatic merge.

Downloads are under the workflow run's Artifacts section:

- `kodi.bin`: rebuilt ARM32 Kodi executable
- `SHA256SUMS` and `manifest.json`: binary digest, source revisions, target,
  patch digest, and build identity
- preflight, dependency, source verification, and build logs

The first build is a cold toolchain/dependency build. The workflow needs at
least 50 GiB of free space after removing listed unused SDKs on the disposable
GitHub runner, and limits the build step to five hours. Logs are uploaded even
on failure. No complete build directory is cached.

Successful compilation does not establish playback correctness. Before
testing the new executable, remove any separate runtime-memory workaround.
First test the rebuilt program with a reversible replacement on the matching
21.3 system. Verify external ASS/SRT, user on/off, external/native switching,
seek/chapter changes, DVD menus, forced subtitles, and ordinary media playback.
Do not treat this candidate as a general firmware upgrade.
