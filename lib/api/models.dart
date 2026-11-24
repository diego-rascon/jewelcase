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
    this.genre,
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
  final String? genre;
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
    genre: _str(j['genre']),
    starred: j['starred'] != null,
    created: _date(j['created']),
    played: _date(j['played']),
    songs: jsonList(j['song']).map(Song.fromJson).toList(),
  );
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
    this.songs = const [],
  });

  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final int songCount;
  final Duration duration;
  final String? coverArt;

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
