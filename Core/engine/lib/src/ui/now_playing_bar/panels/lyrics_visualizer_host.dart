import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

import '../../../rust/api.dart';

/// Мост спектра ядра в [LyricsWaveVisualizer]. Подписку держим только пока
/// смонтированы: ядро считает FFT лишь при наличии подписчика, поэтому на
/// закрытой лирике/паузе CPU простаивает. Цвет — текущий акцент темы.
class LyricsVisualizerHost extends StatefulWidget {
  const LyricsVisualizerHost({super.key});

  @override
  State<LyricsVisualizerHost> createState() => _LyricsVisualizerHostState();
}

class _LyricsVisualizerHostState extends State<LyricsVisualizerHost> {
  final ValueNotifier<Float32List> _bins =
      ValueNotifier(Float32List(LyricsWaveVisualizer.binCount));
  StreamSubscription<Float32List>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = audioSpectrum().listen((bins) => _bins.value = bins);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bins.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LyricsWaveVisualizer(
      bins: _bins,
      accent: ScTheme.paletteOf(context).accent,
    );
  }
}
