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

/// App-facing playback API. Wraps a just_audio [AudioPlayer] whose sources are
/// tagged with the [Song] they play, so the queue is always derived from the
/// player itself rather than a parallel list that could drift.
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
  Song? get current => _state?.currentSource?.tag as Song?;

  /// Indices into [songs] in the order they will play (respects shuffle).
  List<int> get playOrder {
    final s = _state;
    if (s == null || s.sequence.isEmpty) return const [];
    return s.shuffleModeEnabled ? s.shuffleIndices : List.generate(s.sequence.length, (i) => i);
  }

  /// Songs after the current one, paired with their index in [songs].
  List<(int, Song)> get upNext => _upNext ??= () {
    final order = playOrder;
    final pos = order.indexOf(currentIndex ?? -1);
    return List<(int, Song)>.unmodifiable([for (final i in order.skip(pos + 1)) (i, _songs[i])]);
  }();

  bool get hasQueue => _songs.isNotEmpty;
  bool get playing => audio.playing;
  bool get buffering =>
      audio.processingState == ProcessingState.loading || audio.processingState == ProcessingState.buffering;
  bool get shuffle => audio.shuffleModeEnabled;
  LoopMode get loopMode => audio.loopMode;
  double get volume => audio.volume;

  Stream<Duration> get position => audio.positionStream;
  Duration get duration => audio.duration ?? current?.duration ?? Duration.zero;

  // ---- Commands ---------------------------------------------------------

  Future<void> playSongs(List<Song> list, {int index = 0, bool shuffle = false}) async {
    final client = _client;
    if (client == null || list.isEmpty) return;
    final start = shuffle ? Random().nextInt(list.length) : index.clamp(0, list.length - 1);
    await audio.setShuffleModeEnabled(false);
    await audio.setAudioSources([for (final s in list) _source(client, s)], initialIndex: start, preload: false);
    if (shuffle) {
      await audio.shuffle();
      await audio.setShuffleModeEnabled(true);
    }
    _startPlayback();
  }

  Future<void> playNext(List<Song> list) async {
    final client = _client;
    if (client == null || list.isEmpty) return;
    if (!hasQueue) return playSongs(list);
    final at = (currentIndex ?? -1) + 1;
    for (final (i, s) in list.indexed) {
      await audio.insertAudioSource(at + i, _source(client, s));
    }
  }

  Future<void> addToQueue(List<Song> list) async {
    final client = _client;
    if (client == null || list.isEmpty) return;
    if (!hasQueue) return playSongs(list);
    for (final s in list) {
      await audio.addAudioSource(_source(client, s));
    }
  }

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

  Future<void> toggleShuffle() async {
    if (!audio.shuffleModeEnabled) await audio.shuffle();
    await audio.setShuffleModeEnabled(!audio.shuffleModeEnabled);
  }

  Future<void> cycleLoopMode() => audio.setLoopMode(switch (audio.loopMode) {
    LoopMode.off => LoopMode.all,
    LoopMode.all => LoopMode.one,
    LoopMode.one => LoopMode.off,
  });

  Future<void> setVolume(double v) => audio.setVolume(v.clamp(0, 1));

  Future<void> removeAt(int index) => audio.removeAudioSourceAt(index);

  Future<void> move(int from, int to) => audio.moveAudioSource(from, to);

  Future<void> stop() async {
    await audio.stop();
    await audio.clearAudioSources();
  }

  // ---- Internals --------------------------------------------------------

  // just_audio's play() only completes once playback pauses or stops, so it
  // isn't awaited. Its errors also arrive on playbackEventStream (_onError).
  void _startPlayback() => unawaited(audio.play().catchError((Object _) {}));

  AudioSource _source(SubsonicClient client, Song song) => AudioSource.uri(client.streamUrl(song.id), tag: song);

  // just_audio re-emits the sequence state on every playback event; only
  // notify when something the UI shows actually changed.
  void _onSequenceState(SequenceState state) {
    final prev = _state;
    _state = state;
    if (!identical(state.sequence, prev?.sequence)) {
      _songs = List.unmodifiable([for (final s in state.sequence) s.tag as Song]);
    }
    final source = state.currentSource;
    if (!identical(source, _playing)) {
      _playing = source;
      _startPlay();
    }
    if (prev != null &&
        identical(state.sequence, prev.sequence) &&
        state.currentIndex == prev.currentIndex &&
        state.shuffleModeEnabled == prev.shuffleModeEnabled &&
        identical(state.shuffleIndices, prev.shuffleIndices) &&
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
