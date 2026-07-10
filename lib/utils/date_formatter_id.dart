class DateFormatterID {
  DateFormatterID._();

  static const List<String> _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _monthNames = [
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

  static String formatLengkap(DateTime date) {
    final String hari = _dayNames[date.weekday - 1];
    final String bulan = _monthNames[date.month - 1];
    final String jam = date.hour.toString().padLeft(2, '0');
    final String menit = date.minute.toString().padLeft(2, '0');
    return '$hari, ${date.day} $bulan ${date.year}, $jam:$menit';
  }

  static String format(DateTime date) {
    final String bulan = _monthNames[date.month - 1];
    final String jam = date.hour.toString().padLeft(2, '0');
    final String menit = date.minute.toString().padLeft(2, '0');
    return '${date.day} $bulan ${date.year}, $jam:$menit';
  }

  static String formatTanggalSaja(DateTime date) {
    final String bulan = _monthNames[date.month - 1];
    return '${date.day} $bulan ${date.year}';
  }

  static String formatJamSaja(DateTime date) {
    final String jam = date.hour.toString().padLeft(2, '0');
    final String menit = date.minute.toString().padLeft(2, '0');
    return '$jam:$menit';
  }
}
