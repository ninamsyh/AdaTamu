<<<<<<< HEAD
# AdaTamu

=======
# AdaTamu — Aplikasi Buku Tamu Digital

Aplikasi buku tamu digital berbasis Flutter/Dart, dengan 3 halaman:

1. **Dashboard** — background gradient, logo & teks "Selamat Datang" beranimasi, tombol "Isi Buku Tamu".
2. **Form Data Diri** — Nama Lengkap, Jenis Kelamin (dropdown), Alamat Lengkap, Nomor Handphone.
3. **Form Keperluan** — dropdown Keperluan (KWH Meter, Pembayaran Tagihan, Perubahan Daya Listrik, Masalah Administrasi), Keterangan Tambahan, tombol Simpan ke Cloud Firestore.

Target platform: **Android** dan **Windows desktop**.

---

## 1. Struktur folder

```
lib/
  main.dart                     # entry point
  theme/app_theme.dart          # warna, gradient, text style (1 sumber kebenaran)
  models/guest.dart             # model data tamu
  services/
    firebase_config.dart        # ⚠️ ISI project ID & API key Firebase kamu di sini
    guest_service.dart          # logic simpan data ke Firestore (REST API)
  widgets/
    adatamu_logo.dart           # logo buku+petir (JANGAN diubah bentuknya)
    animated_pill_button.dart   # tombol pil kuning interaktif
    guest_text_field.dart       # input teks bergaya pil putih
    guest_dropdown_field.dart   # dropdown bergaya pil putih
  screens/
    dashboard_page.dart         # page 1
    guest_form_page2.dart       # page 2
    guest_form_page3.dart       # page 3
    guest_success_page.dart     # halaman setelah data berhasil disimpan
pubspec.yaml
```

---

## 2. Cara menjalankan project ini

Karena yang saya berikan hanya source code Dart (folder `lib/` + `pubspec.yaml`), kamu perlu membungkusnya jadi project Flutter yang lengkap (folder `android/`, `windows/`, dll dibuat otomatis oleh Flutter, bukan oleh saya — supaya selalu cocok dengan versi Flutter SDK di komputer kamu).

### Langkah-langkah:

```bash
# 1. Buat project Flutter baru kosong
flutter create adatamu_app
cd adatamu_app

# 2. Hapus folder lib/ bawaan, lalu copy folder lib/ yang saya berikan ke sini
#    (timpa pubspec.yaml bawaan dengan pubspec.yaml yang saya berikan)

# 3. Aktifkan dukungan Windows desktop (kalau belum aktif)
flutter config --enable-windows-desktop

# 4. Ambil semua package
flutter pub get

# 5. Jalankan di Android (HP/tablet/emulator harus sudah terhubung)
flutter run -d android

# 6. Jalankan di Windows
flutter run -d windows
```

> **Catatan:** project ini TIDAK memakai plugin `cloud_firestore` sama
> sekali — baik untuk Android maupun Windows — karena plugin tersebut
> sering gagal di-build atau crash di Windows desktop. Sebagai gantinya,
> SEMUA platform memakai **Firestore REST API** lewat package `http`.
> Jadi kamu tidak perlu menjalankan `flutterfire configure` atau
> menaruh `google-services.json`.

---

## 3. Setup Firebase (yang kamu perlukan)

Karena kamu sudah punya project Firebase, kamu hanya perlu **2 informasi**:

### a. Project ID
1. Buka [Firebase Console](https://console.firebase.google.com/).
2. Pilih project kamu.
3. Klik ⚙️ (Project settings) di sidebar kiri atas.
4. Di tab **General**, cari baris **Project ID** (bukan "Project name").

### b. Web API Key
1. Di halaman **Project settings** yang sama, scroll ke bagian **Your apps**.
2. Kalau belum ada app jenis **Web** (ikon `</>`), klik **Add app** → pilih Web → beri nama apa saja → **Register app**.
   (Ini hanya untuk mendapatkan API key, bukan berarti aplikasi kamu jadi web app.)
3. Setelah app Web dibuat, kamu akan melihat config seperti ini:
   ```js
   const firebaseConfig = {
     apiKey: "AIzaSy...",        // <- ini yang dicari
     projectId: "nama-project-id",
     ...
   };
   ```
4. Salin nilai `apiKey` dan `projectId`.

### c. Masukkan ke project
Buka `lib/services/firebase_config.dart`, lalu ganti:

```dart
class FirebaseConfig {
  static const String projectId = 'GANTI_DENGAN_PROJECT_ID';
  static const String apiKey = 'GANTI_DENGAN_WEB_API_KEY';
  static const String collection = 'guests';
}
```

menjadi nilai milikmu, misalnya:

```dart
class FirebaseConfig {
  static const String projectId = 'adatamu-12345';
  static const String apiKey = 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  static const String collection = 'guests';
}
```

### d. Atur Firestore Security Rules
Supaya aplikasi bisa menulis data tanpa login (cocok untuk buku tamu publik), buka **Firestore Database > Rules** di Firebase Console, lalu pakai rule seperti ini sebagai contoh awal:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /guests/{document} {
      allow create: if true;
      allow read, update, delete: if false;
    }
  }
}
```

Rule di atas mengizinkan **siapa saja membuat data baru** di collection `guests`, tapi tidak bisa membaca/mengubah/menghapus data tamu lain — cocok untuk kios buku tamu publik. Sesuaikan lagi kalau kebutuhanmu berbeda (misalnya kalau nanti ingin admin bisa melihat daftar tamu, kamu perlu menambah login admin dan rule baca terpisah).

---

## 4. Catatan desain (jangan diubah tanpa sengaja)

- **Logo**: bentuk ikon buku + petir digambar manual lewat `CustomPainter` di `widgets/adatamu_logo.dart`. Supaya bentuknya tetap konsisten di semua halaman, jangan ubah path di `_BookBoltPainter` — kalau perlu logo lebih besar/kecil, ubah parameter `scale` saja.
- **Warna teks logo**: "Ada" selalu biru (`AppColors.logoAda`), "Tamu" selalu kuning (`AppColors.logoTamu`). Diatur terpusat di `theme/app_theme.dart`.
- **Gradient background**: `AppColors.backgroundGradient`, dipakai di dashboard dan header halaman form supaya konsisten.

---

## 5. Field opsional yang saya tambahkan

- **Keterangan Tambahan** (textarea, opsional) di page 3 — sesuai video referensi, meski tidak disebutkan di awal permintaan.
- **Halaman "Terima Kasih"** setelah data berhasil disimpan, supaya pengguna tahu data sudah masuk sebelum kembali ke dashboard.

Kalau dua hal ini tidak diinginkan, tinggal beri tahu saya dan saya sesuaikan.
>>>>>>> d2590e1e307168aba20a080fbe3e5ccfaed21167
