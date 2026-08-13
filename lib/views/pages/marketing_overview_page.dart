import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

/// Ringkasan khusus Marketing Panel - jumlah konten yang sudah diinput
/// marketing ini sendiri (bukan statistik keseluruhan platform).
class MarketingOverviewPage extends StatefulWidget {
  final void Function(String tujuan)? onNavigate;
  const MarketingOverviewPage({super.key, this.onNavigate});

  @override
  State<MarketingOverviewPage> createState() => _MarketingOverviewPageState();
}

class _MarketingOverviewPageState extends State<MarketingOverviewPage> {
  int _totalIklan = 0;
  int _totalLowongan = 0;
  int _totalPencari = 0;
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        AdminApiService().getMyIklan(),
        AdminApiService().getMyLowongan(),
        AdminApiService().getMyPencari(),
      ]);
      setState(() {
        _totalIklan = results[0].length;
        _totalLowongan = results[1].length;
        _totalPencari = results[2].length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ringkasan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const Text('Konten yang sudah kamu input.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _card('Iklan Jual Beli', '$_totalIklan', Icons.storefront_outlined, Colors.orange),
                          const SizedBox(width: 16),
                          _card('Lowongan Kerja', '$_totalLowongan', Icons.apartment_outlined, Colors.green),
                          const SizedBox(width: 16),
                          _card('Pencari Kerja', '$_totalPencari', Icons.person_outline, Colors.blue),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onNavigate == null ? null : () => widget.onNavigate!('Input Konten'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  height: 48, width: 48, alignment: Alignment.center,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
