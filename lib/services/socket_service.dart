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
  }

  /// Dengarkan 1 event. Pastikan connect() sudah dipanggil sebelumnya
  /// (biasanya di initState halaman yang butuh realtime).
  void on(String event, void Function(dynamic data) callback) {
    _socket?.on(event, callback);
  }

  void off(String event, [void Function(dynamic data)? callback]) {
    if (callback != null) {
      _socket?.off(event, callback);
    } else {
      _socket?.off(event);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedUrl = null;
    _connectedToken = null;
  }
}
