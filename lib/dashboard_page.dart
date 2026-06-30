import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'main.dart'; // pakai AppColors yang sudah didefinisikan di main.dart
import 'services/auth_service.dart';
import 'utils/csv_downloader.dart';
  
/// Warna tambahan khusus dashboard
class _DashColors {
  static const sidebarDark = AppColors.navy; // navy gelap
  static const sidebarTop = AppColors.teal; // teal terang (area avatar/topbar)
  static const menuActive = Color(0xFF0E7E8C); // highlight menu aktif
  static const bg = Color(0xFFBDBDBD); // background konten abu-abu
  static const red = Color(0xFFE63946); // tombol logout
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0; // 0 = Dashboard, 1 = Data Pelanggan
  final _searchController = TextEditingController();

  static const _menuTitles = ['Dashboard', 'Data Pelanggan'];

  void _selectMenu(int index) {
    setState(() => _selectedIndex = index);
    // Tutup drawer otomatis kalau lagi dibuka (mode mobile)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleDownload(BuildContext context) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unduh data saat ini hanya tersedia di versi web (Chrome/Edge).',
          ),
        ),
      );
      return;
    }

    final String csv;
    final String filename;

    if (_selectedIndex == 1) {
      // Halaman Data Pelanggan: unduh seluruh baris tabel.
      final buffer = StringBuffer();
      buffer.writeln('No,Tanggal,Nama,Jenis Layanan,Status');
      for (final row in _DataPelangganContent.rows) {
        buffer.writeln(
          [
            row['no'],
            row['tanggal'],
            row['nama'],
            row['layanan'],
            row['status'],
          ].map(_csvEscape).join(','),
        );
      }
      csv = buffer.toString();
      filename = 'data_pelanggan.csv';
    } else {
      // Halaman Dashboard: unduh ringkasan statistik.
      final buffer = StringBuffer();
      buffer.writeln('Label,Nilai');
      for (final stat in _DashboardContent.stats) {
        buffer.writeln('${_csvEscape(stat.label)},${_csvEscape(stat.value)}');
      }
      csv = buffer.toString();
      filename = 'ringkasan_dashboard.csv';
    }

    downloadCsv(filename, csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mengunduh $filename...')),
    );
  }

  /// Bungkus nilai dengan tanda kutip kalau mengandung koma, kutip,
  /// atau baris baru, supaya format CSV tetap valid.
  String _csvEscape(Object? value) {
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: _DashColors.bg,
          // Di layar lebar sidebar permanen, jadi tidak perlu drawer.
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
                        onDownload: () => _handleDownload(context),
                      ),
                      Expanded(
                        child: _selectedIndex == 0
                            ? const _DashboardContent()
                            : const _DataPelangganContent(),
                      ),
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
        // Area avatar, warna teal terang menyatu dengan topbar
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

        // Menu navigasi
        _SidebarMenuItem(
          label: 'Dashboard',
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

        // Sisa ruang gelap (sesuai desain)
        Expanded(child: Container(color: _DashColors.sidebarDark)),

        // Tombol logout di bagian bawah
        Container(
          width: double.infinity,
          color: _DashColors.sidebarDark,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 110,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Tidak perlu Navigator manual: AuthGate di main.dart
                  // otomatis menampilkan LoginPage begitu status auth
                  // berubah jadi "belum login".
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
                label: const Text('Logout', style: TextStyle(fontSize: 12)),
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
  final VoidCallback onDownload;

  const _TopBar({
    required this.title,
    required this.searchController,
    required this.showMenuButton,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
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
          // Search bar, melebar mengikuti sisa ruang yang tersedia
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari...',
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
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Unduh data sebagai CSV',
            onPressed: onDownload,
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.calendar_today_outlined,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// ====================== KONTEN: DASHBOARD ======================
class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  static const stats = [
    _StatItem(label: 'Total Pelanggan', value: '128'),
    _StatItem(label: 'Pelanggan Baru', value: '12'),
    _StatItem(label: 'Pelanggan Aktif', value: '96'),
  ];

  @override
  Widget build(BuildContext context) {
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

class _StatItem {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
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
class _DataPelangganContent extends StatelessWidget {
  const _DataPelangganContent();

  // Data contoh, ganti dengan data asli dari API/database
  static const rows = [
    {
      'no': '1',
      'tanggal': '01/06/2026',
      'nama': 'Andi Saputra',
      'layanan': 'Sewa Kamar',
      'status': 'Selesai',
    },
    {
      'no': '2',
      'tanggal': '03/06/2026',
      'nama': 'Budi Hartono',
      'layanan': 'Sewa Kamar',
      'status': 'Aktif',
    },
    {
      'no': '3',
      'tanggal': '05/06/2026',
      'nama': 'Citra Dewi',
      'layanan': 'Sewa Kamar',
      'status': 'Aktif',
    },
    {
      'no': '4',
      'tanggal': '07/06/2026',
      'nama': 'Dewi Lestari',
      'layanan': 'Sewa Kamar',
      'status': 'Selesai',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
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
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F0F0)),
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Nama')),
              DataColumn(label: Text('Jenis Layanan')),
              DataColumn(label: Text('Status')),
            ],
            rows: rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(Text(r['no']!)),
                      DataCell(Text(r['tanggal']!)),
                      DataCell(Text(r['nama']!)),
                      DataCell(Text(r['layanan']!)),
                      DataCell(_StatusBadge(status: r['status']!)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'aktif';
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
