import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pengaturan koneksi backend: Server (production) atau Local (buat
/// testing sebelum konek ke server beneran). Pilihan disimpan persisten
/// lewat secure storage supaya tidak perlu diisi ulang tiap buka app.
class ServerConfig {
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  static const String prodApiUrl = "https://fjbbatam.com/admin/api";
  static const String prodImageBaseUrl = "https://fjbbatam.com";

  // GANTI default ini kalau port/URL server local-mu beda.
  static const String defaultLocalApiUrl = "http://localhost:5050/admin/api";

  static const _kMode = "server_mode"; // "server" | "local"
  static const _kLocalUrl = "local_api_url";

  final _storage = const FlutterSecureStorage();

  bool _useLocal = false;
  String _localUrl = defaultLocalApiUrl;
  bool _loaded = false;

  bool get useLocal => _useLocal;
  String get localUrl => _localUrl;

  /// URL dasar buat panggilan API (dipakai AdminApiService).
  String get apiBaseUrl => _useLocal ? _normalizeApi(_localUrl) : prodApiUrl;

  /// URL dasar buat gambar/foto (root domain, tanpa /admin/api).
  String get imageBaseUrl => _useLocal ? _normalizeImage(_localUrl) : prodImageBaseUrl;

  String _normalizeApi(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  String _normalizeImage(String url) {
    var u = _normalizeApi(url);
    // Local URL biasanya diisi user sampai "/admin/api" - potong itu
    // buat dapat root domain tempat folder /images/... berada.
    if (u.endsWith('/admin/api')) {
      u = u.substring(0, u.length - '/admin/api'.length);
    }
    return u;
  }

  /// Wajib dipanggil sekali di awal (main.dart) sebelum UI apa pun
  /// nge-hit API, supaya mode local/server yang tersimpan kepakai.
  Future<void> load() async {
    if (_loaded) return;
    final mode = await _storage.read(key: _kMode);
    final savedUrl = await _storage.read(key: _kLocalUrl);
    _useLocal = mode == 'local';
    if (savedUrl != null && savedUrl.isNotEmpty) _localUrl = savedUrl;
    _loaded = true;
  }

  Future<void> setMode({required bool useLocal, String? localUrl}) async {
    _useLocal = useLocal;
    if (localUrl != null && localUrl.trim().isNotEmpty) {
      _localUrl = localUrl.trim();
    }
    await _storage.write(key: _kMode, value: useLocal ? 'local' : 'server');
    await _storage.write(key: _kLocalUrl, value: _localUrl);
  }
}
