# Blu-ray playback and subtitle fixes

This change set updates the CoreELEC Blu-ray runtime and fixes native Kodi
playback behavior. The Kodi backports are applied by the Amlogic-ng package.

## Runtime

- Update libbluray to 1.5.0 and libudfread to 1.2.0 using their Meson builds.
- Build and package the BD-J Java implementation from the same libbluray version.
- Retain CoreELEC clip timing, playlist and 3D subtitle interfaces, the writable
  Java temporary directory, and both existing seek corrections. The duration
  clamp now targets the 1.5.0 `_seek_time()` implementation.

The Kodi patches and the libbluray menu extensions must be built together.
The added `bd_menu_back()` and `bd_menu_close()` interfaces are local extensions;
stock libbluray does not provide them.

## Navigation and rendering

- Keep menu overlays alive until their explicit release and drain buffered data
  at natural title boundaries before reporting the end of a title.
- Synchronize audio and presentation-graphics stream selections with libbluray,
  including subtitle visibility, while preserving external subtitle handling.
- Track HDMV page history only within the active menu interaction. Reset that
  history across seeks and playback transitions, so returning through menu pages
  does not seek back to an earlier playback position.
- Close menu graphics without changing the current playlist or playback time.
  Keep decoded menu resources available for explicit reopening.
- Route native Back/OSD actions according to active disc navigation, and suspend
  menu overlays while player dialogs are shown.
- Interrupt old buffered data for explicit user navigation instead of waiting
  for the previous menu audio to drain. Preserve draining at natural EOF.

Hierarchical page return and explicit graphics closure are implemented for HDMV.
BD-J uses the existing navigation fallback and has not received equivalent
cross-disc compatibility testing.

## Subtitle browsing and information

The subtitle file browser starts at the current media directory. Blu-ray URLs
are unwrapped to their source; files inside BDMV/PLAYLIST or BDMV/STREAM resolve
to the directory containing BDMV. Nested UDF image sources resolve to the image's
containing directory. Archive handling and additional subtitle sources remain
available; a usable movie directory takes priority as the initial location.

`VideoPlayer.SubtitleCount` is a new read-only integer/label exposing the current
player subtitle stream count. It follows actual stream availability, including
asynchronously loaded external subtitles, rather than the loading request.

## Context-menu initialization

Resource allocation can reload conditional controls after the context-menu
choices have already been prepared. Before restoring initial focus, Kodi now
recreates missing generated choices from the retained choice list. The normal
path keeps its existing controls, avoiding duplicate entries and preserving
selection/cancellation semantics.

## Validation

- SHA-256 checks for both release source archives.
- All libbluray recipe patches applied to a fresh 1.5.0 archive and compared
  byte-for-byte with the compiled source files.
- Kodi backport patches replayed in order against the existing patched baseline.
- Package shell syntax and Git whitespace checks.
- Incremental ARM cross-compilation and linking, followed by device deployment
  on CoreELEC 21.3 Amlogic-ng with Amlogic hardware decoding.
- Device checks covered menu rendering, chapter transitions, page return without
  a playback jump, menu/dialog separation, audio/PG selection, subtitle browser
  roots, and live subtitle-count changes.

This is focused runtime validation, not a new full image build or a claim of
compatibility with every disc, physical drive, archive or UDF image.
