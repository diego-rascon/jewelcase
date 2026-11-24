# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Jewelcase is a Flutter music player client for **Navidrome** servers, speaking the Subsonic/OpenSubsonic REST API. One codebase targets Windows, macOS, Linux, Android and iOS. It should stay simple and lightweight: prefer a small focused change over a new dependency or framework.

## Commands

```sh
flutter pub get
flutter run -d windows                 # or macos, linux, android, ios
flutter analyze                        # flutter_lints + stricter rules in analysis_options.yaml
flutter test                           # all tests
flutter test test/session_test.dart --plain-name "falls back to HTTP"   # single test
dart format lib test tool              # 120 columns (formatter.page_width in analysis_options.yaml)
flutter test tool/generate_icons.dart  # regenerate every platform's app icon
```

The disc logo is drawn in code by `DiscPainter` (`lib/ui/widgets/disc_logo.dart`), used both in the app (`DiscLogo`) and by `tool/generate_icons.dart`. To change the icon, edit the painter and rerun the generator; don't edit the icon PNGs or `.ico` by hand. The generator redraws each existing icon file at its current size. It also writes the Android adaptive-icon layers used by `mipmap-anydpi-v26/ic_launcher.xml`.

`analysis_options.yaml` turns on `unawaited_futures` and `discarded_futures`. A fire-and-forget future must handle its own errors and be wrapped in `unawaited(...)`.

Platform requirements:
- Windows: plugin builds need Developer Mode turned on, for symlink support.
- Linux: needs `libmpv-dev` and `libsecret`.

The app ID is `app.jewelcase.player` on every platform; the Dart package is `jewelcase` (`package:jewelcase/...`).

## Architecture

**Imports:** UI files import `package:material_ui/material_ui.dart`, not `package:flutter/material.dart`. Follow that convention.

**Wiring (`lib/main.dart`):** four long-lived `ChangeNotifier`s are created before `runApp` and provided through `provider`:
- `SessionController`
- `PlayerController`
- `FavoritesController`
- `PlaylistsController`

`NavController` is provided too. A listener on the session calls `attach(client)` on the player, favorites and playlists controllers whenever sign-in state changes. That's how the current `SubsonicClient` reaches them; they never read the session directly. `_Gate` shows the login screen or `AppShell`. `AppShell` is keyed by server URL + username, so switching accounts rebuilds all UI state.

**Session (`lib/state/session.dart`):**
- Owns the client, the selected library (`libraryId`, persisted in shared_preferences) and the credentials (in `flutter_secure_storage`).
- `signIn` tries HTTPS first. It falls back to HTTP only when `isLocalNetworkHost()` is true, or when the user typed `http://` themselves. Don't widen this: a silent downgrade on a public host would send the token in cleartext.

**API layer (`lib/api/`):**
- `SubsonicClient` is a stateless, thin wrapper over `http`. Every request carries token auth params (`u`, `t`, `s`, `v`, `c`, `f=json`).
- Browse methods take an optional `musicFolderId` (the library). Callers pass `session.libraryId`; `null` means all libraries.
- `_get` unwraps `subsonic-response` and turns every failure into a `SubsonicException`. A non-null `code` means the server was reached but rejected the request.
- Never put a request URL or `$e` of an `http.ClientException` into a message: URLs carry the auth token.
- Models in `models.dart` are plain immutable classes with `fromJson`. Use the `jsonList()` helper: Subsonic returns a single object instead of a one-element list when there is only one result.
- `coverUrl`/`coverCacheKey` snap sizes to `SubsonicClient.coverSizes` (150/400/800). This keeps the number of resized copies per cover small. It depends on the salt being fixed per session, so URLs stay stable.

**Playback (`lib/audio/`):**
- `PlayerController` wraps a just_audio `AudioPlayer`. Each `AudioSource` is tagged with its `Song`, and the queue is always derived from the player's sequence state. Don't add a parallel queue list.
- `songs` and `upNext` are cached and rebuilt only when the sequence changes. just_audio re-emits sequence state on every playback event, so the controller notifies listeners only for visible changes.
- In widgets, use `context.select` for the specific fields shown rather than `watch` on the whole controller.
- Scrobbling: a new play is a new current source, or a repeat-one loop (detected through `positionDiscontinuityStream`). Each play sends "now playing", then a submission at `scrobbleThreshold()`: half the track or 4 minutes.
- `JewelcaseAudioHandler` (audio_service) mirrors player state to the OS media session. It's a no-op where unsupported. Windows support comes from `audio_service_win` (SMTC: media keys and the media flyout). `windows/CMakeLists.txt` builds that plugin as C++20, because recent MSVC rejects the C++17 coroutine headers that C++/WinRT uses.
- On Windows and Linux, just_audio uses the `media_kit` (libmpv) backend via `JustAudioMediaKit.ensureInitialized()`.

**Favorites and playlists:**
- `FavoritesController` holds the single set of starred IDs across all libraries, so every heart icon stays in sync. Toggles are optimistic and roll back on error.
- Playlist changes go through `PlaylistsController`, which bumps `revision` after each successful change. Views that list playlists use that revision as an `AsyncView` dependency.
- The server removes playlist songs by position. `PlaylistDetailScreen` therefore blocks further removals until the list has reloaded.

**Navigation (`lib/ui/navigation.dart`, `lib/ui/shell.dart`):**
- Layout is adaptive. At width ≥ `wideLayoutWidth` (840, `isWide()` in `theme.dart`), the app shows a sidebar plus `PlayerBar`; below that, bottom `NavigationBar` tabs plus `MiniPlayer`.
- `NavController` reads the window width itself, so it also works in event handlers.
- Each `Destination` has its own nested `Navigator`, kept alive offstage once visited, so it keeps its history and scroll position.
- Open detail pages with `NavController.push()`, usually through the helpers in `ui/actions.dart` (`openAlbum`, `openArtist`, `openPlaylist`). Don't call `Navigator.push`: `NavController.push()` first closes root-level overlays such as Now Playing, then pushes into the current section.
- On phones, Albums/Artists/Songs/Playlists (`Destination.libraryTabs`) fold into one `library` tab. `NavController.current` maps between the two layouts.
- The wide sidebar has no Playlists item: it lists every playlist under a "Playlists" heading, and each opens with `NavController.openIn(Destination.playlists, …)`. Playlist pages are pushed with a route name (`playlistRouteName`); each section's navigator observer tracks its top route name (`topRouteName`) so the sidebar can highlight the open playlist.

**UI conventions:**
- Server-backed screens load data with `AsyncView` (`widgets/async_view.dart`). It handles loading and error states and reloads when `deps` change. Screens pass `deps: [session.libraryId]` so that switching library refetches.
- Paged or incremental loads, such as `AlbumsScreen`, use a generation counter so responses for an outdated sort or library are dropped.
- Wrap user-triggered API and player calls in `guarded()` from `ui/actions.dart`, which shows errors as a snackbar. Context menus use `MenuAction` with `showActionMenu` or `MoreButton`.
- Build long lists lazily (`ListView.builder`, `SliverList.builder`, `SliverGrid.builder`). Card grids use `cardGrid()`, which already handles narrow widths.
- Anything driven by the position stream sits behind a `RepaintBoundary`, as the seek bar and progress bar do, so it doesn't repaint the blurred Now Playing backdrop.
- Keyboard shortcuts (`PlaybackShortcuts` in `shell.dart`) sit above the root navigator: Space for play/pause, Ctrl/⌘+←/→ for previous/next. They're ignored while a text field has focus.
- Artwork goes through `CoverArt`, which handles caching and a generated placeholder. It requests its laid-out size × device pixel ratio unless `size` is given.
- The theme is dark-only (`buildTheme()`).

## Tests

- `test/subsonic_client_test.dart`: the API client. Tests inject `http/testing.dart`'s `MockClient` through `SubsonicClient(creds, httpClient: ...)` and assert on the request URL and query params.
- `test/session_test.dart`: sign-in rules and persistence. Uses `SessionController(httpClient: ...)`, `FlutterSecureStorage.setMockInitialValues` and `SharedPreferences.setMockInitialValues`.
- `test/state_test.dart`: favorites, playlists and the scrobble threshold.

`PlayerController` itself needs a just_audio platform, so keep its decisions in pure functions (like `scrobbleThreshold`) and test those.
