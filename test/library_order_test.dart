import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/api/models.dart';

DateTime _day(int d) => DateTime.utc(2026, 1, d);

Album _album(String id, {String? artistId, List<String> genres = const [], int? playedDay}) =>
    Album(id: id, name: id, artistId: artistId, genres: genres, played: playedDay == null ? null : _day(playedDay));

void main() {
  test('newestFirst puts the newest first, undated last, and keeps ties in order', () {
    final items = [('a', null), ('b', _day(2)), ('c', _day(5)), ('d', null), ('e', _day(2))];
    expect(newestFirst(items, (i) => i.$2).map((i) => i.$1), ['c', 'b', 'e', 'a', 'd']);
  });

  test('artists are ordered by the last play of any of their albums', () {
    const artists = [Artist(id: 'x', name: 'X'), Artist(id: 'y', name: 'Y'), Artist(id: 'z', name: 'Z')];
    final albums = [
      _album('1', artistId: 'x', playedDay: 1),
      _album('2', artistId: 'y', playedDay: 3),
      _album('3', artistId: 'x', playedDay: 9),
      _album('4', artistId: 'z'),
    ];
    expect(artistsByRecentPlay(artists, albums).map((a) => a.id), ['x', 'y', 'z']);
  });

  test('genres are ordered by their last played album, the rest by name', () {
    final albums = [
      _album('1', genres: ['Rock', 'Pop'], playedDay: 2),
      _album('2', genres: ['Jazz'], playedDay: 7),
      _album('3', genres: ['Rock']),
      _album('4', genres: ['Blues', 'Ambient']),
    ];
    final genres = genresByRecentPlay(albums);
    expect(genres.map((g) => g.name), ['Jazz', 'Pop', 'Rock', 'Ambient', 'Blues']);
    expect(genres.firstWhere((g) => g.name == 'Rock').albumCount, 2);
  });

  test('songs and playlists read their dates', () {
    final song = Song.fromJson({'id': 's', 'title': 'T', 'played': '2026-01-03T10:00:00Z'});
    expect(song.played, DateTime.utc(2026, 1, 3, 10));
    expect(Song.fromJson({'id': 's'}).played, isNull);
    final playlist = Playlist.fromJson({'id': 'p', 'name': 'P', 'changed': '2026-01-04T00:00:00Z'});
    expect(playlist.changed, _day(4));
  });
}
