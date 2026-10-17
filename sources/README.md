# Database Sumber

Isi folder ini adalah bahan laporan:

- `pdf/`   : berkas PDF jurnal/buku. Nama berkas (tanpa ekstensi) dipakai
  sebagai nama sumber di parameter `-Sources`, contoh:
  `.\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2`
  mencari `pdf/jurnal1.pdf` dan `pdf/buku2.pdf`.
- `references.bib` : satu-satunya sumber sitasi yang sah. Sitasi di bab
  hanya boleh memakai citekey yang ada di file ini; sitasi lain otomatis
  diganti `[perlu diisi: sitasi tidak valid]` oleh skrip build.
- `extracted/` : cache hasil ekstraksi teks (dibuat otomatis, diabaikan git).

PDF hasil scan (gambar, tanpa lapisan teks) tidak bisa diekstrak
pdftotext -- perlu OCR dulu (lihat keterbatasan di README root).
