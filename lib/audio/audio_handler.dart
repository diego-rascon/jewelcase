import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../api/subsonic_client.dart';
import 'player_controller.dart';

/// Bridges [PlayerController] to the OS media session: lock screen, Android
/// notification, Bluetooth/headset buttons and Control Center. On platforms
/// audio_service doesn't cover this is simply a no-op.
class JewelcaseAudioHandler extends BaseAudioHandler with SeekHandler {
  JewelcaseAudioHandler(this._player, this._clientOf) {
    final audio = _player.audio;
    audio.playbackEventStream.listen((_) => _broadcastState());
    audio.playerStateStream.listen((_) => _broadcastState());
    audio.sequenceStateStream.listen((_) => _broadcastMedia());
    audio.durationStream.listen((_) => _broadcastMedia());
  }

  final PlayerController _player;
  final SubsonicClient? Function() _clientOf;

  void _broadcastMedia() {
    final song = _player.current;
    if (song == null) return;
    final client = _clientOf();
    final item = MediaItem(
      id: song.id,
      title: song.title,
      album: song.album,
      artist: song.artist,
      duration: _player.audio.duration ?? song.duration,
      artUri: song.coverArt == null || client == null ? null : Uri.parse(client.coverUrl(song.coverArt!)),
    );
    if (mediaItem.value?.id != item.id || mediaItem.value?.duration != item.duration) {
      mediaItem.add(item);
    }
  }

  void _broadcastState() {
    final audio = _player.audio;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          audio.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (audio.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: audio.playing,
        updatePosition: audio.position,
        bufferedPosition: audio.bufferedPosition,
        speed: audio.speed,
        queueIndex: audio.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> stop() async {
    await _player.pause();
    await super.stop();
  }
}
