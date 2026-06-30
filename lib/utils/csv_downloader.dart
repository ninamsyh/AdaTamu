// Conditional export: kalau di-compile untuk web, pakai implementasi yang
// memicu download lewat browser. Kalau di-compile untuk platform lain
// (Windows/Android/dst), pakai implementasi stub yang cuma kasih tahu
// fitur ini belum didukung di platform itu.
export 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart';
