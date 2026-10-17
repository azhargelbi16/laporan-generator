---
description: Otomatisasi pembuatan dan kompilasi karya tulis ilmiah S1 FAPERTA UNEJ menggunakan skill laporan-generator
---

1. Aktifkan skill `laporan-generator`.
2. Lakukan wawancara bertahap: tentukan jenis karya tulis (skripsi/laporan praktikum/responsi/PKL/makalah) dan mode (`skripsi` atau `laporan`).
3. Konfirmasi komponen opsional: Ringkasan, Summary, Lembar Pengesahan, Daftar Gambar, Daftar Tabel.
4. Isi `metadata.yml` dengan `preset: "unej-faperta"` dan data penulis/pembimbing/institusi.
5. Susun isi `chapters/*.md` mengikuti kaidah PPKI FAPERTA (tanpa nomor manual pada heading, sitasi APA 6th).
6. Cek dependensi sistem menggunakan `setup-deps` bila kompilasi gagal.
7. Kompilasi PDF dan DOCX menggunakan `./laporan build` (Linux/Mac) atau `.\laporan.ps1 build` (Windows).
