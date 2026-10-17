# Panduan Arsitektur Template Typst (template.typ)

File `template.typ` adalah inti pemformatan visual PDF. Template ini mengikuti
Buku Pedoman Penulisan Karya Tulis Ilmiah (PPKI) FAPERTA Universitas Jember.

> **Catatan**: Pipeline utama memakai **Typst** (`template.typ`).

---

## Desain Arsitektur & Pemilihan Font

### 1. Pemilihan Font
* PPKI FAPERTA mewajibkan **Times New Roman 12 pt**.
* Template memakai `font_family` dari preset (default `Times New Roman`) dengan
  `font_fallback` ke **Libertinus Serif** bila font sistem tidak tersedia.
* Blok kode memakai **DejaVu Sans Mono** (font bawaan Typst).

### 2. Pengaturan Margin & Spacing
```typst
#let doc-margin = (
  top: 4cm, bottom: 3cm, left: 4cm, right: 3cm,   // dari preset
)
#set page(paper: "a4", margin: doc-margin)
#set par(justify: true, leading: 0.9em, first-line-indent: 1cm)
```
* Margin mengikuti **preset aktual** (`margin_top/bottom/left/right`), bukan hardcode.
* Indentasi paragraf 1 cm; paragraf rata kanan-kiri.

---

## Penomoran Bab dan Halaman

### 1. Format Bab & Heading
```typst
#set heading(numbering: (..ns) => {
  if ns.len() == 1 { "BAB " + numbering("1", ns.at(0)) + "." }  // BAB 1.
  else if ns.len() == 2 { numbering("1.1.", ..ns) }             // 1.1.
  else { numbering("1.1.1", ..ns) }                             // 1.1.1
})
```
* **Bab**: default angka Arab + titik (`BAB 1.`), opsi Romawi (`BAB I`) via
  `heading_chapter_num_format` di preset.
* **Subbab**: `1.1.` (tebal). **Subsubbab**: `1.1.1` (tidak tebal).
* **Heading tanpa nomor** (Prakata, Daftar Isi, Daftar Pustaka): gunakan `{-}`.

### 2. Penomoran Halaman (front matter vs batang tubuh)
* **Bagian awal**: Romawi kecil (`i, ii, iii`) di tengah bawah.
  ```typst
  #set page(numbering: "i", number-align: bottom + center)
  ```
* **Bagian utama**: angka Arab (`1, 2, 3`) di kanan atas, di-reset per bab.
  ```typst
  #set page(numbering: "1", number-align: right + top)
  #counter(page).update(1)
  ```

---

## Halaman Sampul (Cover)

Dirender dari `metadata.yml`: `title`, `subtitle`, `jenis_karya`, `course`,
`lecturer`, `author[]`, `program_studi`, `faculty`, `institution`, `year`, `logo`.

---

## Pemrosesan Elemen Konten

### 1. Tabel
```typst
#set table(stroke: 0.5pt + luma(140), inset: 4pt)
#show table.header: set text(weight: "bold")
```
* Garis tabel tipis; header tebal. Caption `Tabel 1.1.` di atas (Sentence case).

### 2. Gambar
* Caption `Gambar 1.1.` di bawah gambar.
* PNG dinormalisasi saluran alfa oleh ImageMagick di `build.sh` sebelum kompilasi.

### 3. Blok Kode
```typst
#show raw.where(block: true): set text(font: "DejaVu Sans Mono", size: 9pt)
```
