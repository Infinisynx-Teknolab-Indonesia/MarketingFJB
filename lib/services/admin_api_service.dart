import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'server_config.dart';

/// Service tunggal buat semua komunikasi ke admin_api.py (backend REST
/// khusus admin - terpisah dari GraphQL yang dipakai app mobile).
class AdminApiService {
  static final AdminApiService _instance = AdminApiService._internal();
  factory AdminApiService() => _instance;
  AdminApiService._internal();

  final _storage = const FlutterSecureStorage();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ServerConfig().apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Dipanggil habis ServerConfig().load() (saat start app) atau habis
  /// user ganti mode Server/Local di halaman login - supaya request
  /// berikutnya langsung pakai baseUrl yang baru tanpa restart app.
  void applyServerConfig() {
    _dio.options.baseUrl = ServerConfig().apiBaseUrl;
  }

  String? _cachedToken;
  String? _cachedRole;
  String? _cachedUsername;

  Future<String?> get currentToken async {
    _cachedToken ??= await _storage.read(key: "admin_token");
    return _cachedToken;
  }

  Future<String?> get currentRole async {
    _cachedRole ??= await _storage.read(key: "admin_role");
    return _cachedRole;
  }

  Future<String?> get currentUsername async {
    _cachedUsername ??= await _storage.read(key: "admin_username");
    return _cachedUsername;
  }

  /// True kalau role >= 'admin' (admin ATAU super_admin) - dipakai buat
  /// tampil/sembunyiin tombol aksi (approve/tolak/hapus/kunci) di UI.
  Future<bool> get bisaModerasi async {
    final role = await currentRole;
    return role == 'admin' || role == 'super_admin';
  }

  Future<bool> get isSuperAdmin async {
    final role = await currentRole;
    return role == 'super_admin';
  }

  /// True kalau role == 'marketing' - dipakai buat sembunyiin semua menu
  /// moderasi (approve/inactive/hapus/kunci) dan cuma tampilkan menu
  /// "Input Iklan/Loker" (poin 5: marketing cuma bisa input, bukan approve).
  Future<bool> get isMarketing async {
    final role = await currentRole;
    return role == 'marketing';
  }

  /// True kalau role == 'cs' - menunya cuma Ringkasan + Chat CS, tidak
  /// bisa moderasi konten atau input apapun.
  Future<bool> get isCS async {
    final role = await currentRole;
    return role == 'cs';
  }

  /// True kalau role == 'agen' - kemampuan input Iklan/Loker (dulu
  /// namanya 'marketing'). Beda dengan role 'marketing' yang sekarang
  /// kosong dulu (placeholder) - lihat migration_v8.
  Future<bool> get isAgen async {
    final role = await currentRole;
    return role == 'agen';
  }

  Future<void> _simpanSesi(String token, String username, String role) async {
    _cachedToken = token;
    _cachedUsername = username;
    _cachedRole = role;
    await _storage.write(key: "admin_token", value: token);
    await _storage.write(key: "admin_username", value: username);
    await _storage.write(key: "admin_role", value: role);
  }

  Future<void> logout() async {
    // Beri tahu server (khususnya penting buat CS: status online-nya
    // harus langsung mati begitu logout, dipakai tombol 'Chat CS' di
    // halaman Contact publik). Best-effort - tetap logout lokal walau
    // request ini gagal (mis. sudah tidak ada koneksi).
    try {
      await _dio.post('/logout', options: Options(headers: await _authHeaders()));
    } catch (_) {}

    _cachedToken = null;
    _cachedRole = null;
    _cachedUsername = null;
    await _storage.deleteAll();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await currentToken;
    return {if (token != null) "Authorization": "Bearer $token"};
  }

  Exception _mapError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return Exception(data['detail'].toString());
    }
    if (data is String && data.isNotEmpty) {
      // Kadang body error kebaca sebagai String mentah, bukan Map -
      // coba ambil field "detail"-nya manual biar tetap rapi.
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['detail'] != null) {
          return Exception(decoded['detail'].toString());
        }
      } catch (_) {}
    }

    // Lapisan aman terakhir: kalau body error entah kenapa tidak
    // kebaca (server down, proxy motong response, dll), JANGAN tampilkan
    // paragraf teknis Dio mentah - tebak dari status code saja, tetap
    // pesan pendek yang wajar buat pengguna.
    final status = e.response?.statusCode;
    if (status == 401) return Exception('Username atau password salah.');
    if (status == 403) return Exception('Kamu tidak punya akses untuk ini.');
    if (status == 404) return Exception('Data tidak ditemukan.');
    if (status != null && status >= 500) return Exception('Server sedang bermasalah. Coba lagi nanti.');
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return Exception('Server tidak merespons. Cek koneksi internet.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return Exception('Tidak bisa terhubung ke server. Cek koneksi internet.');
    }
    // JANGAN tampilkan e.message mentah ke user (isinya paragraf teknis
    // Dio yang panjang & jelek) - selalu kembalikan pesan yang rapi.
    return Exception('Terjadi kesalahan. Coba lagi.');
  }

  // ================= AUTH =================

  /// [app] wajib diisi oleh masing-masing aplikasi Flutter (admin/cs/
  /// marketing) - dicek juga di server (lihat APP_ALLOWED_ROLES di
  /// admin_api.py) supaya marketing tidak bisa login di CS/Admin Panel,
  /// begitu juga sebaliknya.
  Future<void> login(String username, String password, {required String app}) async {
    try {
      final res = await _dio.post('/login', data: {"username": username, "password": password, "app": app});
      await _simpanSesi(res.data['accessToken'], res.data['username'], res.data['role']);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Sengaja disamaratakan: salah password, salah role buat aplikasi
      // ini (mis. akun marketing coba login di Admin/CS Panel), atau akun
      // dinonaktifkan - SEMUA ditampilkan sebagai satu pesan generik yang
      // sama. Tidak membocorkan info role/status akun ke orang yang belum
      // tentu pemilik akunnya, dan pesannya jadi bersih & konsisten di
      // ketiga aplikasi (Admin/CS/Marketing Panel).
      if (status == 401 || status == 403) {
        throw Exception('Username atau password salah.');
      }
      throw _mapError(e);
    }
  }

  // ================= KELOLA CS (super_admin) =================

  Future<List<Map<String, dynamic>>> getCsAccounts() async {
    try {
      final res = await _dio.get('/cs-accounts', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createCsAccount({required String username, required String password}) async {
    try {
      await _dio.post('/cs-accounts', data: {"username": username, "password": password, "role": "cs"}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<bool> toggleAdminActive(int adminId) async {
    try {
      final res = await _dio.post('/admins/$adminId/toggle-active', options: Options(headers: await _authHeaders()));
      return res.data['isActive'] as bool;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= KELOLA ADMIN (super_admin) =================

  Future<List<Map<String, dynamic>>> getAdmins() async {
    try {
      final res = await _dio.get('/admins', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createAdmin({required String username, required String password, required String role}) async {
    try {
      await _dio.post('/admins', data: {
        "username": username,
        "password": password,
        "role": role,
      }, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> updateAdminRole(int adminId, String role) async {
    try {
      await _dio.post('/admins/$adminId/role', data: {"role": role}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteAdmin(int adminId) async {
    try {
      await _dio.post('/admins/$adminId/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= DASHBOARD =================

  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _dio.get('/stats', options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= MEMBER =================

  Future<Map<String, dynamic>> getMembers({String? search, String? status, int page = 1}) async {
    try {
      final res = await _dio.get('/members', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Detail lengkap 1 member: biodata, sesi, riwayat login, riwayat
  /// lokasi, barang dijual, loker, profil jodoh - semua digabung.
  Future<Map<String, dynamic>> getMemberDetail(int idMember) async {
    try {
      final res = await _dio.get('/members/$idMember/detail', options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<bool> toggleLockMember(int idMember) async {
    try {
      final res = await _dio.post('/members/$idMember/toggle-lock', options: Options(headers: await _authHeaders()));
      return res.data['isLocked'] as bool;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= SESI & LOKASI =================

  Future<List<Map<String, dynamic>>> getRecentSessions({int limit = 50, bool onlyWithLocation = false}) async {
    try {
      final res = await _dio.get('/sessions/recent', queryParameters: {
        'limit': limit,
        'only_with_location': onlyWithLocation,
      }, options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getLoginLogs({int limit = 100}) async {
    try {
      final res = await _dio.get('/login-logs', queryParameters: {'limit': limit}, options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Return (items, tableExists) - tableExists false kalau
  /// log_user_location belum dibuat di database (lihat
  /// create_log_user_location.sql).
  Future<(List<Map<String, dynamic>>, bool)> getLocationHistory({int limit = 100}) async {
    try {
      final res = await _dio.get('/location-history', queryParameters: {'limit': limit}, options: Options(headers: await _authHeaders()));
      final items = List<Map<String, dynamic>>.from(res.data['items']);
      final exists = res.data['tableExists'] as bool? ?? true;
      return (items, exists);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= IKLAN (Jual Beli) =================

  Future<Map<String, dynamic>> getIklan({String? search, String? status, int page = 1}) async {
    try {
      final res = await _dio.get('/iklan', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> approveIklan(String kodeIklan) async {
    try {
      await _dio.post('/iklan/$kodeIklan/approve', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteIklan(String kodeIklan) async {
    try {
      await _dio.post('/iklan/$kodeIklan/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= LOKER =================

  Future<Map<String, dynamic>> getLokerLowongan({String? search, int page = 1}) async {
    try {
      final res = await _dio.get('/loker/lowongan', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteLokerLowongan(String kode) async {
    try {
      await _dio.post('/loker/lowongan/$kode/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getLokerPencari({String? search, int page = 1}) async {
    try {
      final res = await _dio.get('/loker/pencari', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteLokerPencari(String kode) async {
    try {
      await _dio.post('/loker/pencari/$kode/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= BIRO JODOH =================

  Future<Map<String, dynamic>> getJodoh({String? search, String? status, int page = 1}) async {
    try {
      final res = await _dio.get('/jodoh', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> approveJodoh(String kode) async {
    try {
      await _dio.post('/jodoh/$kode/approve', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> rejectJodoh(String kode) async {
    try {
      await _dio.post('/jodoh/$kode/reject', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteJodoh(String kode) async {
    try {
      await _dio.post('/jodoh/$kode/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> inactiveJodoh(String kode) async {
    try {
      await _dio.post('/jodoh/$kode/inactive', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> inactiveIklan(String kodeIklan) async {
    try {
      await _dio.post('/iklan/$kodeIklan/inactive', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> approveLokerLowongan(String kode) async {
    try {
      await _dio.post('/loker/lowongan/$kode/approve', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> inactiveLokerLowongan(String kode) async {
    try {
      await _dio.post('/loker/lowongan/$kode/inactive', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> approveLokerPencari(String kode) async {
    try {
      await _dio.post('/loker/pencari/$kode/approve', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> inactiveLokerPencari(String kode) async {
    try {
      await _dio.post('/loker/pencari/$kode/inactive', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= MEMBER - RESET PASSWORD (poin 3) =================

  Future<String> sendResetPassword(int idMember) async {
    try {
      final res = await _dio.post('/members/$idMember/send-reset', options: Options(headers: await _authHeaders()));
      return res.data['message'] as String? ?? 'Link reset password terkirim.';
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= MARKETING (poin 1 & 2) =================

  Future<List<Map<String, dynamic>>> getMarketingList() async {
    try {
      final res = await _dio.get('/marketing', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// [role] wajib 'agen' (kemampuan input Iklan/Loker, dulu namanya
  /// 'marketing') atau 'marketing' (kosong dulu, placeholder).
  Future<void> createMarketing({
    required String dashboardUsername,
    required String dashboardPassword,
    required String email,
    required String webPassword,
    required String namaLengkap,
    String? telepon,
    String? alamat,
    String role = 'agen',
  }) async {
    try {
      await _dio.post('/marketing', data: {
        "dashboard_username": dashboardUsername,
        "dashboard_password": dashboardPassword,
        "email": email,
        "web_password": webPassword,
        "nama_lengkap": namaLengkap,
        "telepon": telepon,
        "alamat": alamat,
        "role": role,
      }, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<bool> toggleMarketingActive(int adminId) async {
    try {
      final res = await _dio.post('/marketing/$adminId/toggle-active', options: Options(headers: await _authHeaders()));
      return res.data['isActive'] as bool;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Dipakai marketing buat input Iklan (Jual Beli) atas nama akun member
  /// miliknya sendiri. Karena diinput staff internal, status langsung
  /// 'Approved' (tidak perlu menunggu review). fotoPaths = path file lokal
  /// hasil file_picker, maksimal 5.
  Future<void> marketingCreateIklan({
    required int idKategori,
    required int idLokasi,
    required String judul,
    double? harga,
    String? detail,
    List<String> fotoPaths = const [],
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        "id_lokasi": idLokasi,
        "judul": judul,
        if (harga != null) "harga": harga,
        if (detail != null) "detail": detail,
        "foto": [for (final p in fotoPaths) await MultipartFile.fromFile(p)],
      });
      await _dio.post('/marketing/iklan', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> marketingUpdateIklan({
    required String kodeIklan,
    required int idKategori,
    required int idLokasi,
    required String judul,
    double? harga,
    String? detail,
    List<String> fotoBaruPaths = const [],
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        "id_lokasi": idLokasi,
        "judul": judul,
        if (harga != null) "harga": harga,
        if (detail != null) "detail": detail,
        "foto_baru": [for (final p in fotoBaruPaths) await MultipartFile.fromFile(p)],
      });
      await _dio.post('/marketing/iklan/$kodeIklan/update', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyIklan() async {
    try {
      final res = await _dio.get('/marketing/my-iklan', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> marketingCreateLowongan({
    required int idKategori,
    required String namaPerusahaan,
    String? emailPerusahaan,
    List<String>? posisi,
    String? deskripsi,
    String? lokasiKerja,
    String? gaji,
    String? tenggatWaktu,
    String? fotoPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        "nama_perusahaan": namaPerusahaan,
        if (emailPerusahaan != null) "email_perusahaan": emailPerusahaan,
        if (posisi != null && posisi.isNotEmpty) "posisi_yang_dibutuhkan": posisi.join(','),
        if (deskripsi != null) "deskripsi_lowongan": deskripsi,
        if (lokasiKerja != null) "lokasi_kerja": lokasiKerja,
        if (gaji != null) "gaji_ditawarkan": gaji,
        if (tenggatWaktu != null) "tenggat_waktu": tenggatWaktu,
        if (fotoPath != null) "foto_iklan": await MultipartFile.fromFile(fotoPath),
      });
      await _dio.post('/marketing/loker/lowongan', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> marketingUpdateLowongan({
    required String kodeLowongan,
    required int idKategori,
    required String namaPerusahaan,
    String? emailPerusahaan,
    List<String>? posisi,
    String? deskripsi,
    String? lokasiKerja,
    String? gaji,
    String? tenggatWaktu,
    String? fotoPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        "nama_perusahaan": namaPerusahaan,
        if (emailPerusahaan != null) "email_perusahaan": emailPerusahaan,
        if (posisi != null && posisi.isNotEmpty) "posisi_yang_dibutuhkan": posisi.join(','),
        if (deskripsi != null) "deskripsi_lowongan": deskripsi,
        if (lokasiKerja != null) "lokasi_kerja": lokasiKerja,
        if (gaji != null) "gaji_ditawarkan": gaji,
        if (tenggatWaktu != null) "tenggat_waktu": tenggatWaktu,
        if (fotoPath != null) "foto_iklan": await MultipartFile.fromFile(fotoPath),
      });
      await _dio.post('/marketing/loker/lowongan/$kodeLowongan/update', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyLowongan() async {
    try {
      final res = await _dio.get('/marketing/my-loker/lowongan', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> marketingCreatePencari({
    required int idKategori,
    List<String>? keahlian,
    String? pengalamanKerja,
    String? pendidikanTerakhir,
    String? deskripsiDiri,
    String? linkPortfolio,
    String? gajiHarapan,
    String? domisili,
    String? fotoPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        if (keahlian != null && keahlian.isNotEmpty) "keahlian": keahlian.join(','),
        if (pengalamanKerja != null) "pengalaman_kerja": pengalamanKerja,
        if (pendidikanTerakhir != null) "pendidikan_terakhir": pendidikanTerakhir,
        if (deskripsiDiri != null) "deskripsi_diri": deskripsiDiri,
        if (linkPortfolio != null) "link_portfolio": linkPortfolio,
        if (gajiHarapan != null) "gaji_harapan": gajiHarapan,
        if (domisili != null) "domisili": domisili,
        if (fotoPath != null) "foto_iklan": await MultipartFile.fromFile(fotoPath),
      });
      await _dio.post('/marketing/loker/pencari', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> marketingUpdatePencari({
    required String kodePencari,
    required int idKategori,
    List<String>? keahlian,
    String? pengalamanKerja,
    String? pendidikanTerakhir,
    String? deskripsiDiri,
    String? linkPortfolio,
    String? gajiHarapan,
    String? domisili,
    String? fotoPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        "id_kategori": idKategori,
        if (keahlian != null && keahlian.isNotEmpty) "keahlian": keahlian.join(','),
        if (pengalamanKerja != null) "pengalaman_kerja": pengalamanKerja,
        if (pendidikanTerakhir != null) "pendidikan_terakhir": pendidikanTerakhir,
        if (deskripsiDiri != null) "deskripsi_diri": deskripsiDiri,
        if (linkPortfolio != null) "link_portfolio": linkPortfolio,
        if (gajiHarapan != null) "gaji_harapan": gajiHarapan,
        if (domisili != null) "domisili": domisili,
        if (fotoPath != null) "foto_iklan": await MultipartFile.fromFile(fotoPath),
      });
      await _dio.post('/marketing/loker/pencari/$kodePencari/update', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyPencari() async {
    try {
      final res = await _dio.get('/marketing/my-loker/pencari', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= KATEGORI & LOKASI (poin 3) =================

  Future<List<Map<String, dynamic>>> getKategoriJualBeli() async {
    try {
      final res = await _dio.get('/kategori', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createKategoriJualBeli(String namaKategori, {String? ikon}) async {
    try {
      await _dio.post('/kategori', data: {"nama_kategori": namaKategori, "ikon_kategori": ikon}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteKategoriJualBeli(int id) async {
    try {
      await _dio.post('/kategori/$id/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getLokasi() async {
    try {
      final res = await _dio.get('/lokasi', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createLokasi(String namaLokasi) async {
    try {
      await _dio.post('/lokasi', data: {"nama_lokasi": namaLokasi}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteLokasi(int id) async {
    try {
      await _dio.post('/lokasi/$id/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getLokerKategori() async {
    try {
      final res = await _dio.get('/loker-kategori', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createLokerKategori(String namaKategori, {String? deskripsi}) async {
    try {
      await _dio.post('/loker-kategori', data: {"nama_kategori": namaKategori, "deskripsi_kategori": deskripsi}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteLokerKategori(int id) async {
    try {
      await _dio.post('/loker-kategori/$id/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= DASHBOARD - KURVA HARIAN (poin 6) =================

  Future<List<Map<String, dynamic>>> getStatsCharts({int days = 30}) async {
    try {
      final res = await _dio.get('/stats/charts', queryParameters: {'days': days}, options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['series']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= ADVERTISE (poin 8) =================

  Future<List<Map<String, dynamic>>> getAdvertise() async {
    try {
      final res = await _dio.get('/advertise', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createAdvertise(Map<String, dynamic> body) async {
    try {
      await _dio.post('/advertise', data: body, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> updateAdvertise(int id, Map<String, dynamic> body) async {
    try {
      await _dio.post('/advertise/$id/update', data: body, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> toggleAdvertiseStatus(int id) async {
    try {
      await _dio.post('/advertise/$id/toggle-status', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteAdvertise(int id) async {
    try {
      await _dio.post('/advertise/$id/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= WALLET / METODE PEMBAYARAN (poin 9) =================

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final res = await _dio.get('/payment-methods', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> createPaymentMethod(Map<String, dynamic> body) async {
    try {
      await _dio.post('/payment-methods', data: body, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> updatePaymentMethod(int id, Map<String, dynamic> body) async {
    try {
      await _dio.post('/payment-methods/$id/update', data: body, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deletePaymentMethod(int id) async {
    try {
      await _dio.post('/payment-methods/$id/delete', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= REPORT (poin 7) =================

  Future<Map<String, dynamic>> getReportSummary({String? dateFrom, String? dateTo}) async {
    try {
      final res = await _dio.get('/reports/summary', queryParameters: {
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getTransaksi({String? jenis, String? status, String? search, int page = 1}) async {
    try {
      final res = await _dio.get('/transaksi', queryParameters: {
        if (jenis != null) 'jenis': jenis,
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': 20,
      }, options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= PROMOSI =================

  Future<List<Map<String, dynamic>>> getPromoteIklan() async {
    try {
      final res = await _dio.get('/promote/iklan', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> nonaktifkanPromoteIklan(int idPromote) async {
    try {
      await _dio.post('/promote/iklan/$idPromote/nonaktifkan', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPromoteJodoh() async {
    try {
      final res = await _dio.get('/promote/jodoh', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> nonaktifkanPromoteJodoh(int idPromote) async {
    try {
      await _dio.post('/promote/jodoh/$idPromote/nonaktifkan', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getPromoteLoker() async {
    try {
      final res = await _dio.get('/promote/loker', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> nonaktifkanPromoteLoker(int idPromote) async {
    try {
      await _dio.post('/promote/loker/$idPromote/nonaktifkan', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= CHAT CS =================

  /// Dipanggil berkala (tiap ~30 detik) oleh CS Panel selagi aplikasi
  /// aktif, supaya server tahu staf ini masih online (dipakai tombol
  /// "Chat CS" di halaman Contact publik).
  Future<void> csHeartbeat() async {
    try {
      await _dio.post('/cs/heartbeat', options: Options(headers: await _authHeaders()));
    } catch (_) {
      // Heartbeat gagal sekali-dua kali bukan masalah besar, diamkan saja.
    }
  }

  /// scope: 'antrian' (semua chat menunggu, kelihatan ke semua CS),
  /// 'saya' (chat aktif milikku), 'selesai' (riwayat milikku). Tanpa
  /// scope: gabungan antrian + punya sendiri.
  Future<List<Map<String, dynamic>>> getCsConversations({String? scope}) async {
    try {
      final res = await _dio.get('/cs/conversations', queryParameters: {
        if (scope != null) 'scope': scope,
      }, options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// CS mengambil 1 chat dari antrian. Kalau sudah diambil CS lain
  /// duluan, server balas error 409 - tangani di UI dengan refresh list.
  Future<void> claimCsConversation(int idConv) async {
    try {
      await _dio.post('/cs/conversations/$idConv/claim', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> endCsConversation(int idConv) async {
    try {
      await _dio.post('/cs/conversations/$idConv/end', options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getCsMessages(int idConv) async {
    try {
      final res = await _dio.get('/cs/conversations/$idConv/messages', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> csReply(int idConv, String message) async {
    try {
      await _dio.post('/cs/conversations/$idConv/reply', data: {"message": message}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> csReplyImage(int idConv, String imagePath) async {
    try {
      final formData = FormData.fromMap({"foto": await MultipartFile.fromFile(imagePath)});
      await _dio.post('/cs/conversations/$idConv/reply-image', data: formData, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= LAPORAN CS -> ADMIN =================

  /// jenisTarget: 'member' | 'iklan' | 'jodoh' | 'loker_lowongan' | 'loker_pencari'
  Future<void> createCsReport({required String jenisTarget, required int idTarget, required String catatan}) async {
    try {
      await _dio.post('/cs/reports', data: {
        "jenis_target": jenisTarget,
        "id_target": idTarget,
        "catatan": catatan,
      }, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Kalau dipanggil role cs, otomatis cuma laporan miliknya sendiri
  /// (dibatasi server). admin/super_admin lihat semua laporan.
  Future<List<Map<String, dynamic>>> getCsReports({String? status}) async {
    try {
      final res = await _dio.get('/cs/reports', queryParameters: {
        if (status != null) 'status': status,
      }, options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> handleCsReport(int idLaporan, {required String status, String? catatanAdmin}) async {
    try {
      await _dio.post('/cs/reports/$idLaporan/tangani', data: {
        "status": status,
        "catatan_admin": catatanAdmin,
      }, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ================= CHAT INTERNAL (Admin <-> Marketing/Agen) =================

  /// Dipakai sisi staf (marketing/agen) - percakapan pribadinya sendiri
  /// dengan Admin, dibuat otomatis kalau belum ada.
  Future<Map<String, dynamic>> getMyInternalChat() async {
    try {
      final res = await _dio.get('/internal-chat/my-conversation', options: Options(headers: await _authHeaders()));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> sendInternalChatAsStaff(String message) async {
    try {
      await _dio.post('/internal-chat/my-conversation/send', data: {"message": message}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Dipakai sisi admin/super_admin - daftar semua percakapan dengan
  /// staf marketing/agen.
  Future<List<Map<String, dynamic>>> getInternalChatConversations() async {
    try {
      final res = await _dio.get('/internal-chat/conversations', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInternalChatMessages(int idConv) async {
    try {
      final res = await _dio.get('/internal-chat/conversations/$idConv/messages', options: Options(headers: await _authHeaders()));
      return List<Map<String, dynamic>>.from(res.data['items']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> replyInternalChatAsAdmin(int idConv, String message) async {
    try {
      await _dio.post('/internal-chat/conversations/$idConv/reply', data: {"message": message}, options: Options(headers: await _authHeaders()));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
