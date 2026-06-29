import 'package:flutter/material.dart';
import 'package:sc_visual/sc_visual.dart';

/// Сентинел «показать ещё» под виртуальным списком/сеткой профиля (легаси
/// infinite-scroll sentinel `h-16`). Тап догружает следующую страницу.
class UserLoadMore extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const UserLoadMore({super.key, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassButton(
        onTap: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0x8CFFFFFF)),
              )
            : const Text('Show more', style: TextStyle(color: Color(0x8CFFFFFF), fontSize: 13)),
      ),
    );
  }
}
