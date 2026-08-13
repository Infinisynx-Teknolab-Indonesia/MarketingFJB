import 'package:flutter/material.dart';

/// Placeholder untuk role 'marketing' - belum ada fitur khusus,
/// menunggu pengembangan lanjutan. Role 'agen' yang punya kemampuan
/// input Iklan/Loker (lihat MarketingInputPage).
class MarketingBlankPage extends StatelessWidget {
  const MarketingBlankPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Fitur untuk role Marketing segera hadir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Sementara ini kamu bisa pakai menu Chat Admin untuk komunikasi.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
