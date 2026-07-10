class GuestCode {
  GuestCode._();

  static const List<String> _dayAbbr = [
    'SEN',
    'SEL',
    'RAB',
    'KAM',
    'JUM',
    'SAB',
    'MIN',
  ];

  static const List<String> _monthAbbr = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MEI',
    'JUN',
    'JUL',
    'AGU',
    'SEP',
    'OKT',
    'NOV',
    'DES',
  ];

  static String generate(DateTime date, int urutan) {
    final String hari = _dayAbbr[date.weekday - 1];
    final String bulan = _monthAbbr[date.month - 1];
    final String tahun = (date.year % 100).toString().padLeft(2, '0');
    final String urutanStr = urutan.toString().padLeft(2, '0');
    return '$hari${date.day}$bulan$tahun-$urutanStr';
  }
}
