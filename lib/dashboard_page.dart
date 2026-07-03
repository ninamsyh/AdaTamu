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
  /// perlu lowercase berulang tiap kali dibandingkan).
  String get searchableText => [
    namaLengkap,
    kodeTamu,
    alamatLengkap,
    keperluan,
    keteranganTambahan,
    jenisKelamin,
    status,
  ].join(' ').toLowerCase();

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
  static const bg = Color(0xFFBDBDBD); // background konten abu-abu
  static const red = Color(0xFFE63946); // tombol logout
}

/// Satu kartu statistik di halaman Dashboard (mis. "Total Pelanggan: 128").
class _StatItem {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
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
  // memfilter tabel Data Pelanggan secara real-time.
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

  // ===== State filter tanggal (dipakai khusus halaman Data Pelanggan) =====
  DateTime? _tanggalDipilih;
  DateTimeRange? _rentangTanggal;

  static const _menuTitles = ['Beranda', 'Data Pelanggan', 'Profil'];

  void _selectMenu(int index) {
    setState(() => _selectedIndex = index);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _bukaDatePicker(BuildContext context) async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggalDipilih ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (hasil != null) {
      setState(() {
        _tanggalDipilih = hasil;
        _rentangTanggal = null;
      });
    }
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
        final isWide = constraints.maxWidth >= 900;

        // Halaman Profil Admin tidak relevan dengan download CSV maupun
        // filter tanggal, jadi kedua tombol ini dinonaktifkan (null) saat
        // admin sedang berada di halaman tersebut.
        final isProfilAdmin = _selectedIndex == 2;

        return Scaffold(
          backgroundColor: _DashColors.bg,
          drawer: isWide
              ? null
              : Drawer(
                  width: 220,
                  backgroundColor: _DashColors.sidebarDark,
                  child: _Sidebar(
                    selectedIndex: _selectedIndex,
                    onSelect: _selectMenu,
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 220,
                    child: _Sidebar(
                      selectedIndex: _selectedIndex,
                      onSelect: _selectMenu,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        title: _menuTitles[_selectedIndex],
                        searchController: _searchController,
                        showMenuButton: !isWide,
                        // Pencarian cuma relevan di halaman Data
                        // Pelanggan (halaman lain tidak punya daftar
                        // untuk difilter).
                        onSearchChanged: _selectedIndex == 1
                            ? (value) => setState(() => _searchQuery = value)
                            : null,
                        onDownload: isProfilAdmin
                            ? null
                            : () => _handleDownload(context),
                        onCalendarTap: isProfilAdmin
                            ? null
                            : () async {
                                // Kalau diklik dari halaman Dashboard, pindah
                                // dulu ke halaman Data Pelanggan supaya
                                // filternya kelihatan.
                                if (_selectedIndex != 1) {
                                  setState(() => _selectedIndex = 1);
                                }
                                await _bukaDatePicker(context);
                              },
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
          tanggalDipilih: _tanggalDipilih,
          rentangTanggal: _rentangTanggal,
          searchQuery: _searchQuery,
          onResetFilter: () => setState(() {
            _tanggalDipilih = null;
            _rentangTanggal = null;
          }),
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _DashColors.sidebarTop,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFD9D9D9),
            child: Icon(Icons.person, size: 32, color: Colors.white70),
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
          label: 'Profil Admin',
          icon: Icons.account_circle_outlined,
          selected: selectedIndex == 2,
          onTap: () => onSelect(2),
        ),
        Expanded(child: Container(color: _DashColors.sidebarDark)),
        Container(
          width: double.infinity,
          color: _DashColors.sidebarDark,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 110,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await AuthService.instance.logout();
                },
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
    );
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
    return Material(
      color: selected ? _DashColors.menuActive : _DashColors.sidebarDark,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
  final VoidCallback? onDownload; // null = nonaktif (mis. di Profil Admin)
  final VoidCallback?
  onCalendarTap; // null = nonaktif (mis. di halaman Dashboard/Profil Admin)
  // null = kotak pencarian nonaktif/disabled (mis. di halaman Dashboard
  // atau Profil Admin, yang tidak punya daftar untuk difilter).
  final ValueChanged<String>? onSearchChanged;

  const _TopBar({
    required this.title,
    required this.searchController,
    required this.showMenuButton,
    required this.onDownload,
    this.onCalendarTap,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final searchAktif = onSearchChanged != null;
    return Container(
      color: AppColors.teal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: searchController,
                enabled: searchAktif,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: searchAktif
                      ? 'Cari nama, alamat, keperluan, kode tamu...'
                      : 'Cari... (buka Data Pelanggan dulu)',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: searchAktif && searchController.text.isNotEmpty
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
            icon: Icon(
              Icons.download_outlined,
              color: onDownload == null ? Colors.white38 : Colors.white,
            ),
            tooltip: 'Unduh data sebagai CSV',
            onPressed: onDownload,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              Icons.calendar_today_outlined,
              color: onCalendarTap == null ? Colors.white38 : Colors.white,
              size: 20,
            ),
            tooltip: 'Filter berdasarkan tanggal',
            onPressed:
                onCalendarTap, // disabled (null) otomatis kalau bukan di halaman Data Pelanggan
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

  @override
  void initState() {
    super.initState();
    _guestsStream = FirebaseFirestore.instance.collection('guests').snapshots();
    _guestsStream.listen(
      (snapshot) {
        if (!mounted) return;
        var menunggu = 0;
        var selesai = 0;
        for (final doc in snapshot.docs) {
          final rawStatus = doc.data()['status']?.toString().trim() ?? '';
          if (rawStatus.toLowerCase() == 'selesai') {
            selesai++;
          } else {
            menunggu++;
          }
        }
        setState(() {
          _total = snapshot.docs.length;
          _menunggu = menunggu;
          _selesai = selesai;
          _loading = false;
          _errorMessage = null;
        });
        _reportStats();
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

  void _reportStats() {
    final stats = [
      _StatItem(label: 'Total Pelanggan', value: '$_total'),
      _StatItem(label: 'Menunggu', value: '$_menunggu'),
      _StatItem(label: 'Selesai', value: '$_selesai'),
    ];
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

    final stats = [
      _StatItem(label: 'Total Pelanggan', value: '$_total'),
      _StatItem(label: 'Menunggu', value: '$_menunggu'),
      _StatItem(label: 'Selesai', value: '$_selesai'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
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
                    child: _StatCard(item: s),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
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
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// ====================== KONTEN: DATA PELANGGAN ======================
/// Menampilkan data tamu ASLI dari collection `guests` di Firestore,
/// real-time (StreamBuilder-style lewat StreamSubscription manual supaya
/// mudah kirim balik daftar yang sedang tampil ke halaman induk untuk
/// keperluan download CSV).
class _DataPelangganContent extends StatefulWidget {
  final DateTime? tanggalDipilih;
  final DateTimeRange? rentangTanggal;
  final String searchQuery;
  final VoidCallback onResetFilter;
  final ValueChanged<List<GuestRecord>>? onRowsChanged;

  const _DataPelangganContent({
    required this.tanggalDipilih,
    required this.rentangTanggal,
    required this.searchQuery,
    required this.onResetFilter,
    this.onRowsChanged,
  });

  /// Filter daftar baris berdasarkan tanggal tunggal atau rentang tanggal.
  /// Baris tanpa tanggal (null) otomatis disembunyikan kalau ada filter
  /// aktif, karena tidak bisa dipastikan cocok atau tidak.
  static List<GuestRecord> filterByDate(
    List<GuestRecord> data,
    DateTime? tanggalDipilih,
    DateTimeRange? rentangTanggal,
  ) {
    if (tanggalDipilih == null && rentangTanggal == null) return data;

    return data.where((row) {
      final tgl = row.tanggal;
      if (tgl == null) return false;

      if (tanggalDipilih != null) {
        return tgl.year == tanggalDipilih.year &&
            tgl.month == tanggalDipilih.month &&
            tgl.day == tanggalDipilih.day;
      }

      if (rentangTanggal != null) {
        final mulai = DateTime(
          rentangTanggal.start.year,
          rentangTanggal.start.month,
          rentangTanggal.start.day,
        );
        final akhir = DateTime(
          rentangTanggal.end.year,
          rentangTanggal.end.month,
          rentangTanggal.end.day,
        );
        return !tgl.isBefore(mulai) && !tgl.isAfter(akhir);
      }

      return true;
    }).toList();
  }

  /// Filter daftar baris berdasarkan teks pencarian, dicocokkan ke nama,
  /// kode tamu, alamat, keperluan, keterangan tambahan, jenis kelamin,
  /// dan status (lihat `GuestRecord.searchableText`). Pencocokan
  /// case-insensitive dan sederhana (substring), cukup untuk kebutuhan
  /// pencarian cepat di tabel ini.
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

  List<GuestRecord> _applyAllFilters(List<GuestRecord> data) {
    final byDate = _DataPelangganContent.filterByDate(
      data,
      widget.tanggalDipilih,
      widget.rentangTanggal,
    );
    return _DataPelangganContent.filterBySearch(byDate, widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _DataPelangganContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tanggalDipilih != widget.tanggalDipilih ||
        oldWidget.rentangTanggal != widget.rentangTanggal ||
        oldWidget.searchQuery != widget.searchQuery) {
      _reportFiltered();
    }
  }

  /// Kirim daftar baris yang sedang tampil (setelah filter tanggal +
  /// pencarian) ke parent lewat callback. Dijadwalkan sesudah frame
  /// selesai supaya tidak memicu setState di parent saat masih di tengah
  /// proses build.
  void _reportFiltered() {
    final filtered = _applyAllFilters(_allRows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onRowsChanged?.call(filtered);
    });
  }

  String get _labelFilter {
    final f = DateFormat('dd/MM/yyyy');
    if (widget.rentangTanggal != null) {
      return '${f.format(widget.rentangTanggal!.start)} - '
          '${f.format(widget.rentangTanggal!.end)}';
    }
    if (widget.tanggalDipilih != null) {
      return f.format(widget.tanggalDipilih!);
    }
    return '';
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
      builder: (_) => AlertDialog(
        title: const Text('Tandai Selesai'),
        content: Text(
          'Tandai keperluan "${guest.namaLengkap}" sebagai selesai?\n\n'
          'Status ini tidak bisa diubah kembali ke "menunggu" setelah disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Selesai'),
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

    final dataTerfilter = _applyAllFilters(_allRows);
    final adaFilterTanggal =
        widget.tanggalDipilih != null || widget.rentangTanggal != null;
    final adaPencarian = widget.searchQuery.trim().isNotEmpty;

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
              if (adaFilterTanggal || adaPencarian)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (adaFilterTanggal)
                        Chip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          backgroundColor: Colors.white,
                          label: Text('Tanggal: $_labelFilter'),
                        ),
                      if (adaPencarian)
                        Chip(
                          avatar: const Icon(Icons.search, size: 14),
                          backgroundColor: Colors.white,
                          label: Text('Cari: "${widget.searchQuery.trim()}"'),
                        ),
                      if (adaFilterTanggal)
                        ActionChip(
                          avatar: const Icon(Icons.close, size: 14),
                          label: const Text('Reset Tanggal'),
                          onPressed: widget.onResetFilter,
                        ),
                    ],
                  ),
                ),
              if (dataTerfilter.isEmpty)
                Container(
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
                  child: Text(
                    _allRows.isEmpty
                        ? 'Belum ada data tamu.'
                        : adaPencarian
                        ? 'Tidak ada data yang cocok dengan pencarian.'
                        : 'Tidak ada data pada tanggal ini',
                  ),
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
