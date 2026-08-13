import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_center.dart';
import '../widgets/notif_bell_icon.dart';
import 'login_page.dart';
import 'pages/marketing_overview_page.dart';
import 'pages/marketing_input_page.dart';
import 'pages/marketing_blank_page.dart';
import 'pages/staff_chat_page.dart';

/// Dashboard Agen & Marketing Panel - aplikasi TERPISAH dari Admin Panel
/// & CS Panel. Login role 'agen' ATAU 'marketing' (dicek di server,
/// lihat APP_ALLOWED_ROLES di admin_api.py). Tampilannya BEDA sesuai
/// role:
///   - agen      : Ringkasan, Input Konten (Iklan/Loker), Chat Admin
///   - marketing : Chat Admin saja + halaman placeholder kosong (belum
///                 ada fitur - menunggu pengembangan lanjutan)
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;
  String? _username;
  String? _role;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadSesi();
    SocketService().connect();
    NotificationCenter().attachSocketListeners();
  }

  Future<void> _loadSesi() async {
    final username = await AdminApiService().currentUsername;
    final role = await AdminApiService().currentRole;
    setState(() {
      _username = username;
      _role = role;
      _isLoadingRole = false;
    });
  }

  bool get _isAgen => _role == 'agen';

  List<_MenuItem> get _menuItems {
    if (_isAgen) {
      return const [
        _MenuItem('Ringkasan', Icons.dashboard_outlined),
        _MenuItem('Input Konten', Icons.add_box_outlined),
        _MenuItem('Chat Admin', Icons.support_agent_outlined),
      ];
    }
    return const [
      _MenuItem('Beranda', Icons.dashboard_outlined),
      _MenuItem('Chat Admin', Icons.support_agent_outlined),
    ];
  }

  List<Widget> get _pages {
    if (_isAgen) {
      return [
        MarketingOverviewPage(onNavigate: _navigateByLabel),
        const MarketingInputPage(),
        const StaffChatPage(),
      ];
    }
    return const [
      MarketingBlankPage(),
      StaffChatPage(),
    ];
  }

  void _navigateByLabel(String label) {
    final index = _menuItems.indexWhere((m) => m.label == label);
    if (index != -1) setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Kamu akan keluar dari Agen & Marketing Panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (konfirmasi != true) return;

    await AdminApiService().logout();
    SocketService().disconnect();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  static const _roleLabel = {'agen': 'Agen', 'marketing': 'Marketing'};

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                        child: Text('FJB Batam\nAgen & Marketing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5, height: 1.3)),
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
                              Text(_roleLabel[_role] ?? _role ?? '-', style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
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
              child: Column(
                children: [
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedBuilder(
                          animation: NotificationCenter(),
                          builder: (context, _) => NotifBellIcon(
                            icon: Icons.forum_outlined,
                            count: NotificationCenter().chatAdminUnread,
                            tooltip: 'Chat Admin',
                            onTap: () => _navigateByLabel('Chat Admin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(index: selectedIndex, children: _pages),
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

class _MenuItem {
  final String label;
  final IconData icon;
  const _MenuItem(this.label, this.icon);
}
