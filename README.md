# Jewelcase

A simple, good-looking music player for your **Navidrome** server — one Flutter
codebase for Windows, macOS, Linux, Android and iOS.

- **Home** — recently played, recently added, favorites, most played, rediscover; one-tap shuffle.
- **Albums** — sortable grid (added, title, artist, played, random) with infinite scroll.
- **Artists** — A–Z list with jump strip; artist pages with bio, popular songs, discography, similar artists.
- **Playlists** — browse, play, create, add to, remove from, delete.
- **Favorites** — songs, albums and artists, synced with Navidrome stars.
- **Libraries** — switch between Navidrome libraries (music folders) from the sidebar or Settings.
- **Search** across artists, albums and songs.
- **Now Playing** — full-screen player tinted by the album art, queue with reorder/remove.
- Scrobbles plays back to Navidrome (so "Recently/Most played" and Last.fm/ListenBrainz work).
- Lock screen / notification / headset controls on mobile; Space and Ctrl+←/→ on desktop.

Layout adapts by width: sidebar + player bar on desktop/tablet, bottom tabs + mini player on phones.

## Running

```sh
flutter pub get
flutter run -d windows   # or macos, linux, android, ios
```

On Windows, plugin builds need **Developer Mode** (Settings → System → For developers), for symlink support.
Linux needs `libmpv` (`sudo apt install libmpv-dev`) and `libsecret`.

Sign in with your server address (e.g. `music.example.com` or `192.168.1.10:4533` — HTTPS is tried first, then HTTP),
username and password. Only a salted token is stored (in the OS keychain), never the password.

## Code map

```
lib/
  api/          Subsonic client + models (token auth, JSON)
  audio/        PlayerController (just_audio queue) + OS media session bridge
  state/        Session (server, library), Favorites
  ui/           theme, adaptive shell, navigation, screens/, widgets/
```

Playback uses `just_audio` (with the `media_kit` backend on Windows/Linux) and `audio_service`.

```sh
flutter test      # API client tests
flutter analyze
```
