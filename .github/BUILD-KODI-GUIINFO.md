# CoreELEC 21.3 GUIInfo thread safety

Target: Amlogic-ng ARM32, CoreELEC baseline 8ae70e7c26a5e6ae59ae6a47f5846bd633ac9f56,
Kodi acc0fc66bc6af69c31a93c5d17e36900343263b7.

Backports Kodi PR 29235 / commit 864cb9b8518ffa34f040551cee5efa2d5422a10a.
The existing DVD external-subtitle, playback-state artwork and PAPlayer
stop-on-error patches remain included and independently checksum-verified.

GUIInfoManager currently returns references to a vector while other threads
may append and reallocate it. Every multi-info reader now takes a bounded copy
under a dedicated lock; id-chain reads use a locked scalar accessor. Skin
variables similarly copy under the existing info lock and evaluate outside it.

The device's music-start crash dereferenced an invalid CGUIInfo reference in
GetMultiInfoBool. This backport removes the matching upstream lifetime defect;
the original core was unavailable, so the defect is not claimed as the uniquely
proven cause of that historical crash.

Local checks apply the patch to the pinned source; CI compiles the full target
and requires all four patch names in dependency/build logs. Device validation
must verify the running binary hash, media UI transitions, ordinary playback,
failed music opens and preservation of DVD/artwork behavior. This branch does
not automatically deploy or publish a release.

Builds run on codex/fix-playback-state-artwork to reuse the existing scoped compiler caches. The cache prefix and the original three patch checksums remain unchanged.
