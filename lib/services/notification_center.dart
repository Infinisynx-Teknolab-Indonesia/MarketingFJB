import 'package:flutter/foundation.dart';
import 'admin_api_service.dart';
import 'socket_service.dart';

/// Pusat notifikasi realtime - dipakai buat badge lonceng di topbar &
/// angka di Ringkasan. refreshStats() manggil GET /stats (akurat, dari
/// server), dipicu otomatis tiap ada event socket relevan - jadi tidak
/// perlu nunggu polling 15 detik buat kelihatan realtime.
///
/// chatAdminUnread & csTeamUnread beda mekanisme: itu counter LOKAL
/// (bukan dari /stats, yang angkanya global lintas staf) - increment
/// tiap ada event masuk yang relevan buat AKUN INI, direset ke 0 waktu
/// halaman terkait dibuka (lihat markChatAdminRead / markCsTeamRead).
class NotificationCenter extends ChangeNotifier {
  static final NotificationCenter _instance = NotificationCenter._internal();
  factory NotificationCenter() => _instance;
  NotificationCenter._internal();

  // Dipakai Admin & CS Panel (angka global, dari /stats).
  int csBelumDibalas = 0;
  int csAntrian = 0;
  int internalChatBelumDibalas = 0;

  // Dipakai Marketing/Agen & CS Panel - badge "Chat Admin" (chat
  // pribadi akun ini dengan tim admin).
  int chatAdminUnread = 0;

  // Dipakai CS Panel - badge "Chat Tim CS".
  int csTeamUnread = 0;

  bool _attached = false;
  DateTime? _lastRefresh;

  Future<void> refreshStats() async {
    // Debounce ringan - kalau beberapa event socket nembak beruntun
    // (mis. kirim gambar = 1 insert + beberapa update), jangan spam
    // request /stats berkali-kali dalam sepersekian detik.
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < const Duration(milliseconds: 400)) return;
    _lastRefresh = now;
    try {
      final s = await AdminApiService().getStats();
      csBelumDibalas = (s['csBelumDibalas'] ?? 0) as int;
      csAntrian = (s['csAntrian'] ?? 0) as int;
      internalChatBelumDibalas = (s['internalChatBelumDibalas'] ?? 0) as int;
      notifyListeners();
    } catch (_) {
      // Diamkan - bukan fatal, badge cuma nggak ke-update sesaat.
    }
  }

  void markChatAdminRead() {
    if (chatAdminUnread == 0) return;
    chatAdminUnread = 0;
    notifyListeners();
  }

  void markCsTeamRead() {
    if (csTeamUnread == 0) return;
    csTeamUnread = 0;
    notifyListeners();
  }

  void _onInternalChatMessage(dynamic data) {
    refreshStats();
    try {
      if (data is Map && data['sender_role'] == 'admin') {
        chatAdminUnread++;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onCsMessage(dynamic data) => refreshStats();
  void _onCsConversationUpdated(dynamic data) => refreshStats();

  void _onCsTeamMessage(dynamic data) {
    csTeamUnread++;
    notifyListeners();
  }

  /// Panggil sekali di dashboard_shell initState, SETELAH
  /// SocketService().connect() dipanggil.
  void attachSocketListeners() {
    if (_attached) return;
    _attached = true;
    SocketService().on('internal_chat_message', _onInternalChatMessage);
    SocketService().on('cs_message', _onCsMessage);
    SocketService().on('cs_conversation_updated', _onCsConversationUpdated);
    SocketService().on('cs_team_message', _onCsTeamMessage);
  }

  void detachSocketListeners() {
    if (!_attached) return;
    _attached = false;
    SocketService().off('internal_chat_message', _onInternalChatMessage);
    SocketService().off('cs_message', _onCsMessage);
    SocketService().off('cs_conversation_updated', _onCsConversationUpdated);
    SocketService().off('cs_team_message', _onCsTeamMessage);
  }
}
