import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../audio/player_controller.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import 'filled_icon.dart';
import 'thin_slider.dart';

/// Seek bar with elapsed / remaining labels. While scrubbing, the labels
/// follow the drag rather than the playing position.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, this.color});

  final Color? color;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  /// Where the drag would seek to.
  Duration? _drag;

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
          final shown = _drag ?? (pos > total ? total : pos);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThinSlider(
                value: total == Duration.zero ? 0 : pos.inMilliseconds / total.inMilliseconds,
                color: widget.color,
                thickness: largeSliderThickness,
                activeThickness: largeSliderActiveThickness,
                hitHeight: largeSliderHitHeight,
                onChanged: (f) => setState(() => _drag = total * f),
                onChangeEnd: (f) {
                  setState(() => _drag = null);
                  unawaited(guarded(context, () => player.seek(total * f)));
                },
              ),
              Row(
                children: [
                  Text(formatDuration(shown), style: labelStyle),
                  const Spacer(),
                  Text('-${formatDuration(total - shown)}', style: labelStyle),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The [ThinSlider] sizes for Now Playing's seek and volume bars, bolder than
/// the player bars' progress line.
const largeSliderThickness = 4.0;
const largeSliderActiveThickness = 8.0;
const largeSliderHitHeight = 28.0;

/// Shuffle · previous · play/pause · next · repeat.
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, this.uniform = false, this.color, this.showModes = true, this.spread = false});

  /// Every button the same size, the ambient [IconButtonTheme]'s, side by
  /// side with no extra gaps (the player bars). Otherwise they're Now
  /// Playing's: previous, play/pause and next at [IconSizes.xlarge] with gaps
  /// between them, shuffle and repeat at [IconSizes.large].
  final bool uniform;

  /// The buttons' color. Shuffle and repeat take the theme's primary while
  /// on: white in the app's neutral theme, the art's color in Now Playing.
  final Color? color;
  final bool showModes;

  /// Fill the available width, with shuffle and repeat pushed to the edges.
  final bool spread;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (shuffle, loopMode, hasQueue) = context.select<PlayerController, (bool, LoopMode, bool)>(
      (p) => (p.shuffle, p.loopMode, p.hasQueue),
    );
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurface;
    final active = scheme.primary;

    final transportSize = uniform ? null : IconSizes.xlarge;
    final modeSize = uniform ? null : IconSizes.large;
    final gap = uniform ? null : const SizedBox(width: 20);
    final skipButtons = [
      IconButton(
        tooltip: 'Previous',
        iconSize: transportSize,
        color: fg,
        onPressed: hasQueue ? p.previous : null,
        icon: const FilledIcon(FilledIcons.skipBack),
      ),
      ?gap,
      _PlayButton(iconSize: transportSize, color: fg),
      ?gap,
      IconButton(
        tooltip: 'Next',
        iconSize: transportSize,
        color: fg,
        onPressed: hasQueue ? p.next : null,
        icon: const FilledIcon(FilledIcons.skipForward),
      ),
    ];
    if (!showModes) return Row(mainAxisSize: MainAxisSize.min, children: skipButtons);

    final shuffleButton = IconButton(
      tooltip: 'Shuffle',
      iconSize: modeSize,
      color: shuffle ? active : fg.withValues(alpha: 0.6),
      onPressed: () => unawaited(guarded(context, p.toggleShuffle)),
      icon: ModeIcon(icon: LucideIcons.shuffle, on: shuffle, color: active),
    );
    final repeatButton = IconButton(
      tooltip: switch (loopMode) {
        LoopMode.off => 'Repeat',
        LoopMode.all => 'Repeat all',
        LoopMode.one => 'Repeat one',
      },
      iconSize: modeSize,
      color: loopMode == LoopMode.off ? fg.withValues(alpha: 0.6) : active,
      onPressed: p.cycleLoopMode,
      icon: ModeIcon(
        icon: loopMode == LoopMode.one ? LucideIcons.repeat1 : LucideIcons.repeat,
        on: loopMode != LoopMode.off,
        color: active,
      ),
    );
    return Row(
      mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
      children: [shuffleButton, if (spread) const Spacer(), ...skipButtons, if (spread) const Spacer(), repeatButton],
    );
  }
}

/// A mode's icon (shuffle, repeat), with a dot below it while the mode is on.
class ModeIcon extends StatelessWidget {
  const ModeIcon({super.key, required this.icon, required this.on, required this.color});

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
  const _PlayButton({required this.iconSize, required this.color});

  /// `null` takes the ambient [IconButtonTheme]'s size.
  final double? iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final (playing, buffering, hasQueue) = context.select<PlayerController, (bool, bool, bool)>(
      (p) => (p.playing, p.buffering, p.hasQueue),
    );
    return IconButton(
      tooltip: playing ? 'Pause' : 'Play',
      iconSize: iconSize,
      color: color,
      onPressed: hasQueue ? p.togglePlay : null,
      icon: buffering && playing
          // Sized like the icon it replaces, which IconButton passes down.
          ? Builder(
              builder: (context) {
                final s = IconTheme.of(context).size ?? 24;
                return SizedBox.square(
                  dimension: s,
                  child: Padding(
                    padding: EdgeInsets.all(s * 0.2),
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                );
              },
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: FilledIcon(playing ? FilledIcons.pause : FilledIcons.play, key: ValueKey(playing)),
            ),
    );
  }
}

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, this.width = 110});

  /// The slider's width; `null` shows only the mute button.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final v = context.select<PlayerController, double>((p) => p.volume);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: v == 0 ? 'Unmute' : 'Mute',
          onPressed: () => p.setVolume(v == 0 ? 1 : 0),
          icon: Icon(
            v == 0
                ? LucideIcons.volumeX
                : v < 0.5
                ? LucideIcons.volume1
                : LucideIcons.volume2,
          ),
        ),
        if (width != null)
          SizedBox(
            width: width,
            child: ThinSlider(value: v, onChanged: p.setVolume, onChangeEnd: p.setVolume),
          ),
      ],
    );
  }
}

/// Full-width volume slider between a mute button and a loudspeaker icon.
class VolumeBar extends StatelessWidget {
  const VolumeBar({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.read<PlayerController>();
    final v = context.select<PlayerController, double>((p) => p.volume);
    final fg = (color ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.65);
    return Row(
      children: [
        IconButton(
          tooltip: v == 0 ? 'Unmute' : 'Mute',
          iconSize: IconSizes.large,
          color: fg,
          onPressed: () => p.setVolume(v == 0 ? 1 : 0),
          icon: Icon(v == 0 ? LucideIcons.volumeX : LucideIcons.volume),
        ),
        Expanded(
          child: ThinSlider(
            value: v,
            color: color,
            thickness: largeSliderThickness,
            activeThickness: largeSliderActiveThickness,
            hitHeight: largeSliderHitHeight,
            onChanged: p.setVolume,
            onChangeEnd: p.setVolume,
          ),
        ),
        // Matches the mute button's width, so the slider sits centered.
        SizedBox(
          width: 40,
          child: Icon(LucideIcons.volume2, size: IconSizes.large, color: fg),
        ),
      ],
    );
  }
}
