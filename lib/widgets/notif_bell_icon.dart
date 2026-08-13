import 'package:flutter/material.dart';

/// Ikon lonceng dengan badge angka merah - dipakai di topbar tiap panel.
/// count 0 -> badge tidak muncul. count > 99 -> ditampilkan "99+".
class NotifBellIcon extends StatelessWidget {
  final int count;
  final IconData icon;
  final Color? color;
  final String? tooltip;
  final VoidCallback onTap;
  const NotifBellIcon({
    super.key,
    required this.count,
    required this.onTap,
    this.icon = Icons.notifications_outlined,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = count > 99 ? '99+' : '$count';
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color ?? Colors.grey.shade700, size: 24),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      badgeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
