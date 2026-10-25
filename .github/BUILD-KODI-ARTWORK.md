# CoreELEC 21.3: preserve artwork on playback state updates

Pinned to Kodi acc0fc66bc6af69c31a93c5d17e36900343263b7 and Amlogic-ng ARM32.
The existing DVD external-subtitle fix remains included and checksum-verified.

When a changed resume bookmark is saved, SaveFileStateJob broadcasts a copy of
the player FileItem as GUI_MSG_UPDATE_ITEM. A sparse nonempty player art map
can replace a complete library row art map through CFileItem::UpdateInfo.
The database remains intact while the visible card loses poster/fanart/landscape.

The new patch fills the notification's library artwork using the existing
VideoThumbLoader::FillLibraryArt helper before broadcasting the item. This
preserves full artwork for both UpdateInfo recipients and playlist recipients
that replace the entire item, while updating resume, playcount and stream data.
Non-library items retain their existing behavior. The patch does not change
general artwork replacement, scraping or SetArt semantics. A FileItem boundary
regression case covers both recipient styles.

This branch builds a new Kodi executable; it does not automatically deploy,
merge or publish a release. The cold build may take hours. Artifact collection
requires both patches to appear in the build log and records both checksums.
The cross-built unit test is not executed by this package-build workflow.
Compilation alone does not establish real-device correctness.

Build caching restores a pinned toolchain, dependency stamps/install outputs,
source downloads and compiler caches. Kodi's own build stamp and installed
product are excluded so an old successful build cannot skip a changed patch.
Each compiler cache is limited to 1 GiB. A full compressed snapshot is saved
only up to 7 GiB; larger snapshots fall back to compiler caches alone, without
changing repository billing limits. The first build still needs to create
the cache. Cache-filter and round-trip fixtures run on the Ubuntu runner with
its real zstd before the package build. Local fixture checks used a gzip shim
because the local WSL environment did not have zstd.

Device acceptance must include a library movie with valid art: start playback,
seek repeatedly beyond the bookmark threshold (for example to 30 minutes),
stop, and inspect the same unrefreshed list row. Its art fields and displayed
card must remain present. Also verify progress updates and DVD subtitle playback.
