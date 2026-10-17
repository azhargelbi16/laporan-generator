// ============================================================================
// template.typ — Template Typst untuk Laporan Akademik S1 FAPERTA UNEJ
// Mengacu pada Pedoman Penulisan Karya Tulis Ilmiah (PPKI) FAPERTA UNEJ.
// Layout: A4, margin 4-3-4-3 cm, Times New Roman 12pt, spasi 1.5,
// heading "BAB 1. JUDUL" (arabic) / "1.1. Judul" / "1.1.1 Judul" (non-bold).
// ============================================================================

#set document(
  title: "$title$",
  author: ($for(author)$"$author.name$"$sep$,$endfor$),
)

// --- Margin: dibaca langsung dari preset (fix: tidak lagi hardcode margin_preset)
$if(margin_top)$
#let doc-margin = (
  top: $margin_top$,
  bottom: $margin_bottom$,
  left: $margin_left$,
  right: $margin_right$,
)
$else$
#let doc-margin = (
  top: 4cm,
  bottom: 3cm,
  left: 4cm,
  right: 3cm,
)
$endif$

#let front-position = "$if(page_number_front_position)$$page_number_front_position$$else$bottom-center$endif$"
#let body-position = "$if(page_number_body_position)$$page_number_body_position$$else$top-right$endif$"

#let position-to-align = (pos) => {
  if pos == "bottom-center" or pos == "top-center" {
    center
  } else if pos == "top-right" {
    right
  } else if pos == "top-left" {
    left
  } else {
    right
  }
}

// --- Pengaturan halaman dasar: front matter Romawi kecil, bawah tengah.
// Bagian utama (Arab, kanan atas) di-set pada aturan heading level 1.
#set page(
  paper: "a4",
  margin: doc-margin,
  numbering: "i",
  number-align: bottom + center,
)

$if(font_family)$
#let base-font = "$font_family$"
$else$
#let base-font = "Times New Roman"
$endif$
$if(font_fallback)$
#let fallback-font = "$font_fallback$"
#set text(font: (base-font, fallback-font), size: $if(font_size)$$font_size$$else$12pt$endif$)
$else$
#set text(font: base-font, size: $if(font_size)$$font_size$$else$12pt$endif$)
$endif$

// --- Spasi baris 1.5 (Typst: leading dalam em mengikuti font size)
#set par(
  justify: true,
  leading: 0.9em,
  first-line-indent: $if(first_line_indent)$$first_line_indent$$else$1cm$endif$,
)
#show bibliography: set par(hanging-indent: $if(first_line_indent)$$first_line_indent$$else$1cm$endif$, first-line-indent: 0cm)

// --- Konfigurasi penomoran bab dari preset
#let raw-prefix = "$if(heading_chapter_prefix)$$heading_chapter_prefix$$else$BAB $endif$"
#let chapter-prefix = if raw-prefix == "" {
  ""
} else if raw-prefix.ends-with(" ") {
  raw-prefix
} else {
  raw-prefix + " "
}
#let chapter-fmt = "$if(heading_chapter_num_format)$$heading_chapter_num_format$$else$arabic$endif$"
#let chapter-dot = "$if(heading_chapter_dot)$$heading_chapter_dot$$else$true$endif$" == "true"
#let sub-dot = "$if(heading_sub_dot)$$heading_sub_dot$$else$true$endif$" == "true"
#let subsub-dot = "$if(heading_subsub_dot)$$heading_subsub_dot$$else$false$endif$" == "true"
#let subsub-bold = "$if(heading_subsub_bold)$$heading_subsub_bold$$else$false$endif$" == "true"

#let format-chapter-num(n) = {
  if chapter-fmt == "roman" {
    numbering("I", n)
  } else {
    numbering("1", n)
  }
}

// --- Format penomoran heading berjenjang
#set heading(numbering: (..ns) => {
  if ns.len() == 1 {
    let base = if chapter-prefix != "" {
      chapter-prefix + format-chapter-num(ns.at(0))
    } else {
      format-chapter-num(ns.at(0))
    }
    if chapter-dot { base + "." } else { base }
  } else if ns.len() == 2 {
    numbering("1.1" + if sub-dot { "." } else { "" }, ..ns)
  } else {
    numbering("1.1.1" + if subsub-dot { "." } else { "" }, ..ns)
  }
})

// --- Penomoran ilustrasi mengikat nomor bab (Gambar 1.1, Tabel 2.3)
#show figure.where(kind: image): set figure(
  supplement: [Gambar],
  numbering: it => {
    let ch = counter(heading).get().at(0, default: 1)
    str(ch) + "." + str(it)
  }
)
#show figure.where(kind: table): set figure(
  supplement: [Tabel],
  numbering: it => {
    let ch = counter(heading).get().at(0, default: 1)
    str(ch) + "." + str(it)
  }
)
#show figure.where(kind: raw): set figure(
  supplement: [Listing],
  numbering: it => {
    let ch = counter(heading).get().at(0, default: 1)
    str(ch) + "." + str(it)
  }
)
#set math.equation(numbering: it => "(" + str(counter(heading).get().at(0, default: 1)) + "." + str(it) + ")")

// --- Heading level 1: halaman baru, kapital bold, tengah, reset counter
#show heading.where(level: 1): it => {
  counter(figure.where(kind: image)).update(0)
  counter(figure.where(kind: table)).update(0)
  counter(figure.where(kind: raw)).update(0)
  counter(math.equation).update(0)
  pagebreak(weak: true)

  align(center)[
    #block(inset: (top: 0.5em, bottom: 1.8em))[
      #text(size: 12pt, weight: "bold")[
        #if it.numbering != none [
          #context {
            let n = counter(heading).get().at(0)
            let base = if chapter-prefix != "" {
              chapter-prefix + format-chapter-num(n)
            } else {
              format-chapter-num(n)
            }
            if chapter-dot { base + "." } else { base }
            linebreak()
          }
          #if it.body.has("text") [
            #upper(it.body.text)
          ] else [
            #upper(it.body)
          ]
        ] else [
          #it.body
        ]
      ]
    ]
  ]
}

// --- Heading level 2: subbab, kiri, bold, Title Case (nomor + titik)
#show heading.where(level: 2): it => {
  block(above: 1.2em, below: 0.6em)[
    #text(size: 12pt, weight: "bold")[#it]
  ]
}

// --- Heading level 3: subsubbab, kiri, non-bold (default), Title Case
#show heading.where(level: 3): it => {
  block(above: 1.0em, below: 0.5em)[
    #text(size: 12pt, weight: if subsub-bold { "bold" } else { "regular" })[#it]
  ]
}

#show figure: it => it + par[]
#show list: it => it + par[]
#show enum: it => it + par[]
#show quote: it => {
  block(
    fill: rgb("#f3f4f6"),
    stroke: (left: 3.5pt + rgb("#2563eb")),
    inset: (x: 12pt, y: 8pt),
    radius: (right: 4pt),
    width: 100%,
  )[
    #set text(size: 10.5pt, style: "italic")
    #set par(justify: true, leading: 0.65em)
    #it.body
  ]
}
#show table: it => it + par[]
#show raw.where(block: true): it => {
  block(
    fill: rgb("#f8f9fa"),
    stroke: 0.5pt + rgb("#d1d5db"),
    inset: (x: 10pt, y: 8pt),
    radius: 4pt,
    width: 100%,
  )[
    #set text(font: "DejaVu Sans Mono", size: 8.5pt)
    #set par(justify: false, leading: 0.55em)
    #it
  ]
}

#show outline.entry.where(level: 1): set text(weight: "bold")

// --- Pemisah judul menjadi baris seimbang (segitiga terbalik)
#let balance-split(title, k) = {
  let words = title.split(" ")
  let n = words.len()
  if n <= 1 {
    return (title,)
  }
  if n <= k {
    return words
  }
  let single-count = lines => lines.map(l => if l.split(" ").len() <= 1 { 1 } else { 0 }).sum()
  let candidates = ()
  if k == 2 {
    for c in range(1, n) {
      let line1 = words.slice(0, c).join(" ")
      let line2 = words.slice(c, n).join(" ")
      let mx = calc.max(line1.len(), line2.len())
      candidates = candidates + (
        (mx + 100 * single-count((line1, line2)), (line1, line2)),
      )
    }
  } else if k == 3 {
    for c1 in range(1, n - 1) {
      for c2 in range(c1 + 1, n) {
        let line1 = words.slice(0, c1).join(" ")
        let line2 = words.slice(c1, c2).join(" ")
        let line3 = words.slice(c2, n).join(" ")
        let mx = calc.max(line1.len(), line2.len(), line3.len())
        candidates = candidates + (
          (mx + 100 * single-count((line1, line2, line3)), (line1, line2, line3)),
        )
      }
    }
  }
  let best = candidates.at(0)
  for cand in candidates {
    if cand.at(0) < best.at(0) {
      best = cand
    }
  }
  best.at(1)
}

#let title-lines = layout(size => {
  let t = upper("$title$".replace("\n", " ").replace("\r", " "))
  let lines = if measure(text(t, size: 14pt, weight: "bold")).width <= size.width {
    (t,)
  } else {
    let two = balance-split(t, 2)
    let w-two = two.map(l => measure(text(l, size: 14pt, weight: "bold")).width)
      .fold(0pt, calc.max)
    let orphan = two.any(l => l.split(" ").len() <= 1)
    if (not orphan) and w-two <= size.width {
      two
    } else {
      balance-split(t, 3)
    }
  }
  let out = ()
  for i in range(lines.len()) {
    if i > 0 {
      out.push(linebreak())
    }
    out.push(lines.at(i))
  }
  out.join()
})

#set table(stroke: 0.5pt + luma(140), inset: 4pt)
#show table.header: set text(weight: "bold")
#set figure.caption(position: bottom)
#show raw.where(block: true): set text(font: "DejaVu Sans Mono", size: 9pt)

// ============================================================================
// HALAMAN SAMPUL
// ============================================================================
#v(1cm)
#align(center)[
  #text(size: 14pt, weight: "bold")[#title-lines]
]
$if(subtitle)$
#v(0.3cm)
#align(center)[
  #text(size: 14pt, weight: "bold")[#upper("$subtitle$".replace("\n", " "))]
]
$endif$
$if(jenis_karya)$
#v(0.8cm)
#align(center)[
  #text(size: 12pt, weight: "bold")[#upper("$jenis_karya$")]
]
$endif$
$if(course)$
#v(0.5cm)
#align(center)[
  #text(size: 12pt)[#emph("$course$")]
]
$endif$
$if(lecturer)$
#let hide-lecturer = ("$cover_hide_lecturer$" == "true" or "$cover_show_lecturer$" == "false")
#if not hide-lecturer [
  #v(0.4cm)
  #align(center)[
    #text(size: 11pt)[$if(lecturer_label)$$lecturer_label$$else$Dosen Pengampu:$endif$]
    #linebreak()
    #text(size: 12pt, weight: "bold")[$lecturer$]
  ]
]
$endif$

#v(1fr)
#align(center)[
  #image("logo.jpg", width: $if(cover_logo_width)$$cover_logo_width$$else$3cm$endif$)
]
#v(1fr)

#align(center)[
  #text(size: 12pt)[Disusun oleh:]
]
$for(author)$
#v(0.3cm)
#align(center)[
  #text(size: 12pt, weight: "bold")[$author.name$] \
  #text(size: 11pt)[$author.nim$]
]
$endfor$

#v(1fr)
#align(center)[
  #text(size: 12pt, weight: "bold")[#upper("$program_studi$".replace("\n", " "))]
  #linebreak()
  #text(size: 12pt, weight: "bold")[#upper("$faculty$".replace("\n", " "))]
  #linebreak()
  #text(size: 12pt, weight: "bold")[#upper("$institution$".replace("\n", " "))]
  #linebreak()
  #text(size: 12pt, weight: "bold")[$year$]
]
#v(1cm)

// ============================================================================
// BAGIAN AWAL (FRONT MATTER) — Romawi kecil, bawah tengah
// ============================================================================
#pagebreak()
#set page(numbering: "i", number-align: bottom + center)
#counter(page).update(1)

// --- Lembar Pengesahan
$if(approval)$
#align(center)[
  #text(size: 14pt, weight: "bold")[LEMBAR PENGESAHAN]
  #v(0.8cm)
  #text(size: 12pt, weight: "bold")[#title-lines]
]
#v(0.5cm)
#align(center)[
  #text(size: 11pt)[Disusun oleh:] \
  $for(author)$
  #text(size: 11pt, weight: "bold")[$author.name$] #text(size: 11pt)[($author.nim$)] \
  $endfor$
]
$if(approval.hari_tanggal)$
#v(0.3cm)
#align(center)[
  #text(size: 11pt)[Telah diuji dan disahkan pada:] \
  #text(size: 11pt)[$approval.hari_tanggal$]
]
$endif$
#v(1cm)
#grid(
  columns: (1fr, 1fr),
  gutter: 20pt,
  $for(approval.supervisors)$
  align(center)[
    #text(size: 10.5pt)[$it.role$] \
    #v(2cm)
    #text(size: 10.5pt, weight: "bold")[$it.name$] \
    $if(it.nip)$#text(size: 9pt)[NIP. $it.nip$]$endif$
  ],
  $endfor$
)
$if(approval.dean)$
#v(1cm)
#align(center)[
  #text(size: 10.5pt)[Mengesahkan] \
  #text(size: 10.5pt)[$approval.dean.role$] \
  #v(2cm)
  #text(size: 10.5pt, weight: "bold")[$approval.dean.name$] \
  $if(approval.dean.nip)$#text(size: 9pt)[NIP. $approval.dean.nip$]$endif$
]
$endif$
#pagebreak()
$endif$

// --- Ringkasan (Bahasa Indonesia)
$if(abstract_id)$
#align(center)[
  #text(size: 14pt, weight: "bold")[RINGKASAN]
]
#v(0.5cm)
#align(center)[
  #text(size: 11pt, weight: "bold")[#title-lines]
]
#v(0.5cm)
#set par(justify: true, leading: 0.9em, first-line-indent: 1cm)
#text(size: 11pt)[
  $abstract_id$
]
$if(keywords_id)$
#v(0.5cm)
#text(size: 10.5pt)[
  #set par(first-line-indent: 0cm)
  #strong[Kata Kunci:] #emph[$for(keywords_id)$$keywords_id$$sep$, $endfor$]
]
$endif$
#pagebreak()
$endif$

// --- Summary (Bahasa Inggris)
$if(abstract_en)$
#align(center)[
  #text(size: 14pt, weight: "bold")[SUMMARY]
]
#v(0.5cm)
#align(center)[
  #text(size: 11pt, weight: "bold", style: "italic")[#title-lines]
]
#v(0.5cm)
#set par(justify: true, leading: 0.9em, first-line-indent: 1cm)
#text(size: 11pt, style: "italic")[
  $abstract_en$
]
$if(keywords_en)$
#v(0.5cm)
#text(size: 10.5pt)[
  #set par(first-line-indent: 0cm)
  #strong[Keywords:] #emph[$for(keywords_en)$$keywords_en$$sep$, $endfor$]
]
$endif$
#pagebreak()
$endif$

#let opt-daftar-gambar = $if(daftar_gambar)$$daftar_gambar$$else$$if(list_of_figures)$$list_of_figures$$else$false$endif$$endif$
#let opt-daftar-tabel = $if(daftar_tabel)$$daftar_tabel$$else$$if(list_of_tables)$$list_of_tables$$else$false$endif$$endif$

$body$
