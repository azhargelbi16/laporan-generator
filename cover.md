# PRAKATA {-}

Puji syukur kehadirat Tuhan Yang Maha Esa atas segala rahmat dan karunia-Nya sehingga penulis dapat menyelesaikan karya tulis ilmiah yang berjudul **RESPON PERTUMBUHAN TANAMAN JAGUNG (*Zea mays* L.) TERHADAP PEMBERIAN PUPUK ORGANIK CAIR** dengan baik dan tepat waktu.

Karya tulis ilmiah ini disusun untuk memenuhi salah satu persyaratan menyelesaikan pendidikan pada Program Studi Agroteknologi, Fakultas Pertanian, Universitas Jember. Pada kesempatan ini penulis menyampaikan terima kasih kepada:

1. Ir. Nama Dosen Pembimbing, M.P., selaku dosen pembimbing yang telah memberikan bimbingan dan arahan pada penyusunan karya tulis ilmiah ini.
2. Seluruh pihak yang telah membantu kelancaran penulisan karya tulis ilmiah ini.

Penulis menyadari bahwa karya tulis ilmiah ini masih memiliki kekurangan. Oleh karena itu, kritik dan saran yang membangun sangat diharapkan demi perbaikan di masa mendatang. Semoga karya tulis ilmiah ini dapat memberikan manfaat bagi pembaca.

```{=typst}
#v(0.8cm)
#align(right)[
  Jember, Juni 2026

  #v(1cm)
  Penulis
]
#pagebreak()
#outline(
  title: [#align(center)[#text(size: 12pt, weight: "bold")[DAFTAR ISI]]],
  depth: 3,
)
#context {
  if opt-daftar-gambar {
    let imgs = query(figure.where(kind: image))
    if imgs.len() > 0 {
      pagebreak()
      outline(
        title: align(center)[#text(size: 12pt, weight: "bold")[DAFTAR GAMBAR]],
        target: figure.where(kind: image),
      )
    }
  }
  if opt-daftar-tabel {
    let tbls = query(figure.where(kind: table))
    if tbls.len() > 0 {
      pagebreak()
      outline(
        title: align(center)[#text(size: 12pt, weight: "bold")[DAFTAR TABEL]],
        target: figure.where(kind: table),
      )
    }
  }
}
```

```{=typst}
// --- Transisi ke bagian utama: nomor Arab (1, 2, 3...) di kanan atas.
// Berlaku untuk seluruh konten setelah blok ini (batang tubuh bab).
#set page(numbering: "1", number-align: top + right)
#counter(page).update(1)
```

```{=openxml}
<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="454"/></w:pPr><w:r><w:t>Jember, Juni 2026</w:t></w:r></w:p>
<w:p><w:pPr><w:jc w:val="right"/><w:spacing w:before="567"/></w:pPr><w:r><w:t>Penulis</w:t></w:r></w:p>
```
