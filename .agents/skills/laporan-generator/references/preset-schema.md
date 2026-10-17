# Spesifikasi Skema Preset Format (Preset Schema)

Berkas preset disimpan di `presets/<preset-id>.yml` dan mendefinisikan tata
letak, tipografi, gaya penomoran heading, serta sampul untuk output PDF (Typst)
dan Word (DOCX).

Proyek ini menyediakan satu preset: **`unej-faperta`** (FAPERTA Universitas Jember).

---

## Contoh Lengkap (presets/unej-faperta.yml)

```yaml
preset_id: "unej-faperta"
name: "Universitas Jember - Fakultas Pertanian"
description: "Format penulisan karya tulis ilmiah S1 FAPERTA UNEJ."

# 1. Geometri & Margin Halaman
margin_top: 4cm
margin_bottom: 3cm
margin_left: 4cm
margin_right: 3cm

# 2. Tipografi & Spasi
font_family: "Times New Roman"
font_fallback: "Libertinus Serif"
font_size: 12pt
line_spacing: 1.5
first_line_indent: 1cm

# 3. Penomoran Heading
heading_chapter_prefix: "BAB "
heading_chapter_num_format: "arabic"   # "arabic" (BAB 1.) atau "roman" (BAB I)
heading_chapter_dot: true
heading_sub_dot: true                  # "1.1." vs "1.1"
heading_subsub_dot: false              # "1.1.1" vs "1.1.1."
heading_subsub_bold: false             # subsubbab tidak dicetak tebal

# 4. Nomor Halaman
page_number_front: "i"
page_number_front_position: "bottom-center"
page_number_body_position: "top-right"
page_number_chapter_first_position: "bottom-center"

# 5. Sampul
cover_show_lecturer: true
cover_logo_width: 5cm
cover_logo_height: 5cm

# 6. Sitasi
citation_style: "apa-7th"
```

---

## Daftar Field

| Kategori | Field | Tipe | Default | Keterangan |
|---|---|---|---|---|
| Identitas | `preset_id` | String | nama berkas | ID unik preset |
| | `name` | String | - | Nama institusi |
| | `description` | String | - | Penjelasan singkat |
| Margin | `margin_top` | Satuan | `4cm` | Pias atas |
| | `margin_bottom` | Satuan | `3cm` | Pias bawah |
| | `margin_left` | Satuan | `4cm` | Pias kiri |
| | `margin_right` | Satuan | `3cm` | Pias kanan |
| Tipografi | `font_family` | String | `Times New Roman` | Font utama |
| | `font_fallback` | String | `Libertinus Serif` | Font cadangan |
| | `font_size` | pt | `12pt` | Ukuran teks isi |
| | `line_spacing` | Angka | `1.5` | Spasi baris |
| | `first_line_indent` | cm | `1cm` | Indentasi paragraf |
| Heading | `heading_chapter_prefix` | String | `BAB ` | Awalan bab |
| | `heading_chapter_num_format` | `arabic`/`roman` | `arabic` | Format nomor bab |
| | `heading_chapter_dot` | Boolean | `true` | Titik setelah nomor bab |
| | `heading_sub_dot` | Boolean | `true` | Titik setelah nomor subbab |
| | `heading_subsub_dot` | Boolean | `false` | Titik setelah nomor subsubbab |
| | `heading_subsub_bold` | Boolean | `false` | Bold pada subsubbab |
| Halaman | `page_number_front_position` | String | `bottom-center` | Posisi nomor bagian awal |
| | `page_number_body_position` | String | `top-right` | Posisi nomor bagian utama |
| Sampul | `cover_show_lecturer` | Boolean | `true` | Tampilkan dosen di sampul |
| | `cover_logo_width` | cm | `5cm` | Lebar logo (wajib 5cm) |
| | `cover_logo_height` | cm | `5cm` | Tinggi logo (wajib 5cm) |
| Sitasi | `citation_style` | String | `apa-7th` | Gaya sitasi |

---

## Cara Menggunakan Preset

```yaml
# metadata.yml
preset: "unej-faperta"
```

Validasi:
```bash
./laporan preset validate unej-faperta
```
