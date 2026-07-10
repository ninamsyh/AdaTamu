import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // pastikan package 'intl' sudah ada di pubspec.yaml
import 'admin_profile_page.dart';
import 'main.dart'; // pakai AppColors yang sudah didefinisikan di main.dart
import 'services/auth_service.dart';
import 'utils/csv_downloader.dart';

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
  final DateTime? waktuMasuk;
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

  bool get sudahSelesai => status.toLowerCase() == 'selesai';
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
  static const sidebarDark = AppColors.navy;
  static const sidebarTop = AppColors.teal;
  static const menuActive = Color(0xFF0E7E8C);
  static const bg = Color(0xFFBDBDBD);
  static const red = Color(0xFFE63946);
}

class _StatItem {
  final String label;
  final String value;
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
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<GuestRecord> _currentGuestRows = const [];
  List<_StatItem> _currentStats = const [];

  DateTime? _tanggalDipilih;
  DateTimeRange? _rentangTanggal;
  String? _statusFilter;

  static const _menuTitles = ['Beranda', 'Data Pelanggan', 'Profil'];

  void _selectMenu(int index) {
    setState(() => _selectedIndex = index);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _bukaDataPelangganDenganStatus(String statusKey) {
    setState(() {
      _selectedIndex = 1;
      _statusFilter = statusKey == 'total' ? null : statusKey;
    });
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
        final tampilkanAlatPencarian = _selectedIndex == 1;

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
                        showTools: tampilkanAlatPencarian,
                        onSearchChanged: tampilkanAlatPencarian
                            ? (value) => setState(() => _searchQuery = value)
                            : null,
                        onDownload: tampilkanAlatPencarian
                            ? () => _handleDownload(context)
                            : null,
                        onCalendarTap: tampilkanAlatPencarian
                            ? () => _bukaDatePicker(context)
                            : null,
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
          onStatusTap: _bukaDataPelangganDenganStatus,
        );
      case 1:
        return _DataPelangganContent(
          tanggalDipilih: _tanggalDipilih,
          rentangTanggal: _rentangTanggal,
          searchQuery: _searchQuery,
          statusFilter: _statusFilter,
          onResetFilter: () => setState(() {
            _tanggalDipilih = null;
            _rentangTanggal = null;
          }),
          onResetStatus: () => setState(() => _statusFilter = null),
          onRowsChanged: (rows) {
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

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.teal, _DashColors.sidebarDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
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
          const Divider(color: Colors.white30, thickness: 1, height: 1),
          _SidebarMenuItem(
            label: 'Data Pelanggan',
            icon: Icons.people_outline,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          const Divider(color: Colors.white30, thickness: 1, height: 1),
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
      ),
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
      color: selected ? _DashColors.menuActive : Colors.transparent,
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

class _TopBar extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final bool showMenuButton;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onCalendarTap;
  final ValueChanged<String>? onSearchChanged;

  const _TopBar({
    required this.title,
    required this.searchController,
    required this.showMenuButton,
    required this.showTools,
    this.onDownload,
    this.onCalendarTap,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
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
              onPressed: () => Scaffold.of(context).openDrawer(),
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
                    hintText: 'Cari nama, alamat, keperluan, kode tamu...',
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
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Filter berdasarkan tanggal',
              onPressed: onCalendarTap,
            ),
          ] else
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

class _DashboardContent extends StatefulWidget {
  final ValueChanged<List<_StatItem>>? onStatsChanged;
  final ValueChanged<String>? onStatusTap;
  const _DashboardContent({this.onStatsChanged, this.onStatusTap});

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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allDocs = [];
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

  DateTime? _tanggalDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return GuestRecord._parseTanggal(
      data['tanggalKunjungan'] ?? data['createdAt'],
    );
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

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

  List<GuestRecord> _recentGuests() {
    final all = _allDocs.map(GuestRecord.fromDoc).toList()
      ..sort((a, b) {
        final ta = a.waktuMasuk ?? a.tanggal;
        final tb = b.waktuMasuk ?? b.tanggal;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    return all.take(5).toList();
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
          if (months.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: _MonthFilterDropdown(
                selectedMonth: _selectedMonth,
                months: months,
                monthLabelBuilder: _monthLabel,
                onChanged: _onMonthChanged,
              ),
            ),
          if (months.isNotEmpty) const SizedBox(height: 14),
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
                          onTap: widget.onStatusTap == null
                              ? null
                              : () => widget.onStatusTap!(s.key),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final chart = _StatusChartCard(
                total: _total,
                menunggu: _menunggu,
                selesai: _selesai,
              );
              final recent = _RecentGuestsCard(
                guests: _recentGuests(),
                onLihatSemua: widget.onStatusTap == null
                    ? null
                    : () => widget.onStatusTap!('total'),
              );

              if (narrow) {
                return Column(
                  children: [chart, const SizedBox(height: 16), recent],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: chart),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: recent),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthFilterDropdown extends StatelessWidget {
  final String selectedMonth;
  final List<String> months;
  final String Function(String) monthLabelBuilder;
  final ValueChanged<String?> onChanged;

  const _MonthFilterDropdown({
    required this.selectedMonth,
    required this.months,
    required this.monthLabelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          icon: const Icon(Icons.expand_more_rounded, size: 16),
          isDense: true,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: [
            const DropdownMenuItem(
              value: 'semua',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  SizedBox(width: 6),
                  Text('Semua Bulan'),
                ],
              ),
            ),
            ...months.map(
              (m) =>
                  DropdownMenuItem(value: m, child: Text(monthLabelBuilder(m))),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RecentGuestsCard extends StatelessWidget {
  final List<GuestRecord> guests;
  final VoidCallback? onLihatSemua;
  const _RecentGuestsCard({required this.guests, this.onLihatSemua});

  @override
  Widget build(BuildContext context) {
    final jamFmt = DateFormat('dd/MM • HH:mm');
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tamu Terbaru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              if (onLihatSemua != null)
                TextButton(
                  onPressed: onLihatSemua,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(fontSize: 11, color: AppColors.teal),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (guests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada tamu yang tercatat.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            ...guests.map((g) {
              final waktu = g.waktuMasuk ?? g.tanggal;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.teal.withOpacity(0.12),
                      child: const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.namaLengkap,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            waktu != null ? jamFmt.format(waktu) : '-',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(status: g.status, compact: true),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          final donut = SizedBox(
            width: 96,
            height: 96,
            child: total == 0
                ? const Center(
                    child: Text(
                      'Belum ada data',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 10,
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
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 10),
              _LegendRow(
                color: AppColors.teal,
                label: 'Selesai',
                value: selesai,
              ),
              const SizedBox(height: 6),
              _LegendRow(
                color: AppColors.yellow,
                label: 'Menunggu',
                value: menunggu,
              ),
              const SizedBox(height: 6),
              _LegendRow(color: AppColors.navy, label: 'Total', value: total),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                legend,
                const SizedBox(height: 14),
                Center(child: donut),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: legend),
              const SizedBox(width: 16),
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
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12, color: AppColors.darkText),
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
    const strokeWidth = 14.0;
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

class _DataPelangganContent extends StatefulWidget {
  final DateTime? tanggalDipilih;
  final DateTimeRange? rentangTanggal;
  final String searchQuery;
  final String? statusFilter;
  final VoidCallback onResetFilter;
  final VoidCallback onResetStatus;
  final ValueChanged<List<GuestRecord>>? onRowsChanged;

  const _DataPelangganContent({
    required this.tanggalDipilih,
    required this.rentangTanggal,
    required this.searchQuery,
    required this.statusFilter,
    required this.onResetFilter,
    required this.onResetStatus,
    this.onRowsChanged,
  });

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

  static List<GuestRecord> filterBySearch(
    List<GuestRecord> data,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return data;
    return data.where((row) => row.searchableText.contains(q)).toList();
  }

  static List<GuestRecord> filterByStatus(
    List<GuestRecord> data,
    String? status,
  ) {
    if (status == null) return data;
    final wantSelesai = status == 'selesai';
    return data.where((row) => row.sudahSelesai == wantSelesai).toList();
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
    _guestsStream = FirebaseFirestore.instance.collection('guests').snapshots();
    _guestsStream.listen(
      (snapshot) {
        if (!mounted) return;
        final rows = snapshot.docs.map(GuestRecord.fromDoc).toList()
          ..sort((a, b) {
            final ta = a.tanggal;
            final tb = b.tanggal;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
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
    final byStatus = _DataPelangganContent.filterByStatus(
      byDate,
      widget.statusFilter,
    );
    return _DataPelangganContent.filterBySearch(byStatus, widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _DataPelangganContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tanggalDipilih != widget.tanggalDipilih ||
        oldWidget.rentangTanggal != widget.rentangTanggal ||
        oldWidget.statusFilter != widget.statusFilter ||
        oldWidget.searchQuery != widget.searchQuery) {
      _reportFiltered();
    }
  }

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

  Future<void> _tandaiSelesai(BuildContext context, GuestRecord guest) async {
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
    final adaFilterStatus = widget.statusFilter != null;
    final adaPencarian = widget.searchQuery.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (adaFilterTanggal || adaFilterStatus || adaPencarian)
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
                      if (adaFilterStatus)
                        Chip(
                          avatar: Icon(
                            widget.statusFilter == 'selesai'
                                ? Icons.task_alt_rounded
                                : Icons.hourglass_top_rounded,
                            size: 14,
                          ),
                          backgroundColor: Colors.white,
                          label: Text(
                            'Status: ${widget.statusFilter == 'selesai' ? 'Selesai' : 'Menunggu'}',
                          ),
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
                      if (adaFilterStatus)
                        ActionChip(
                          avatar: const Icon(Icons.close, size: 14),
                          label: const Text('Reset Status'),
                          onPressed: widget.onResetStatus,
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

class _StatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;
  final bool compact;
  const _StatusBadge({required this.status, this.onTap, this.compact = false});

  bool get _isSelesai => status.toLowerCase() == 'selesai';

  @override
  Widget build(BuildContext context) {
    final color = _isSelesai ? Colors.green : Colors.orange;
    final label = _isSelesai ? 'selesai' : 'menunggu';
    final bisaDiklik = onTap != null;

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 4,
      ),
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
              fontSize: compact ? 10 : 11,
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
