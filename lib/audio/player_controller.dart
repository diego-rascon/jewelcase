import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../api/models.dart';
import '../api/subsonic_client.dart';

/// How long a track must play before it counts as listened to: half the track
/// or 4 minutes, whichever comes first. Tracks under 30 seconds never count.
Duration? scrobbleThreshold(Duration total) {
  if (total.inSeconds < 30) return null;
  return Duration(seconds: min(total.inSeconds ~/ 2, 240));
}

/// The order [upcoming] goes back to when shuffle is turned off: carry on from
/// the current song (at original position [current]) in the original order,
/// then the still-unplayed songs that came before it.
List<T> unshuffledOrder<T>(Iterable<T> upcoming, double Function(T) orderOf, double current) {
  int byOrder(T a, T b) => orderOf(a).compareTo(orderOf(b));
  return [
    ...upcoming.where((x) => orderOf(x) > current).toList()..sort(byOrder),
    ...upcoming.where((x) => orderOf(x) <= current).toList()..sort(byOrder),
  ];
}

/// The tag of every source in the player: the song, and its position in the
/// unshuffled order, which turning shuffle off restores.
class _QueueItem {
  const _QueueItem(this.song, this.order);

  final Song song;
  final double order;
}

/// App-facing playback API. Wraps a just_audio [AudioPlayer] whose sources are
/// tagged with the [Song] they play, so the queue is always derived from the
/// player itself rather than a parallel list that could drift.
///
/// Shuffle reorders the player's queue itself, so the queue is always in play
/// order. just_audio's own shuffle mode stays off: its media_kit backend
/// (Windows, Linux) hands it to mpv, which reorders its playlist without
/// telling just_audio, and the two then disagree on what's playing.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    _subs = [
      audio.sequenceStateStream.listen(_onSequenceState),
      audio.playerStateStream.listen((_) => notifyListeners()),
      audio.volumeStream.listen((_) => notifyListeners()),
      audio.positionDiscontinuityStream.listen(_onDiscontinuity),
      audio.positionStream.listen(_onPosition),
      audio.playbackEventStream.listen(null, onError: _onError),
    ];
  }

  final AudioPlayer audio = AudioPlayer();
  late final List<StreamSubscription<Object?>> _subs;

  SubsonicClient? _client;
  final _random = Random();

  /// The shuffle mode. It outlives the queue, so it can be set before Play.
  bool _shuffle = false;

  /// Queue edits take several player calls each, so they run one at a time.
  Future<void> _queueOps = Future.value();

  // Derived from the last sequence state, rebuilt only when it changes.
  SequenceState? _state;
  List<Song> _songs = const [];
  List<(int, Song)>? _upNext;

  /// The source of the play in progress, to tell a new play from a queue edit.
  IndexedAudioSource? _playing;
  bool _scrobbled = false;

  /// Call when the session changes; stops playback if the server changed.
  void attach(SubsonicClient? client) {
    if (identical(client, _client)) return;
    _client = client;
    unawaited(stop().catchError((Object e) => debugPrint('Could not stop playback: $e')));
  }

  // ---- State ------------------------------------------------------------

  List<Song> get songs => _songs;
  int? get currentIndex => _state?.currentIndex;
  Song? get current => (_state?.currentSource?.tag as _QueueItem?)?.song;

  /// Songs after the current one, paired with their index in [songs].
  List<(int, Song)> get upNext =>
      _upNext ??= List.unmodifiable([for (var i = (currentIndex ?? -1) + 1; i < _songs.length; i++) (i, _songs[i])]);

  bool get hasQueue => _songs.isNotEmpty;
  bool get playing => audio.playing;
  bool get buffering =>
      audio.processingState == ProcessingState.loading || audio.processingState == ProcessingState.buffering;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => audio.loopMode;
  double get volume => audio.volume;

  Stream<Duration> get position => audio.positionStream;
  Duration get duration => audio.duration ?? current?.duration ?? Duration.zero;

  // ---- Commands ---------------------------------------------------------

  /// Replaces the queue with [list] and plays it from [index]. [shuffle] sets
  /// the shuffle mode first; `null` keeps it. While shuffling, [index] plays
  /// first (a random song if it's `null`) and the rest follow in random order.
  Future<void> playSongs(List<Song> list, {int? index, bool? shuffle}) =>
      _serial(() => _playSongs(list, index: index, shuffle: shuffle));

  Future<void> _playSongs(List<Song> list, {int? index, bool? shuffle}) async {
    if (shuffle != null) _setShuffle(shuffle);
    final client = _client;
    if (client == null || list.isEmpty) return;
    final items = [for (final (i, s) in list.indexed) _QueueItem(s, i.toDouble())];
    var start = (index ?? 0).clamp(0, list.length - 1);
    if (_shuffle) {
      final first = items.removeAt(index == null ? _random.nextInt(list.length) : start);
      items
        ..shuffle(_random)
        ..insert(0, first);
      start = 0;
    }
    await audio.setAudioSources([for (final item in items) _source(client, item)], initialIndex: start, preload: false);
    _startPlayback();
  }

  Future<void> playNext(List<Song> list) => _serial(() async {
    final client = _client;
    if (client == null || list.isEmpty) return;
    if (!hasQueue) return _playSongs(list);
    final index = currentIndex;
    final at = (index ?? -1) + 1;
    // Unshuffled, these go between the current song and the one after it.
    final cur = index == null ? -1.0 : _ordersFrom(index).first;
    final next = _ordersFrom(at).where((o) => o > cur).fold(cur + 1, min);
    final step = (next - cur) / (list.length + 1);
    final end = audio.sequence.length;
    await audio.addAudioSources([
      for (final (i, s) in list.indexed) _source(client, _QueueItem(s, cur + step * (i + 1))),
    ]);
    // Appending then moving, rather than inserting: just_audio_media_kit
    // appends inserted sources to mpv's playlist wherever they were meant to go.
    if (at < end) {
      for (var i = 0; i < list.length; i++) {
        await audio.moveAudioSource(end + i, at + i);
      }
    }
  });

  Future<void> addToQueue(List<Song> list) => _serial(() async {
    final client = _client;
    if (client == null || list.isEmpty) return;
    if (!hasQueue) return _playSongs(list);
    final last = _ordersFrom(currentIndex ?? 0).fold(-1.0, max);
    await audio.addAudioSources([for (final (i, s) in list.indexed) _source(client, _QueueItem(s, last + i + 1))]);
  });

  Future<void> togglePlay() async => audio.playing ? await audio.pause() : _startPlayback();
  Future<void> play() async => _startPlayback();
  Future<void> pause() => audio.pause();
  Future<void> seek(Duration position) => audio.seek(position);
  Future<void> jumpTo(int index) async {
    await audio.seek(Duration.zero, index: index);
    if (!audio.playing) _startPlayback();
  }

  Future<void> next() async {
    if (audio.hasNext) await audio.seekToNext();
  }

  /// Restarts the song if we're a few seconds in, otherwise goes back.
  Future<void> previous() async {
    if (audio.position > const Duration(seconds: 3) || !audio.hasPrevious) {
      await audio.seek(Duration.zero);
    } else {
      await audio.seekToPrevious();
    }
  }

  /// Flips the shuffle mode and reorders the songs after the current one:
  /// randomly, or back to their unshuffled order. The current song and the
  /// ones before it stay put, so the player's current index never moves.
  Future<void> toggleShuffle() => _serial(() async {
    _setShuffle(!_shuffle);
    final client = _client;
    final index = currentIndex;
    if (client == null || index == null) return;
    final sequence = audio.sequence;
    if (index >= sequence.length - 1) return;
    final cur = (sequence[index].tag as _QueueItem).order;
    final upcoming = [for (final s in sequence.skip(index + 1)) s.tag as _QueueItem];
    final List<_QueueItem> reordered;
    if (_shuffle) {
      // Renumber from the current order, so that turning shuffle off again
      // restores it, including any manual reordering.
      reordered = [for (final (i, item) in upcoming.indexed) _QueueItem(item.song, cur + i + 1)]..shuffle(_random);
    } else {
      reordered = unshuffledOrder(upcoming, (item) => item.order, cur);
    }
    await audio.removeAudioSourceRange(index + 1, sequence.length);
    await audio.addAudioSources([for (final item in reordered) _source(client, item)]);
  });

  void _setShuffle(bool on) {
    if (on == _shuffle) return;
    _shuffle = on;
    notifyListeners();
  }

  Future<void> cycleLoopMode() => audio.setLoopMode(switch (audio.loopMode) {
    LoopMode.off => LoopMode.all,
    LoopMode.all => LoopMode.one,
    LoopMode.one => LoopMode.off,
  });

  Future<void> setVolume(double v) => audio.setVolume(v.clamp(0, 1));

  Future<void> removeAt(int index) => audio.removeAudioSourceAt(index);

  Future<void> move(int from, int to) => audio.moveAudioSource(from, to);

  Future<void> stop() => _serial(() async {
    await audio.stop();
    await audio.clearAudioSources();
  });

  // ---- Internals --------------------------------------------------------

  // just_audio's play() only completes once playback pauses or stops, so it
  // isn't awaited. Its errors also arrive on playbackEventStream (_onError).
  void _startPlayback() => unawaited(audio.play().catchError((Object _) {}));

  AudioSource _source(SubsonicClient client, _QueueItem item) =>
      AudioSource.uri(client.streamUrl(item.song.id), tag: item);

  /// The unshuffled-order positions of the queue's songs from [start] on.
  Iterable<double> _ordersFrom(int start) => audio.sequence.skip(start).map((s) => (s.tag as _QueueItem).order);

  Future<void> _serial(Future<void> Function() op) {
    final result = _queueOps.then((_) => op());
    _queueOps = result.catchError((Object _) {});
    return result;
  }

  // just_audio re-emits the sequence state on every playback event; only
  // notify when something the UI shows actually changed.
  void _onSequenceState(SequenceState state) {
    final prev = _state;
    _state = state;
    if (!identical(state.sequence, prev?.sequence)) {
      _songs = List.unmodifiable([for (final s in state.sequence) (s.tag as _QueueItem).song]);
    }
    final source = state.currentSource;
    if (!identical(source, _playing)) {
      _playing = source;
      _startPlay();
    }
    if (prev != null &&
        identical(state.sequence, prev.sequence) &&
        state.currentIndex == prev.currentIndex &&
        state.loopMode == prev.loopMode) {
      return;
    }
    _upNext = null;
    notifyListeners();
  }

  // With repeat-one (or a one-song queue on repeat-all) the source stays the
  // same while the track starts over: that is a new play too.
  void _onDiscontinuity(PositionDiscontinuity d) {
    if (d.reason == PositionDiscontinuityReason.autoAdvance && d.previousEvent.currentIndex == d.event.currentIndex) {
      _startPlay();
    }
  }

  void _startPlay() {
    _scrobbled = false;
    final song = current;
    if (song == null) return;
    final client = _client;
    if (client == null) return;
    unawaited(client.scrobble(song.id, submission: false).catchError((Object e) => debugPrint('now playing: $e')));
  }

  void _onPosition(Duration pos) {
    final song = current;
    if (song == null || _scrobbled) return;
    final threshold = scrobbleThreshold(duration);
    if (threshold != null && pos >= threshold) {
      _scrobbled = true;
      final client = _client;
      if (client != null) {
        unawaited(client.scrobble(song.id, submission: true).catchError((Object e) => debugPrint('scrobble: $e')));
      }
    }
  }

  // Debug output only: the error can include the stream URL, which carries
  // the auth token.
  void _onError(Object error, StackTrace _) => debugPrint('Playback error: $error');

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(audio.dispose());
    super.dispose();
  }
}
