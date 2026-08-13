import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import 'login_page.dart';
import 'pages/marketing_overview_page.dart';
import 'pages/marketing_input_page.dart';

/// Dashboard Marketing Panel - aplikasi TERPISAH dari Admin Panel & CS
/// Panel. Login role 'marketing' saja (dicek di server, lihat
/// APP_ALLOWED_ROLES di admin_api.py). Menu sengaja cuma 2: Ringkasan
/// (ringan) dan Input Konten - marketing HANYA bisa input Iklan & Loker
/// atas nama akunnya sendiri, tidak bisa moderasi apapun.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;
  String? _username;

  static const _menuItems = [
    _MenuItem('Ringkasan', Icons.dashboard_outlined),
    _MenuItem('Input Konten', Icons.add_box_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadSesi();
  }

  Future<void> _loadSesi() async {
    final username = await AdminApiService().currentUsername;
    setState(() => _username = username);
  }

  List<Widget> get _pages => [
        MarketingOverviewPage(onNavigate: _navigateByLabel),
        const MarketingInputPage(),
      ];

  void _navigateByLabel(String label) {
    final index = _menuItems.indexWhere((m) => m.label == label);
    if (index != -1) setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Kamu akan keluar dari Marketing Panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (konfirmasi != true) return;

    await AdminApiService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex.clamp(0, _pages.length - 1);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: const Color(0xFF3D2A00),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.centerLeft,
                  child: const Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.white, size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('FJB Batam\nMarketing Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5, height: 1.3)),
                      ),
                    ],
                  ),
                ),
                if (_username != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_username!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              const Text('Marketing', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final selected = index == selectedIndex;
                      return Material(
                        color: selected ? const Color(0xFFB8860B) : Colors.transparent,
                        child: ListTile(
                          leading: Icon(item.icon, color: Colors.white, size: 20),
                          title: Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    title: const Text('Keluar', style: TextStyle(color: Colors.redAccent, fontSize: 13.5)),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF1F3F8),
              child: IndexedStack(index: selectedIndex, children: _pages),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  const _MenuItem(this.label, this.icon);
}
