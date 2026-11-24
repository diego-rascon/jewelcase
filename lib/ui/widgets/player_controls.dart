import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../audio/player_controller.dart';
import '../format.dart';

/// Seek bar with elapsed / remaining labels. Holds the drag position locally
/// so the thumb doesn't jump while scrubbing.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, this.compact = false, this.color});

  final bool compact;
  final Color? color;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final total = context.select<PlayerController, Duration>((p) => p.duration);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: (widget.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.65),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Own layer: position ticks several times a second and must not repaint
    // the (often blurred, shadowed) screen around it.
    return RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: player.position,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          final max = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
          final value = (_dragValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
          final shown = Duration(milliseconds: value.round());

          final slider = SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.color,
              thumbColor: widget.color,
              inactiveTrackColor: widget.color?.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                unawaited(player.seek(Duration(milliseconds: v.round())));
                setState(() => _dragValue = null);
              },
            ),
          );

          if (widget.compact) {
            return Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(formatDuration(shown), style: labelStyle, textAlign: TextAlign.right),
                ),
                Expanded(child: slider),
                SizedBox(width: 44, child: Text(formatDuration(total), style: labelStyle)),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              slider,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(formatDuration(shown), style: labelStyle),
                    const Spacer(),
                    Text('-${formatDuration(total - shown)}', style: labelStyle),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shuffle · previous · play/pause · next · repeat.
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, this.size = 1, this.color, this.showModes = true});

  final double size;
  final Color? color;
  final bool showModes;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (shuffle, loopMode, hasQueue) = context.select<PlayerController, (bool, LoopMode, bool)>(
      (p) => (p.shuffle, p.loopMode, p.hasQueue),
    );
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurface;
    final active = color ?? scheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showModes)
          IconButton(
            tooltip: 'Shuffle',
            iconSize: 22 * size,
            color: shuffle ? active : fg.withValues(alpha: 0.6),
            onPressed: p.toggleShuffle,
            icon: _ModeIcon(icon: Icons.shuffle_rounded, on: shuffle, color: active),
          ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 32 * size,
          color: fg,
          onPressed: hasQueue ? p.previous : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        SizedBox(width: 8 * size),
        _PlayButton(size: size, color: fg),
        SizedBox(width: 8 * size),
        IconButton(
          tooltip: 'Next',
          iconSize: 32 * size,
          color: fg,
          onPressed: hasQueue ? p.next : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        if (showModes)
          IconButton(
            tooltip: switch (loopMode) {
              LoopMode.off => 'Repeat',
              LoopMode.all => 'Repeat all',
              LoopMode.one => 'Repeat one',
            },
            iconSize: 22 * size,
            color: loopMode == LoopMode.off ? fg.withValues(alpha: 0.6) : active,
            onPressed: p.cycleLoopMode,
            icon: _ModeIcon(
              icon: loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              on: loopMode != LoopMode.off,
              color: active,
            ),
          ),
      ],
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({required this.icon, required this.on, required this.color});

  final IconData icon;
  final bool on;
  final Color color;

  @override
  // The dot hangs below the icon without taking layout space, so the icon
  // stays centered in the button's hover circle.
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Icon(icon),
      Positioned(
        bottom: -6,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    ],
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (playing, buffering, hasQueue) = context.select<PlayerController, (bool, bool, bool)>(
      (p) => (p.playing, p.buffering, p.hasQueue),
    );
    final dim = 48.0 * size;
    final bg = color;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black;
    return SizedBox.square(
      dimension: dim,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: hasQueue ? p.togglePlay : null,
          child: Center(
            child: buffering && playing
                ? SizedBox.square(
                    dimension: dim * 0.4,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(playing),
                      size: dim * 0.6,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, this.width = 110});

  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final v = context.select<PlayerController, double>((p) => p.volume);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: v == 0 ? 'Unmute' : 'Mute',
          iconSize: 20,
          onPressed: () => p.setVolume(v == 0 ? 1 : 0),
          icon: Icon(
            v == 0
                ? Icons.volume_off_rounded
                : v < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
          ),
        ),
        SizedBox(
          width: width,
          child: Slider(value: v, onChanged: p.setVolume),
        ),
      ],
    );
  }
}
