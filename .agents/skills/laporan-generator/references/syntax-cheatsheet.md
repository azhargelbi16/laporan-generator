# Cheatsheet Sintaks Markdown Akademik (FAPERTA UNEJ)

Panduan sintaks Markdown untuk pipeline **Laporan Generator** (Typst PDF dan
Microsoft Word DOCX), mengikuti PPKI FAPERTA Universitas Jember.

---

## 1. Sitasi & Bibliografi (APA 6th)

Daftar pustaka dikelola via `references.bib`; format memakai **APA 6th edition** (`apa.csl`).

| Sintaks Markdown | Hasil | Keterangan |
|---|---|---|
| `[@addy2012characterization]` | (Addy dkk., 2012) | Sitasi tanda kurung |
| `@salisbury1995plant menyatakan...` | Salisbury dan Ross (1995) menyatakan... | Sitasi naratif |
| `[-@hardjowigeno2010ilmu]` | (2010) | Hanya tahun |
| `[@addy2012characterization, hal. 45]` | (Addy dkk., 2012, hal. 45) | Dengan halaman |
| `[@hardjowigeno2010ilmu; @soepardi1983sifat]` | (Hardjowigeno, 2010; Soepardi, 1983) | Multi-sitasi |

> Gaya selingkung FAPERTA: "dan" atau "&" untuk dua penulis; "dkk." atau "et al."
> (konsisten) untuk lebih dari dua penulis.

---

## 2. Struktur Heading & Penomoran Bab

Tulis heading TANPA angka manual. Mesin menomori otomatis.

```markdown
# PENDAHULUAN
Menjadi "BAB 1. PENDAHULUAN" (default) atau "BAB I PENDAHULUAN" (opsi Romawi).

## Latar Belakang
Menjadi "1.1. Latar Belakang".

### Identifikasi Masalah
Menjadi "1.1.1 Identifikasi Masalah".

# PRAKATA {-}
Gunakan `{-}` atau `{.unnumbered}` untuk bagian tanpa nomor bab.
```

---

## 3. Gambar

Simpan berkas di folder `gambar/`:

```markdown
![Diagram alir pengendalian hama](gambar/diagram-alur.png)
```

* Menjadi `Gambar 1.1. Diagram alir pengendalian hama` (nomor bab otomatis).
* Format: `.png`, `.jpg`, `.jpeg`, `.webp`. Caption Sentence case, di bawah gambar.
* Sertakan sumber bila bukan karya sendiri: `(Sumber: ...)`.

---

## 4. Tabel

Format Pipe Table standar Pandoc:

```markdown
| Perlakuan | Kejadian Penyakit (%) | Kriteria Ketahanan |
|:---|:---:|:---|
| Kontrol + | 100 | Rentan |
| As (H-7) | 33,33 | Medium Tahan |
```

* Caption `Tabel 1.1.` di atas tabel (Sentence case, diakhiri tanpa titik).
* Sel berupa frasa ditulis lower case tanpa tanda titik.

---

## 5. Persamaan Matematika

* Inline: `$f(x) = \frac{1}{1 + e^{-x}}$`
* Blok:
  ```markdown
  $$
  n_i = \frac{N_i}{N} \times 100\%
  $$
  ```
  Persamaan blok dinomori indeks bab, misalnya `(1.1)`.

---

## 6. Blok Kode & Listing

```markdown
```python
def hitung_akurasi(y_true, y_pred):
    return sum(t == p for t, p in zip(y_true, y_pred)) / len(y_true)
```
```

---

## 7. Catatan Kaki & Kutipan Langsung

* Kutipan blok:
  ```markdown
  > "Kutipan langsung lebih dari empat baris ditulis dengan spasi tunggal..."
  ```
* Catatan kaki:
  ```markdown
  Teks dengan catatan kaki[^catatan].

  [^catatan]: Isi catatan kaki.
  ```

---

## 8. Tips Kompatibilitas

1. **Hindari karakter box-drawing** (`├──`, `└──`, `│`).
2. **Jangan mengetik angka bab manual** (`## 1.1 Latar Belakang` → ganda).
3. **Nama berkas gambar tanpa spasi** (`diagram-alur.png`).
