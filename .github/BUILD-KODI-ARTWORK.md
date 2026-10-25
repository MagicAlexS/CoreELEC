# CoreELEC 21.3: preserve artwork on playback state updates

Pinned to Kodi acc0fc66bc6af69c31a93c5d17e36900343263b7 and Amlogic-ng ARM32.
The existing DVD external-subtitle fix remains included and checksum-verified.

When a changed resume bookmark is saved, SaveFileStateJob broadcasts a copy of
the player FileItem as GUI_MSG_UPDATE_ITEM. A sparse nonempty player art map
can replace a complete library row art map through CFileItem::UpdateInfo.
The database remains intact while the visible card loses poster/fanart/landscape.

The new patch excludes artwork from this playback-state notification, preserving
the recipient's artwork while still updating resume, playcount and stream data.
It does not change general artwork replacement, scraping or SetArt semantics.
ClearArt also resets libraryartfilled, allowing the existing loader to refill
art on a later load. A FileItem boundary regression case accompanies the fix.

This branch builds a new Kodi executable; it does not automatically deploy,
merge or publish a release. The cold build may take hours. Artifact collection
requires both patches to appear in the build log and records both checksums.
The cross-built unit test is not executed by this package-build workflow.
Compilation alone does not establish real-device correctness.

Device acceptance must include a library movie with valid art: start playback,
seek repeatedly beyond the bookmark threshold (for example to 30 minutes),
stop, and inspect the same unrefreshed list row. Its art fields and displayed
card must remain present. Also verify progress updates and DVD subtitle playback.
