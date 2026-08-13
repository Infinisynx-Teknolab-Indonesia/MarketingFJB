import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'admin_api_service.dart';
import 'server_config.dart';

/// Koneksi Socket.IO realtime buat Chat Admin & Chat CS. Server-nya SAMA
/// dengan yang dipakai app mobile (lihat chat_socket.py) - cuma sekarang
/// Admin/CS/Marketing Panel juga ikut connect pakai token admin (bukan
/// token member), supaya pesan baru langsung sampai tanpa nunggu polling.
///
/// Dipasang sebagai singleton karena cuma butuh 1 koneksi socket per
/// aplikasi, dipakai bareng-bareng oleh halaman manapun yang lagi kebuka
/// (Chat Admin, Chat CS, dll).
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _connectedUrl;
  String? _connectedToken;
  bool get isConnected => _socket?.connected ?? false;

  // PENTING: connect() itu async (nunggu baca token dari secure storage
  // dulu sebelum bikin socket-nya). Kalau ada halaman yang manggil on()
  // TEPAT setelah connect() dipanggil tanpa di-await (ini yang terjadi di
  // initState dashboard_shell.dart), _socket masih null waktu on() jalan
  // -> listener-nya "hilang" begitu saja (silent no-op), notifikasi jadi
  // kelihatan "tidak real-time" padahal sebenarnya cuma listener-nya
  // nggak pernah nyambung ke socket asli. Makanya semua listener yang
  // pernah didaftarkan disimpan di sini juga, lalu dipasang ULANG ke
  // socket begitu instance-nya siap (baik pertama kali connect maupun
  // reconnect karena ganti mode Server/Local).
  final Map<String, List<void Function(dynamic data)>> _pendingListeners = {};

  /// Connect (atau reconnect kalau URL/token berubah, mis. abis ganti
  /// mode Server/Local). Aman dipanggil berkali-kali - kalau sudah
  /// connect ke URL & token yang sama, tidak melakukan apa-apa.
  Future<void> connect() async {
    final token = await AdminApiService().currentToken;
    if (token == null || token.isEmpty) return;

    // Socket.IO di-mount di root server (/socket.io), BUKAN di bawah
    // /admin/api - jadi pakai imageBaseUrl (root domain), bukan apiBaseUrl.
    final url = ServerConfig().imageBaseUrl;

    if (_socket != null && _connectedUrl == url && _connectedToken == token) {
      return; // sudah connect ke tujuan yang sama, tidak perlu reconnect
    }

    _socket?.dispose();
    _connectedUrl = url;
    _connectedToken = token;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    // Pasang ulang SEMUA listener yang sudah pernah didaftarkan lewat
    // on() ke instance socket yang baru ini - baik yang telat (race
    // condition di atas) maupun yang perlu pindah gara-gara reconnect.
    _pendingListeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        _socket!.on(event, cb);
      }
    });
  }

  /// Dengarkan 1 event. Aman dipanggil kapan saja (bahkan sebelum
  /// connect() selesai) - listener otomatis nyambung begitu socket siap.
  void on(String event, void Function(dynamic data) callback) {
    _pendingListeners.putIfAbsent(event, () => []).add(callback);
    _socket?.on(event, callback);
  }

  void off(String event, [void Function(dynamic data)? callback]) {
    if (callback != null) {
      _pendingListeners[event]?.remove(callback);
      _socket?.off(event, callback);
    } else {
      _pendingListeners.remove(event);
      _socket?.off(event);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedUrl = null;
    _connectedToken = null;
    _pendingListeners.clear();
  }
}
