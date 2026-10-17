# Panduan Format Penulisan FAPERTA Universitas Jember

Dokumen ini merangkum aturan format karya tulis ilmiah tingkat **S1** di
Fakultas Pertanian Universitas Jember berdasarkan Buku Pedoman Penulisan Karya
Tulis Ilmiah (PPKI) FAPERTA UNEJ (SK Dekan No. 5705/UN25.1.3/KP.8/2021).

Proyek ini hanya menyediakan satu preset: **`unej-faperta`**.

---

## 1. Mengaktifkan Preset

Pada `metadata.yml`:
```yaml
preset: "unej-faperta"
```

Atau via CLI:
```bash
./laporan preset show unej-faperta
./laporan preset apply unej-faperta
```

---

## 2. Ringkasan Aturan Format

| Aspek | Ketentuan |
|---|---|
| Kertas | A4 (21 × 29,7 cm), 80 gram |
| Margin | Atas 4 cm, Bawah 3 cm, Kiri 4 cm, Kanan 3 cm |
| Font | Times New Roman 12 pt (judul sampul 14 pt) |
| Indentasi | 1 cm dari pias kiri |
| Spasi baris | 1,5 |
| Judul bab | `BAB 1. JUDUL` (Arab + titik, default) / `BAB I JUDUL` (opsi Roman) |
| Subbab | `1.1. Judul Subbab` (tebal) |
| Subsubbab | `1.1.1 Judul Subsubbab` (tidak tebal) |
| Nomor halaman | Romawi kecil tengah-bawah (awal); Arab kanan-atas (utama) |
| Sitasi | APA 6th edition |

---

## 3. Mode Dokumen

Preset `unej-faperta` dipakai untuk semua jenis dokumen S1. Perbedaan struktur
diatur melalui field `mode` pada `metadata.yml`:

| Mode | Front Matter |
|---|---|
| `skripsi` | Sampul, Lembar Pengesahan, Ringkasan, Summary, Prakata, Daftar Isi/Tabel/Gambar |
| `laporan` | Sampul, Prakata/Kata Pengantar, Daftar Isi (+ Daftar Gambar/Tabel bila ada) |

---

## 4. Mengganti Logo

Salin logo resmi (mis. lambang Universitas Jember, 3 × 3 cm) ke direktori utama
dengan nama **`logo.jpg`**. Ukuran di sampul diatur melalui `cover_logo_width`
(default `3cm`).

---

## 5. Catatan

Aturan untuk jenjang Magister (Tesis) dan Doktor (Disertasi) tidak disertakan
dalam preset ini karena hanya menargetkan jenjang S1.
