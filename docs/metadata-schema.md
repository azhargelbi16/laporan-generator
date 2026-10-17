# Spesifikasi Skema Metadata (metadata.yml)

`metadata.yml` mengendalikan informasi sampul, identitas penyusun, pembimbing,
mode dokumen, dan komponen halaman depan. Dipakai oleh Pandoc, `template.typ`,
dan `docx.lua`.

---

## Contoh Lengkap

```yaml
---
title: "RESPON PERTUMBUHAN TANAMAN JAGUNG (Zea mays L.) TERHADAP PUPUK ORGANIK CAIR"
subtitle: ""
jenis_karya: "SKRIPSI"
mode: "skripsi"            # "skripsi" | "laporan"

author:
  - name: "Nama Mahasiswa"
    nim: "251510501059"

lecturer: "Ir. Nama Dosen Pembimbing, M.P."
lecturer_label: "Dosen Pembimbing:"
course: ""

program_studi: "Program Studi Agroteknologi"
faculty: "Fakultas Pertanian"
institution: "Universitas Jember"
year: "2026"
date: "Juni 2026"

preset: "unej-faperta"

daftar_gambar: false
daftar_tabel: false
daftar_lampiran: false

# abstract_id: |
#   Ringkasan dalam Bahasa Indonesia (maks. 600 kata)...
# keywords_id:
#   - kata kunci 1
# abstract_en: |
#   Summary in English...
# keywords_en:
#   - keyword 1

# approval:
#   hari_tanggal: "Rabu, 15 April 2026"
#   supervisors:
#     - name: "Ir. Nama Pembimbing, M.P."
#       nip: "197501012000031001"
#       role: "Dosen Pembimbing Skripsi"
#   dean:
#     name: "Prof. Dr. Ir. Nama Dekan, M.P."
#     nip: "196403041989021001"
#     role: "Dekan"
...
```

---

## Penjelasan Field

| Field | Tipe | Wajib | Keterangan |
|---|---|---|---|
| `title` | String | Ya | Judul karya tulis (KAPITAL, bukan kalimat) |
| `subtitle` | String | Tidak | Subjudul / anak judul |
| `jenis_karya` | String | Ya | `SKRIPSI`, nama laporan, dsb. |
| `mode` | String | Ya | `skripsi` (front matter lengkap) atau `laporan` |
| `author` | List | Ya | Daftar penulis (`name`, `nim`) |
| `lecturer` | String | Ya | Nama dosen pembimbing/pengampu + gelar |
| `lecturer_label` | String | Tidak | Label dosen (default "Dosen Pengampu:") |
| `course` | String | Tidak | Nama mata kuliah (untuk laporan kuliah) |
| `program_studi` | String | Ya | Program studi |
| `faculty` | String | Ya | Fakultas (Fakultas Pertanian) |
| `institution` | String | Ya | Universitas Jember |
| `year` | String | Ya | Tahun lulus (mis. `2026`) |
| `date` | String | Tidak | Bulan/tahun (mis. `Juni 2026`) |
| `preset` | String | Ya | `unej-faperta` |
| `daftar_gambar` | Boolean | Tidak | Aktifkan halaman DAFTAR GAMBAR |
| `daftar_tabel` | Boolean | Tidak | Aktifkan halaman DAFTAR TABEL |
| `daftar_lampiran` | Boolean | Tidak | Aktifkan halaman DAFTAR LAMPIRAN |
| `abstract_id` | Multiline | Tidak | Ringkasan Bahasa Indonesia |
| `abstract_en` | Multiline | Tidak | Summary Bahasa Inggris |
| `keywords_id` / `keywords_en` | List | Tidak | Kata kunci |
| `approval` | Object | Tidak | Lembar pengesahan (mode skripsi) |

---

## Multi-Author

```yaml
author:
  - name: "Mahasiswa A"
    nim: "251510501059"
  - name: "Mahasiswa B"
    nim: "251510501060"
```
