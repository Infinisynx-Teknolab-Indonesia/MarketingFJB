import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_center.dart';

/// Chat Admin - percakapan tunggal antara akun Agen/Marketing ini dengan
/// Admin Panel. Beda dengan Chat CS (member<->CS) - ini murni komunikasi
/// staf internal, terpisah total (lihat internal_chat_conversations di
/// backend).
class StaffChatPage extends StatefulWidget {
  const StaffChatPage({super.key});

  @override
  State<StaffChatPage> createState() => _StaffChatPageState();
}

class _StaffChatPageState extends State<StaffChatPage> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  final _pesanC = TextEditingController();
  bool _sending = false;
  final _scrollController = ScrollController();
  Timer? _autoRefreshTimer;

  void _onPesanRealtime(dynamic data) {
    // Event ini broadcast ke semua staf/admin - abaikan kalau bukan
    // punya percakapan kita (jaga-jaga kalau nanti ada lebih dari 1
    // percakapan aktif per device).
    _load(silent: true);
    NotificationCenter().markChatAdminRead();
  }

  @override
  void initState() {
    super.initState();
    _load();
    NotificationCenter().markChatAdminRead();
    SocketService().on('internal_chat_message', _onPesanRealtime);
    // Tetap dipertahankan sebagai fallback kalau socket putus/reconnect.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    SocketService().off('internal_chat_message', _onPesanRealtime);
    _autoRefreshTimer?.cancel();
    _pesanC.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final data = await AdminApiService().getMyInternalChat();
      final items = List<Map<String, dynamic>>.from(data['items']);
      final adaPesanBaru = items.length != _messages.length;
      setState(() { _messages = items; _isLoading = false; });
      if (!silent || adaPesanBaru) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (silent) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _kirim() async {
    final teks = _pesanC.text.trim();
    if (teks.isEmpty) return;
    setState(() => _sending = true);
    try {
      await AdminApiService().sendInternalChatAsStaff(teks);
      _pesanC.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatWaktu(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${bulan[dt.month - 1]} ${dt.year}, $jam:$menit';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Ngobrol langsung dengan tim Admin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(
                              child: _messages.isEmpty
                                  ? const Center(child: Text('Belum ada pesan. Mulai chat dengan Admin di bawah.', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.all(14),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        final m = _messages[index];
                                        final dariSaya = m['sender_role'] == 'staff';
                                        return Align(
                                          alignment: dariSaya ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Column(
                                            crossAxisAlignment: dariSaya ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                constraints: const BoxConstraints(maxWidth: 420),
                                                decoration: BoxDecoration(
                                                  color: dariSaya ? const Color(0xFFB8860B) : const Color(0xFFF1F3F8),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(m['message'] ?? '', style: TextStyle(color: dariSaya ? Colors.white : Colors.black87, fontSize: 13)),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                                                child: Text(_formatWaktu(m['created_at']?.toString()), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _pesanC,
                                      decoration: InputDecoration(
                                        hintText: 'Tulis pesan ke Admin...',
                                        filled: true,
                                        fillColor: const Color(0xFFF1F3F8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      onSubmitted: (_) => _kirim(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _sending ? null : _kirim,
                                    icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: Color(0xFFB8860B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
