---
name: laporan-generator
description: >-
  Generator laporan akademik & karya tulis ilmiah S1 untuk Fakultas Pertanian
  Universitas Jember (FAPERTA UNEJ) dengan Native MCP Tools. Use when the user
  wants to scaffold, draft, write, format, audit, or compile academic documents:
  skripsi, laporan praktikum, laporan responsi, laporan PKL/magang, proposal
  usaha, atau makalah kuliah yang mengikuti Buku Pedoman Penulisan Karya Tulis
  Ilmiah (PPKI) FAPERTA Universitas Jember.
---

# Laporan Generator: Engine Dokumen Akademik FAPERTA UNEJ (S1)

Skill ini membantu agen AI menyusun, menulis, mengaudit, dan mengompilasi
karya tulis ilmiah tingkat S1 di lingkungan **Fakultas Pertanian Universitas
Jember** mengikuti Buku Pedoman Penulisan Karya Tulis Ilmiah (PPKI) FAPERTA UNEJ
(SK Dekan No. 5705/UN25.1.3/KP.8/2021). Mesin ganda: **Typst (PDF)** dan
**Pandoc + OpenXML (Word DOCX)**.

> [!CRITICAL]
> **ARSTEKTUR MARKDOWN MODULAR — WAJIB**:
> - JANGAN menulis kode Typst mentah dari awal atau mengimpor template pihak ketiga.
> - JANGAN membuat dokumen satu-berkas raksasa.
> Mesin ini dirancang pada komponen modular:
> 1. `metadata.yml`: metadata akademik (judul, penulis, pembimbing, institusi, mode, preset).
> 2. `cover.md`: Prakata + blok transisi Daftar Isi & penomoran halaman.
> 3. `chapters/`: berkas bab modular dalam Markdown standar (`bab1-pendahuluan.md`, dst.).
> 4. `references.bib`: basis data sitasi BibTeX (gaya APA 6th).
> 5. `template.typ` & `docx.lua`: mesin kompilasi ganda bawaan.

--------------------------------------------------------------------------------

## 1. Aturan Format FAPERTA UNEJ (WAJIB DIPATUHI)

| Elemen | Aturan PPKI FAPERTA |
| :--- | :--- |
| Kertas | A4, 80 gram |
| Margin | Pias atas **4 cm**, bawah **3 cm**, kiri **4 cm**, kanan **3 cm** |
| Font | **Times New Roman 12 pt** (judul sampul 14 pt) |
| Indentasi paragraf | **1 cm** dari pias kiri |
| Spasi baris | **1,5** (daftar pustaka 1 spasi; antar-pustaka 2 spasi) |
| Judul bab | Halaman baru, KAPITAL dicetak tebal, tengah, angka Arab + titik: **`BAB 1. PENDAHULUAN`** (opsi Romawi: `BAB I`) |
| Subbab | Kiri, **tebal**, Title Case, nomor + titik: **`1.1. Judul Subbab`** |
| Subsubbab | Kiri, **tidak tebal**, Title Case, tanpa titik akhir: **`1.1.1 Judul Subsubbab`** |
| Nomor halaman | Romawi kecil (i, ii, iii) tengah-bawah untuk bagian awal; Arab (1, 2, 3) kanan-atas untuk bagian utama; halaman pertama tiap bab di tengah-bawah |
| Ilustrasi | `Tabel 1.1.` (caption di atas) dan `Gambar 1.1.` (caption di bawah) — 11 pt, Sentence case |
| Sitasi | **APA 6th edition**: `(Nama, 2020)`, `Nama dan Nama (2020)`, `Nama dkk. (2020)` |

--------------------------------------------------------------------------------

## 2. Native MCP Tools & Perintah CLI

Saat tersedia, utamakan **native MCP tools**:

| Aksi | Native MCP Tool | Fallback CLI |
| :--- | :--- | :--- |
| Inisialisasi Proyek | `laporan_init({ preset, title, author_name, institution })` | `npx laporan-generator init` |
| Audit Kesehatan | `laporan_doctor({ target_dir })` | `./laporan doctor` |
| Statistik Dokumen | `laporan_stats({ target_dir })` | `./laporan stats` |
| Inspeksi Preset | `laporan_presets({ action: "list" \| "get" })` | `./laporan preset list` |
| Tambah Sitasi | `laporan_citations({ action: "add_citation", doi })` | Manual edit `references.bib` |
| Kompilasi | `laporan_build({ format: "all" \| "pdf" \| "docx" })` | `./laporan build` |

--------------------------------------------------------------------------------

## 3. Protokol Interaktif (5 Tahap)

### Tahap 1: Identifikasi Jenis Karya Tulis S1
Tanyakan jenis dokumen:
1. **Skripsi** (mode `skripsi`): struktur 5 bab, ringkasan/summary bilingual, lembar pengesahan.
2. **Laporan Praktikum / Responsi** (mode `laporan`): cover + kata pengantar/prakata + daftar isi (+ daftar gambar/tabel bila ada).
3. **Laporan PKL / Magang** (mode `laporan`).
4. **Proposal Usaha / Makalah Kuliah** (mode `laporan`).

### Tahap 2: Konfirmasi Struktur & Scaffolding
1. Konfirmasi komponen opsional: Ringkasan (`abstract_id`), Summary (`abstract_en`), Lembar Pengesahan (`approval`), Daftar Gambar (`daftar_gambar`), Daftar Tabel (`daftar_tabel`).
2. Jalankan `laporan_init` atau `npx laporan-generator init`.
3. Isi `metadata.yml`: `title`, `jenis_karya`, `mode`, `author`, `lecturer`, `program_studi`, `faculty`, `institution`, `year`, `preset: "unej-faperta"`.
4. Sesuaikan `cover.md` (Prakata).

### Tahap 3: Penulisan Akademik
- Gunakan gaya **objektif & impersonal** ("Penelitian ini merancang..." bukan "Saya merancang...").
- Hindari klise AI ("Dalam era globalisasi...", "Tak dapat dipungkiri bahwa...").
- **JANGAN menulis nomor di heading**: `# Pendahuluan` (bukan `# BAB 1. Pendahuluan`), `## Latar Belakang` (bukan `## 1.1 Latar Belakang`). Mesin menghitung nomor otomatis.
- Gunakan Title Case untuk subbab/subsubbab tanpa titik akhir.

### Tahap 4: Higiene Sitasi (APA 6th)
- TIDAK boleh mengarang referensi.
- Cari referensi nyata via `laporan_citations` (Crossref).
- Sitasi di naskah: `[@citekey]`, `@citekey`, atau `[@citekey1; @citekey2]`.

### Tahap 5: Audit & Kompilasi
1. Jalankan `laporan_doctor` → pastikan `missing_keys: 0`, `broken_images: 0`.
2. Jalankan `laporan_build` → hasilkan `Laporan.pdf` (Typst) dan `Laporan.docx` (Word).

--------------------------------------------------------------------------------

## 4. Guardrail Sintaks

| Elemen | Sintaks Benar | Hindari |
| :--- | :--- | :--- |
| Simbol & mata uang | `\$100` atau `100 USD` | `$100` tanpa escape |
| Rumus | Inline `$E = m c^2$`; blok `$$...$$` | `$` tanpa escape berlebih |
| Gambar | `![Diagram](gambar/arsitektur.png)` | path absolut/berkas tidak ada |
| Tabel | Tabel pipe Markdown | karakter box-drawing (┌ ─ └ │) |
| Kode | Blok triple backtick + bahasa | kode Typst mentah |

--------------------------------------------------------------------------------

## 5. Troubleshooting

- **Pandoc/Typst tidak ada**: jalankan `npx laporan-generator setup`.
- **Sitasi "@key" tidak ditemukan**: jalankan `laporan_citations({ action: "validate" })`.
- **Daftar Isi Word**: `finalize-docx.py` otomatis menyusun tab leader dan perataan.
