/// Stub untuk platform selain web. Saat ini fitur download CSV cuma
/// didukung di build web (Chrome/Edge), karena memakai mekanisme
/// download bawaan browser. Kalau dipanggil dari platform lain,
/// fungsi ini tidak melakukan apa-apa (pemanggil sebaiknya cek
/// `kIsWeb` dulu dan tampilkan pesan ke user).
void downloadCsv(String filename, String csvContent) {
  // Sengaja dikosongkan untuk platform non-web.
}
