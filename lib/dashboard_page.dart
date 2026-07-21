import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // pastikan package 'intl' sudah ada di pubspec.yaml
import 'admin_profile_page.dart';
import 'main.dart'; // pakai AppColors yang sudah didefinisikan di main.dart
import 'services/auth_service.dart';
import 'utils/csv_downloader.dart';

/// Model satu baris data tamu, dipetakan dari dokumen di collection
/// `guests` (Firestore). SENGAJA cuma "membaca" collection ini — dashboard
/// admin tidak pernah menulis/mengubah struktur `guests`, kecuali field
/// `status` dan `selesaiAt` yang memang sengaja ditulis balik oleh admin
/// lewat badge status.
///
/// Catatan nama field: disesuaikan dengan field yang dipakai form tamu.
/// Kalau nanti field aslinya beda nama, tinggal ganti key di
/// `GuestRecord.fromDoc` di bawah ini saja — bagian lain tidak perlu
/// diubah.
class GuestRecord {
  final String id;
  final DateTime? tanggal;
  final String kodeTamu;
  final String namaLengkap;
  final String jenisKelamin;
  final String alamatLengkap;
  final String keperluan;
  final String keteranganTambahan;
  final String? fotoUrl;
  final String status;
  // Waktu tamu mengisi/submit form (dipakai untuk kolom "Waktu Masuk").
  final DateTime? waktuMasuk;
  // Waktu admin menandai status jadi "selesai" (dipakai untuk kolom
  // "Waktu Selesai"). Null selama status masih "menunggu".
  final DateTime? waktuSelesai;

  const GuestRecord({
    required this.id,
    required this.tanggal,
    required this.kodeTamu,
    required this.namaLengkap,
    required this.jenisKelamin,
    required this.alamatLengkap,
    required this.keperluan,
    required this.keteranganTambahan,
    required this.fotoUrl,
    required this.status,
    required this.waktuMasuk,
    required this.waktuSelesai,
  });

  /// Dianggap "selesai" HANYA kalau field status persis 'selesai'
  /// (case-insensitive). Selain itu (termasuk kosong/'-'/status lain
  /// peninggalan lama seperti 'aktif'/'pending') dianggap "menunggu" —
  /// dipakai juga oleh statistik dashboard supaya jumlahnya konsisten
  /// dengan badge di tabel Data Pelanggan.
  bool get sudahSelesai => status.toLowerCase() == 'selesai';

  /// Gabungan semua teks yang bisa dicari lewat kotak "Cari..." di atas
  /// (dibuat lowercase sekali di sini supaya pencarian efisien & tidak
  /// perlu lowercase berulang tiap kali dibandingkan). Mencakup SEMUA
  /// field yang relevan -- termasuk tanggal & waktu -- supaya admin bisa
  /// mencari data pelanggan apa saja lewat satu kotak cari yang sama
  /// (nomor kode tamu, waktu masuk/selesai, nama, kelamin, alamat,
  /// keperluan, keterangan, status, dll).
  String get searchableText {
    final tanggalFmt = DateFormat('dd/MM/yyyy');
    final jamFmt = DateFormat('HH:mm');
    return [
      namaLengkap,
      kodeTamu,
      alamatLengkap,
      keperluan,
      keteranganTambahan,
      jenisKelamin,
      status,
      sudahSelesai ? 'selesai' : 'menunggu',
      if (tanggal != null) tanggalFmt.format(tanggal!),
      if (waktuMasuk != null) jamFmt.format(waktuMasuk!),
      if (waktuSelesai != null) jamFmt.format(waktuSelesai!),
    ].join(' ').toLowerCase();
  }

  factory GuestRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return GuestRecord(
      id: doc.id,
      // Coba field 'tanggalKunjungan' dulu, kalau tidak ada fallback ke
      // 'createdAt' (waktu server saat dokumen dibuat).
      tanggal: _parseTanggal(data['tanggalKunjungan'] ?? data['createdAt']),
      kodeTamu: _str(data['kodeTamu']),
      namaLengkap: _str(data['nama']),
      jenisKelamin: _str(data['jenisKelamin']),
      alamatLengkap: _str(data['alamat']),
      keperluan: _str(data['keperluan']),
      keteranganTambahan: _str(
        data['keteranganTambahan'] ?? data['keterangan'],
      ),
      fotoUrl: (data['fotoUrl'] ?? data['foto']) as String?,
      status: _str(data['status']),
      // "Waktu Masuk" = saat tamu submit form -> selalu ambil dari
      // createdAt (timestamp server), bukan dari tanggalKunjungan (yang
      // biasanya cuma tanggal tanpa jam).
      waktuMasuk: _parseTanggal(data['createdAt']),
      waktuSelesai: _parseTanggal(data['selesaiAt']),
    );
  }

  static String _str(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? '-' : s;
  }

  static DateTime? _parseTanggal(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateFormat('dd/MM/yyyy').parse(value);
      } catch (_) {}
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }
}

/// Warna tambahan khusus dashboard
class _DashColors {
  static const sidebarDark = AppColors.navy; // navy gelap
  static const sidebarTop = AppColors.teal; // teal terang (area avatar/topbar)
  static const menuActive = Color(0xFF0E7E8C); // highlight menu aktif
  // Highlight blok untuk item menu aktif -- gaya "flat", jadi cuma beda
  // shade (sedikit lebih terang dari background sidebar), bukan warna lain.
  static const menuActiveBg = Color(0x33FFFFFF); // putih transparan tipis
  static const bg = Color(0xFFBDBDBD); // background konten abu-abu
  static const red = Color(0xFFE63946); // tombol logout
  // Warna teks breadcrumb (link non-aktif abu, item aktif pakai teal).
  static const breadcrumbMuted = Color(0xFF6B7280);
}

/// Sepasang tombol aksi dialog (Batal + tombol konfirmasi) dengan gaya
/// yang RAPI & KONSISTEN di seluruh app: sama-sama lebar penuh sejajar,
/// tinggi & radius sama, tombol "Batal" berupa outline abu (tidak
/// menarik perhatian), tombol konfirmasi terisi warna solid sesuai
/// konteksnya (merah untuk aksi berbahaya seperti keluar, hijau untuk
/// aksi positif seperti menandai selesai, dst).
class _DialogActionButtons extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _DialogActionButtons({
    this.cancelLabel = 'Batal',
    required this.confirmLabel,
    required this.confirmColor,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 10.0;
    const height = 42.0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkText,
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: Text(
                cancelLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: height,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu kartu statistik di halaman Dashboard (mis. "Total Pelanggan: 128").
class _StatItem {
  final String label;
  final String value;
  // Identitas stat ('total' / 'menunggu' / 'selesai') dipakai untuk
  // menentukan gradient warna, ikon, dan tujuan navigasi saat kartu
  // diketuk.
  final String key;
  const _StatItem({
    required this.label,
    required this.value,
    required this.key,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 0 = Dashboard, 1 = Data Pelanggan, 2 = Profil Admin
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  // Teks yang sedang diketik di kotak "Cari..." -- dipakai untuk
  // memfilter tabel Data Pelanggan secara real-time. Pencarian selalu
  // mencakup SEMUA field sekaligus (lihat `GuestRecord.searchableText`) --
  // tidak ada lagi filter/kategori pencarian terpisah.
  String _searchQuery = '';

  // Baris tamu (guests) yang sedang tampil di tabel Data Pelanggan
  // (setelah difilter tanggal & pencarian). Dipakai supaya tombol
  // download CSV bisa mengekspor data ASLI yang sedang dilihat admin,
  // bukan data statis.
  List<GuestRecord> _currentGuestRows = const [];

  // Statistik dashboard (Total Pelanggan / Menunggu / Selesai), dihitung
  // real-time dari Firestore oleh _DashboardContent lalu dilaporkan balik
  // ke sini lewat callback -- dipakai supaya tombol download CSV di
  // halaman Dashboard mengekspor angka yang SAMA dengan yang tampil di
  // layar, bukan data statis.
  List<_StatItem> _currentStats = const [];

  // Status buka/tutup sidebar di layar sempit (HP/tablet kecil). Sidebar
  // TIDAK memakai Drawer bawaan Flutter lagi (yang menumpuk/menyembunyikan
  // konten di belakangnya) -- sebagai gantinya lebar sidebar dianimasikan
  // dari 0 ke 220 sehingga konten di sebelahnya benar-benar bergeser ke
  // samping (efek "menarik" konten), bukan disembunyikan di belakang
  // overlay gelap. Defaultnya TERBUKA (di semua ukuran layar) -- tombol
  // 3-garis di navbar selalu tampil dan bisa dipakai untuk buka/tutup
  // kapan saja, bukan cuma di layar sempit.
  bool _sidebarOpen = true;

  static const _menuTitles = ['Beranda', 'Data Pelanggan', 'Profil'];
  static const _menuIcons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.account_circle_outlined,
  ];

  void _selectMenu(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  void _handleDownload(BuildContext context) {
    if (!kIsWeb) {
      showAppSnackBar(
        context,
        'Unduh data saat ini hanya tersedia di versi web (Chrome/Edge).',
        isError: true,
      );
      return;
    }

    final String csv;
    final String filename;

    if (_selectedIndex == 1) {
      final buffer = StringBuffer();
      buffer.writeln(
        'No,Tanggal,Kode Tamu,Nama Lengkap,Jenis Kelamin,Alamat Lengkap,'
        'Keperluan,Keterangan Tambahan,Foto,Status,Waktu Masuk,Waktu Selesai',
      );
      final f = DateFormat('dd/MM/yyyy HH:mm');
      for (var i = 0; i < _currentGuestRows.length; i++) {
        final row = _currentGuestRows[i];
        buffer.writeln(
          [
            i + 1,
            row.tanggal != null ? f.format(row.tanggal!) : '-',
            row.kodeTamu,
            row.namaLengkap,
            row.jenisKelamin,
            row.alamatLengkap,
            row.keperluan,
            row.keteranganTambahan,
            row.fotoUrl ?? '-',
            row.status,
            row.waktuMasuk != null ? f.format(row.waktuMasuk!) : '-',
            row.waktuSelesai != null ? f.format(row.waktuSelesai!) : '-',
          ].map(_csvEscape).join(','),
        );
      }
      csv = buffer.toString();
      filename = 'data_pelanggan.csv';
    } else {
      final buffer = StringBuffer();
      buffer.writeln('Label,Nilai');
      for (final stat in _currentStats) {
        buffer.writeln('${_csvEscape(stat.label)},${_csvEscape(stat.value)}');
      }
      csv = buffer.toString();
      filename = 'ringkasan_dashboard.csv';
    }

    downloadCsv(filename, csv);
    showAppSnackBar(context, 'Mengunduh $filename...', isError: false);
  }

  String _csvEscape(Object? value) {
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fitur cari, download, dan kalender cuma relevan di halaman Data
        // Pelanggan (satu-satunya halaman yang punya daftar untuk
        // dicari/difilter/diunduh). Di Beranda maupun Profil, ketiga
        // fitur ini disembunyikan sepenuhnya dari top bar.
        final tampilkanAlatPencarian = _selectedIndex == 1;
        // Lebar sidebar saat ini -- SELALU mengikuti status buka/tutup
        // (dianimasikan), di layar lebar maupun sempit. Tombol 3-garis di
        // navbar selalu tampil untuk menggeser sidebar ini masuk/keluar.
        final sidebarWidth = _sidebarOpen ? 220.0 : 0.0;

        return Scaffold(
          backgroundColor: _DashColors.bg,
          body: SafeArea(
            child: Row(
              children: [
                // Sidebar yang "bergeser" masuk/keluar dengan animasi lebar
                // (bukan Drawer bawaan yang menumpuk di atas/di belakang
                // konten). Konten di sebelah kanan otomatis ikut bergeser
                // karena sidebar ini beneran memakan ruang lewat Row biasa.
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    width: sidebarWidth,
                    child: OverflowBox(
                      minWidth: 220,
                      maxWidth: 220,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 220,
                        child: _Sidebar(
                          selectedIndex: _selectedIndex,
                          onSelect: _selectMenu,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        title: _menuTitles[_selectedIndex],
                        searchController: _searchController,
                        // Tombol menu (3 garis) SELALU tampil -- di layar
                        // lebar maupun sempit -- persis seperti admin panel
                        // pada umumnya, supaya sidebar bisa ditarik
                        // masuk/keluar kapan saja.
                        showMenuButton: true,
                        onMenuTap: _toggleSidebar,
                        // Cari & download cuma ditampilkan di halaman Data
                        // Pelanggan.
                        showTools: tampilkanAlatPencarian,
                        onSearchChanged: tampilkanAlatPencarian
                            ? (value) => setState(() => _searchQuery = value)
                            : null,
                        onDownload: tampilkanAlatPencarian
                            ? () => _handleDownload(context)
                            : null,
                      ),
                      // Breadcrumb halaman yang sedang dibuka, persis di
                      // bawah navbar -- selalu diawali "Beranda" (root),
                      // lalu nama halaman lain kalau sedang bukan di
                      // Beranda. "Beranda" bisa diklik buat balik kapan
                      // saja.
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _selectedIndex == 0
                                  ? null
                                  : () => _selectMenu(0),
                              child: Text(
                                'Beranda',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedIndex == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedIndex == 0
                                      ? AppColors.teal
                                      : _DashColors.breadcrumbMuted,
                                ),
                              ),
                            ),
                            if (_selectedIndex != 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '/',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _DashColors.breadcrumbMuted,
                                  ),
                                ),
                              ),
                              Text(
                                _menuTitles[_selectedIndex],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardContent(
          onStatsChanged: (stats) {
            if (identical(stats, _currentStats)) return;
            setState(() => _currentStats = stats);
          },
        );
      case 1:
        return _DataPelangganContent(
          searchQuery: _searchQuery,
          onRowsChanged: (rows) {
            // Hindari setState kalau isinya sama persis (mis. rebuild
            // biasa tanpa data baru).
            if (identical(rows, _currentGuestRows)) return;
            setState(() => _currentGuestRows = rows);
          },
        );
      case 2:
      default:
        return const AdminProfilePage();
    }
  }
}

/// ====================== SIDEBAR ======================
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Solid navy -- gaya "flat" (bukan gradient) supaya konsisten
      // dengan tampilan sidebar admin panel pada umumnya.
      decoration: const BoxDecoration(color: _DashColors.sidebarDark),
      child: Column(
        children: [
          // Header sidebar: logo kecil + nama app sejajar (bukan avatar
          // bundar besar di tengah), persis pola header sidebar admin
          // panel pada umumnya.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white24, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'lib/assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AdaTamu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Label kecil kayak "Website" di contoh -- penanda kelompok menu.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MENU',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          _SidebarMenuItem(
            label: 'Beranda',
            icon: Icons.dashboard_outlined,
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _SidebarMenuItem(
            label: 'Data Pelanggan',
            icon: Icons.people_outline,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _SidebarMenuItem(
            label: 'Profil',
            icon: Icons.account_circle_outlined,
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          const Expanded(child: SizedBox.shrink()),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 110,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DashColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Keluar', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilkan pop up konfirmasi sebelum benar-benar keluar (logout),
  /// supaya tombol "Keluar" tidak ke-klik tidak sengaja.
  Future<void> _confirmLogout(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          _DialogActionButtons(
            confirmLabel: 'Yakin',
            confirmColor: _DashColors.red,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (yakin == true) {
      await AuthService.instance.logout();
    }
  }
}

class _SidebarMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? _DashColors.menuActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// ====================== TOP BAR ======================
class _TopBar extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final bool showMenuButton;
  // Dipanggil saat tombol menu (3 garis) diketuk -- buka/tutup sidebar
  // yang bergeser di layar sempit.
  final VoidCallback? onMenuTap;
  // Kalau false (mis. di halaman Beranda/Profil), kotak cari dan tombol
  // download disembunyikan sepenuhnya -- cuma ditampilkan di halaman
  // Data Pelanggan.
  final bool showTools;
  final VoidCallback? onDownload;
  final ValueChanged<String>? onSearchChanged;

  const _TopBar({
    required this.title,
    required this.searchController,
    required this.showMenuButton,
    required this.showTools,
    this.onMenuTap,
    this.onDownload,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Gradient teal -> navy dari kiri ke kanan supaya top bar tidak
        // terasa flat/polos, tetap dalam palet warna aplikasi yang sama.
        gradient: LinearGradient(
          colors: [AppColors.teal, AppColors.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuTap,
            ),
          if (showTools) ...[
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Cari nama, waktu, kelamin, alamat, keperluan, '
                        'keterangan, status...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged?.call('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: 'Unduh data sebagai CSV',
              onPressed: onDownload,
            ),
          ] else
            // Halaman tanpa alat cari/download/kalender (Beranda & Profil):
            // tidak menampilkan tulisan apa pun, tapi tinggi top bar tetap
            // disamakan dengan halaman Data Pelanggan (pakai placeholder
            // TextField yang sama tapi disembunyikan) supaya konten di
            // bawahnya tidak ikut naik/turun.
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Logo AdaTamu di pojok kanan atas navbar. Tanpa background putih
          // -- cuma tinggi yang dibatasi (lebar menyesuaikan otomatis lewat
          // BoxFit.contain) supaya rasio gambar tidak gepeng dan tinggi
          // navbar tidak ikut membesar.
          SizedBox(
            height: 44,
            child: Image.asset(
              'lib/assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

/// ====================== KONTEN: DASHBOARD ======================
/// Kartu statistik ("Total Pelanggan", "Menunggu", "Selesai") dihitung
/// REAL-TIME dari collection `guests` di Firestore -- bukan angka statis
/// lagi. "Menunggu"/"Selesai" dihitung dari field `status` tiap dokumen,
/// pakai definisi yang sama persis dengan `GuestRecord.sudahSelesai` biar
/// jumlahnya selalu konsisten dengan badge status di tabel Data Pelanggan.
class _DashboardContent extends StatefulWidget {
  final ValueChanged<List<_StatItem>>? onStatsChanged;
  const _DashboardContent({this.onStatsChanged});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _guestsStream;
  bool _loading = true;
  String? _errorMessage;
  int _total = 0;
  int _menunggu = 0;
  int _selesai = 0;

  // Semua dokumen mentah dari Firestore (belum difilter bulan), disimpan
  // supaya bisa dihitung ulang tiap kali filter bulan berubah tanpa perlu
  // listen ulang ke stream.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allDocs = [];

  // Bulan yang dipilih di dropdown ('semua' = tidak difilter, atau
  // 'yyyy-MM' untuk bulan+tahun tertentu). Daftar opsi dibangun dari
  // tanggal yang benar-benar ada di data supaya tidak menampilkan bulan
  // yang datanya kosong.
  String _selectedMonth = 'semua';

  @override
  void initState() {
    super.initState();
    _guestsStream = FirebaseFirestore.instance.collection('guests').snapshots();
    _guestsStream.listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _allDocs = snapshot.docs;
          _loading = false;
          _errorMessage = null;
        });
        _recomputeStats();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Gagal memuat statistik: $e';
          _loading = false;
        });
      },
    );
  }

  /// Ambil tanggal satu dokumen tamu (coba 'tanggalKunjungan' dulu, lalu
  /// fallback ke 'createdAt'), pakai parser yang sama dengan GuestRecord.
  DateTime? _tanggalDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return GuestRecord._parseTanggal(
      data['tanggalKunjungan'] ?? data['createdAt'],
    );
  }

  /// Kunci bulan 'yyyy-MM' dari sebuah tanggal, dipakai sebagai value
  /// dropdown maupun untuk pencocokan filter.
  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Daftar bulan yang tersedia (ada datanya), diurutkan terbaru dulu.
  List<String> _availableMonths() {
    final keys = <String>{};
    for (final doc in _allDocs) {
      final tgl = _tanggalDoc(doc);
      if (tgl != null) keys.add(_monthKey(tgl));
    }
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  static const _namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Nama bulan ditulis manual (bukan lewat DateFormat locale 'id_ID')
  // supaya tidak perlu tambahan inisialisasi async
  // (initializeDateFormatting) di main() hanya demi label dropdown ini.
  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return '${_namaBulan[month - 1]} $year';
  }

  void _recomputeStats() {
    var menunggu = 0;
    var selesai = 0;
    var total = 0;
    for (final doc in _allDocs) {
      if (_selectedMonth != 'semua') {
        final tgl = _tanggalDoc(doc);
        if (tgl == null || _monthKey(tgl) != _selectedMonth) continue;
      }
      total++;
      final rawStatus = doc.data()['status']?.toString().trim() ?? '';
      if (rawStatus.toLowerCase() == 'selesai') {
        selesai++;
      } else {
        menunggu++;
      }
    }
    setState(() {
      _total = total;
      _menunggu = menunggu;
      _selesai = selesai;
    });
    _reportStats();
  }

  void _onMonthChanged(String? value) {
    if (value == null) return;
    if (value != _selectedMonth) {
      setState(() => _selectedMonth = value);
      _recomputeStats();
    }
    _showMonthDataPopup(value);
  }

  /// Tampilkan pop up berisi daftar tamu (format sama seperti tabel di
  /// halaman Data Pelanggan) untuk bulan yang baru dipilih di dropdown.
  /// 'semua' menampilkan seluruh data tanpa filter tanggal. Popup ini
  /// TIDAK berpindah ke halaman/menu "Data Pelanggan" -- admin tetap
  /// berada di Beranda, cuma diberi jendela intip data cepat.
  void _showMonthDataPopup(String monthKey) {
    final rows =
        _allDocs.map(GuestRecord.fromDoc).where((r) {
          if (monthKey == 'semua') return true;
          final tgl = r.tanggal;
          if (tgl == null) return false;
          return _monthKey(tgl) == monthKey;
        }).toList()..sort((a, b) {
          final ta = a.tanggal;
          final tb = b.tanggal;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

    showDialog(
      context: context,
      builder: (_) => _GuestDataPopup(
        title: monthKey == 'semua' ? 'Semua Bulan' : _monthLabel(monthKey),
        rows: rows,
      ),
    );
  }

  /// Tampilkan pop up daftar tamu untuk status tertentu ('total' /
  /// 'menunggu' / 'selesai'), dipicu dari kartu statistik. Sama seperti
  /// pop up bulan di atas -- ini SENGAJA berupa pop up, BUKAN berpindah
  /// ke halaman/menu "Data Pelanggan", supaya admin tetap di Beranda dan
  /// cuma mengintip datanya sekilas. Filter bulan yang sedang aktif di
  /// dropdown ikut diterapkan supaya datanya konsisten dengan angka yang
  /// tampil di kartu statistik.
  void _openStatusPopup(String statusKey) {
    final rows =
        _allDocs.map(GuestRecord.fromDoc).where((r) {
          if (_selectedMonth != 'semua') {
            final tgl = r.tanggal;
            if (tgl == null || _monthKey(tgl) != _selectedMonth) return false;
          }
          if (statusKey == 'menunggu') return !r.sudahSelesai;
          if (statusKey == 'selesai') return r.sudahSelesai;
          return true; // 'total'
        }).toList()..sort((a, b) {
          final ta = a.tanggal;
          final tb = b.tanggal;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

    final judulStatus = switch (statusKey) {
      'menunggu' => 'Menunggu',
      'selesai' => 'Selesai',
      _ => 'Total Pelanggan',
    };
    final judulBulan = _selectedMonth == 'semua'
        ? 'Semua Bulan'
        : _monthLabel(_selectedMonth);

    showDialog(
      context: context,
      builder: (_) =>
          _GuestDataPopup(title: '$judulStatus — $judulBulan', rows: rows),
    );
  }

  List<_StatItem> _buildStats() => [
    _StatItem(label: 'Total Pelanggan', value: '$_total', key: 'total'),
    _StatItem(label: 'Menunggu', value: '$_menunggu', key: 'menunggu'),
    _StatItem(label: 'Selesai', value: '$_selesai', key: 'selesai'),
  ];

  void _reportStats() {
    final stats = _buildStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onStatsChanged?.call(stats);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    final stats = _buildStats();
    final months = _availableMonths();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (months.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'semua',
                        child: Text('Semua Bulan'),
                      ),
                      ...months.map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(_monthLabel(m)),
                        ),
                      ),
                    ],
                    onChanged: _onMonthChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 500;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: stats
                    .map(
                      (s) => SizedBox(
                        width: narrow
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 32) / 3,
                        child: _StatCard(
                          item: s,
                          onTap: () => _openStatusPopup(s.key),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          // Kalau filter bulan sedang "Semua Bulan": tampilkan DUA chart
          // sekaligus -- ringkasan status (donut) DAN tren jumlah
          // pelanggan per bulan (diagram batang, lengkap dengan naik/
          // turun dalam persen dari bulan sebelumnya). Kalau admin sedang
          // memfilter satu bulan tertentu, cukup tampilkan ringkasan
          // status untuk bulan itu saja.
          if (_selectedMonth == 'semua') ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final monthly = _monthlyCounts();
                final donut = _StatusChartCard(
                  total: _total,
                  menunggu: _menunggu,
                  selesai: _selesai,
                );
                final trend = _MonthlyTrendChart(
                  data: monthly,
                  monthLabel: _monthLabelShort,
                );
                final sideBySide = constraints.maxWidth >= 760;
                if (!sideBySide) {
                  return Column(
                    children: [donut, const SizedBox(height: 16), trend],
                  );
                }
                // PENTING: sengaja TIDAK pakai IntrinsicHeight di sini.
                // _StatusChartCard membungkus isinya dengan LayoutBuilder,
                // dan LayoutBuilder tidak boleh diletakkan di dalam
                // IntrinsicHeight (Flutter akan melempar error "does not
                // support returning intrinsic dimensions" saat itu
                // dipaksa menghitung tinggi intrinsik) -- errornya bikin
                // seluruh halaman gagal render sehingga tidak ada apa pun
                // yang bisa disentuh. Row biasa (tanpa stretch tinggi
                // paksa) sudah cukup; kedua kartu boleh beda tinggi.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: donut),
                    const SizedBox(width: 16),
                    Expanded(child: trend),
                  ],
                );
              },
            ),
          ] else
            _StatusChartCard(
              total: _total,
              menunggu: _menunggu,
              selesai: _selesai,
            ),
        ],
      ),
    );
  }

  /// Jumlah tamu per bulan ('yyyy-MM' -> jumlah), diurutkan dari bulan
  /// terlama ke terbaru, dipakai oleh diagram batang tren bulanan.
  /// Dibatasi ke 6 bulan terakhir saja supaya batangnya tidak terlalu
  /// sempit/padat saat datanya sudah banyak bulan.
  List<MapEntry<String, int>> _monthlyCounts() {
    final counts = <String, int>{};
    for (final doc in _allDocs) {
      final tgl = _tanggalDoc(doc);
      if (tgl == null) continue;
      final key = _monthKey(tgl);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.length > 6) {
      return entries.sublist(entries.length - 6);
    }
    return entries;
  }

  // Label bulan singkat (3 huruf) dipakai sebagai label di bawah tiap
  // batang pada diagram tren bulanan supaya tidak makan tempat.
  String _monthLabelShort(String key) {
    final parts = key.split('-');
    final month = int.parse(parts[1]);
    return _namaBulan[month - 1].substring(0, 3);
  }
}

/// Pop up daftar tamu, dipicu dari dropdown bulan di Beranda. Tabelnya
/// sengaja dibuat semirip mungkin dengan tabel di halaman Data Pelanggan
/// (kolom & format sama) tapi read-only — cuma buat intip data cepat
/// tanpa pindah halaman, jadi tidak ada aksi ubah status/lihat foto besar
/// di sini.
class _GuestDataPopup extends StatelessWidget {
  final String title;
  final List<GuestRecord> rows;
  const _GuestDataPopup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final tanggalFmt = DateFormat('dd/MM/yyyy');
    final jamFmt = DateFormat('HH:mm');
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.92,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data Tamu — $title',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${rows.length} tamu',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('Tidak ada data tamu pada periode ini.'),
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF0F0F0),
                            ),
                            columns: const [
                              DataColumn(label: Text('No')),
                              DataColumn(label: Text('Tanggal')),
                              DataColumn(label: Text('Waktu Masuk')),
                              DataColumn(label: Text('Waktu Selesai')),
                              DataColumn(label: Text('Kode Tamu')),
                              DataColumn(label: Text('Nama Lengkap')),
                              DataColumn(label: Text('Jenis Kelamin')),
                              DataColumn(label: Text('Alamat Lengkap')),
                              DataColumn(label: Text('Keperluan')),
                              DataColumn(label: Text('Keterangan Tambahan')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: List<DataRow>.generate(rows.length, (i) {
                              final r = rows[i];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(
                                    Text(
                                      r.tanggal != null
                                          ? tanggalFmt.format(r.tanggal!)
                                          : '-',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      r.waktuMasuk != null
                                          ? jamFmt.format(r.waktuMasuk!)
                                          : '-',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      r.waktuSelesai != null
                                          ? jamFmt.format(r.waktuSelesai!)
                                          : '-',
                                    ),
                                  ),
                                  DataCell(Text(r.kodeTamu)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        r.namaLengkap,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(r.jenisKelamin)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                      ),
                                      child: Text(
                                        r.alamatLengkap,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 140,
                                      ),
                                      child: Text(
                                        r.keperluan,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        r.keteranganTambahan,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(_StatusBadge(status: r.status)),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  final VoidCallback? onTap;
  const _StatCard({required this.item, this.onTap});

  /// Gradient & ikon per jenis stat, tetap dalam palet warna aplikasi
  /// (teal/navy/yellow) supaya konsisten dengan tampilan lain.
  List<Color> get _gradientColors {
    switch (item.key) {
      case 'menunggu':
        return const [AppColors.yellow, Color(0xFFC9A227)];
      case 'selesai':
        return const [AppColors.navy, AppColors.teal];
      case 'total':
      default:
        return const [AppColors.teal, AppColors.navy];
    }
  }

  IconData get _icon {
    switch (item.key) {
      case 'menunggu':
        return Icons.hourglass_top_rounded;
      case 'selesai':
        return Icons.task_alt_rounded;
      case 'total':
      default:
        return Icons.groups_rounded;
    }
  }

  // Kartu "Menunggu" pakai gradient kuning yang terang, jadi teksnya
  // dibuat gelap supaya tetap kebaca; dua kartu lain pakai teks putih.
  Color get _textColor =>
      item.key == 'menunggu' ? AppColors.darkText : Colors.white;

  @override
  Widget build(BuildContext context) {
    final textColor = _textColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(_icon, color: textColor.withOpacity(0.85), size: 26),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: textColor.withOpacity(0.6),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu grafik ringkasan status tamu (donut chart Menunggu vs Selesai),
/// mengisi ruang kosong di bawah kartu statistik pada halaman Beranda.
/// Digambar manual pakai CustomPainter (tanpa dependency chart pihak
/// ketiga) supaya tidak perlu tambahan package.
class _StatusChartCard extends StatelessWidget {
  final int total;
  final int menunggu;
  final int selesai;
  const _StatusChartCard({
    required this.total,
    required this.menunggu,
    required this.selesai,
  });

  @override
  Widget build(BuildContext context) {
    final persenSelesai = total == 0 ? 0.0 : selesai / total;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 480;
          final donut = SizedBox(
            width: 150,
            height: 150,
            child: total == 0
                ? const Center(
                    child: Text(
                      'Belum ada data',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  )
                : CustomPaint(
                    painter: _DonutChartPainter(persenSelesai: persenSelesai),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(persenSelesai * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );

          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ringkasan Status Tamu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Komposisi status seluruh tamu',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const SizedBox(height: 16),
              _LegendRow(
                color: AppColors.teal,
                label: 'Selesai',
                value: selesai,
                total: total,
              ),
              const SizedBox(height: 10),
              _LegendRow(
                color: AppColors.yellow,
                label: 'Menunggu',
                value: menunggu,
                total: total,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Colors.black12),
              ),
              _LegendRow(
                color: AppColors.navy,
                label: 'Total',
                value: total,
                bold: true,
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                legend,
                const SizedBox(height: 20),
                Center(child: donut),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: legend),
              const SizedBox(width: 24),
              donut,
            ],
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  // Kalau diisi (dan > 0), tampilkan persentase dari total di sebelah
  // kanan baris, mis. "Selesai 12 (60%)".
  final int? total;
  final bool bold;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.total,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final persen = (total != null && total! > 0)
        ? ' (${((value / total!) * 100).round()}%)'
        : '';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.darkText,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          '$value$persen',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.darkText,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double persenSelesai;
  const _DonutChartPainter({required this.persenSelesai});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final bgPaint = Paint()
      ..color = AppColors.yellow.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2832, false, bgPaint);

    final fgPaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweep = 6.2832 * persenSelesai;
    if (sweep > 0) {
      canvas.drawArc(rect, -1.5708, sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.persenSelesai != persenSelesai;
}

/// Kartu diagram batang tren jumlah pelanggan per bulan, lengkap dengan
/// badge naik/turun (%) dibanding bulan sebelumnya. Melengkapi donut
/// chart ringkasan status supaya Beranda punya DUA chart: satu untuk
/// komposisi status (selesai vs menunggu), satu lagi untuk tren jumlah
/// dari waktu ke waktu.
class _MonthlyTrendChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final String Function(String monthKey) monthLabel;
  const _MonthlyTrendChart({required this.data, required this.monthLabel});

  /// Persentase perubahan dari bulan sebelum-terakhir ke bulan terakhir.
  /// Null kalau datanya kurang dari 2 bulan (tidak bisa dibandingkan).
  double? get _persenPerubahan {
    if (data.length < 2) return null;
    final prev = data[data.length - 2].value;
    final curr = data.last.value;
    if (prev == 0) return curr == 0 ? 0 : 100;
    return ((curr - prev) / prev) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final persen = _persenPerubahan;
    final naik = (persen ?? 0) >= 0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tren Pelanggan per Bulan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              if (persen != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (naik ? Colors.green : Colors.red).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        naik
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: naik ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${persen.abs().round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: naik ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Dibanding bulan sebelumnya',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  )
                : CustomPaint(
                    painter: _BarChartPainter(data: data),
                    child: Container(),
                  ),
          ),
          if (data.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: data
                  .map(
                    (e) => Expanded(
                      child: Text(
                        monthLabel(e.key),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Diagram batang sederhana (digambar manual pakai CustomPainter, tanpa
/// dependency chart pihak ketiga) untuk tren jumlah pelanggan per bulan.
class _BarChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> data;
  const _BarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxValue = data
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1 : maxValue;

    const labelSpace = 20.0; // ruang buat angka di atas batang
    final chartHeight = size.height - labelSpace;
    final slotWidth = size.width / data.length;
    final barWidth = slotWidth * 0.5;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var i = 0; i < data.length; i++) {
      final value = data[i].value;
      final barHeight = (value / safeMax) * (chartHeight - 8);
      final left = i * slotWidth + (slotWidth - barWidth) / 2;
      final top = chartHeight - barHeight;

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      final paint = Paint()
        ..color = i == data.length - 1
            ? AppColors.teal
            : AppColors.teal.withOpacity(0.55);
      canvas.drawRRect(rect, paint);

      textPainter.text = TextSpan(
        text: '$value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(left + (barWidth - textPainter.width) / 2, top - 16),
      );
    }

    // Garis dasar (sumbu horizontal) supaya batang terlihat "berdiri".
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data;
}

/// ====================== KONTEN: DATA PELANGGAN ======================
/// Menampilkan data tamu ASLI dari collection `guests` di Firestore,
/// real-time (StreamBuilder-style lewat StreamSubscription manual supaya
/// mudah kirim balik daftar yang sedang tampil ke halaman induk untuk
/// keperluan download CSV).
///
/// Semua data tamu ditampilkan langsung sebagai satu daftar datar
/// (tidak dikelompokkan ke dalam folder tahun/bulan).
class _DataPelangganContent extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<List<GuestRecord>>? onRowsChanged;

  const _DataPelangganContent({required this.searchQuery, this.onRowsChanged});

  /// Filter daftar baris berdasarkan teks pencarian. Dicocokkan ke
  /// gabungan SEMUA field tamu sekaligus (lihat `GuestRecord.
  /// searchableText`) -- nomor kode tamu, tanggal, waktu masuk/selesai,
  /// nama, jenis kelamin, alamat, keperluan, keterangan, sampai status.
  /// Pencocokan case-insensitive dan sederhana (substring), tidak ada
  /// lagi filter/kategori pencarian terpisah.
  static List<GuestRecord> filterBySearch(
    List<GuestRecord> data,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return data;
    return data.where((row) => row.searchableText.contains(q)).toList();
  }

  @override
  State<_DataPelangganContent> createState() => _DataPelangganContentState();
}

class _DataPelangganContentState extends State<_DataPelangganContent> {
  List<GuestRecord> _allRows = const [];
  bool _loading = true;
  String? _errorMessage;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _guestsStream;

  // Bulan yang dipilih untuk memfilter tabel Data Pelanggan ('semua' =
  // tidak difilter, atau 'yyyy-MM'). Sama polanya dengan filter bulan di
  // Beranda, tapi di sini benar-benar menyaring baris tabel (bukan cuma
  // membuka pop up).
  String _selectedMonth = 'semua';

  /// Kunci bulan 'yyyy-MM' dari sebuah tanggal.
  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Daftar bulan yang ada datanya (dari seluruh baris tamu), terbaru
  /// dulu -- supaya dropdown tidak menampilkan bulan yang kosong.
  List<String> _availableMonths() {
    final keys = <String>{};
    for (final row in _allRows) {
      final tgl = row.tanggal;
      if (tgl != null) keys.add(_monthKey(tgl));
    }
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Label bulan untuk ditampilkan di dropdown, mis. "Juli 2026". Pakai
  /// daftar nama bulan yang sama dengan yang dipakai di Beranda supaya
  /// konsisten.
  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return '${_DashboardContentState._namaBulan[month - 1]} $year';
  }

  void _onMonthChanged(String? value) {
    if (value == null || value == _selectedMonth) return;
    setState(() => _selectedMonth = value);
    _reportFiltered();
  }

  @override
  void initState() {
    super.initState();
    // Stream dibuat SEKALI di initState (bukan di build) supaya tidak
    // subscribe ulang setiap kali widget rebuild.
    _guestsStream = FirebaseFirestore.instance.collection('guests').snapshots();
    _guestsStream.listen(
      (snapshot) {
        if (!mounted) return;
        final rows = snapshot.docs.map(GuestRecord.fromDoc).toList()
          ..sort((a, b) {
            final ta = a.tanggal;
            final tb = b.tanggal;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1; // tanpa tanggal ditaruh di bawah
            if (tb == null) return -1;
            return tb.compareTo(ta); // terbaru dulu
          });
        setState(() {
          _allRows = rows;
          _loading = false;
          _errorMessage = null;
        });
        _reportFiltered();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Gagal memuat data tamu: $e';
          _loading = false;
        });
      },
    );
  }

  bool get _searchActive => widget.searchQuery.trim().isNotEmpty;
  bool get _monthFilterActive => _selectedMonth != 'semua';

  /// Baris yang benar-benar tampil di tabel -- disaring bertahap: dulu
  /// berdasarkan bulan yang dipilih (kalau ada), lalu berdasarkan teks
  /// pencarian (semua field sekaligus).
  List<GuestRecord> get _visibleRows {
    var rows = _allRows;
    if (_monthFilterActive) {
      rows = rows.where((r) {
        final tgl = r.tanggal;
        return tgl != null && _monthKey(tgl) == _selectedMonth;
      }).toList();
    }
    if (_searchActive) {
      rows = _DataPelangganContent.filterBySearch(rows, widget.searchQuery);
    }
    return rows;
  }

  @override
  void didUpdateWidget(covariant _DataPelangganContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _reportFiltered();
    }
  }

  /// Kirim daftar baris yang sedang tampil ke parent lewat callback.
  /// Dijadwalkan sesudah frame selesai supaya tidak memicu setState di
  /// parent saat masih di tengah proses build.
  void _reportFiltered() {
    final filtered = _visibleRows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onRowsChanged?.call(filtered);
    });
  }

  void _bukaFotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Gagal memuat foto'),
            ),
          ),
        ),
      ),
    );
  }

  /// Tandai tamu sebagai "selesai". Ini SEKALI JALAN saja (one-shot):
  /// begitu status berubah jadi "selesai", badge tidak bisa diklik lagi,
  /// jadi tidak ada jalan untuk mengembalikannya ke "menunggu" dari UI.
  /// Waktu penyelesaian dicatat di field `selesaiAt` (server timestamp)
  /// supaya tercatat kapan tepatnya admin menyelesaikannya.
  Future<void> _tandaiSelesai(BuildContext context, GuestRecord guest) async {
    // Jaga-jaga: kalau entah bagaimana sudah selesai, jangan tulis ulang.
    if (guest.sudahSelesai) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tandai Selesai'),
        content: Text(
          'Tandai keperluan "${guest.namaLengkap}" sebagai selesai?\n\n'
          'Status ini tidak bisa diubah kembali ke "menunggu" setelah disimpan.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          _DialogActionButtons(
            confirmLabel: 'Selesai',
            confirmColor: Colors.green,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('guests')
          .doc(guest.id)
          .update({
            'status': 'selesai',
            'selesaiAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Gagal mengubah status: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    final months = _availableMonths();
    final String emptyMessage;
    if (_searchActive) {
      emptyMessage = 'Tidak ada data yang cocok dengan pencarian.';
    } else if (_monthFilterActive) {
      emptyMessage =
          'Belum ada data tamu di bulan ${_monthLabel(_selectedMonth)}.';
    } else {
      emptyMessage = 'Belum ada data tamu.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (months.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'semua',
                        child: Text('Semua Bulan'),
                      ),
                      ...months.map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(_monthLabel(m)),
                        ),
                      ),
                    ],
                    onChanged: _onMonthChanged,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          // Selalu tampilkan sebagai daftar datar (tidak dikelompokkan ke
          // folder tahun/bulan).
          child: _buildTableView(
            searchChip: _searchActive,
            emptyMessage: emptyMessage,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBox(String message) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Text(message),
    );
  }

  /// Tabel/daftar-kartu data tamu, dengan chip kecil yang menunjukkan
  /// kata kunci pencarian yang sedang aktif (kalau ada).
  Widget _buildTableView({
    required bool searchChip,
    required String emptyMessage,
  }) {
    final dataTerfilter = _visibleRows;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint khusus konten ini: di layar sempit (mis. HP), tabel
        // horizontal-scroll susah dipakai, jadi ditampilkan sebagai daftar
        // kartu (satu tamu = satu kartu) supaya tetap enak dibaca.
        final narrow = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (searchChip)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.search, size: 14),
                        backgroundColor: Colors.white,
                        label: Text('Cari: "${widget.searchQuery.trim()}"'),
                      ),
                    ],
                  ),
                ),
              if (dataTerfilter.isEmpty)
                _buildEmptyBox(
                  _allRows.isEmpty ? 'Belum ada data tamu.' : emptyMessage,
                )
              else if (narrow)
                Column(
                  children: List.generate(dataTerfilter.length, (i) {
                    final r = dataTerfilter[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GuestCard(
                        nomor: i + 1,
                        guest: r,
                        onTandaiSelesai: () => _tandaiSelesai(context, r),
                        onFotoTap: r.fotoUrl == null
                            ? null
                            : () => _bukaFotoDialog(context, r.fotoUrl!),
                      ),
                    );
                  }),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF0F0F0),
                      ),
                      columns: const [
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Waktu Masuk')),
                        DataColumn(label: Text('Waktu Selesai')),
                        DataColumn(label: Text('Kode Tamu')),
                        DataColumn(label: Text('Nama Lengkap')),
                        DataColumn(label: Text('Jenis Kelamin')),
                        DataColumn(label: Text('Alamat Lengkap')),
                        DataColumn(label: Text('Keperluan')),
                        DataColumn(label: Text('Keterangan Tambahan')),
                        DataColumn(label: Text('Foto')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: List<DataRow>.generate(dataTerfilter.length, (i) {
                        final r = dataTerfilter[i];
                        final tanggalFmt = DateFormat('dd/MM/yyyy');
                        // Cuma jam:menit -- tanggalnya sudah ada di kolom
                        // "Tanggal" tersendiri, jadi tidak perlu diulang.
                        final jamFmt = DateFormat('HH:mm');
                        return DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(
                              Text(
                                r.tanggal != null
                                    ? tanggalFmt.format(r.tanggal!)
                                    : '-',
                              ),
                            ),
                            DataCell(
                              Text(
                                r.waktuMasuk != null
                                    ? jamFmt.format(r.waktuMasuk!)
                                    : '-',
                              ),
                            ),
                            DataCell(
                              Text(
                                r.waktuSelesai != null
                                    ? jamFmt.format(r.waktuSelesai!)
                                    : '-',
                              ),
                            ),
                            DataCell(Text(r.kodeTamu)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 160,
                                ),
                                child: Text(
                                  r.namaLengkap,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(r.jenisKelamin)),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Text(
                                  r.alamatLengkap,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Text(
                                  r.keperluan,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 160,
                                ),
                                child: Text(
                                  r.keteranganTambahan,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              r.fotoUrl == null
                                  ? const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 20,
                                      color: Colors.grey,
                                    )
                                  : InkWell(
                                      onTap: () =>
                                          _bukaFotoDialog(context, r.fotoUrl!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          r.fotoUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                                size: 20,
                                                color: Colors.grey,
                                              ),
                                        ),
                                      ),
                                    ),
                            ),
                            DataCell(
                              _StatusBadge(
                                status: r.status,
                                onTap: r.sudahSelesai
                                    ? null
                                    : () => _tandaiSelesai(context, r),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Kartu satu baris data tamu — dipakai sebagai pengganti DataTable di
/// layar sempit (lihat breakpoint `narrow` di atas).
/// layar sempit (lihat breakpoint `narrow` di atas).
class _GuestCard extends StatelessWidget {
  final int nomor;
  final GuestRecord guest;
  final VoidCallback onTandaiSelesai;
  final VoidCallback? onFotoTap;

  const _GuestCard({
    required this.nomor,
    required this.guest,
    required this.onTandaiSelesai,
    this.onFotoTap,
  });

  @override
  Widget build(BuildContext context) {
    final tanggalFmt = DateFormat('dd/MM/yyyy');
    // Cuma jam:menit -- konsisten dengan tampilan tabel di layar lebar.
    final jamFmt = DateFormat('HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onFotoTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: guest.fotoUrl == null
                      ? Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                        )
                      : Image.network(
                          guest.fotoUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFFF0F0F0),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$nomor  ${guest.namaLengkap}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guest.kodeTamu,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                status: guest.status,
                onTap: guest.sudahSelesai ? null : onTandaiSelesai,
              ),
            ],
          ),
          const Divider(height: 20),
          _CardField(
            label: 'Tanggal',
            value: guest.tanggal != null
                ? tanggalFmt.format(guest.tanggal!)
                : '-',
          ),
          _CardField(
            label: 'Waktu Masuk',
            value: guest.waktuMasuk != null
                ? jamFmt.format(guest.waktuMasuk!)
                : '-',
          ),
          _CardField(
            label: 'Waktu Selesai',
            value: guest.waktuSelesai != null
                ? jamFmt.format(guest.waktuSelesai!)
                : '-',
          ),
          _CardField(label: 'Jenis Kelamin', value: guest.jenisKelamin),
          _CardField(label: 'Alamat Lengkap', value: guest.alamatLengkap),
          _CardField(label: 'Keperluan', value: guest.keperluan),
          _CardField(
            label: 'Keterangan Tambahan',
            value: guest.keteranganTambahan,
          ),
        ],
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  final String label;
  final String value;
  const _CardField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

/// Badge status. Kalau [onTap] diberikan (artinya status masih
/// "menunggu"), badge bisa diklik SEKALI untuk menandai selesai — begitu
/// status jadi "selesai", parent akan mengoper `onTap: null` sehingga
/// badge otomatis tidak bisa diklik lagi (one-shot, tidak ada jalan balik
/// dari UI).
class _StatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;
  const _StatusBadge({required this.status, this.onTap});

  bool get _isSelesai => status.toLowerCase() == 'selesai';

  @override
  Widget build(BuildContext context) {
    final color = _isSelesai ? Colors.green : Colors.orange;
    final label = _isSelesai ? 'selesai' : 'menunggu';
    final bisaDiklik = onTap != null;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: bisaDiklik
            ? Border.all(color: color.withOpacity(0.4), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bisaDiklik) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle_outline, size: 12, color: color),
          ],
        ],
      ),
    );

    if (!bisaDiklik) return badge;

    return Tooltip(
      message: 'Ketuk untuk tandai selesai (tidak bisa dibatalkan)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: badge,
      ),
    );
  }
}
