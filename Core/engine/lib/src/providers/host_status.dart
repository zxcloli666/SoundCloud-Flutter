import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rust/api.dart';
import 'auth.dart';

/// Вердикт по хосту (зеркало `sc-net::Verdict`).
enum HostVerdict { up, down, unknown }

HostVerdict _verdict(String s) => switch (s) {
      'up' => HostVerdict.up,
      'down' => HostVerdict.down,
      _ => HostVerdict.unknown,
    };

/// Статус бэкенд-хостов из ядра (failover main⇄star + premium). Source of truth —
/// Rust (`HostPool`); здесь только подписка для UI-модалок.
final hostStatusProvider =
    StreamProvider<HostStatusDto>((ref) => hostStatusStream());

/// Что показать по статусу хостов (порт легаси `selectFailoverUi`).
enum FailoverUi {
  /// Ничего: main жив/неизвестен, либо офлайн-режим.
  none,

  /// Премиум на резервном STAR (main лёг) — ненавязчивый баннер.
  starActive,

  /// main лёг, STAR жив, но юзер без подписки — предложить купить STAR.
  starOffer,

  /// Оба хоста легли — только офлайн-библиотека.
  allDown,
}

/// Чистый выбор UI по статусу (тестируемо, без side-effects).
FailoverUi selectFailoverUi(
  HostStatusDto? s, {
  required bool hasSession,
  required bool offlineBypass,
}) {
  if (s == null || offlineBypass) return FailoverUi.none;
  if (_verdict(s.main) != HostVerdict.down) return FailoverUi.none;
  switch (_verdict(s.star)) {
    case HostVerdict.up:
      return (s.premium && hasSession)
          ? FailoverUi.starActive
          : FailoverUi.starOffer;
    case HostVerdict.down:
      return FailoverUi.allDown;
    case HostVerdict.unknown:
      return FailoverUi.none; // рано: STAR ещё не опрошен
  }
}

/// Производный UI-вердикт failover (учитывает сессию и офлайн-байпас).
final failoverUiProvider = Provider<FailoverUi>((ref) {
  final status = ref.watch(hostStatusProvider).value;
  final hasSession = ref.watch(authProvider).value?.canUseMainShell ?? false;
  final offline = ref.watch(offlineBypassProvider);
  return selectFailoverUi(status, hasSession: hasSession, offlineBypass: offline);
});
