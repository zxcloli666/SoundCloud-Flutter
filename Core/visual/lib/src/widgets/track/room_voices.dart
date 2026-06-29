import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../primitives/avatar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Один комментарий («голос») для [RoomVoices]. Данные приходят готовыми —
/// презентация без сети.
class VoiceCardData {
  final String username;
  final String? avatarUrl;
  final String userUrn;
  final String body;

  /// ISO-время создания (для «N минут назад»); пусто — метку не показываем.
  final String createdAt;

  /// Таймкод в треке (мс); `null` — комментарий без привязки к моменту.
  final int? timestampMs;

  const VoiceCardData({
    required this.username,
    required this.userUrn,
    required this.body,
    this.avatarUrl,
    this.createdAt = '',
    this.timestampMs,
  });
}

/// Подписи секции (приходят из i18n хоста — visual строк не знает).
class RoomVoicesLabels {
  final String title;
  final String empty;
  final String addCommentHint;

  /// Префикс «комментировать на …» над живым моментом в композере.
  final String commentAt;

  const RoomVoicesLabels({
    required this.title,
    required this.empty,
    required this.addCommentHint,
    required this.commentAt,
  });
}

/// «Голоса слушателей» — стена комментариев трека (порт легаси `RoomVoices`).
/// Таймкод-комментарии кликабельны (прыжок в момент); композер привязывает
/// новый голос к текущему моменту воспроизведения.
class RoomVoices extends StatelessWidget {
  final List<VoiceCardData> comments;
  final bool loading;
  final bool loadingMore;
  final RoomVoicesLabels labels;
  final Color accent;

  /// Текущая позиция воспроизведения (сек) для живого момента в композере;
  /// `null` — этот трек не играет, момент не показываем.
  final ValueListenable<double>? position;

  final void Function(double seconds) onSeek;
  final void Function(String userUrn) onUserTap;
  final Future<void> Function(String body, int? timestampMs) onPost;
  final VoidCallback? onLoadMore;

  const RoomVoices({
    super.key,
    required this.comments,
    required this.loading,
    required this.loadingMore,
    required this.labels,
    required this.accent,
    required this.onSeek,
    required this.onUserTap,
    required this.onPost,
    this.position,
    this.onLoadMore,
  });

  Color get _accentSoft => accent.withValues(alpha: 0.16);
  Color get _accentGlow => accent.withValues(alpha: 0.45);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.mode_comment_outlined, size: 14, color: accent),
            ),
            const SizedBox(width: 12),
            Text(
              labels.title,
              style: const TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _CommentForm(
          accent: accent,
          accentSoft: _accentSoft,
          hint: labels.addCommentHint,
          momentLabel: labels.commentAt,
          position: position,
          onPost: onPost,
        ),
        const SizedBox(height: 18),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x26FFFFFF)),
              ),
            ),
          )
        else if (comments.isEmpty)
          _Empty(label: labels.empty)
        else
          Column(
            children: [
              for (final c in comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VoiceCard(
                    comment: c,
                    accent: accent,
                    accentSoft: _accentSoft,
                    accentGlow: _accentGlow,
                    onSeek: onSeek,
                    onUserTap: onUserTap,
                  ),
                ),
              if (loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x26FFFFFF)),
                  ),
                )
              else if (onLoadMore != null)
                _LoadMore(onTap: onLoadMore!),
            ],
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: const Icon(Icons.mode_comment_outlined, size: 24, color: Color(0x26FFFFFF)),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 14)),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMore({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: const Text('···', style: TextStyle(color: Color(0x59FFFFFF), fontSize: 16)),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final VoiceCardData comment;
  final Color accent, accentSoft, accentGlow;
  final void Function(double seconds) onSeek;
  final void Function(String userUrn) onUserTap;

  const _VoiceCard({
    required this.comment,
    required this.accent,
    required this.accentSoft,
    required this.accentGlow,
    required this.onSeek,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = comment.timestampMs;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0x09FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Stack(
        children: [
          if (ts != null)
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 2.5,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: accentGlow, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onUserTap(comment.userUrn),
                child: Avatar(src: comment.avatarUrl, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => onUserTap(comment.userUrn),
                            child: Text(
                              comment.username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ago(comment.createdAt),
                          style: const TextStyle(color: Color(0x40FFFFFF), fontSize: 10),
                        ),
                        if (ts != null) ...[
                          const Spacer(),
                          _SeekChip(
                            label: _durLong(ts),
                            accent: accent,
                            accentSoft: accentSoft,
                            onTap: () => onSeek(ts / 1000.0),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.body,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeekChip extends StatelessWidget {
  final String label;
  final Color accent, accentSoft;
  final VoidCallback onTap;

  const _SeekChip({
    required this.label,
    required this.accent,
    required this.accentSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.play, size: 12, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentForm extends StatefulWidget {
  final Color accent, accentSoft;
  final String hint;
  final String momentLabel;
  final ValueListenable<double>? position;
  final Future<void> Function(String body, int? timestampMs) onPost;

  const _CommentForm({
    required this.accent,
    required this.accentSoft,
    required this.hint,
    required this.momentLabel,
    required this.position,
    required this.onPost,
  });

  @override
  State<_CommentForm> createState() => _CommentFormState();
}

class _CommentFormState extends State<_CommentForm> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final secs = widget.position?.value ?? 0;
    final ms = secs > 0 ? (secs * 1000).floor() : null;
    setState(() => _sending = true);
    try {
      await widget.onPost(text, ms);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.position != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.clock, size: 11, color: widget.accent),
                  const SizedBox(width: 6),
                  Text(
                    widget.momentLabel.toUpperCase(),
                    style: TextStyle(
                      color: widget.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<double>(
                    valueListenable: widget.position!,
                    builder: (_, secs, __) => Text(
                      _durLong((secs.clamp(0, double.infinity) * 1000).floor()),
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, height: 1.4),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: const TextStyle(color: Color(0x33FFFFFF), fontSize: 13),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                accent: widget.accent,
                accentSoft: widget.accentSoft,
                enabled: !_sending,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final Color accent, accentSoft;
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({
    required this.accent,
    required this.accentSoft,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.send_rounded, size: 16, color: enabled ? accent : accent.withValues(alpha: 0.3)),
      ),
    );
  }
}

/// `мс → m:ss` (как `durLong` легаси).
String _durLong(int ms) {
  final total = (ms / 1000).floor();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Грубое «N назад» из ISO-времени (минуты/часы/дни). Пусто/непарсимо → ''.
String _ago(String iso) {
  if (iso.isEmpty) return '';
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 1) return 'только что';
  if (d.inMinutes < 60) return '${d.inMinutes}м';
  if (d.inHours < 24) return '${d.inHours}ч';
  if (d.inDays < 30) return '${d.inDays}д';
  if (d.inDays < 365) return '${d.inDays ~/ 30}мес';
  return '${d.inDays ~/ 365}г';
}
