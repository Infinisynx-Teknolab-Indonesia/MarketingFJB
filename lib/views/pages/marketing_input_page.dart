import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/admin_api_service.dart';
import '../../services/server_config.dart';

/// Halaman utama Marketing Panel: input Iklan (Jual Beli) dan Loker
/// (lowongan & pencari kerja) atas nama akun member miliknya sendiri,
/// lengkap dengan foto, kategori/lokasi dari dropdown (bukan ID manual),
/// dan daftar konten yang sudah dia input (bisa diedit karena dia
/// pemiliknya). Konten otomatis 'Approved' karena diinput staff internal.
class MarketingInputPage extends StatefulWidget {
  const MarketingInputPage({super.key});

  @override
  State<MarketingInputPage> createState() => _MarketingInputPageState();
}

class _MarketingInputPageState extends State<MarketingInputPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Input Konten', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text(
            'Iklan & Loker yang kamu input di sini langsung aktif atas nama akunmu sendiri.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF1E3A8A),
            tabs: const [
              Tab(text: 'Iklan Jual Beli'),
              Tab(text: 'Lowongan Kerja'),
              Tab(text: 'Pencari Kerja'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_IklanTab(), _LowonganTab(), _PencariTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB IKLAN JUAL BELI
// ============================================================

class _IklanTab extends StatefulWidget {
  const _IklanTab();
  @override
  State<_IklanTab> createState() => _IklanTabState();
}

class _IklanTabState extends State<_IklanTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final data = await AdminApiService().getMyIklan();
      setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _bukaForm({Map<String, dynamic>? existing}) async {
    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => _IklanFormDialog(existing: existing),
    );
    if (berhasil == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _bukaForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Ajukan Iklan Baru', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('Belum ada iklan yang kamu input.', style: TextStyle(color: Colors.grey)))
                      : Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final fotoUrl = item['foto'] != null ? '${ServerConfig().imageBaseUrl}/images/gambariklan/${item['foto']}' : null;
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: fotoUrl != null
                                      ? Image.network(fotoUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.grey.shade200))
                                      : Container(width: 44, height: 44, color: Colors.grey.shade200, child: const Icon(Icons.image_outlined, color: Colors.grey)),
                                ),
                                title: Text(item['judul'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                subtitle: Text('${item['nama_kategori'] ?? '-'} • ${item['nama_lokasi'] ?? '-'} • ${item['view'] ?? 0} dilihat', style: const TextStyle(fontSize: 12)),
                                trailing: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Chip(
                                      label: Text(item['status_iklan_baru'] ?? '-', style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                                      backgroundColor: item['status_iklan_baru'] == 'Approved' ? Colors.green : Colors.grey,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _bukaForm(existing: item)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _IklanFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _IklanFormDialog({this.existing});

  @override
  State<_IklanFormDialog> createState() => _IklanFormDialogState();
}

class _IklanFormDialogState extends State<_IklanFormDialog> {
  final _judulC = TextEditingController();
  final _hargaC = TextEditingController();
  final _detailC = TextEditingController();
  List<Map<String, dynamic>> _kategoriList = [];
  List<Map<String, dynamic>> _lokasiList = [];
  int? _idKategori;
  int? _idLokasi;
  List<String> _fotoPaths = [];
  bool _loadingOptions = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _judulC.text = widget.existing?['judul'] ?? '';
    _hargaC.text = widget.existing?['harga']?.toString() ?? '';
    _detailC.text = widget.existing?['detail'] ?? '';
    _idKategori = widget.existing?['id_kategori'];
    _idLokasi = widget.existing?['id_lokasi'];
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([AdminApiService().getKategoriJualBeli(), AdminApiService().getLokasi()]);
      setState(() {
        _kategoriList = results[0];
        _lokasiList = results[1];
        _loadingOptions = false;
      });
    } catch (e) {
      setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pilihFoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() => _fotoPaths = result.paths.whereType<String>().take(5).toList());
    }
  }

  Future<void> _submit() async {
    if (_judulC.text.trim().isEmpty || _idKategori == null || _idLokasi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul, Kategori, dan Lokasi wajib diisi.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.existing == null) {
        await AdminApiService().marketingCreateIklan(
          idKategori: _idKategori!,
          idLokasi: _idLokasi!,
          judul: _judulC.text.trim(),
          harga: double.tryParse(_hargaC.text.trim()),
          detail: _detailC.text.trim().isEmpty ? null : _detailC.text.trim(),
          fotoPaths: _fotoPaths,
        );
      } else {
        await AdminApiService().marketingUpdateIklan(
          kodeIklan: widget.existing!['kode_iklan'],
          idKategori: _idKategori!,
          idLokasi: _idLokasi!,
          judul: _judulC.text.trim(),
          harga: double.tryParse(_hargaC.text.trim()),
          detail: _detailC.text.trim().isEmpty ? null : _detailC.text.trim(),
          fotoBaruPaths: _fotoPaths,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Ajukan Iklan Baru' : 'Edit Iklan'),
      content: SizedBox(
        width: 420,
        child: _loadingOptions
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: _judulC, decoration: const InputDecoration(labelText: 'Judul Iklan', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _idKategori,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: _kategoriList.map((k) => DropdownMenuItem<int>(value: k['id_kategori'], child: Text(k['nama_kategori']))).toList(),
                      onChanged: (v) => setState(() => _idKategori = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _idLokasi,
                      decoration: const InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder()),
                      items: _lokasiList.map((l) => DropdownMenuItem<int>(value: l['id_lokasi'], child: Text(l['nama_lokasi']))).toList(),
                      onChanged: (v) => setState(() => _idLokasi = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _hargaC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (kosongkan / isi 1 kalau nego)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _detailC, maxLines: 4, decoration: const InputDecoration(labelText: 'Detail', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(onPressed: _pilihFoto, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Pilih Foto (maks 5)')),
                    ),
                    if (_fotoPaths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          children: _fotoPaths.map((p) => ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(File(p), width: 56, height: 56, fit: BoxFit.cover),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ============================================================
// TAB LOWONGAN KERJA
// ============================================================

class _LowonganTab extends StatefulWidget {
  const _LowonganTab();
  @override
  State<_LowonganTab> createState() => _LowonganTabState();
}

class _LowonganTabState extends State<_LowonganTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final data = await AdminApiService().getMyLowongan();
      setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _bukaForm({Map<String, dynamic>? existing}) async {
    final berhasil = await showDialog<bool>(context: context, builder: (context) => _LowonganFormDialog(existing: existing));
    if (berhasil == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _bukaForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Ajukan Lowongan Baru', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('Belum ada lowongan yang kamu input.', style: TextStyle(color: Colors.grey)))
                      : Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListTile(
                                leading: const Icon(Icons.apartment_outlined),
                                title: Text(item['nama_perusahaan'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                subtitle: Text('${item['lokasi_kerja'] ?? '-'} • ${item['total_lamaran'] ?? 0} lamaran', style: const TextStyle(fontSize: 12)),
                                trailing: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Chip(
                                      label: Text(item['status_moderasi'] ?? '-', style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                                      backgroundColor: item['status_moderasi'] == 'Approved' ? Colors.green : Colors.grey,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _bukaForm(existing: item)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _LowonganFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LowonganFormDialog({this.existing});

  @override
  State<_LowonganFormDialog> createState() => _LowonganFormDialogState();
}

class _LowonganFormDialogState extends State<_LowonganFormDialog> {
  final _perusahaanC = TextEditingController();
  final _emailC = TextEditingController();
  final _posisiC = TextEditingController();
  final _deskripsiC = TextEditingController();
  final _lokasiC = TextEditingController();
  final _gajiC = TextEditingController();
  List<Map<String, dynamic>> _kategoriList = [];
  int? _idKategori;
  String? _fotoPath;
  bool _loadingOptions = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _perusahaanC.text = widget.existing?['nama_perusahaan'] ?? '';
    _emailC.text = widget.existing?['email_perusahaan'] ?? '';
    _deskripsiC.text = widget.existing?['deskripsi_lowongan'] ?? '';
    _lokasiC.text = widget.existing?['lokasi_kerja'] ?? '';
    _gajiC.text = widget.existing?['gaji_ditawarkan'] ?? '';
    _idKategori = widget.existing?['id_kategori'];
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final data = await AdminApiService().getLokerKategori();
      setState(() { _kategoriList = data; _loadingOptions = false; });
    } catch (e) {
      setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pilihFoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.paths.isNotEmpty) {
      setState(() => _fotoPath = result.paths.first);
    }
  }

  Future<void> _submit() async {
    if (_perusahaanC.text.trim().isEmpty || _idKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama perusahaan & Kategori wajib diisi.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final posisi = _posisiC.text.trim().isEmpty ? null : _posisiC.text.trim().split(',').map((e) => e.trim()).toList();
      if (widget.existing == null) {
        await AdminApiService().marketingCreateLowongan(
          idKategori: _idKategori!,
          namaPerusahaan: _perusahaanC.text.trim(),
          emailPerusahaan: _emailC.text.trim().isEmpty ? null : _emailC.text.trim(),
          posisi: posisi,
          deskripsi: _deskripsiC.text.trim().isEmpty ? null : _deskripsiC.text.trim(),
          lokasiKerja: _lokasiC.text.trim().isEmpty ? null : _lokasiC.text.trim(),
          gaji: _gajiC.text.trim().isEmpty ? null : _gajiC.text.trim(),
          fotoPath: _fotoPath,
        );
      } else {
        await AdminApiService().marketingUpdateLowongan(
          kodeLowongan: widget.existing!['kode_lowongan'],
          idKategori: _idKategori!,
          namaPerusahaan: _perusahaanC.text.trim(),
          emailPerusahaan: _emailC.text.trim().isEmpty ? null : _emailC.text.trim(),
          posisi: posisi,
          deskripsi: _deskripsiC.text.trim().isEmpty ? null : _deskripsiC.text.trim(),
          lokasiKerja: _lokasiC.text.trim().isEmpty ? null : _lokasiC.text.trim(),
          gaji: _gajiC.text.trim().isEmpty ? null : _gajiC.text.trim(),
          fotoPath: _fotoPath,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Ajukan Lowongan Baru' : 'Edit Lowongan'),
      content: SizedBox(
        width: 420,
        child: _loadingOptions
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: _perusahaanC, decoration: const InputDecoration(labelText: 'Nama Perusahaan', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _idKategori,
                      decoration: const InputDecoration(labelText: 'Kategori Loker', border: OutlineInputBorder()),
                      items: _kategoriList.map((k) => DropdownMenuItem<int>(value: k['id_kategori'], child: Text(k['nama_kategori']))).toList(),
                      onChanged: (v) => setState(() => _idKategori = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email Perusahaan (opsional)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _posisiC, decoration: const InputDecoration(labelText: 'Posisi Dibutuhkan (pisah koma)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _lokasiC, decoration: const InputDecoration(labelText: 'Lokasi Kerja', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _gajiC, decoration: const InputDecoration(labelText: 'Gaji Ditawarkan', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _deskripsiC, maxLines: 4, decoration: const InputDecoration(labelText: 'Deskripsi Lowongan', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(onPressed: _pilihFoto, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_fotoPath == null ? 'Pilih Logo/Foto' : 'Foto dipilih')),
                    ),
                    if (_fotoPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(_fotoPath!), width: 56, height: 56, fit: BoxFit.cover)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ============================================================
// TAB PENCARI KERJA
// ============================================================

class _PencariTab extends StatefulWidget {
  const _PencariTab();
  @override
  State<_PencariTab> createState() => _PencariTabState();
}

class _PencariTabState extends State<_PencariTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final data = await AdminApiService().getMyPencari();
      setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _bukaForm({Map<String, dynamic>? existing}) async {
    final berhasil = await showDialog<bool>(context: context, builder: (context) => _PencariFormDialog(existing: existing));
    if (berhasil == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _bukaForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Ajukan Profil Baru', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('Belum ada profil pencari kerja yang kamu input.', style: TextStyle(color: Colors.grey)))
                      : Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(item['domisili'] ?? item['kode_pencarikerja'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                subtitle: Text('${item['pendidikan_terakhir'] ?? '-'} • ${item['gaji_harapan'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                                trailing: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Chip(
                                      label: Text(item['status_moderasi'] ?? '-', style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                                      backgroundColor: item['status_moderasi'] == 'Approved' ? Colors.green : Colors.grey,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _bukaForm(existing: item)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _PencariFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _PencariFormDialog({this.existing});

  @override
  State<_PencariFormDialog> createState() => _PencariFormDialogState();
}

class _PencariFormDialogState extends State<_PencariFormDialog> {
  final _keahlianC = TextEditingController();
  final _pengalamanC = TextEditingController();
  final _pendidikanC = TextEditingController();
  final _deskripsiC = TextEditingController();
  final _portfolioC = TextEditingController();
  final _gajiC = TextEditingController();
  final _domisiliC = TextEditingController();
  List<Map<String, dynamic>> _kategoriList = [];
  int? _idKategori;
  String? _fotoPath;
  bool _loadingOptions = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _pengalamanC.text = widget.existing?['pengalaman_kerja'] ?? '';
    _pendidikanC.text = widget.existing?['pendidikan_terakhir'] ?? '';
    _deskripsiC.text = widget.existing?['deskripsi_diri'] ?? '';
    _portfolioC.text = widget.existing?['link_portfolio'] ?? '';
    _gajiC.text = widget.existing?['gaji_harapan'] ?? '';
    _domisiliC.text = widget.existing?['domisili'] ?? '';
    _idKategori = widget.existing?['id_kategori'];
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final data = await AdminApiService().getLokerKategori();
      setState(() { _kategoriList = data; _loadingOptions = false; });
    } catch (e) {
      setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pilihFoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.paths.isNotEmpty) {
      setState(() => _fotoPath = result.paths.first);
    }
  }

  Future<void> _submit() async {
    if (_idKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori wajib dipilih.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final keahlian = _keahlianC.text.trim().isEmpty ? null : _keahlianC.text.trim().split(',').map((e) => e.trim()).toList();
      if (widget.existing == null) {
        await AdminApiService().marketingCreatePencari(
          idKategori: _idKategori!,
          keahlian: keahlian,
          pengalamanKerja: _pengalamanC.text.trim().isEmpty ? null : _pengalamanC.text.trim(),
          pendidikanTerakhir: _pendidikanC.text.trim().isEmpty ? null : _pendidikanC.text.trim(),
          deskripsiDiri: _deskripsiC.text.trim().isEmpty ? null : _deskripsiC.text.trim(),
          linkPortfolio: _portfolioC.text.trim().isEmpty ? null : _portfolioC.text.trim(),
          gajiHarapan: _gajiC.text.trim().isEmpty ? null : _gajiC.text.trim(),
          domisili: _domisiliC.text.trim().isEmpty ? null : _domisiliC.text.trim(),
          fotoPath: _fotoPath,
        );
      } else {
        await AdminApiService().marketingUpdatePencari(
          kodePencari: widget.existing!['kode_pencarikerja'],
          idKategori: _idKategori!,
          keahlian: keahlian,
          pengalamanKerja: _pengalamanC.text.trim().isEmpty ? null : _pengalamanC.text.trim(),
          pendidikanTerakhir: _pendidikanC.text.trim().isEmpty ? null : _pendidikanC.text.trim(),
          deskripsiDiri: _deskripsiC.text.trim().isEmpty ? null : _deskripsiC.text.trim(),
          linkPortfolio: _portfolioC.text.trim().isEmpty ? null : _portfolioC.text.trim(),
          gajiHarapan: _gajiC.text.trim().isEmpty ? null : _gajiC.text.trim(),
          domisili: _domisiliC.text.trim().isEmpty ? null : _domisiliC.text.trim(),
          fotoPath: _fotoPath,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Ajukan Profil Pencari Kerja' : 'Edit Profil Pencari Kerja'),
      content: SizedBox(
        width: 420,
        child: _loadingOptions
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _idKategori,
                      decoration: const InputDecoration(labelText: 'Kategori Loker', border: OutlineInputBorder()),
                      items: _kategoriList.map((k) => DropdownMenuItem<int>(value: k['id_kategori'], child: Text(k['nama_kategori']))).toList(),
                      onChanged: (v) => setState(() => _idKategori = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _keahlianC, decoration: const InputDecoration(labelText: 'Keahlian (pisah koma)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _pengalamanC, decoration: const InputDecoration(labelText: 'Pengalaman Kerja', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _pendidikanC, decoration: const InputDecoration(labelText: 'Pendidikan Terakhir', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _domisiliC, decoration: const InputDecoration(labelText: 'Domisili', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _gajiC, decoration: const InputDecoration(labelText: 'Gaji Harapan', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _portfolioC, decoration: const InputDecoration(labelText: 'Link Portfolio', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _deskripsiC, maxLines: 4, decoration: const InputDecoration(labelText: 'Deskripsi Diri', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(onPressed: _pilihFoto, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_fotoPath == null ? 'Pilih Foto Profil' : 'Foto dipilih')),
                    ),
                    if (_fotoPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(_fotoPath!), width: 56, height: 56, fit: BoxFit.cover)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}
