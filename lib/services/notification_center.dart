import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'admin_api_service.dart';
import 'socket_service.dart';

/// Pusat notifikasi realtime - dipakai buat badge lonceng di topbar,
/// suara notifikasi, & angka di Ringkasan. refreshStats() manggil GET
/// /stats (akurat, dari server), dipicu otomatis tiap ada event socket
/// relevan - jadi tidak perlu nunggu polling buat kelihatan realtime.
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
  DateTime? _lastSound;
  int? _myAdminId;

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

  /// Bunyikan notifikasi sistem (tanpa perlu file audio - pakai suara
  /// bawaan OS lewat SystemSound, jadi selalu ada di semua platform).
  /// Di-debounce 800ms supaya beberapa event yang nembak beruntun (mis.
  /// kirim gambar = beberapa event socket sekaligus) tidak bikin suara
  /// nyaring bertubi-tubi.
  void _bunyikanNotifikasi() {
    final now = DateTime.now();
    if (_lastSound != null && now.difference(_lastSound!) < const Duration(milliseconds: 800)) return;
    _lastSound = now;
    SystemSound.play(SystemSoundType.alert);
  }

  /// True kalau event ini berasal dari akun yang sedang login sendiri -
  /// dipakai supaya badge/suara TIDAK muncul untuk pesan yang kita
  /// sendiri baru saja kirim (server broadcast ke seluruh tim, termasuk
  /// balik ke pengirimnya).
  bool _dariSayaSendiri(dynamic data, String senderIdField) {
    try {
      if (_myAdminId == null || data is! Map) return false;
      final senderId = data[senderIdField];
      return senderId != null && senderId == _myAdminId;
    } catch (_) {
      return false;
    }
  }

  void _onInternalChatMessage(dynamic data) {
    refreshStats();
    final dariSaya = _dariSayaSendiri(data, 'sender_id');
    try {
      if (!dariSaya && data is Map && data['sender_role'] == 'admin') {
        chatAdminUnread++;
        notifyListeners();
      }
    } catch (_) {}
    if (!dariSaya) _bunyikanNotifikasi();
  }

  void _onCsMessage(dynamic data) {
    refreshStats();
    if (!_dariSayaSendiri(data, 'sender_id')) _bunyikanNotifikasi();
  }

  void _onCsConversationUpdated(dynamic data) => refreshStats();

  void _onCsTeamMessage(dynamic data) {
    final dariSaya = _dariSayaSendiri(data, 'sender_admin_id');
    if (!dariSaya) {
      csTeamUnread++;
      notifyListeners();
      _bunyikanNotifikasi();
    }
  }

  /// Panggil sekali di dashboard_shell initState, SETELAH
  /// SocketService().connect() dipanggil.
  void attachSocketListeners() {
    if (_attached) return;
    _attached = true;
    // Async, tapi tidak perlu di-await - listener socket di bawah tetap
    // langsung terpasang (lihat SocketService.on(), aman dipanggil
    // sebelum koneksi selesai). _myAdminId cuma dipakai buat filter
    // suara/badge, jadi telat sepersekian detik di awal tidak masalah.
    AdminApiService().currentAdminId.then((id) => _myAdminId = id);

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
