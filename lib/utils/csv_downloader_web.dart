import 'dart:convert';
import 'dart:html' as html;

/// Memicu download file CSV lewat browser.
/// [filename] sebaiknya sudah termasuk ekstensi, contoh: 'data_pelanggan.csv'.
void downloadCsv(String filename, String csvContent) {
  // Tambahkan BOM (Byte Order Mark) di awal supaya Excel otomatis
  // mendeteksi encoding UTF-8 dengan benar (penting untuk karakter
  // non-ASCII seperti huruf bertanda baca, dsb).
  const bom = '\uFEFF';
  final bytes = utf8.encode(bom + csvContent);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();

  html.Url.revokeObjectUrl(url);
}
