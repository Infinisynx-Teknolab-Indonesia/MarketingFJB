import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/admin_api_service.dart';
import 'views/login_page.dart';
import 'views/dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup jendela desktop - ukuran nyaman buat tabel & sidebar.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 700),
    center: true,
    title: 'FJB Batam - Marketing Panel',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FJB Batam - Marketing Panel',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFFB8860B),
        scaffoldBackgroundColor: const Color(0xFFF1F3F8),
        fontFamily: 'Roboto',
      ),
      home: const _SplashDecider(),
    );
  }
}

/// Cek apakah ada token admin tersimpan - kalau ada, langsung ke
/// Dashboard tanpa perlu login ulang tiap buka app.
class _SplashDecider extends StatefulWidget {
  const _SplashDecider();

  @override
  State<_SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<_SplashDecider> {
  @override
  void initState() {
    super.initState();
    _cekSesi();
  }

  Future<void> _cekSesi() async {
    final token = await AdminApiService().currentToken;
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardShell()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
