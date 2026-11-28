// Plain data classes mapped from the Subsonic/OpenSubsonic JSON API that
// Navidrome implements.

typedef Json = Map<String, dynamic>;

List<Json> jsonList(Object? value) {
  if (value is List) return value.cast<Json>();
  if (value is Map) return [value.cast<String, dynamic>()];
  return const [];
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) => v == null ? null : _int(v);
String? _str(Object? v) => v?.toString();
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

class MusicFolder {
  const MusicFolder({required this.id, required this.name});

  final String id;
  final String name;

  factory MusicFolder.fromJson(Json j) => MusicFolder(id: '${j['id']}', name: _str(j['name']) ?? 'Library');
}

class Song {
  const Song({
    required this.id,
    required this.title,
    this.album,
    this.albumId,
    this.artist,
    this.artistId,
    this.track,
    this.discNumber,
    this.year,
    this.duration = Duration.zero,
    this.coverArt,
    this.starred = false,
    this.suffix,
    this.bitRate,
    this.played,
  });

  final String id;
  final String title;
  final String? album;
  final String? albumId;
  final String? artist;
  final String? artistId;
  final int? track;
  final int? discNumber;
  final int? year;
  final Duration duration;
  final String? coverArt;
  final bool starred;
  final String? suffix;
  final int? bitRate;

  /// Last play (OpenSubsonic); null if never played or not reported.
  final DateTime? played;

  factory Song.fromJson(Json j) => Song(
    id: '${j['id']}',
    title: _str(j['title']) ?? 'Unknown title',
    album: _str(j['album']),
    albumId: _str(j['albumId']),
    artist: _str(j['artist']),
    artistId: _str(j['artistId']),
    track: _intOrNull(j['track']),
    discNumber: _intOrNull(j['discNumber']),
    year: _intOrNull(j['year']),
    duration: Duration(seconds: _int(j['duration'])),
    coverArt: _str(j['coverArt']),
    starred: j['starred'] != null,
    suffix: _str(j['suffix']),
    bitRate: _intOrNull(j['bitRate']),
    played: _date(j['played']),
  );
}

class Album {
  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount = 0,
    this.duration = Duration.zero,
    this.year,
    this.genres = const [],
    this.starred = false,
    this.created,
    this.played,
    this.songs = const [],
  });

  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int songCount;
  final Duration duration;
  final int? year;

  /// Every genre of the album (OpenSubsonic `genres`), or the single
  /// Subsonic `genre` on servers without it.
  final List<String> genres;
  final bool starred;

  /// When the album was added to the library.
  final DateTime? created;

  /// Last play (OpenSubsonic); null if never played or not reported.
  final DateTime? played;

  /// Only populated by `getAlbum`.
  final List<Song> songs;

  factory Album.fromJson(Json j) => Album(
    id: '${j['id']}',
    name: _str(j['name'] ?? j['title']) ?? 'Unknown album',
    artist: _str(j['artist']),
    artistId: _str(j['artistId']),
    coverArt: _str(j['coverArt']),
    songCount: _int(j['songCount']),
    duration: Duration(seconds: _int(j['duration'])),
    year: _intOrNull(j['year']),
    genres: _genres(j),
    starred: j['starred'] != null,
    created: _date(j['created']),
    played: _date(j['played']),
    songs: jsonList(j['song']).map(Song.fromJson).toList(),
  );

  static List<String> _genres(Json j) {
    final names = {for (final g in jsonList(j['genres'])) ?_str(g['name'])}.where((n) => n.isNotEmpty).toList();
    if (names.isNotEmpty) return names;
    final single = _str(j['genre']);
    return single == null || single.isEmpty ? const [] : [single];
  }
}

class Genre {
  const Genre({required this.name, required this.albumCount});

  final String name;
  final int albumCount;
}

/// The genres of [albums] with how many albums carry each, by name. Counted
/// here rather than taken from `getGenres`, whose counts the server saves at
/// scan time: they include missing albums and every library, so they don't
/// match what `getAlbumList2?type=byGenre` returns.
List<Genre> genresOf(Iterable<Album> albums) {
  final ids = <String, Set<String>>{};
  for (final album in albums) {
    for (final g in album.genres) {
      (ids[g] ??= {}).add(album.id);
    }
  }
  return [for (final MapEntry(:key, :value) in ids.entries) Genre(name: key, albumCount: value.length)]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// [items] with the newest [date] first and undated items last. Ties keep
/// their order (List.sort isn't stable, so they're broken by position).
List<T> newestFirst<T>(Iterable<T> items, DateTime? Function(T) date) {
  final indexed = [for (final (i, item) in items.indexed) (i, item, date(item))]
    ..sort((a, b) {
      final (ia, _, da) = a;
      final (ib, _, db) = b;
      final c = da == null
          ? (db == null ? 0 : 1)
          : db == null
          ? -1
          : db.compareTo(da);
      return c != 0 ? c : ia.compareTo(ib);
    });
  return [for (final (_, item, _) in indexed) item];
}

/// The latest play of each key's albums, for ordering things that have no
/// play date of their own (artists, genres) by their albums'.
Map<String, DateTime> _lastPlayed(Iterable<Album> albums, Iterable<String> Function(Album) keys) {
  final last = <String, DateTime>{};
  for (final album in albums) {
    final played = album.played;
    if (played == null) continue;
    for (final key in keys(album)) {
      final prev = last[key];
      if (prev == null || played.isAfter(prev)) last[key] = played;
    }
  }
  return last;
}

/// [artists], the one whose album was played last first; artists never
/// played keep their order at the end.
List<Artist> artistsByRecentPlay(List<Artist> artists, Iterable<Album> albums) {
  final last = _lastPlayed(albums, (a) => [?a.artistId]);
  return newestFirst(artists, (a) => last[a.id]);
}

/// The genres of [albums] (see [genresOf]), the one whose album was played
/// last first; genres never played follow by name.
List<Genre> genresByRecentPlay(Iterable<Album> albums) {
  final last = _lastPlayed(albums, (a) => a.genres);
  return newestFirst(genresOf(albums), (g) => last[g.name]);
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.coverArt,
    this.imageUrl,
    this.albumCount = 0,
    this.starred = false,
    this.albums = const [],
  });

  final String id;
  final String name;
  final String? coverArt;
  final String? imageUrl;
  final int albumCount;
  final bool starred;

  /// Only populated by `getArtist`.
  final List<Album> albums;

  factory Artist.fromJson(Json j) => Artist(
    id: '${j['id']}',
    name: _str(j['name']) ?? 'Unknown artist',
    coverArt: _str(j['coverArt']),
    imageUrl: _str(j['artistImageUrl']),
    albumCount: _int(j['albumCount']),
    starred: j['starred'] != null,
    albums: jsonList(j['album']).map(Album.fromJson).toList(),
  );
}

class ArtistInfo {
  const ArtistInfo({this.biography, this.imageUrl, this.similar = const []});

  final String? biography;
  final String? imageUrl;
  final List<Artist> similar;

  factory ArtistInfo.fromJson(Json j) => ArtistInfo(
    biography: _cleanBio(_str(j['biography'])),
    imageUrl: _str(j['largeImageUrl'] ?? j['mediumImageUrl']),
    similar: jsonList(j['similarArtist']).map(Artist.fromJson).toList(),
  );

  // Last.fm bios end with an HTML "Read more" link; strip any markup.
  static String? _cleanBio(String? bio) {
    if (bio == null) return null;
    final text = bio.replaceAll(RegExp(r'<a [^>]*>.*?</a>\.?'), '').replaceAll(RegExp(r'<[^>]+>'), '').trim();
    return text.isEmpty ? null : text;
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.songCount = 0,
    this.duration = Duration.zero,
    this.coverArt,
    this.changed,
    this.songs = const [],
  });

  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final int songCount;
  final Duration duration;
  final String? coverArt;

  /// Last edit. The server doesn't record when a playlist was played.
  final DateTime? changed;

  /// Only populated by `getPlaylist`.
  final List<Song> songs;

  factory Playlist.fromJson(Json j) => Playlist(
    id: '${j['id']}',
    name: _str(j['name']) ?? 'Untitled playlist',
    comment: _str(j['comment']),
    owner: _str(j['owner']),
    songCount: _int(j['songCount']),
    duration: Duration(seconds: _int(j['duration'])),
    coverArt: _str(j['coverArt']),
    changed: _date(j['changed']),
    songs: jsonList(j['entry']).map(Song.fromJson).toList(),
  );
}

class SearchResults {
  const SearchResults({this.artists = const [], this.albums = const [], this.songs = const []});

  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  factory SearchResults.fromJson(Json j) => SearchResults(
    artists: jsonList(j['artist']).map(Artist.fromJson).toList(),
    albums: jsonList(j['album']).map(Album.fromJson).toList(),
    songs: jsonList(j['song']).map(Song.fromJson).toList(),
  );
}

/// Sort orders accepted by `getAlbumList2`.
enum AlbumSort {
  newest('newest', 'Recently added'),
  recent('recent', 'Recently played'),
  frequent('frequent', 'Most played'),
  alphabeticalByName('alphabeticalByName', 'Title'),
  alphabeticalByArtist('alphabeticalByArtist', 'Artist'),
  random('random', 'Random'),
  starred('starred', 'Favorites'),

  /// Newest year first (see `SubsonicClient.getAlbumList`).
  byYear('byYear', 'Year');

  const AlbumSort(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Sorts [albums] the way the server would for [sort], for lists the server
/// can't sort itself (such as starred albums). Orders without a client-side
/// equivalent keep the given order.
List<Album> sortAlbums(List<Album> albums, AlbumSort sort) {
  String key(String? s) => (s ?? '').toLowerCase();
  // Newest first; missing values last.
  int byDateDesc(DateTime? a, DateTime? b) => a == null
      ? (b == null ? 0 : 1)
      : b == null
      ? -1
      : b.compareTo(a);
  final Comparator<Album>? compare = switch (sort) {
    AlbumSort.alphabeticalByName => (a, b) => key(a.name).compareTo(key(b.name)),
    AlbumSort.alphabeticalByArtist => (a, b) {
      final c = key(a.artist).compareTo(key(b.artist));
      return c != 0 ? c : (a.year ?? 0).compareTo(b.year ?? 0);
    },
    AlbumSort.byYear => (a, b) {
      final c = (b.year ?? 0).compareTo(a.year ?? 0);
      return c != 0 ? c : key(a.name).compareTo(key(b.name));
    },
    AlbumSort.newest => (a, b) => byDateDesc(a.created, b.created),
    AlbumSort.recent => (a, b) => byDateDesc(a.played, b.played),
    _ => null,
  };
  if (compare == null) return albums;
  // List.sort isn't stable, so break ties by original position.
  final indexed = albums.indexed.toList()
    ..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final (_, album) in indexed) album];
}

enum SongSortField { title, artist, album, duration }

/// A column sort for song lists; `null` stands for the list's own order.
typedef SongSort = ({SongSortField field, bool descending});

/// Sorts [songs] by [sort], pairing each song with its original position
/// (playlists edit by position). Ties keep the original order.
List<(int, Song)> sortSongs(List<Song> songs, SongSort? sort) {
  final indexed = songs.indexed.toList();
  if (sort == null) return indexed;
  String key(String? s) => (s ?? '').toLowerCase();
  // Keys are computed once up front: the Songs screen sorts whole libraries.
  final titles = [for (final s in songs) key(s.title)];
  final artists = [for (final s in songs) key(s.artist)];
  final albums = [for (final s in songs) key(s.album)];
  int albumOrder(int a, int b) {
    var c = albums[a].compareTo(albums[b]);
    if (c == 0) c = (songs[a].discNumber ?? 0).compareTo(songs[b].discNumber ?? 0);
    if (c == 0) c = (songs[a].track ?? 0).compareTo(songs[b].track ?? 0);
    return c;
  }

  final int Function(int, int) compare = switch (sort.field) {
    SongSortField.title => (a, b) {
      final c = titles[a].compareTo(titles[b]);
      return c != 0 ? c : artists[a].compareTo(artists[b]);
    },
    SongSortField.artist => (a, b) {
      final c = artists[a].compareTo(artists[b]);
      return c != 0 ? c : albumOrder(a, b);
    },
    SongSortField.album => albumOrder,
    SongSortField.duration => (a, b) => songs[a].duration.compareTo(songs[b].duration),
  };
  final sign = sort.descending ? -1 : 1;
  // List.sort isn't stable, so break ties by original position.
  return indexed..sort((a, b) {
    final c = compare(a.$1, b.$1) * sign;
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
}
