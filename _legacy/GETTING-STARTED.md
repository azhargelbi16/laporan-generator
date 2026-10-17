# Panduan Memulai: Zero to PDF (Laporan Generator FAPERTA UNEJ)

Selamat datang! Dokumen ini membantu Anda -- baik pemula maupun berpengalaman --
menghasilkan karya tulis ilmiah S1 berstandar **PPKI FAPERTA Universitas Jember**
dalam bentuk PDF dan Microsoft Word dalam waktu singkat.

---

## Pilih Jalur yang Sesuai dengan Anda

| Jalur | Persyaratan | Cocok Untuk |
|---|---|---|
| **[1. Opsi AI Agent](#1-opsi-ai-agent-paling-cepat--otomatis)** | AI Agent (OpenCode, Claude Code, Antigravity) | Pemula yang ingin laporan dibuatkan otomatis |
| **[2. Opsi Docker](#2-opsi-docker-tanpa-install-tools-lokal)** | Docker Desktop | Pengguna yang tidak mau install Pandoc/Typst lokal |
| **[3. Opsi Manual (CLI)](#3-opsi-manual-cli-kompilasi-lokal)** | Pandoc + Typst + ImageMagick | Pengguna Linux/Mac/Windows yang biasa dengan CLI |

---

## 1. Opsi AI Agent (Paling Cepat & Otomatis)

```bash
# 1. Buka AI Agent (OpenCode, Claude Code, Antigravity) di folder project ini
# 2. Instruksikan:
"Baca prompt.md dan bantu saya menyusun skripsi/laporan FAPERTA UNEJ"
# 3. Jawab pertanyaan wawancara AI (jenis karya, mode, metadata)
# 4. AI menyusun chapters/*.md, metadata.yml, references.bib
# 5. Kompilasi:
.\laporan.ps1 build     # Windows
# atau
./laporan build         # Linux/macOS
```

---

## 2. Opsi Docker (Tanpa Install Tools Lokal)

Tidak perlu menginstall Pandoc, Typst, atau ImageMagick di komputer Anda. Semua dependensi sudah terkemas dalam container Docker terisolasi.

### Langkah-langkah:
1. Pastikan **Docker Desktop** sudah terinstall dan berjalan di komputer Anda. ([Download Docker](https://www.docker.com/products/docker-desktop/))
2. Buka terminal di dalam folder project ini.
3. Edit isi laporan manual di folder `chapters/` dan data di `metadata.yml`.
4. Jalankan perintah kompilasi:
   ```bash
   docker compose run --rm laporan-generator
   ```
5. File `Laporan.pdf` siap di folder project Anda!

> **Tips:** Gunakan `make docker-watch` untuk auto-rebuild otomatis setiap kali Anda menyimpan perubahan file markdown.

---

## 3. Opsi Manual CLI (Kompilasi Lokal)

Jika Anda lebih menyukai kompilasi cepat di mesin lokal Linux/macOS:

### Prasyarat System Packages:
* **Ubuntu/Debian**:
  ```bash
  sudo apt install pandoc imagemagick xz-utils
  wget -q https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz -O /tmp/typst.tar.xz
  tar -xJf /tmp/typst.tar.xz -C /tmp
  sudo mv /tmp/typst-x86_64-unknown-linux-musl/typst /usr/local/bin/
  ```
* **Arch Linux**:
  ```bash
  sudo pacman -S pandoc typst imagemagick
  ```
* **Nix / NixOS**:
  ```bash
  nix develop
  ```
* **Windows (PowerShell / Winget)**:
  ```powershell
  winget install JohnMacFarlane.Pandoc
  winget install Typst.Typst
  winget install ImageMagick.ImageMagick
  ```

### Jalankan Build:

**Linux / macOS:**
```bash
# Inisialisasi git hooks (opsional)
make init

# Build PDF (atau ./laporan build)
make build

# Export Word (.docx)
make docx

# Buka PDF di viewer
make view
```

**Windows (PowerShell):**
```powershell
# Cek dependensi & berkas
.\laporan.ps1 check

# Build PDF
.\laporan.ps1 build

# Buka PDF di viewer
.\laporan.ps1 view
```

---

## Glosarium Istilah Teknis

* **Pandoc**: Program pengubah format dokumen (Markdown → Typst/PDF/Word).
* **Typst**: Engine typesetting dokumen modern, cepat, dan ringan.
* **BibTeX**: Format standar penyimpanan referensi akademik (`references.bib`).
* **CSL (Citation Style Language)**: Berkas aturan sitasi (proyek ini memakai **APA 6th edition**).
* **PAGEREF DOCX**: Mekanisme penomoran halaman otomatis pada Daftar Isi Word.

---

## FAQ & Troubleshooting Singkat

* **Q: Mengapa penomoran bab menjadi ganda seperti "BAB 1. BAB 1"?**
  *A:* Di `chapters/bab*.md`, gunakan heading `# Judul Bab` tanpa "BAB 1." —
  template menambahkan nomor bab otomatis.

* **Q: Bagaimana cara menambahkan gambar?**
  *A:* Simpan di folder `gambar/` lalu panggil `![](gambar/nama-file.png)`.

* **Q: Bagaimana format sitasi yang benar?**
  *A:* Masukkan entri BibTeX di `references.bib`, lalu panggil `[@citekey]`.
  Gaya sitasi mengikuti APA 6th edition.

* **Q: Bagaimana jika pedoman FAPERTA berubah?**
  *A:* Sesuaikan parameter di `presets/unej-faperta.yml` (margin, spasi, format
  heading) lalu validasi dengan `./laporan preset validate unej-faperta`.

---

Untuk panduan lebih mendalam, silakan baca dokumentasi di folder `docs/`:
- [docs/campus-guide.md](docs/campus-guide.md)
- [docs/preset-schema.md](docs/preset-schema.md)
- [docs/metadata-schema.md](docs/metadata-schema.md)
- [docs/template-guide.md](docs/template-guide.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
