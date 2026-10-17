# laporan-generator (v3, alur DOCX-only)

Pipeline lokal untuk membuat laporan akademik dalam format **DOCX saja**,
dijalankan dari **Windows PowerShell**. Dua database menjadi input:

- `templates/`  : database template laporan (`praktikum`, `tugas-dosen`; tiap
  template = `reference.docx` + `struktur.md` + `metadata.yml`)
- `sources/`    : database sumber (`pdf/*.pdf` + `references.bib` sebagai
  satu-satunya sumber sitasi sah)

Alur: pilih template & sumber -> ekstraksi teks PDF (pdftotext) -> potong
teks per-bagian (chunking) -> dirangkum AI menjadi `chapters/bab*.md`
sesuai struktur template -> validasi sitasi terhadap `references.bib` ->
Pandoc (`--reference-doc` + `docx.lua` + citeproc APA) ->
**`output/<nama>.docx`**.

Jalur PDF/Typst, CLI npm, Docker, dan docs lama ada di `_legacy/`.
Format FAPERTA UNEJ (margin, Times New Roman, heading bab bernomor,
logo kampus 5 cm x 5 cm, sitasi **APA 7th**) tetap berlaku lewat
`reference.docx`, `docx.lua`, `presets/unej-faperta.yml`, dan `apa.csl`.

## Pemakaian

```powershell
.\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2   # penuh dengan AI
.\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2 -OutFile "laporan-praktikum-jagung"
.\laporan.ps1 build -Template tugas-dosen -Sources contoh-jurnal # penuh dengan AI
.\laporan.ps1 build -Template praktikum -NoAi                    # kerangka [perlu diisi] tanpa AI
.\laporan.ps1 build -Template praktikum -Sources contoh-jurnal -Bab 1  # tulis ulang bab 1 saja
.\laporan.ps1 docx -Template praktikum -OutFile "laporan-final"  # kompilasi ulang dari chapters/
.\laporan.ps1 check    # cek dependensi, template, sumber, validasi sitasi
.\laporan.ps1 list     # daftar template & sumber
.\laporan.ps1 clean    # hapus chapters/bab*.md, cache, tmp (output/ tetap)
```

Semua hasil build disimpan di **`output/`** supaya tidak bercampur dengan
berkas pipeline. Nama berkas bisa dipilih sendiri lewat `-OutFile`
(alias `-Nama`); tanpa `-OutFile` hasilnya `output/Laporan.docx`.
Ekstensi `.docx` ditambahkan otomatis, dan path seperti
`-OutFile "arsip/laporan-jagung"` juga diterima.

Nama sumber = nama berkas PDF tanpa ekstensi di `sources/pdf/`
(contoh `-Sources contoh-jurnal` -> `sources/pdf/contoh-jurnal.pdf`).

## Konfigurasi AI (`ai-config.json`)

- `command`: baris perintah yang dipanggil skrip; placeholder
  `{prompt_file}` diganti path berkas prompt (aman untuk teks panjang).
  Default `["hermes","chat","--query-file","{prompt_file}","-Q"]` =
  Hermes non-interaktif, mengikuti model/provider profil Hermes aktif
  (teks sumber terkirim ke layanan model tersebut). Bisa diganti CLI AI
  lain, mis. `["ollama","run","qwen3"]`.
- `enabled: false` atau switch `-NoAi`: bab dibuat sebagai kerangka
  `[perlu diisi]` tanpa memanggil layanan apa pun.
- `chunk_chars` / `chunk_overlap` / `max_chunks_per_call`: pemotongan teks
  sumber agar tidak melebihi konteks model.

## Aturan sitasi (dipaksakan skrip)

- Sitasi hanya boleh citekey yang ada di `sources/references.bib`.
  Sitasi lain otomatis diganti `*[perlu diisi: sitasi ... tidak ada di
  references.bib]*` (lihat `.\laporan.ps1 check` tahap 5).
- Informasi yang tidak ada di sumber ditulis `[perlu diisi]`; AI dilarang
  mengarang penulis/tahun/angka/kutipan (juga diperintahkan demikian di
  prompt).

## Struktur repo (aktif)

```
laporan.ps1            pipeline utama (satu-satunya perintah)
ai-config.json         konfigurasi tahap AI
templates/<nama>/      reference.docx + struktur.md + metadata.yml
sources/pdf/           PDF sumber; sources/references.bib; sources/extracted/ (cache)
chapters/              bab hasil AI (bab1-*.md dst., ditulis ulang saat build)
output/                DOCX hasil build (nama dipilih via -OutFile; default Laporan.docx)
docx.lua, apa.csl      filter & gaya sitasi pandoc (APA 7th)
cover.md, logo.jpg, metadata.yml, presets/   data halaman depan (metadata.yml root
                       menimpa metadata template)
scripts/               finalize-docx.py, docx-pagenum.py (pasca-proses penomoran)
_legacy/               semua alur lama (PDF/Typst, npm CLI, Docker, docs)
```

## Dependensi

| Alat       | Wajib | Cek versi                |
|------------|-------|--------------------------|
| Pandoc     | ya    | `pandoc --version`       |
| pdftotext (Poppler) | untuk `-Sources` | `pdftotext -v` |
| Python 3   | opsional (penomoran halaman) | `python --version` |
| Hermes CLI | opsional (tahap AI default)  | `hermes --version` |

Catatan: pdftotext tersedia otomatis bila Git for Windows terpasang
(`<Git>\mingw64\bin`); skrip juga mencarinya di PATH dan di sana.

## Keterbatasan

- PDF hasil scan (gambar) tidak terbaca pdftotext -- perlu OCR dulu.
  Skrip memberi peringatan bila hasil ekstraksi hampir kosong.
- `docx-pagenum.py` butuh LibreOffice (`soffice`) untuk mengisi nomor
  halaman daftar isi; tanpa itu field tetap diperbarui Word saat dibuka.
- Teks sumber dikirim ke layanan model pada provider Hermes aktif saat
  tahap AI aktif; pakai `-NoAi` bila tidak ingin itu.
- `metadata.yml` root masih memuat judul skripsi Anda dan menimpa judul
  template - ubah `title` (dan `jenis_karya`) di `metadata.yml` bila
  berganti jenis laporan.
