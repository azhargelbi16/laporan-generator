# =============================================================================
# laporan.ps1 - Pipeline laporan akademik DOCX-only untuk Windows PowerShell
#
# Alur   : template + sumber PDF -> ekstraksi teks (pdftotext) -> potong teks
#          -> rangkuman AI (konfigurabel via ai-config.json) -> chapters/bab*.md
#          -> validasi sitasi vs sources/references.bib -> Pandoc
#          (--reference-doc + docx.lua) -> output/<nama>.docx
# Output : output\<nama>.docx (default output\Laporan.docx; atur nama dengan
#          -OutFile "nama pilihan") - jalur PDF/Typst lama ada di _legacy/
#
# Contoh :
#   .\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2
#   .\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2 -OutFile "laporan-praktikum-jagung"
#   .\laporan.ps1 build -Template tugas-dosen -Sources contoh-jurnal -NoAi
#   .\laporan.ps1 check
#   .\laporan.ps1 list
#   .\laporan.ps1 clean
# =============================================================================

param(
    [Parameter(Position=0)][string]$Command = "help",
    [Parameter(Position=1)][string]$Template = "",
    [Parameter()][string[]]$Sources = @(),
    [Parameter()][switch]$NoAi,
    [Parameter()][string]$Bab = "",
    [Parameter()][Alias("Nama","Name")][string]$OutFile = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot
$env:PYTHONUTF8 = "1"

# ------------------------------------------------------------------ helpers --

function Write-Step { param([string]$m) Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Wrn  { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "  [ERR]  $m" -ForegroundColor Red }

function Get-PythonCommand {
    foreach ($cmd in @("python", "python3")) {
        $c = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($c) {
            if ($c.Source -match "WindowsApps\\python") { continue }
            return $c.Source
        }
    }
    $fallback = Get-Command "python" -ErrorAction SilentlyContinue
    if ($fallback) { return $fallback.Source }
    return ""
}

function Resolve-OutputPath {
    # Semua hasil build masuk ke folder output/ supaya mudah dicari.
    # -OutFile "nama pilihan"      -> output\nama pilihan.docx
    # -OutFile "arsip\nama"        -> arsip\nama.docx (relatif repo)
    # -OutFile "D:\folder\nama"    -> path absolut dihormati
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = "Laporan.docx" }
    $Name = $Name.Trim().Trim('"').Trim("'")
    if (-not $Name) { $Name = "Laporan.docx" }

    # pipeline ini DOCX-only: ekstensi lain diganti, tanpa ekstensi ditambah .docx
    if ($Name -match '\.(pdf|doc|odt|typ)$') {
        $Name = $Name -replace '\.(pdf|doc|odt|typ)$', '.docx'
    } elseif ($Name -notmatch '\.docx$') {
        $Name = "$Name.docx"
    }

    $hasDir = ($Name -match '[\\/]') -or [System.IO.Path]::IsPathRooted($Name)
    if ($hasDir) {
        if ([System.IO.Path]::IsPathRooted($Name)) { $full = $Name }
        else { $full = Join-Path $RepoRoot $Name }
    } else {
        $full = Join-Path (Join-Path $RepoRoot "output") $Name
    }

    $dir = [System.IO.Path]::GetDirectoryName($full)
    if (-not $dir) { $dir = Join-Path $RepoRoot "output" }
    $leaf = [System.IO.Path]::GetFileName($full)
    $leaf = [regex]::Replace($leaf, '[<>:"/\\|?*]', '-')
    if (-not $leaf) { $leaf = "Laporan.docx" }
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return (Join-Path $dir $leaf)
}

function Get-Pdftotext {
    $c = Get-Command "pdftotext" -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $exe = "C:\Program Files\Git\mingw64\bin\pdftotext.exe"
    if (Test-Path $exe) { return $exe }
    $toolsDir = Join-Path $env:LOCALAPPDATA "hermes\tools"
    if (Test-Path $toolsDir) {
        $hit = Get-ChildItem $toolsDir -Recurse -Filter "pdftotext.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Get-ToolVersion {
    # ambil baris pertama output (stdout+stderr) tanpa memicu ErrorActionPreference
    param([string]$Exe, [string[]]$ArgList)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Exe
        $psi.Arguments = ($ArgList -join ' ')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        try {
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        } catch {}
        $p = [System.Diagnostics.Process]::Start($psi)
        $o = $p.StandardOutput.ReadToEnd()
        $e = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $line = ($o + " " + $e).Trim()
        return (($line -split "\r?\n")[0].Trim())
    } catch { return "" }
}

# ------------------------------------------------------------ konfigurasi AI --

function Read-AiConfig {
    $cfg = @{
        enabled = $true
        command = @("hermes", "chat", "-q")
        extra_args = @()
        timeout_seconds = 600
        chunk_chars = 5000
        chunk_overlap = 300
        max_chunks_per_call = 2
    }
    $path = Join-Path $RepoRoot "ai-config.json"
    if (Test-Path $path) {
        try {
            $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $j.enabled)   { $cfg.enabled = [bool]$j.enabled }
            if ($j.command)             { $cfg.command = @($j.command) }
            if ($j.extra_args)          { $cfg.extra_args = @($j.extra_args) }
            if ($j.timeout_seconds)     { $cfg.timeout_seconds = [int]$j.timeout_seconds }
            if ($j.chunk_chars)         { $cfg.chunk_chars = [int]$j.chunk_chars }
            if ($j.chunk_overlap)       { $cfg.chunk_overlap = [int]$j.chunk_overlap }
            if ($j.max_chunks_per_call) { $cfg.max_chunks_per_call = [int]$j.max_chunks_per_call }
        } catch {
            Write-Wrn "ai-config.json tidak terbaca ($($_.Exception.Message)); memakai default."
        }
    }
    return $cfg
}

# --------------------------------------------------------------- database ---

function Get-BibKeys {
    $bib = Join-Path $RepoRoot "sources\references.bib"
    $keys = @()
    if (Test-Path $bib) {
        foreach ($line in Get-Content $bib -Encoding UTF8) {
            if ($line -match '^\s*@[A-Za-z]+\{([^,\s]+),') { $keys += $Matches[1] }
        }
    }
    return @($keys | Select-Object -Unique)
}

function Get-TemplateStructure {
    # struktur.md: "## Bab N Judul" = bab, "- Nama" = subbab
    param([string]$TplDir)
    $chapters = @()
    $file = Join-Path $TplDir "struktur.md"
    if (-not (Test-Path $file)) { return @() }
    $cur = $null
    foreach ($line in Get-Content $file -Encoding UTF8) {
        if ($line -match '^##\s+(.+)$') {
            $h = $Matches[1].Trim()
            $num = 0; $title = $h
            if ($h -match '^(?:Bab|BAB)\s+(\d+)\s*[.:)\-]?\s*(.*)$') {
                $num = [int]$Matches[1]; $title = $Matches[2].Trim()
            } elseif ($h -match '^(\d+)\s*[.:)\-]\s*(.*)$') {
                $num = [int]$Matches[1]; $title = $Matches[2].Trim()
            }
            if ($num -eq 0) { $num = $chapters.Count + 1 }
            if (-not $title) { $title = "BAB $num" }
            $cur = @{ Num = $num; Title = $title; Sections = @() }
            $chapters += $cur
        } elseif (($line -match '^-\s+(.+)$') -and ($null -ne $cur)) {
            $cur.Sections += $Matches[1].Trim()
        }
    }
    return @($chapters)
}

function Resolve-SourcePdfs {
    param([string[]]$Names)
    $found = @(); $missing = @()
    foreach ($n in $Names) {
        # terima "jurnal1,buku2" sebagai satu string (pemanggilan via powershell -File)
        # maupun array terpisah (pemanggilan interaktif di sesi PowerShell)
        foreach ($part in ("$n" -split ',')) {
            $part = $part.Trim()
            if (-not $part) { continue }
            $cand = @(
                (Join-Path $RepoRoot "sources\$part.pdf"),
                (Join-Path $RepoRoot "sources\pdf\$part.pdf")
            )
            $hit = $cand | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($hit) { $found += $hit } else { $missing += $part }
        }
    }
    return @{ Found = @($found); Missing = @($missing) }
}

function Get-AvailableSourceNames {
    $names = @()
    foreach ($d in @("sources", "sources\pdf")) {
        $p = Join-Path $RepoRoot $d
        if (Test-Path $p) {
            $names += Get-ChildItem $p -Filter "*.pdf" -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
        }
    }
    return @($names | Select-Object -Unique)
}

# -------------------------------------------------------------- ekstraksi ---

function Invoke-ExtractSources {
    param([string[]]$Pdfs)
    $texts = @()
    $pdftotext = Get-Pdftotext
    if (-not $pdftotext) {
        Write-Err "pdftotext tidak ditemukan. Cara memasang (pilih salah satu):"
        Write-Host "  - Chocolatey : choco install poppler"
        Write-Host "  - Scoop       : scoop install poppler"
        Write-Host "  - Manual      : https://github.com/oschwartz10612/poppler-windows (ekstrak, lalu tambahkan folder bin ke PATH)"
        Write-Host "  - Catatan     : Git for Windows terbaru menyertakan pdftotext di <Git>\mingw64\bin"
        throw "pdftotext tidak tersedia"
    }
    $outDir = Join-Path $RepoRoot "sources\extracted"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    foreach ($pdf in $Pdfs) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($pdf)
        $txt = Join-Path $outDir "$base.txt"
        if ((Test-Path $txt) -and ((Get-Item $txt).LastWriteTime -ge (Get-Item $pdf).LastWriteTime)) {
            Write-Ok "cache ekstraksi masih segar: $base.txt"
        } else {
            & $pdftotext "-enc" "UTF-8" "-nopgbrk" $pdf $txt
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $txt)) {
                Write-Wrn "gagal mengekstrak $([System.IO.Path]::GetFileName($pdf)) (exit $LASTEXITCODE); sumber dilewati"
                continue
            }
        }
        $content = Get-Content $txt -Raw -Encoding UTF8
        if ($null -eq $content) { $content = "" }
        if ($content.Trim().Length -lt 50) {
            Write-Wrn "teks '$base' hampir kosong ($($content.Trim().Length) karakter). PDF mungkin hasil scan (gambar) dan perlu OCR dulu."
        } else {
            Write-Ok "ekstraksi $base : $($content.Trim().Length) karakter"
        }
        $texts += $content
    }
    return @($texts)
}

function Get-TextChunks {
    # potong teks panjang agar tidak melebihi batas konteks model;
    # dipecah di batas paragraf bila memungkinkan, dengan tumpang tindih (overlap)
    param([string]$Text, [int]$Size, [int]$Overlap)
    $chunks = @()
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $text = $Text.Trim()
    if ($text.Length -le $Size) { return @($text) }
    $step = [Math]::Max(1, $Size - $Overlap)
    $paras = [regex]::Split($text, "\r?\n\s*\r?\n")
    $cur = ""
    foreach ($p in $paras) {
        $p = $p.Trim()
        if (-not $p) { continue }
        if ($p.Length -gt $Size) {
            if ($cur) { $chunks += $cur; $cur = "" }
            $idx = 0
            while ($idx -lt $p.Length) {
                $len = [Math]::Min($Size, $p.Length - $idx)
                $chunks += $p.Substring($idx, $len).Trim()
                $idx += $step
            }
            continue
        }
        if (($cur.Length + $p.Length + 2) -gt $Size) {
            if ($cur) { $chunks += $cur }
            if ($Overlap -gt 0 -and $cur.Length -gt $Overlap) {
                $cur = $cur.Substring($cur.Length - $Overlap).Trim() + "`n`n" + $p
            } else { $cur = $p }
        } else {
            if ($cur) { $cur = $cur + "`n`n" + $p } else { $cur = $p }
        }
    }
    if ($cur) { $chunks += $cur }
    return @($chunks)
}

# ------------------------------------------------------------------ tahap AI --

function Build-AiPrompt {
    param($Chapter, [string]$TemplateId, [string]$DocTitle, [string[]]$ChunkTexts, [string[]]$CiteKeys)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Anda adalah penulis laporan akademik S1 Indonesia. Tulis satu bab laporan.")
    [void]$sb.AppendLine("Jenis laporan : $TemplateId")
    [void]$sb.AppendLine("Judul laporan : $DocTitle")
    [void]$sb.AppendLine("BAB $($Chapter.Num) : $($Chapter.Title)")
    $subs = @($Chapter.Sections)
    if ($subs.Count -gt 0) {
        [void]$sb.AppendLine("Subbab yang harus ada di bab ini:")
        foreach ($s in $subs) { [void]$sb.AppendLine("- $s") }
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("TEKS SUMBER (bahan isi; mungkin tidak semuanya relevan untuk bab ini):")
    $nChunks = @($ChunkTexts).Count
    for ($i = 0; $i -lt $nChunks; $i++) {
        [void]$sb.AppendLine("----- potongan sumber $($i+1) dari $nChunks -----")
        [void]$sb.AppendLine($ChunkTexts[$i])
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("ATURAN WAJIB:")
    [void]$sb.AppendLine("1. Ringkas dan tulis dengan kata-kata sendiri. DILARANG menyalin kalimat atau paragraf panjang dari teks sumber.")
    if (@($CiteKeys).Count -gt 0) {
        [void]$sb.AppendLine("2. Sitasi HANYA boleh memakai citekey berikut: $($CiteKeys -join ', '). Format pandoc: [@key] atau [@k1; @k2]. DILARANG mengarang penulis, tahun, angka, atau kutipan.")
    } else {
        [void]$sb.AppendLine("2. Jangan memakai sitasi apa pun (references.bib kosong).")
    }
    [void]$sb.AppendLine("3. Jika informasi tidak tersedia di teks sumber, tulis [perlu diisi] -- jangan mengira-ngira.")
    [void]$sb.AppendLine("4. Jawab HANYA berupa markdown bab ini, tanpa kalimat pembuka/penutup dan tanpa blok kode:")
    [void]$sb.AppendLine("   - Baris pertama : # $($Chapter.Title)")
    [void]$sb.AppendLine("   - Tiap subbab   : ## <nama subbab>")
    [void]$sb.AppendLine("   - Minimal satu paragraf bermakna per subbab.")
    return $sb.ToString()
}

function Test-AiNetwork {
    param([string]$Exe)
    try {
        $p = [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo -Property @{
            FileName = $Exe; Arguments = '--help'; UseShellExecute = $false;
            RedirectStandardOutput = $true; RedirectStandardError = $true;
            CreateNoWindow = $true
        }))
        if (-not $p.WaitForExit(10000)) { try { $p.Kill() } catch {}; return $false }
        return $true
    } catch { return $false }
}

function Invoke-Ai {
    param($Cfg, [string]$Prompt, [int]$RetryCount = 2)
    $exe = @($Cfg.command)[0]
    $resolved = Get-Command $exe -ErrorAction SilentlyContinue
    if (-not $resolved) {
        return @{ Ok = $false; Error = "perintah AI '$exe' tidak ditemukan di PATH. Pastikan Hermes terpasang dan ada di PATH, atau ubah ai-config.json (contoh command: ollama run qwen3)." }
    }
    if (-not (Test-AiNetwork -Exe $resolved.Source)) {
        return @{ Ok = $false; Error = "Tidak dapat menjalankan perintah AI '$exe'. Kemungkinan proses terblokir antivirus/firewall, atau membutuhkan koneksi ke router/proxy (pastikan jaringan/router aktif)." }
    }
    $argItems = @()
    if (@($Cfg.command).Count -gt 1) { $argItems += @($Cfg.command)[1..(@($Cfg.command).Count - 1)] }
    if (@($Cfg.extra_args).Count -gt 0) { $argItems += @($Cfg.extra_args) }

    $workdir = Join-Path $RepoRoot "tmp"
    if (-not (Test-Path $workdir)) { New-Item -ItemType Directory -Path $workdir | Out-Null }

    # placeholder {prompt_file}: prompt ditulis ke berkas (aman untuk teks panjang)
    $usesFile = $false
    $tmpArgs = @()
    foreach ($a in $argItems) {
        if ("$a" -eq "{prompt_file}") { $usesFile = $true; $tmpArgs += (Join-Path $workdir "ai-prompt.txt") }
        elseif ("$a" -like "*{prompt_file}*") {
            $usesFile = $true
            $tmpArgs += ($a -replace '\{prompt_file\}', (Join-Path $workdir "ai-prompt.txt"))
        } else { $tmpArgs += $a }
    }
    $argItems = $tmpArgs
    if ($usesFile) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $workdir "ai-prompt.txt"), $Prompt, $utf8NoBom)
    } else {
        $argItems += $Prompt
    }

    $argLine = ""
    foreach ($a in $argItems) {
        $argLine += ' "' + ($a -replace '"', '\"') + '"'
    }
    if ((-not $usesFile) -and ($argLine.Length -gt 30000)) {
        return @{ Ok = $false; Error = "prompt terlalu panjang ($($argLine.Length) karakter; batas 30000). Turunkan chunk_chars/max_chunks_per_call di ai-config.json, atau pakai placeholder {prompt_file}" }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $resolved.Source
    $psi.Arguments = $argLine
    $psi.WorkingDirectory = $workdir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    try {
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    } catch {}

    $attempt = 0
    while ($attempt -lt $RetryCount) {
        $attempt++
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        $timeoutMs = [int]($Cfg.timeout_seconds) * 1000
        if (-not $p.WaitForExit($timeoutMs)) {
            try { $p.Kill() } catch {}
            $err = "timeout setelah $($Cfg.timeout_seconds) detik"
            if ($attempt -lt $RetryCount) {
                Write-Wrn "AI percobaan $attempt gagal ($err), mencoba lagi..."
                continue
            }
            return @{ Ok = $false; Error = $err + " (percobaan $attempt x gagal)" }
        }
        $stdout = $outTask.Result
        $stderr = $errTask.Result
        if ($p.ExitCode -ne 0) {
            $msg = ($stderr -replace "\s+", " ").Trim()
            if ($msg.Length -gt 500) { $msg = $msg.Substring(0, 500) + "..." }
            $err = "exit code $($p.ExitCode): $msg"
            if ($attempt -lt $RetryCount) {
                Write-Wrn "AI percobaan $attempt gagal ($err), mencoba lagi..."
                continue
            }
            return @{ Ok = $false; Error = $err + " (percobaan $attempt x gagal)" }
        }
        if ([string]::IsNullOrWhiteSpace($stdout)) {
            $msg = ($stderr -replace "\s+", " ").Trim()
            if ($msg.Length -gt 500) { $msg = $msg.Substring(0, 500) + "..." }
            $err = "output kosong. stderr: $msg"
            if ($attempt -lt $RetryCount) {
                Write-Wrn "AI percobaan $attempt gagal ($err), mencoba lagi..."
                continue
            }
            return @{ Ok = $false; Error = $err + " (percobaan $attempt x gagal)" }
        }
        return @{ Ok = $true; Text = $stdout }
    }
    return @{ Ok = $false; Error = "Gagal setelah $RetryCount percobaan" }
}

function ConvertTo-ChapterMarkdown {
    param([string]$Raw)
    $t = $Raw.Trim()
    $esc = [string][char]27
    $t = $t -replace "$esc\[[0-9;]*[A-Za-z]", ""
    # buang sampah pembungkus CLI (kotak dekoratif, info sesi Hermes, dll.)
    $keep = @()
    foreach ($ln in ($t -split "\r?\n")) {
        if ($ln -match '^\s*$') { $keep += $ln; continue }
        if ($ln -match '^[\u2500-\u257F=\-\s]+$') { continue }                 # garis/tepi kotak dekoratif
        if ($ln -match '^(Query|Initializing agent|Resume this session|Session|Duration|Messages|hermes --resume)\s*:') { continue }
        if ($ln -match '^\s*hermes --resume\s') { continue }
        $keep += $ln
    }
    $t = ($keep -join "`n").Trim()
    if ($t -match '(?s)^```[a-zA-Z]*\r?\n(.*)\r?\n```\s*$') { $t = $Matches[1].Trim() }
    $lines = $t -split "\r?\n"
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^#{1,3}\s+') { $startIdx = $i; break }
    }
    if ($startIdx -gt 0) { $t = ($lines[$startIdx..($lines.Count - 1)] -join "`n").Trim() }
    return $t
}

function Repair-Citations {
    # sitasi hanya boleh citekey yang ada di sources/references.bib;
    # yang tidak dikenal diganti placeholder [perlu diisi ...]
    param([string]$Md, [string[]]$ValidKeys)
    $bad = @{}
    $newMd = [regex]::Replace($Md, '\[[^\[\]]*@[^\[\]]*\]', {
        param($m)
        $keys = [regex]::Matches($m.Value, '@([A-Za-z0-9_.:+\-]+)') | ForEach-Object { $_.Groups[1].Value }
        $keep = @()
        foreach ($k in $keys) {
            if ($ValidKeys -contains $k) { $keep += $k } else { $bad[$k] = $true }
        }
        if ($keep.Count -eq 0) { return '*[perlu diisi: sitasi tidak valid]*' }
        return '[@' + ($keep -join '; @') + ']'
    })
    $newMd = [regex]::Replace($newMd, '(?<!\[)@([A-Za-z0-9_.:+\-]+)', {
        param($m)
        $k = $m.Groups[1].Value
        if ($ValidKeys -contains $k) { return $m.Value }
        $bad[$k] = $true
        return '*[perlu diisi: sitasi ' + $k + ' tidak ada di references.bib]*'
    })
    return @{ Text = $newMd; BadKeys = @($bad.Keys) }
}

function New-SkeletonChapter {
    param($Chapter)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $($Chapter.Title)")
    [void]$sb.AppendLine("")
    foreach ($s in @($Chapter.Sections)) {
        [void]$sb.AppendLine("## $s")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("[perlu diisi]")
        [void]$sb.AppendLine("")
    }
    if (@($Chapter.Sections).Count -eq 0) {
        [void]$sb.AppendLine("[perlu diisi]")
    }
    return $sb.ToString()
}

function Get-BabFileName {
    param($Chapter)
    $slug = ($Chapter.Title -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower()
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).Trim('-') }
    if (-not $slug) { $slug = "bab" }
    return "bab$($Chapter.Num)-$slug.md"
}

# ------------------------------------------------------------------ pandoc ---

function Invoke-PandocDocx {
    param([string]$TplDir, [string]$OutPath)
    $chaptersDir = Join-Path $RepoRoot "chapters"
    $babs = Get-ChildItem $chaptersDir -Filter "bab*.md" -ErrorAction SilentlyContinue |
        Sort-Object { if ($_.Name -match 'bab(\d+)') { [int]$Matches[1] } else { 999 } }
    if (-not $babs -or @($babs).Count -eq 0) {
        Write-Err "tidak ada chapters/bab*.md untuk dikompilasi"
        return $false
    }
    $inputs = @()
    $cover = Join-Path $RepoRoot "cover.md"
    if (Test-Path $cover) { $inputs += $cover }
    $inputs += @($babs | ForEach-Object { $_.FullName })

    $pandocArgs = @()
    $pandocArgs += $inputs
    # urutan --metadata-file: preset -> template -> root (yang belakangan menang)
    $metaRoot = Join-Path $RepoRoot "metadata.yml"
    if (Test-Path $metaRoot) {
        $content = Get-Content $metaRoot -Raw -Encoding UTF8
        if ($content -match '(?:preset|margin_preset)\s*:\s*["'']?([a-zA-Z0-9_-]+)') {
            $presetFile = Join-Path $RepoRoot "presets\$($Matches[1]).yml"
            if (Test-Path $presetFile) { $pandocArgs += "--metadata-file=$presetFile" }
        }
    }
    $tplMeta = Join-Path $TplDir "metadata.yml"
    if (Test-Path $tplMeta) { $pandocArgs += "--metadata-file=$tplMeta" }
    if (Test-Path $metaRoot) { $pandocArgs += "--metadata-file=$metaRoot" }
    $pandocArgs += "--citeproc"
    $pandocArgs += "--bibliography=$(Join-Path $RepoRoot 'sources\references.bib')"
    $csl = Join-Path $RepoRoot "apa.csl"
    if (Test-Path $csl) { $pandocArgs += "--csl=$csl" }
    $pandocArgs += "--metadata=reference-section-title=DAFTAR PUSTAKA"
    $pandocArgs += "--top-level-division=chapter"
    $pandocArgs += "--reference-doc=$(Join-Path $TplDir 'reference.docx')"
    $luaFilter = Join-Path $RepoRoot "docx.lua"
    if (Test-Path $luaFilter) { $pandocArgs += "--lua-filter=$luaFilter" }
    $pandocArgs += "--resource-path=$RepoRoot"

    $tmpDir = Join-Path $RepoRoot "tmp"
    if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }
    $docx1 = Join-Path $tmpDir "Laporan-pass1.docx"
    $docx2 = Join-Path $tmpDir "Laporan-pass2.docx"
    $final = $OutPath
    if (-not [System.IO.Path]::IsPathRooted($final)) { $final = Join-Path $RepoRoot $final }
    $finalDir = [System.IO.Path]::GetDirectoryName($final)
    if ($finalDir -and -not (Test-Path $finalDir)) {
        New-Item -ItemType Directory -Path $finalDir -Force | Out-Null
    }

    & pandoc @pandocArgs -o $docx1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "pandoc gagal (exit $LASTEXITCODE)"
        return $false
    }
    Write-Ok "pandoc pass-1 : $docx1"

    $py = Get-PythonCommand
    $finalize = Join-Path $RepoRoot "scripts\finalize-docx.py"
    $pagenum = Join-Path $RepoRoot "scripts\docx-pagenum.py"
    if ($py -and (Test-Path $finalize)) {
        try {
            & $py $finalize $docx1 $docx2
            if ($LASTEXITCODE -eq 0 -and (Test-Path $docx2)) {
                Write-Ok "finalize-docx : penomoran bagian diterapkan"
            } else {
                Write-Wrn "finalize-docx gagal; memakai hasil pandoc langsung"
                Copy-Item $docx1 $docx2 -Force
            }
            if (Test-Path $pagenum) {
                & $py $pagenum $docx2 $final
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path $final)) {
                    Write-Wrn "docx-pagenum gagal; memakai hasil finalize"
                    Copy-Item $docx2 $final -Force
                }
            } else {
                Copy-Item $docx2 $final -Force
            }
        } catch {
            Write-Err "gagal menulis '$final'. Kemungkinan file sedang dibuka di Word - tutup lalu ulangi build."
            Write-Host "         detail: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Wrn "python / finalize-docx.py tidak tersedia; DOCX tanpa pasca-proses penomoran"
        try { Copy-Item $docx1 $final -Force }
        catch {
            Write-Err "gagal menulis '$final'. Kemungkinan file sedang dibuka di Word - tutup lalu ulangi build."
            return $false
        }
    }
    if (Test-Path $final) {
        Write-Ok "output       : $final ($([Math]::Round((Get-Item $final).Length/1KB,1)) KB)"
        return $true
    }
    Write-Err "DOCX gagal dibuat"
    return $false
}

# ------------------------------------------------------------------ build ---

function Cmd-Build {
    param([string]$TemplateId, [string[]]$SourceNames, [switch]$SkipAi, [string]$BabFilter, [string]$OutPath)

    if (-not $TemplateId) { $TemplateId = "praktikum" }
    Write-Step "Tahap 1: template '$TemplateId'"
    $tplDir = Join-Path $RepoRoot "templates\$TemplateId"
    if (-not (Test-Path $tplDir)) {
        Write-Err "template tidak ditemukan: templates\$TemplateId"
        $avail = Get-ChildItem (Join-Path $RepoRoot "templates") -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
        Write-Host "  tersedia: $($avail -join ', ')"
        exit 1
    }
    if (-not (Test-Path (Join-Path $tplDir "reference.docx"))) {
        Write-Err "templates\$TemplateId\reference.docx tidak ada"; exit 1
    }
    $structure = Get-TemplateStructure $tplDir
    if (@($structure).Count -eq 0) { Write-Err "struktur.md kosong/tidak terbaca di template"; exit 1 }
    Write-Ok "struktur     : $(@($structure).Count) bab ($(@($structure | ForEach-Object { $_.Title }) -join ' | '))"

    $cfg = Read-AiConfig
    $keys = Get-BibKeys

    Write-Step "Tahap 2: sitasi"
    if (@($keys).Count -gt 0) {
        Write-Ok "$($keys.Count) citekey di sources/references.bib: $($keys -join ', ')"
    } else {
        Write-Wrn "references.bib kosong/tidak ada - semua sitasi akan ditolak"
    }

    $texts = @()
    if (@($SourceNames).Count -gt 0) {
        $res = Resolve-SourcePdfs $SourceNames
        foreach ($m in @($res.Missing)) {
            Write-Wrn "sumber '$m' tidak ditemukan (dicari sources\<nama>.pdf dan sources\pdf\<nama>.pdf)"
        }
        $avail = Get-AvailableSourceNames
        if (@($avail).Count -gt 0) { Write-Host "  sumber tersedia: $($avail -join ', ')" }
        if (@($res.Found).Count -eq 0) { Write-Err "tidak ada PDF sumber yang cocok"; exit 1 }
        Write-Step "Tahap 3: ekstraksi teks PDF (pdftotext)"
        $texts = Invoke-ExtractSources @($res.Found)
    } else {
        Write-Wrn "parameter -Sources kosong: bab dibuat tanpa bahan sumber"
    }

    $pool = @()
    if (@($texts).Count -gt 0) {
        Write-Step "Tahap 4: pemotongan teks (chunking)"
        foreach ($t in $texts) {
            $pool += Get-TextChunks -Text $t -Size $cfg.chunk_chars -Overlap $cfg.chunk_overlap
        }
        Write-Ok "$($pool.Count) potongan teks (maks $($cfg.chunk_chars) karakter/potongan; dipakai maks $($cfg.max_chunks_per_call) per bab)"
    }

    $useAi = (-not $SkipAi) -and $cfg.enabled -and ($pool.Count -gt 0)
    if ((-not $SkipAi) -and $cfg.enabled -and ($pool.Count -eq 0)) {
        Write-Wrn "AI dilewati (tidak ada teks sumber); dipakai kerangka [perlu diisi]"
    } elseif ($SkipAi) {
        Write-Host "  mode -NoAi: semua bab menjadi kerangka [perlu diisi]"
    } elseif (-not $cfg.enabled) {
        Write-Host "  ai-config.json: enabled=false -> kerangka [perlu diisi]"
    } else {
        Write-Host "  AI: $($cfg.command -join ' ') (lihat ai-config.json)"
    }

    $docTitle = ""
    $metaRoot = Join-Path $RepoRoot "metadata.yml"
    if (Test-Path $metaRoot) {
        $c = Get-Content $metaRoot -Raw -Encoding UTF8
        if ($c -match '(?m)^\s*title\s*:\s*["'']?(.+?)["'']?\s*$') { $docTitle = $Matches[1].Trim() }
    }
    if (-not $docTitle) { $docTitle = "(judul belum diisi di metadata.yml)" }

    Write-Step "Tahap 5: penulisan bab -> chapters/"
    $chaptersDir = Join-Path $RepoRoot "chapters"
    if (-not (Test-Path $chaptersDir)) { New-Item -ItemType Directory -Path $chaptersDir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $expected = @()
    $chIdx = 0
    foreach ($ch in $structure) {
        $chIdx++
        if ($BabFilter -and ("$($ch.Num)" -ne "$BabFilter")) { continue }
        $fname = Get-BabFileName $ch
        $expected += $fname
        $fpath = Join-Path $chaptersDir $fname
        $written = $false
        if ($useAi) {
            $take = @()
            if ($pool.Count -le $cfg.max_chunks_per_call) {
                $take = $pool
            } else {
                $start = ($chIdx * $cfg.max_chunks_per_call) % $pool.Count
                for ($i = 0; $i -lt $cfg.max_chunks_per_call; $i++) {
                    $take += $pool[($start + $i) % $pool.Count]
                }
            }
            $prompt = Build-AiPrompt -Chapter $ch -TemplateId $TemplateId -DocTitle $docTitle -ChunkTexts $take -CiteKeys $keys
            Write-Host "  AI menulis $fname (bahan: $($take.Count) potongan teks)..."
            $r = Invoke-Ai -Cfg $cfg -Prompt $prompt
            if ($r.Ok) {
                $md = ConvertTo-ChapterMarkdown $r.Text
                $rep = Repair-Citations -Md $md -ValidKeys $keys
                if (@($rep.BadKeys).Count -gt 0) {
                    Write-Wrn "sitasi tak dikenal diganti placeholder: $($rep.BadKeys -join ', ')"
                }
                [System.IO.File]::WriteAllText($fpath, $rep.Text, $utf8NoBom)
                $written = $true
                Write-Ok "$fname ditulis AI"
            } else {
                Write-Wrn "AI gagal untuk $fname : $($r.Error)"
                if (Test-Path -LiteralPath $fpath) {
                    $existing = Get-Content -LiteralPath $fpath -Raw -Encoding UTF8
                    if ($existing -notmatch '\[perlu diisi\]' -and $existing.Trim().Length -gt 50) {
                        Write-Host "  mempertahankan isi lama $fname (AI gagal, file tidak ditimpa)" -ForegroundColor Yellow
                        $written = $true
                    }
                }
            }
        }
        if (-not $written) {
            $skel = New-SkeletonChapter $ch
            [System.IO.File]::WriteAllText($fpath, $skel, $utf8NoBom)
            Write-Ok "$fname kerangka [perlu diisi]"
        }
    }

    # buang bab lama yang bukan bagian template ini (hanya saat build penuh)
    if (-not $BabFilter) {
        Get-ChildItem $chaptersDir -Filter "bab*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($expected -notcontains $_.Name) {
                Write-Host "  hapus bab di luar template: $($_.Name)"
                Remove-Item $_.FullName -Force
            }
        }
    }

    $finalPath = Resolve-OutputPath -Name $OutPath
    Write-Step "Tahap 6: kompilasi DOCX (pandoc + reference-doc + docx.lua)"
    $ok = Invoke-PandocDocx -TplDir $tplDir -OutPath $finalPath
    if (-not $ok) { exit 1 }

    $allMd = (Get-ChildItem $chaptersDir -Filter "bab*.md" | Sort-Object Name | ForEach-Object {
        Get-Content $_.FullName -Raw -Encoding UTF8
    }) -join "`n"
    $nPlaceholder = ([regex]::Matches($allMd, '\[perlu diisi')).Count
    Write-Host ""
    Write-Host "=== BUILD SELESAI ===" -ForegroundColor Green
    Write-Host "  Output  : $finalPath"
    Write-Host "  Catatan : $nPlaceholder penanda [perlu diisi] di naskah - lengkapi/cek manual."
}

# ------------------------------------------------------------------ check ---

function Cmd-Check {
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "   LAPORAN GENERATOR - cek dependensi & struktur" -ForegroundColor Cyan
    Write-Host "  ==================================================" -ForegroundColor Cyan
    $allOk = $true

    Write-Step "[1] Perintah eksternal"
    $pandoc = Get-Command "pandoc" -ErrorAction SilentlyContinue
    if ($pandoc) {
        $v = Get-ToolVersion $pandoc.Source @("--version")
        Write-Ok "pandoc    : $v"
    } else {
        Write-Err "pandoc tidak ditemukan (WAJIB). Pasang: https://pandoc.org/installing.html"
        $allOk = $false
    }
    $pt = Get-Pdftotext
    if ($pt) {
        $v = Get-ToolVersion $pt @("-v")
        Write-Ok "pdftotext : $v  ($pt)"
    } else {
        Write-Err "pdftotext tidak ditemukan (dibutuhkan untuk -Sources)."
        Write-Host "          pasang Poppler: choco install poppler / scoop install poppler"
        Write-Host "          manual: https://github.com/oschwartz10612/poppler-windows (tambahkan folder bin ke PATH)"
        $allOk = $false
    }
    $py = Get-PythonCommand
    if ($py) {
        $v = Get-ToolVersion $py @("--version")
        Write-Ok "python    : $v  ($py)"
    } else {
        Write-Wrn "python tidak ditemukan (opsional; untuk pasca-proses penomoran DOCX)"
    }
    $cfg = Read-AiConfig
    if ($cfg.enabled) {
        $exe = @($cfg.command)[0]
        $ai = Get-Command $exe -ErrorAction SilentlyContinue
        if ($ai) { Write-Ok "AI        : $($cfg.command -join ' ') -> $($ai.Source)" }
        else { Write-Wrn "AI '$exe' tidak ditemukan di PATH (ubah ai-config.json atau set enabled=false)" }
    } else {
        Write-Host "  [INFO] AI dimatikan di ai-config.json (build = kerangka [perlu diisi])"
    }

    Write-Step "[2] Berkas pipeline"
    foreach ($f in @("laporan.ps1", "ai-config.json", "docx.lua", "apa.csl", "cover.md", "metadata.yml")) {
        if (Test-Path (Join-Path $RepoRoot $f)) { Write-Ok $f } else { Write-Wrn "$f tidak ada" }
    }
    foreach ($s in @("scripts\finalize-docx.py", "scripts\docx-pagenum.py", "sources\references.bib")) {
        if (Test-Path (Join-Path $RepoRoot $s)) { Write-Ok $s } else { Write-Wrn "$s tidak ada"; $allOk = $false }
    }

    Write-Step "[3] Template"
    $tplRoot = Join-Path $RepoRoot "templates"
    if (-not (Test-Path $tplRoot)) { Write-Err "folder templates/ tidak ada"; $allOk = $false }
    Get-ChildItem $tplRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $ref = Test-Path (Join-Path $_.FullName "reference.docx")
        $n = @(Get-TemplateStructure $_.FullName).Count
        if ($ref -and ($n -gt 0)) { Write-Ok "$($_.Name): reference.docx + $n bab" }
        else { Write-Wrn "$($_.Name): reference.docx ada=$ref, bab terdeteksi=$n" }
    }

    Write-Step "[4] Sumber"
    $names = Get-AvailableSourceNames
    if (@($names).Count -gt 0) { Write-Ok "PDF sumber: $($names -join ', ')" }
    else { Write-Host "  [INFO] belum ada PDF di sources/pdf/" }
    $keys = Get-BibKeys
    if (@($keys).Count -gt 0) { Write-Ok "$($keys.Count) citekey: $($keys -join ', ')" }
    else { Write-Wrn "sources/references.bib kosong" }

    Write-Step "[5] Validasi sitasi chapters/ (bila ada)"
    $babs = Get-ChildItem (Join-Path $RepoRoot "chapters") -Filter "bab*.md" -ErrorAction SilentlyContinue
    if ($babs) {
        foreach ($b in $babs) {
            $md = Get-Content $b.FullName -Raw -Encoding UTF8
            $rep = Repair-Citations -Md $md -ValidKeys $keys
            if (@($rep.BadKeys).Count -gt 0) {
                Write-Wrn "$($b.Name): sitasi tak dikenal: $($rep.BadKeys -join ', ')"
            } else {
                Write-Ok "$($b.Name): sitasi valid"
            }
        }
    } else {
        Write-Host "  [INFO] chapters/ kosong (belum ada build)"
    }

    Write-Host ""
    if ($allOk) {
        Write-Host "SIAP. Contoh: .\laporan.ps1 build -Template praktikum -Sources <nama-pdf>" -ForegroundColor Green
    } else {
        Write-Host "ADA KOMPONEN KURANG - perbaiki yang bertanda [ERR]/[WARN] di atas." -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------- list ---

function Cmd-List {
    Write-Step "Template (templates/)"
    Get-ChildItem (Join-Path $RepoRoot "templates") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  * $($_.Name)" -ForegroundColor Green
        foreach ($c in @(Get-TemplateStructure $_.FullName)) {
            Write-Host "      BAB $($c.Num) $($c.Title)  [$(@($c.Sections) -join '; ')]"
        }
    }
    Write-Step "Sumber (sources/)"
    $names = Get-AvailableSourceNames
    if (@($names).Count -gt 0) {
        foreach ($n in $names) { Write-Host "  * $n  (sources/pdf/$n.pdf)" -ForegroundColor Green }
    } else { Write-Host "  (belum ada PDF)" }
    $keys = Get-BibKeys
    Write-Host "  citekey references.bib: $($keys -join ', ')"
}

# ------------------------------------------------------------------ clean ---

function Cmd-Clean {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $RepoRoot "Laporan.docx")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $RepoRoot "chapters\*.md")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $RepoRoot "sources\extracted\*.txt")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $RepoRoot "tmp")
    Write-Ok "dibersihkan: chapters/bab*.md, cache ekstraksi, tmp/"
    Write-Host "  folder output/ TIDAK dihapus (berisi DOCX hasil build Anda)" -ForegroundColor Yellow
}

# ------------------------------------------------------------------- help ---

function Show-Help {
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "   LAPORAN GENERATOR - pipeline DOCX (PowerShell)" -ForegroundColor Cyan
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Pemakaian:"
    Write-Host "    .\laporan.ps1 build -Template <nama> -Sources <pdf1,pdf2> [-NoAi] [-Bab <n>] [-OutFile <nama>]"
    Write-Host "    .\laporan.ps1 docx      kompilasi ulang DOCX dari chapters/ yang ada"
    Write-Host "    .\laporan.ps1 check     cek dependensi & struktur"
    Write-Host "    .\laporan.ps1 list      daftar template & sumber"
    Write-Host "    .\laporan.ps1 clean     hapus berkas kerja (output/ tetap)"
    Write-Host ""
    Write-Host "  Contoh:"
    Write-Host "    .\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2"
    Write-Host "    .\laporan.ps1 build -Template praktikum -Sources jurnal1,buku2 -OutFile `"laporan-praktikum-jagung`""
    Write-Host "    .\laporan.ps1 build -Template tugas-dosen -Sources contoh-jurnal"
    Write-Host "    .\laporan.ps1 build -Template praktikum -NoAi     (kerangka [perlu diisi] saja)"
    Write-Host "    .\laporan.ps1 build -Template praktikum -Sources contoh-jurnal -Bab 1"
    Write-Host ""
    Write-Host "  Konfigurasi AI  : ai-config.json (default: hermes chat -q, non-interaktif)"
    Write-Host "  Template        : templates\<nama>\{reference.docx, struktur.md, metadata.yml}"
    Write-Host "  Sumber & sitasi : sources\pdf\*.pdf + sources\references.bib (APA 7th)"
    Write-Host "  Output          : output\<nama>.docx (default output\Laporan.docx)"
    Write-Host "                    pilih nama sendiri dengan -OutFile `"nama laporan`""
}

# -------------------------------------------------------------- dispatcher --

switch ($Command.ToLower()) {
    "build" { Cmd-Build -TemplateId $Template -SourceNames $Sources -SkipAi:$NoAi -BabFilter $Bab -OutPath $OutFile }
    "docx"  {
        if (-not $Template) { $Template = "praktikum" }
        $tplDir = Join-Path $RepoRoot "templates\$Template"
        if (-not (Test-Path $tplDir)) { Write-Err "template tidak ditemukan: templates\$Template"; exit 1 }
        $finalPath = Resolve-OutputPath -Name $OutFile
        Write-Step "Kompilasi ulang DOCX dari chapters/ yang ada (template '$Template') -> $finalPath"
        $ok = Invoke-PandocDocx -TplDir $tplDir -OutPath $finalPath
        if (-not $ok) { exit 1 }
    }
    "check" { Cmd-Check }
    "list"  { Cmd-List }
    "clean" { Cmd-Clean }
    "help"  { Show-Help }
    default { Show-Help; Write-Err "perintah tidak dikenal: $Command" }
}

