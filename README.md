# TaniFlow — Agro Commodity Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://android.com)
[![License](https://img.shields.io/badge/Developer-Ansor%20Studio-2E7D32)](https://github.com/angga2103/taniFlow)

> **"Kelola Setoran. Kendalikan Penjualan. Pantau Keuntungan."**

**TaniFlow** adalah sistem manajemen operasional dan keuangan komprehensif yang dirancang khusus untuk para pengepul hasil pertanian dan pedagang komoditas sayuran di sentra produksi agropolitan dan pasar induk. Aplikasi ini berjalan secara **100% offline-first** menggunakan basis data lokal SQLite (Drift), dilengkapi pencadangan terenkripsi ke Google Drive, pencetakan bukti transaksi melalui thermal printer Bluetooth (ESC/POS 58mm & 80mm), ekspor laporan keuangan profesional ke format PDF dan Excel (.xlsx), serta pembagian bukti digital via WhatsApp menggunakan Android Share Sheet.

---

## 1. Identitas Aplikasi

- **Nama Aplikasi**: TaniFlow
- **Tagline**: *Kelola Setoran. Kendalikan Penjualan. Pantau Keuntungan.*
- **Deskripsi**: AGRO COMMODITY MANAGEMENT
- **Pengembang**: **Ansor Studio**
- **Versi**: `1.0.0+1`
- **Package ID**: `id.ansorstudio.taniflow`
- **Platform Sasaran**: Android (HP & Tablet Responsif)
- **Bahasa Pengantar**: Bahasa Indonesia
- **Mata Uang**: Rupiah (Rp)
- **Format Tanggal**: DD-MM-YYYY (WIB - Waktu Indonesia Barat)
- **Satuan Dasar Berat**: Kilogram (kg), presisi 2 desimal

---

## 2. Alur Bisnis Operasional

TaniFlow bukan aplikasi kasir konvensional. Sistem ini mengakomodasi alur rantai pasok agribisnis riil:

```
PETANI
  └──> 1. SETORAN HASIL PANEN (Timbangan Kotor - Tara = Bersih)
         └──> 2. SORTIR & GRADING (Grade A, B, C, Afkir, Rekonsiliasi Susut)
                └──> 3. PENGEMASAN & PENGIRIMAN PASAR (Gabungan Banyak Petani)
                       └──> 4. PENJUALAN PASAR (Bertahap / Tunai & Tempo)
                              └──> 5. ALOKASI HASIL KE PETANI SUMBER
                                     └──> 6. PENENTUAN HARGA PETANI
                                            └──> 7. PEMBAYARAN KAS PETANI
                                                   └──> 8. BUKU KAS & LABA BERSIH
```

### Prinsip Utama
1. **Ketertelusuran Asal Bobot**: Setiap kilogram sayuran yang dijual di pasar induk tetap tercatat asal petaninya melalui tabel relasi alokasi `shipment_allocations` dan `sale_allocations`.
2. **Rekonsiliasi Berat Sortir**: Sistem memverifikasi kesesuaian:
   $$\text{Berat Masuk} = \text{Grade A} + \text{Grade B} + \text{Grade C} + \text{Rusak} + \text{Selisih Belum Terjelaskan}$$
   Jika selisih melebihi batas toleransi susut komoditas, sistem mewajibkan pengisian alasan penjelasan dan mencatatnya ke audit log.
3. **Pemisahan Laporan Kas vs Laba**: Pembayaran kas kepada petani dicatat sebagai pengurang kewajiban pada buku kas, bukan biaya ganda pengurang laba rugi.
4. **Harga Petani Pasca-Penjualan**: Harga beli petani ditentukan secara manual setelah hasil sayuran terjual di pasar, dengan acuan harga jual rata-rata tertimbang aktual.

---

## 3. Arsitektur Teknis

- **Framework**: Flutter 3.47.5 stable, Dart null safety
- **Database Lokal**: SQLite via [Drift](https://drift.simonbinder.eu/) (34 tabel relasional, foreign keys, index, dan ACID transactions)
- **State Management**: [Riverpod](https://riverpod.dev/) (flutter_riverpod 2.6.1)
- **Keamanan**: 
  - Android Keystore & Flutter Secure Storage
  - Hash PIN 6-digit dengan Salt SHA-256
  - Biometrik (Fingerprint / Face Unlock via `local_auth`)
  - 8-Karakter Recovery Code untuk pemulihan akses tanpa menghilangkan database
- **Printer Struk**: Bluetooth ESC/POS Thermal Printer (dukungan kertas 58mm & 80mm via `print_bluetooth_thermal` dan `esc_pos_utils_plus`)
- **Dokumen & Ekspor**:
  - PDF Generator (`pdf`, `printing`)
  - Spreadsheet Excel (`excel` XLSX)
  - Android Native Share Sheet (`share_plus`)
- **Pencadangan Cloud**: Google Drive API (`googleapis`, `google_sign_in`) dengan kompresi ZIP, enkripsi metadata, dan retensi maksimal 30 versi terakhir.

---

## 4. Struktur Basis Data (34 Tabel Relasional)

1. `farmers`: Data identitas petani penyetor
2. `buyers`: Data pembeli / kios pasar induk
3. `commodities`: Katalog komoditas sayur dan toleransi susut
4. `commodity_units`: Master satuan (kg, gram, keranjang, karung, ikat, peti)
5. `unit_conversions`: Multiplier konversi satuan per komoditas ke kg
6. `market_price_references`: Riwayat catatan harga referensi pasar
7. `farmer_submissions`: Header setoran timbangan petani
8. `submission_items`: Detail komoditas ditimbang (kotor, tara, bersih)
9. `submission_photos`: Dokumentasi visual setoran
10. `grading_records`: Hasil sortir (Grade A, B, C, rusak, selisih)
11. `packaging_records`: Pencatatan wadah/kemasan dan biaya
12. `damage_records`: Kerusakan sayur dan pembagian beban kerugian
13. `shipments`: Surat jalan pengiriman muatan ke pasar
14. `shipment_items`: Rincian muatan per komoditas dan grade
15. `shipment_allocations`: Relasi many-to-many bobot muatan dari petani sumber
16. `sales`: Header faktur penjualan pasar (tunai / tempo)
17. `sale_items`: Detail item terjual, bobot, dan harga jual/kg
18. `sale_allocations`: Distribusi proporsional hasil penjualan ke petani asal
19. `farmer_price_determinations`: Penetapan harga beli petani
20. `farmer_payables`: Rekap total hak dan sisa kewajiban petani
21. `farmer_payments`: Bukti pembayaran tunai kepada petani
22. `buyer_receivables`: Kartu piutang pembeli penjualan tempo
23. `buyer_payments`: Penerimaan cicilan / pelunasan piutang pembeli
24. `expenses`: Pengeluaran operasional dan biaya kemasan
25. `cash_transactions`: Mutasi buku kas berjalan (masuk & keluar)
26. `daily_cash_closings`: Rekonsiliasi tutup kas fisik harian vs sistem
27. `app_settings`: Konfigurasi preferensi sistem
28. `business_profiles`: Identitas nama usaha, pemilik, dan kop nota
29. `calendar_events`: Pengingat operasional dan jatuh tempo
30. `audit_logs`: Rekam jejak perubahan data krusial
31. `backup_histories`: Riwayat pencadangan data
32. `notification_settings`: Pengaturan notifikasi lokal Android

---

## 5. Fitur Utama

### A. Operasional Timbangan & Bukti Setoran
- Penimbangan cepat: Petani $\to$ Komoditas $\to$ Kotor $\to$ Tara $\to$ Bersih otomatis.
- Multi-komoditas per transaksi setoran.
- Cetak struk thermal dan bagikan ke WhatsApp.
- Bukti setoran awal tanpa harga dengan disclaimer resmi: *"Harga dan pembayaran ditentukan setelah hasil panen terjual."*

### B. Sortir & Rekonsiliasi Berat
- Pilihan Mode Grading (Grade A, B, C) atau Mode Harga Tunggal.
- Peringatan otomatis jika selisih berat melampaui batas toleransi susut komoditas.
- Audit trail untuk setiap alasan selisih bobot.

### C. Pengiriman Gabungan & Alokasi Penjualan
- Penggabungan hasil panen banyak petani dalam satu truk pengiriman.
- Penjualan bertahap kepada satu atau banyak pembeli.
- Alokasi proporsional otomatis hasil penjualan ke masing-masing petani asal:
  $$\text{Alokasi Bobot Petani} = \left( \frac{\text{Bobot Sumber Petani}}{\text{Total Bobot Sumber Muatan}} \right) \times \text{Bobot Terjual}$$

### D. Manajemen Kas & Tutup Kas
- Pencatatan otomatis kas masuk (penjualan tunai & pelunasan piutang).
- Pencatatan kas keluar (pembayaran petani & biaya operasional).
- Fitur Tutup Kas Harian membandingkan uang fisik aktual dengan saldo sistem.

### E. Laporan Keuangan
- Filter: Harian, Mingguan, Bulanan, Tahunan, Custom Rentang Tanggal.
- Metrik: Omzet, Hak Petani, Margin Kotor, Biaya Kemasan, Biaya Operasional, Laba Bersih.
- Ekspor ke PDF dan Excel (.xlsx).

---

## 6. Pengujian Otomatis

Seluruh logika bisnis dan rekonsiliasi telah diuji secara menyeluruh melalui unit tests dan scenario tests:
- `test/unit/business_calculator_test.dart`: Formula berat bersih, konversi, alokasi proporsional, rata-rata tertimbang, laba rugi, dan format mata uang.
- `test/unit/scenarios_test.dart`: Simulasi alur penuh Skenario A hingga H (Setoran 100 kg cabai, sortir melampaui toleransi, pengiriman gabungan, penjualan bertahap, piutang, penetapan harga petani, pelunasan bertahap, dan rekonsiliasi akhir).
- `test/widget_test.dart`: Verifikasi rendering widget antarmuka aplikasi.

Jalankan test secara lokal:
```bash
flutter test
```

---

## 7. Build APK & GitHub Actions CI/CD

Repository ini telah dikonfigurasi dengan workflow otomatis GitHub Actions di `.github/workflows/android-build.yml`.

Setiap commit atau push ke branch `main` akan secara otomatis:
1. Memeriksa sintaks dan aturan kode (`flutter analyze`)
2. Menjalankan seluruh pengujian (`flutter test`)
3. Membangun file APK rilis (`flutter build apk --release`)
4. Mengunggah APK ke **GitHub Actions Artifacts** sehingga dapat langsung diunduh dan dipasang pada perangkat Android.

---

## 8. Panduan Menjalankan Proyek Secara Lokal

1. Pastikan Flutter SDK telah terpasang:
   ```bash
   flutter --version
   ```
2. Pasang dependensi proyek:
   ```bash
   flutter pub get
   ```
3. Bangun kode database Drift:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Jalankan aplikasi pada perangkat Android / emulator:
   ```bash
   flutter run
   ```
