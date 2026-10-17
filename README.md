<p align="center">
  <img src="logo.jpg" alt="Laporan Generator" width="180"/>
</p>

<h1 align="center">Laporan Generator — FAPERTA Universitas Jember</h1>

<p align="center">
  <b>Generator Karya Tulis Ilmiah S1 FAPERTA UNEJ dari Markdown ke PDF & Word</b><br/>
  Menyusun <b>skripsi, laporan praktikum/responsi, laporan PKL/magang, proposal usaha,
  dan makalah kuliah</b> mengikuti Buku Pedoman Penulisan Karya Tulis Ilmiah (PPKI)
  Fakultas Pertanian Universitas Jember — dalam hitungan detik.
</p>

<p align="center">
  <a href="GETTING-STARTED.md">Panduan Cepat</a> &bull;
  <a href="docs/campus-guide.md">Panduan Format FAPERTA</a> &bull;
  <a href="docs/syntax-cheatsheet.md">Cheatsheet Sintaks</a> &bull;
  <a href="docs/metadata-schema.md">Skema Metadata</a> &bull;
  <a href="docs/troubleshooting.md">Penyelesaian Masalah</a>
</p>

---

## Ikhtisar

Laporan Generator adalah kompilator otomatisasi dokumen akademik berevolusi ganda
(*dual-engine*) dari berkas sumber Markdown modular menjadi:

1. **PDF**: kompilasi tipografi presisi berbasis Typst.
2. **Microsoft Word (.docx)**: dokumen OpenXML dengan hierarki heading rapi,
   Daftar Isi dinamis, dan penomoran halaman ganda (Romawi kecil bagian awal,
   Arab bagian utama).

Proyek ini dikonfigurasi khusus untuk **jenjang S1 FAPERTA Universitas Jember**
dengan satu preset: **`unej-faperta`**.

---

## Format FAPERTA UNEJ (Ringkas)

| Aspek | Ketentuan |
|---|---|
| Kertas | A4, 80 gram |
| Margin | Atas **4 cm**, Bawah **3 cm**, Kiri **4 cm**, Kanan **3 cm** |
| Font | **Times New Roman 12 pt** (judul sampul 14 pt) |
| Indentasi | **1 cm** |
| Spasi baris | **1,5** (daftar pustaka 1 spasi) |
| Judul bab | **`BAB 1. PENDAHULUAN`** (Arab + titik, default; opsi Romawi `BAB I`) |
| Subbab | **`1.1. Judul Subbab`** (tebal) |
| Subsubbab | **`1.1.1 Judul Subsubbab`** (tidak tebal) |
| Nomor halaman | Romawi kecil tengah-bawah (awal); Arab kanan-atas (utama) |
| Ilustrasi | `Tabel 1.1.` (atas) dan `Gambar 1.1.` (bawah) |
| Sitasi | **APA 6th edition** |

---

## Struktur Dokumen (Mode)

Field `mode` pada `metadata.yml` menentukan struktur halaman depan:

- **`mode: skripsi`** → Sampul → Lembar Pengesahan → Ringkasan → Summary →
  Prakata → Daftar Isi/Tabel/Gambar → Batang Tubuh → Daftar Pustaka → Lampiran.
- **`mode: laporan`** → Sampul → Prakata/Kata Pengantar → Daftar Isi
  (+ Daftar Gambar/Tabel bila ada) → Batang Tubuh → Daftar Pustaka → Lampiran.

---

## Alur Penggunaan Cepat

### Prasyarat
Pasang dependensi sistem (Typst, Pandoc, ImageMagick, Python):
```powershell
.\laporan.ps1 setup      # Windows
```
```bash
./laporan setup          # Linux / macOS
```

### 1. Inisialisasi dokumentasi proyek (konten contoh)
```powershell
.\laporan.ps1 init
```

### 2. Sunting berkas
- `metadata.yml` — judul, penulis, pembimbing, prodi, tahun, mode.
- `cover.md` — Prakata/Kata Pengantar.
- `chapters/bab*.md` — isi bab.
- `references.bib` — daftar pustaka (APA 6th).
- `gambar/` — gambar, tabel, diagram.

### 3. Kompilasi
```powershell
.\laporan.ps1 build      # PDF + DOCX
.\laporan.ps1 pdf        # hanya PDF
.\laporan.ps1 docx       # hanya DOCX
```

Hasil: `Laporan.pdf` dan `Laporan.docx`.

---

## Matriks Perintah CLI

| Perintah | Bash (`./laporan`) | PowerShell (`.\laporan.ps1`) | Fungsi |
|---|---|---|---|
| `mcp` | Didukung | Didukung | Menjalankan MCP Server |
| `init` | Didukung | Didukung | Wizard konfigurasi metadata |
| `setup` | Didukung | Didukung | Pasang dependensi sistem |
| `check` | Didukung | Didukung | Audit dependensi & berkas |
| `build` / `pdf` / `docx` | Didukung | Didukung | Kompilasi dokumen |
| `stats` | Didukung | Didukung | Statistik kata, halaman, gambar |
| `doctor` | Didukung | Didukung | Audit sitasi, gambar, heading |
| `bundle` | Didukung | Didukung | Kemas menjadi arsip ZIP |
| `preset list/show/apply/validate` | Didukung | Didukung | Kelola preset (`unej-faperta`) |
| `view` / `watch` / `clean` | Didukung | Didukung | Lihat, pantau, bersihkan |

---

## Konfigurasi (`metadata.yml`)

```yaml
title: "JUDUL KARYA TULIS"
jenis_karya: "SKRIPSI"
mode: "skripsi"
author:
  - name: "Nama Mahasiswa"
    nim: "251510501059"
lecturer: "Ir. Nama Dosen Pembimbing, M.P."
lecturer_label: "Dosen Pembimbing:"
program_studi: "Program Studi Agroteknologi"
faculty: "Fakultas Pertanian"
institution: "Universitas Jember"
year: "2026"
preset: "unej-faperta"
daftar_gambar: false
daftar_tabel: false
```

---

## Struktur Direktori

```text
laporan-generator/
├── bin/                    # Router CLI & MCP server (Node.js)
├── lib/                    # Modul init, setup, sync-hosts, uninstall
├── .agents/skills/         # Agent Skill lintas platform
├── chapters/               # Berkas bab modular (bab1..bab5)
├── contoh/                 # Contoh nyata & pedoman PPKI FAPERTA
├── docs/                   # Dokumentasi teknis
├── gambar/                 # Gambar & diagram
├── presets/unej-faperta.yml
├── scripts/                # Utilitas Python (doctor, stats, dll.)
├── apa.csl                 # Gaya sitasi APA 6th
├── cover.md                # Prakata & transisi Daftar Isi
├── docx.lua                # Filter Pandoc untuk DOCX
├── metadata.yml            # Konfigurasi dokumen aktif
├── references.bib          # Basis data sitasi BibTeX
├── template.typ            # Mesin tata letak Typst
├── laporan / laporan.ps1   # CLI Bash / PowerShell
└── build.sh / build-docx.sh
```

---

## Pusat Dokumentasi

- **[Panduan Pemula](GETTING-STARTED.md)**: dari instalasi hingga kompilasi pertama.
- **[Panduan Format FAPERTA](docs/campus-guide.md)**: ringkasan aturan PPKI FAPERTA.
- **[Cheatsheet Sintaks](docs/syntax-cheatsheet.md)**: sitasi, rumus, tabel, gambar.
- **[Skema Metadata](docs/metadata-schema.md)**: seluruh field `metadata.yml`.
- **[Skema Preset](docs/preset-schema.md)**: spesifikasi preset `unej-faperta`.
- **[Panduan Template](docs/template-guide.md)**: arsitektur tipografi Typst.
- **[Troubleshooting](docs/troubleshooting.md)**: penanganan kendala umum.

---

## Lisensi

Didistribusikan di bawah lisensi MIT. Lihat berkas [LICENSE](LICENSE).
