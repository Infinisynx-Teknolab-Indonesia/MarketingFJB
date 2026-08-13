import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import '../services/server_config.dart';
import 'dashboard_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Mode koneksi - dipakai buat testing sebelum konek ke server beneran.
  // Nilai awal diambil dari pilihan yang sudah tersimpan (ServerConfig).
  late bool _useLocal = ServerConfig().useLocal;

  @override
  void initState() {
    super.initState();
    _localUrlController.text = ServerConfig().localUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _localUrlController.dispose();
    super.dispose();
  }

  /// Simpan pilihan mode + URL local, lalu langsung terapkan ke
  /// AdminApiService supaya percobaan login berikutnya pakai baseUrl baru.
  Future<void> _terapkanModeKoneksi() async {
    await ServerConfig().setMode(
      useLocal: _useLocal,
      localUrl: _useLocal ? _localUrlController.text : null,
    );
    AdminApiService().applyServerConfig();
  }

  Future<void> _handleLogin() async {
    await _terapkanModeKoneksi();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AdminApiService().login(_usernameController.text.trim(), _passwordController.text, app: 'marketing');
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardShell()));
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFB8860B), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.campaign, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('FJB Batam', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                const Center(
                  child: Text('Agen & Marketing Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                // ===== Mode Koneksi (Server / Local) - buat testing =====
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dns_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text('Mode Koneksi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Server'),
                              selected: !_useLocal,
                              onSelected: (v) => setState(() => _useLocal = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Local'),
                              selected: _useLocal,
                              onSelected: (v) => setState(() => _useLocal = true),
                            ),
                          ),
                        ],
                      ),
                      if (_useLocal) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _localUrlController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'URL server local',
                            hintText: 'http://localhost:5050/admin/api',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Username wajib diisi' : null,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB8860B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
