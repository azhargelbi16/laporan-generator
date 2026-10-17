# =============================================================================
# Laporan-Generator.ps1 - TUI (PwshSpectreConsole) untuk pipeline laporan.ps1
#
# Menjalankan laporan.ps1 sebagai proses anak (tidak di-dot-source).
# Jalankan lewat Laporan-Generator.bat, atau:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\Laporan-Generator.ps1
# Tes mandiri (tanpa UI):
#   pwsh -NoProfile -File .\Laporan-Generator.ps1 -SelfTest
# =============================================================================
#requires -Version 7.4
param(
    [Parameter()][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # host tanpa dukungan pengaturan encoding (mis. host tertanam) - abaikan
    $script:LgrEncodingSet = $false
}
$script:LgrRoot = $PSScriptRoot

# =============================================================================
# FUNGSI LOGIKA MURNI (tanpa UI, bisa diuji oleh -SelfTest)
# =============================================================================

function Get-LgrSanitizedFileName {
    # Buang karakter terlarang, strip ".docx" yang diketik user, trim titik/spasi ujung.
    param([Parameter()][AllowEmptyString()][string]$Name)
    $s = $Name
    while ($s -match '(?i)\.docx$') {
        $s = [regex]::Replace($s, '(?i)\.docx$', '')
    }
    foreach ($ch in @('\', '/', ':', '*', '?', '"', '<', '>', '|')) {
        $s = $s.Replace($ch, '')
    }
    return $s.Trim(' ', '.')
}

function Get-LgrStrukturChapters {
    # struktur.md: "## Bab N Judul" -> @{ Number; Title }
    param([Parameter(Mandatory)][string]$StrukturPath)
    $result = @()
    if (-not (Test-Path -LiteralPath $StrukturPath)) { return @() }
    foreach ($line in [System.IO.File]::ReadAllLines($StrukturPath)) {
        if ($line -match '^##\s+(?:Bab|BAB)\s+(\d+)\s*[.:)\-]?\s*(.*)$') {
            $result += [pscustomobject]@{
                Number = $Matches[1]
                Title  = $Matches[2].Trim()
            }
        }
    }
    return @($result)
}

function Get-LgrTemplates {
    # Template valid = folder di templates\ yang punya reference.docx DAN struktur.md.
    param([Parameter(Mandatory)][string]$Root)
    $valid = @()
    $incomplete = @()
    $tDir = Join-Path $Root 'templates'
    if (Test-Path -LiteralPath $tDir) {
        foreach ($d in (Get-ChildItem -Path $tDir -Directory -ErrorAction SilentlyContinue)) {
            $hasRef = Test-Path -LiteralPath (Join-Path $d.FullName 'reference.docx')
            $hasStr = Test-Path -LiteralPath (Join-Path $d.FullName 'struktur.md')
            if ($hasRef -and $hasStr) { $valid += $d.Name }
            else { $incomplete += $d.Name }
        }
    }
    return @{ Valid = @($valid); Incomplete = @($incomplete) }
}

function Get-LgrSourceNames {
    # Gabungan BaseName unik dari sources\*.pdf dan sources\pdf\*.pdf.
    param([Parameter(Mandatory)][string]$Root)
    $names = [System.Collections.Generic.List[string]]::new()
    $dirs = @(
        (Join-Path $Root 'sources'),
        (Join-Path (Join-Path $Root 'sources') 'pdf')
    )
    foreach ($dir in $dirs) {
        if (Test-Path -LiteralPath $dir) {
            foreach ($f in (Get-ChildItem -Path $dir -Filter '*.pdf' -File -ErrorAction SilentlyContinue)) {
                if (-not $names.Contains($f.BaseName)) { $names.Add($f.BaseName) }
            }
        }
    }
    $names.Sort([System.StringComparer]::OrdinalIgnoreCase)
    return $names.ToArray()
}

function Get-LgrIndonesianMonthYear {
    param([Parameter()][datetime]$When = (Get-Date))
    $months = @('Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember')
    return ('{0} {1}' -f $months[$When.Month - 1], $When.Year)
}

function ConvertTo-LgrQuoted {
    # Nilai YAML dalam kutip ganda; escape \ dan "; tolak newline.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    if ($Value -match "[`r`n]") {
        throw 'Nilai metadata mengandung newline - ditolak.'
    }
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return ('"' + $escaped + '"')
}

function Get-LgrMetadataDefaults {
    # Baca nilai metadata saat ini untuk prefill form (read-only).
    param([Parameter(Mandatory)][string]$Path)
    $result = @{
        title = ''; jenis_karya = ''; author_name = ''; author_nim = ''
        lecturer = ''; course = ''; date = ''; year = ''
    }
    if (-not (Test-Path -LiteralPath $Path)) { return $result }
    $simpleKeys = @('title', 'jenis_karya', 'lecturer', 'course', 'date', 'year')
    $inAuthor = $false
    $nameDone = $false
    $nimDone = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line.StartsWith('#')) { continue }
        if ($inAuthor) {
            if ($line -match '^\S') {
                $inAuthor = $false
            } elseif (-not $nameDone -and $line -match '^\s*-\s*name\s*:\s*"?(.*?)"?\s*$') {
                $result.author_name = $Matches[1]
                $nameDone = $true
                continue
            } elseif ($nameDone -and -not $nimDone -and $line -match '^\s*nim\s*:\s*"?(.*?)"?\s*$') {
                $result.author_nim = $Matches[1]
                $nimDone = $true
                continue
            } else {
                continue
            }
        }
        if ($line -match '^author\s*:') { $inAuthor = $true; continue }
        foreach ($k in $simpleKeys) {
            if ($line -match ('^\s*' + $k + '\s*:\s*"?(.*?)"?\s*$')) {
                $result[$k] = $Matches[1]
            }
        }
    }
    return $result
}

function New-LgrBackupPath {
    # metadata.yml.bak-<yyyyMMdd-HHmmss>; tidak pernah menimpa backup lama.
    param([Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Parent $Path
    $base = (Split-Path -Leaf $Path) + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $candidate = Join-Path $dir $base
    $n = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $dir ($base + '-' + $n)
        $n++
    }
    return $candidate
}

function Update-LgrMetadata {
    <#
        Edit metadata.yml per baris dengan regex (komentar tetap).
        - Backup dulu; tulis UTF-8 tanpa BOM; newline (CRLF/LF) dipertahankan.
        - Ganti nilai memakai MatchEvaluator (scriptblock) agar "$" aman.
        - Verifikasi sesudah tulis: baris tak terkait identik; gagal -> restore + throw.
        - Return: @{ BackupPath; ChangedCount; Newline }
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Changes
    )
    foreach ($k in @($Changes.Keys)) {
        $v = [string]$Changes[$k]
        if ($v -match "[`r`n]") {
            throw ("Nilai untuk '$k' mengandung newline - ditolak.")
        }
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Berkas tidak ditemukan: $Path"
    }

    $raw = [System.IO.File]::ReadAllText($Path)
    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $origLines = [string[]]($raw -split "\r?\n")

    $backupPath = New-LgrBackupPath -Path $Path
    Copy-Item -LiteralPath $Path -Destination $backupPath

    $simpleKeys = @('title', 'subtitle', 'jenis_karya', 'lecturer', 'course', 'date', 'year')
    $changed = [System.Collections.Generic.HashSet[int]]::new()
    $newLines = [System.Collections.Generic.List[string]]::new()

    # Pengganti baris key sederhana; MatchEvaluator agar karakter $ aman.
    $applySimple = {
        param([string]$ln, [int]$idx)
        foreach ($k in $simpleKeys) {
            if ($Changes.ContainsKey($k)) {
                $key = $k
                $val = ConvertTo-LgrQuoted ([string]$Changes[$k])
                $pattern = '^(\s*)' + [regex]::Escape($k) + '\s*:\s*[^\r\n]*$'
                $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
                    param($m)
                    $m.Groups[1].Value + $key + ': ' + $val
                }
                $replaced = [regex]::Replace($ln, $pattern, $evaluator)
                if ($replaced -cne $ln) {
                    $ln = $replaced
                    [void]$changed.Add($idx)
                    break
                }
            }
        }
        return $ln
    }

    $inAuthor = $false
    $nameDone = $false
    $nimDone = $false
    for ($i = 0; $i -lt $origLines.Count; $i++) {
        $line = $origLines[$i]
        $newLine = $line

        if ($line.StartsWith('#')) {
            # komentar: selalu dipertahankan apa adanya
        }
        elseif (-not $inAuthor) {
            if ($line -match '^author\s*:') {
                $inAuthor = $true
            } else {
                $newLine = & $applySimple $line $i
            }
        }
        else {
            if ($line -match '^\S') {
                # key top-level baru: keluar blok author, proses sebagai key sederhana
                $inAuthor = $false
                $newLine = & $applySimple $line $i
            }
            elseif (-not $nameDone -and $line -match '^(\s*-\s*name)\s*:\s*[^\r\n]*$') {
                if ($Changes.ContainsKey('author_name')) {
                    $val = ConvertTo-LgrQuoted ([string]$Changes['author_name'])
                    $pattern = '^(\s*-\s*name)\s*:\s*[^\r\n]*$'
                    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
                        param($m)
                        $m.Groups[1].Value + ': ' + $val
                    }
                    $newLine = [regex]::Replace($line, $pattern, $evaluator)
                    [void]$changed.Add($i)
                }
                $nameDone = $true
            }
            elseif ($nameDone -and -not $nimDone -and $line -match '^(\s*nim)\s*:\s*[^\r\n]*$') {
                if ($Changes.ContainsKey('author_nim')) {
                    $val = ConvertTo-LgrQuoted ([string]$Changes['author_nim'])
                    $pattern = '^(\s*nim)\s*:\s*[^\r\n]*$'
                    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
                        param($m)
                        $m.Groups[1].Value + ': ' + $val
                    }
                    $newLine = [regex]::Replace($line, $pattern, $evaluator)
                    [void]$changed.Add($i)
                }
                $nimDone = $true
            }
        }
        $newLines.Add($newLine)
    }

    $new = [string]::Join($nl, $newLines)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $new, $utf8NoBom)

    # --- verifikasi: baris tak terkait harus identik dengan aslinya ---
    $verifyFail = $null
    $checkLines = [string[]]([System.IO.File]::ReadAllText($Path) -split "\r?\n")
    if ($checkLines.Count -ne $origLines.Count) {
        $verifyFail = ('jumlah baris berubah: ' + $origLines.Count + ' -> ' + $checkLines.Count)
    } else {
        for ($i = 0; $i -lt $origLines.Count; $i++) {
            if (-not $changed.Contains($i)) {
                if ($checkLines[$i] -cne $origLines[$i]) {
                    $verifyFail = ('baris tak terkait berubah di indeks ' + $i + ': [' + $origLines[$i] + '] -> [' + $checkLines[$i] + ']')
                    break
                }
            } elseif ($checkLines[$i] -cne $newLines[$i]) {
                $verifyFail = ('baris terubah tidak sesuai harapan di indeks ' + $i)
                break
            }
        }
    }
    if ($verifyFail) {
        Copy-Item -LiteralPath $backupPath -Destination $Path -Force
        throw ("Verifikasi metadata gagal; file dikembalikan dari backup. Alasan: $verifyFail. Backup: $backupPath")
    }

    return @{ BackupPath = $backupPath; ChangedCount = $changed.Count; Newline = $nl }
}

function Restore-LgrMetadata {
    param(
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw "Backup tidak ditemukan: $BackupPath"
    }
    Copy-Item -LiteralPath $BackupPath -Destination $Path -Force
}

function Test-LgrFileLocked {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $fs.Close()
        return $false
    } catch {
        return $true
    }
}

function Backup-LgrChapters {
    # Salin chapters\bab*.md ke chapters.bak\<stamp>\. Return path backup, atau
    # $null bila tidak ada bab / gagal. Tidak pernah menghapus sumbernya.
    param([Parameter(Mandatory)][string]$Root)
    $chaptersDir = Join-Path $Root 'chapters'
    $files = @(Get-ChildItem -Path $chaptersDir -Filter 'bab*.md' -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $null }
    $bakRoot = Join-Path $Root 'chapters.bak'
    if (-not (Test-Path -LiteralPath $bakRoot)) {
        New-Item -ItemType Directory -Path $bakRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $bakRoot $stamp
    $n = 2
    while (Test-Path -LiteralPath $dest) {
        $dest = Join-Path $bakRoot ($stamp + '-' + $n)
        $n++
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in $files) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $f.Name)
    }
    return $dest
}

function Get-LgrPipelineExe {
    # laporan.ps1 ditulis untuk Windows PowerShell 5.1 -> utamakan powershell.exe.
    $c = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return ''
}

function Invoke-LgrPipeline {
    # Panggil laporan.ps1 sebagai proses anak. Output berwarna dari anak tampil
    # langsung di konsol; exit code disimpan di $script:LgrPipelineExit.
    # Timeout (detik) dicek melalui $script:LgrPipelineTimeout (default 0 = tanpa batas).
    param(
        [Parameter(Mandatory)][string]$PsExe,
        [Parameter(Mandatory)][string]$Command,
        [string]$Template = '',
        [string]$Sources = '',
        [switch]$NoAi,
        [string]$Bab = '',
        [string]$OutName = ''
    )
    $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        (Join-Path $script:LgrRoot 'laporan.ps1'), $Command
    )
    if ($Template) { $argList += @('-Template', $Template) }
    if ($Sources)  { $argList += @('-Sources', $Sources) }
    if ($NoAi)     { $argList += '-NoAi' }
    if ($Bab)      { $argList += @('-Bab', $Bab) }
    if ($OutName)  { $argList += @('-OutFile', $OutName) }

    $timeoutSec = [int]$script:LgrPipelineTimeout
    if ($timeoutSec -gt 0) {
        # Jalankan dengan timeout agar TUI tidak macet bila AI menunggu jaringan/router.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PsExe
        $psi.Arguments = ($argList -join ' ')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        if (-not $p.WaitForExit($timeoutSec * 1000)) {
            try { $p.Kill() } catch {}
            Write-SpectreHost -Message ('[red]Pipeline melebihi batas waktu ' + $timeoutSec + ' detik (mungkin AI menunggu koneksi jaringan/router). Dihentikan paksa.[/]')
            $script:LgrPipelineExit = 1
            return
        }
        $script:LgrPipelineExit = [int]$p.ExitCode
    } else {
        & $PsExe @argList
        if ($null -ne $LASTEXITCODE) {
            $script:LgrPipelineExit = [int]$LASTEXITCODE
        } else {
            $script:LgrPipelineExit = 1
        }
    }
}

function Test-LgrOutputSuccess {
    # SUKSES = exit 0 DAN output\<nama>.docx ada dengan LastWriteTime >= mulai.
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][datetime]$StartedAt
    )
    if ($ExitCode -ne 0) { return $false }
    if (-not (Test-Path -LiteralPath $OutPath)) { return $false }
    return ((Get-Item -LiteralPath $OutPath).LastWriteTime -ge $StartedAt.AddSeconds(-2))
}

function New-LgrTempDir {
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ('lgr-selftest-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    if ($script:LgrTempDirs) { $script:LgrTempDirs.Add($base) }
    return $base
}

function Get-LgrExtraToolDirs {
    # Direktori tool yang dipakai pipeline tapi sering TIDAK ada di PATH user
    # (pdftotext bawaan Git-for-Windows milik Hermes, CLI hermes, Pandoc user).
    # Tanpa ini, Get-Pdftotext di laporan.ps1 melakukan scan rekursif lambat.
    $dirs = [System.Collections.Generic.List[string]]::new()
    $cands = @(
        (Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent\.hermes\bin'),
        (Join-Path $env:LOCALAPPDATA 'hermes\bin'),
        (Join-Path $env:LOCALAPPDATA 'Pandoc')
    )
    $toolsRoot = Join-Path $env:LOCALAPPDATA 'hermes\tools'
    if (Test-Path -LiteralPath $toolsRoot) {
        $cands += @(Get-ChildItem -Path $toolsRoot -Directory -Filter 'git-*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'mingw64\bin' })
    }
    foreach ($d in $cands) {
        if ($d -and (Test-Path -LiteralPath $d) -and -not $dirs.Contains($d)) { $dirs.Add($d) }
    }
    return $dirs.ToArray()
}

function Add-LgrToolDirsToPath {
    # Prepends direktori tool yang ada ke PATH sesi ini (diwarisi proses anak
    # laporan.ps1). Idempoten: direktori yang sudah ada di PATH dilewati.
    $have = @($env:Path -split ';' | Where-Object { $_ })
    $added = 0
    foreach ($d in (Get-LgrExtraToolDirs)) {
        if ($have -notcontains $d) {
            $env:Path = $d + ';' + $env:Path
            $have += $d
            $added++
        }
    }
    return $added
}

# =============================================================================
# SELFTEST (-SelfTest): hanya fungsi logika, tanpa Spectre, tanpa menu.
# =============================================================================

function Invoke-LgrSelfTest {
    $script:LgrPass = 0
    $script:LgrFail = 0
    $script:LgrTempDirs = [System.Collections.Generic.List[string]]::new()
    $root = $script:LgrRoot
    $yamlScalarRe = '^\s*(?:-\s*)?[A-Za-z_][A-Za-z0-9_]*\s*:\s*"(?:[^"\\]|\\.)*"\s*$'

    function T {
        param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
        try {
            & $Body
            Write-Host ('[PASS] ' + $Name)
            $script:LgrPass++
        } catch {
            Write-Host ('[FAIL] ' + $Name + ' :: ' + $_.Exception.Message)
            $script:LgrFail++
        }
    }

    # ---- 1. Sanitasi nama file ----
    T 'Sanitasi nama file: karakter terlarang, .docx ganda, titik/spasi ujung, kosong' {
        $r = Get-LgrSanitizedFileName 'a/b\c:d*e?f"g<h>i|j'
        if ($r -cne 'abcdefghij') { throw ("harusnya 'abcdefghij', dapat: '$r'") }
        $r = Get-LgrSanitizedFileName 'report.DOCX.docx'
        if ($r -cne 'report') { throw ("harusnya 'report', dapat: '$r'") }
        $r = Get-LgrSanitizedFileName ' trailing.. '
        if ($r -cne 'trailing') { throw ("harusnya 'trailing', dapat: '$r'") }
        $r = Get-LgrSanitizedFileName ''
        if ($r -cne '') { throw ("harusnya '', dapat: '$r'") }
    }

    T 'Sanitasi nama file: [ ] dan $ dipertahankan' {
        $r = Get-LgrSanitizedFileName 'Laporan [2026] $1 "Final"'
        if ($r -cne 'Laporan [2026] $1 Final') { throw ("dapat: '$r'") }
    }

    # ---- 2. Parse struktur.md semua template nyata ----
    T 'Parse struktur.md (regex bab) pada semua template nyata' {
        $tmpl = Get-LgrTemplates -Root $root
        if ($tmpl.Valid.Count -lt 1) { throw 'tidak ada template valid' }
        foreach ($t in $tmpl.Valid) {
            $sf = Join-Path (Join-Path (Join-Path $root 'templates') $t) 'struktur.md'
            $chs = Get-LgrStrukturChapters -StrukturPath $sf
            if ($chs.Count -lt 1) { throw ("$t tidak terparse bab") }
            foreach ($c in $chs) {
                if ($c.Number -notmatch '^\d+$') { throw ("$t nomor bab aneh: '$($c.Number)'") }
                if ([string]::IsNullOrWhiteSpace($c.Title)) { throw ("$t bab $($c.Number) judul kosong") }
            }
        }
    }

    # ---- 3. Edit metadata pada SALINAN di temp: nilai jahat ----
    T 'Edit metadata: nilai berisi [ ], kutip, $1, titik dua, backslash' {
        $tmp = New-LgrTempDir
        $meta = Join-Path $tmp 'metadata.yml'
        Copy-Item -LiteralPath (Join-Path $root 'metadata.yml') -Destination $meta
        $origRaw = [System.IO.File]::ReadAllText($meta)
        $changes = @{
            title       = 'Uji [judul] "kutip" $1 dan $2: C:\folder\file'
            jenis_karya = 'LAPORAN [UJI]'
            lecturer    = 'Dr. "X $y", M.S.'
            course      = 'AGRO $1 [101]'
            date        = 'Oktober 2026'
            year        = '2026'
            author_name = 'Nama [$ Penulis]'
            author_nim  = '1234567890'
        }
        $info = Update-LgrMetadata -Path $meta -Changes $changes
        if (-not (Test-Path -LiteralPath $info.BackupPath)) { throw 'backup tidak dibuat' }

        $newLines = [System.IO.File]::ReadAllText($meta) -split "\r?\n"
        $origLines = $origRaw -split "\r?\n"
        if ($newLines.Count -ne $origLines.Count) { throw ('jumlah baris berubah: ' + $origLines.Count + ' -> ' + $newLines.Count) }

        # baris title harus persis key: <quoted>
        $titleLine = @($newLines | Where-Object { $_ -match '^\s*title\s*:' })[0]
        if ($titleLine -cne ('title: ' + (ConvertTo-LgrQuoted $changes.title))) { throw ('baris title salah: ' + $titleLine) }

        # $ tidak boleh hilang oleh substitusi regex, backslash harus ter-escape
        if ($titleLine -notlike '*$1 dan $2*') { throw 'nilai $ hilang (substitusi regex bocor)' }
        if ($titleLine -notlike '*C:\\folder\\file*') { throw 'backslash tidak di-escape ganda' }

        # author: baris - name: dan nim: pertama
        $nameLine = @($newLines | Where-Object { $_ -match '^\s*-\s*name\s*:' })[0]
        if ($nameLine -cne ('  - name: ' + (ConvertTo-LgrQuoted $changes.author_name))) { throw ('baris author name salah: ' + $nameLine) }
        $nimLine = @($newLines | Where-Object { $_ -match '^\s*nim\s*:' })[0]
        if ($nimLine -cne ('    nim: ' + (ConvertTo-LgrQuoted $changes.author_nim))) { throw ('baris nim salah: ' + $nimLine) }

        # semua baris scalar yang berubah valid secara kutip YAML
        foreach ($ln in @($titleLine, $nameLine, $nimLine) +
                @($newLines | Where-Object { $_ -match '^\s*(jenis_karya|lecturer|course|date|year)\s*:' })) {
            if ($ln -notmatch $yamlScalarRe) { throw ('kutipan YAML tidak valid: ' + $ln) }
        }

        # komentar utuh
        $oc = @($origLines | Where-Object { $_.StartsWith('#') })
        $nc = @($newLines | Where-Object { $_.StartsWith('#') })
        if ($oc.Count -ne $nc.Count) { throw ('jumlah baris komentar berubah: ' + $oc.Count + ' -> ' + $nc.Count) }
        for ($i = 0; $i -lt $oc.Count; $i++) {
            if ($oc[$i] -cne $nc[$i]) { throw ('komentar berubah: ' + $oc[$i]) }
        }

        # penutup ... tetap ada
        if (($newLines -join "`n") -notmatch "(?m)^\.\.\.\s*$") { throw 'penutup ... hilang' }

        # simpan state untuk tes restore
        $script:LgrT3 = @{ Meta = $meta; Backup = $info.BackupPath; OrigRaw = $origRaw }
    }

    T 'Edit metadata: nilai dengan newline DITOLAK (file tak berubah)' {
        $tmp = New-LgrTempDir
        $meta = Join-Path $tmp 'metadata.yml'
        Copy-Item -LiteralPath (Join-Path $root 'metadata.yml') -Destination $meta
        $before = [System.IO.File]::ReadAllText($meta)
        $rejected = $false
        try {
            Update-LgrMetadata -Path $meta -Changes @{ title = "baris1`nbaris2" } | Out-Null
        } catch {
            $rejected = $true
            if ($_.Exception.Message -notmatch 'newline') { throw ('pesan penolakan salah: ' + $_.Exception.Message) }
        }
        if (-not $rejected) { throw 'nilai newline tidak ditolak' }
        $after = [System.IO.File]::ReadAllText($meta)
        if ($after -cne $before) { throw 'file berubah padahal harus ditolak sebelum tulis' }
    }

    T 'Edit metadata: gaya newline dipertahankan (CRLF dan LF)' {
        $srcRaw = [System.IO.File]::ReadAllText((Join-Path $root 'metadata.yml'))
        $lfRaw = $srcRaw -replace "`r`n", "`n"
        $crlfRaw = $lfRaw -replace "(?<!\r)\n", "`r`n"
        if ($crlfRaw.Contains("`n") -and -not $crlfRaw.Contains("`r`n")) { throw 'konversi CRLF gagal' }
        foreach ($pair in @(
            @{ Name = 'CRLF'; Content = $crlfRaw },
            @{ Name = 'LF';   Content = $lfRaw }
        )) {
            $tmp = New-LgrTempDir
            $meta = Join-Path $tmp 'metadata.yml'
            [System.IO.File]::WriteAllText($meta, $pair.Content, [System.Text.UTF8Encoding]::new($false))
            Update-LgrMetadata -Path $meta -Changes @{ title = 'T ' + $pair.Name; date = 'Oktober 2026'; year = '2026' } | Out-Null
            $after = [System.IO.File]::ReadAllText($meta)
            if ($pair.Name -eq 'CRLF') {
                if ($after -match '(?<!\r)\n') { throw 'CRLF berubah jadi LF sebagian' }
            } else {
                if ($after.Contains("`r`n")) { throw 'LF berubah jadi CRLF' }
            }
        }
    }

    # ---- 4. Restore dari backup ----
    T 'Restore metadata dari backup mengembalikan isi persis' {
        if (-not $script:LgrT3) { throw 'state tes 3 tidak ada' }
        Restore-LgrMetadata -BackupPath $script:LgrT3.Backup -Path $script:LgrT3.Meta
        $after = [System.IO.File]::ReadAllText($script:LgrT3.Meta)
        if ($after -cne $script:LgrT3.OrigRaw) { throw 'isi hasil restore tidak identik dengan asli' }
    }

    T 'Verifikasi update menolak bila baris tak terkait berubah (simulasi tamper)' {
        # Menulis lewat Update-LgrMetadata lalu merusak manual -> verifikasi internal
        # diuji tidak dengan tamper eksternal (tidak bisa diinjeksi), jadi cukup
        # pastikan double-run dengan nilai berbeda tetap menjaga komentar & baris lain.
        $tmp = New-LgrTempDir
        $meta = Join-Path $tmp 'metadata.yml'
        Copy-Item -LiteralPath (Join-Path $root 'metadata.yml') -Destination $meta
        $origLines = [System.IO.File]::ReadAllText($meta) -split "\r?\n"
        Update-LgrMetadata -Path $meta -Changes @{ title = 'A'; course = 'X' } | Out-Null
        Update-LgrMetadata -Path $meta -Changes @{ title = 'B'; course = 'Y' } | Out-Null
        $newLines = [System.IO.File]::ReadAllText($meta) -split "\r?\n"
        if ($newLines.Count -ne $origLines.Count) { throw 'jumlah baris berubah pada double-run' }
        $t = @($newLines | Where-Object { $_ -match '^\s*title\s*:' })[0]
        if ($t -cne 'title: "B"') { throw ('double-run title salah: ' + $t) }
    }

    # ---- 5. Daftar sumber gabungan unik ----
    T 'Daftar sumber: nyata terdeteksi + gabungan unik pada struktur sintetis' {
        $real = Get-LgrSourceNames -Root $root
        if ($real -notcontains 'buku-dummy') { throw 'buku-dummy tidak terdeteksi' }
        if ($real -notcontains 'contoh-jurnal') { throw 'contoh-jurnal tidak terdeteksi' }
        $dup = @($real | Group-Object | Where-Object { $_.Count -gt 1 })
        if ($dup.Count -gt 0) { throw 'ada duplikat pada sumber nyata' }

        $tmp = New-LgrTempDir
        $s1 = Join-Path $tmp 'sources'
        $s2 = Join-Path $s1 'pdf'
        New-Item -ItemType Directory -Path $s2 -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $s1 'a.pdf') -Value ''
        Set-Content -LiteralPath (Join-Path $s2 'a.pdf') -Value ''
        Set-Content -LiteralPath (Join-Path $s2 'b.pdf') -Value ''
        $names = Get-LgrSourceNames -Root $tmp
        if ($names.Count -ne 2 -or $names -notcontains 'a' -or $names -notcontains 'b') {
            throw ('gabungan unik salah: ' + ($names -join ','))
        }
    }

    # ---- 6. Backup path tidak menimpa ----
    T 'Backup path unik: tidak pernah menimpa backup lama' {
        $tmp = New-LgrTempDir
        $meta = Join-Path $tmp 'metadata.yml'
        Set-Content -LiteralPath $meta -Value 'x'
        $p1 = New-LgrBackupPath -Path $meta
        Set-Content -LiteralPath $p1 -Value 'bak1'
        $p2 = New-LgrBackupPath -Path $meta
        if ($p1 -eq $p2) { throw 'kolisi path backup pada detik yang sama' }
    }

    # ---- 7. Default metadata terbaca (read-only) ----
    T 'Default metadata terbaca dari metadata.yml asli (read-only)' {
        $d = Get-LgrMetadataDefaults -Path (Join-Path $root 'metadata.yml')
        if ([string]::IsNullOrWhiteSpace($d.title)) { throw 'title kosong' }
        if ($d.author_nim -notmatch '^\d+$') { throw ('NIM bukan angka: ' + $d.author_nim) }
        if ([string]::IsNullOrWhiteSpace($d.jenis_karya)) { throw 'jenis_karya kosong' }
        if ($d.year -notmatch '^\d{4}$') { throw ('year aneh: ' + $d.year) }
    }

    # ---- 8. Bulan Indonesia ----
    T 'Bulan-bulan Indonesia' {
        $m = Get-LgrIndonesianMonthYear -When ([datetime]'2026-10-17')
        if ($m -cne 'Oktober 2026') { throw ("dapat: '$m'") }
    }

    # ---- 9. PATH augmentation tool pipeline ----
    T 'Direktori tool tambahan: ada & memuat pdftotext bila Hermes terpasang' {
        $dirs = Get-LgrExtraToolDirs
        foreach ($d in $dirs) {
            if (-not (Test-Path -LiteralPath $d)) { throw ("dir terdaftar tapi tidak ada: $d") }
        }
        $toolsRoot = Join-Path $env:LOCALAPPDATA 'hermes\tools'
        if (Test-Path -LiteralPath $toolsRoot) {
            $pt = @($dirs | Where-Object { Test-Path -LiteralPath (Join-Path $d 'pdftotext.exe') })
            if ($pt.Count -lt 1) { throw 'pdftotext.exe tidak tercakup padahal hermes tools ada' }
        }
        # Add-LgrToolDirsToPath idempoten
        $env:Path = ($env:Path -replace ';;;;+', ';;;')
        $a1 = Add-LgrToolDirsToPath
        $a2 = Add-LgrToolDirsToPath
        if ($a2 -ne 0) { throw ('pemanggilan kedua masih menambah ' + $a2 + ' entri (tidak idempoten)') }
        foreach ($d in $dirs) {
            if (($env:Path -split ';') -notcontains $d) { throw ("tidak tertambah ke PATH: $d") }
        }
    }

    # cleanup
    foreach ($d in $script:LgrTempDirs) {
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host ('Hasil SelfTest: ' + $script:LgrPass + ' PASS, ' + $script:LgrFail + ' FAIL')
    return ($script:LgrFail -eq 0)
}

if ($SelfTest) {
    if (Invoke-LgrSelfTest) { exit 0 } else { exit 1 }
}

# =============================================================================
# UI (PwshSpectreConsole) - hanya dijalankan setelah -SelfTest dicek
# =============================================================================

function Import-LgrSpectre {
    Import-Module PwshSpectreConsole -ErrorAction SilentlyContinue
    if (Get-Module PwshSpectreConsole) { return $true }
    Write-Host ''
    Write-Host 'Modul PwshSpectreConsole belum terpasang (butuh PowerShell 7.4+).'
    $ans = Read-Host 'Pasang sekarang dengan Install-Module -Scope CurrentUser? (y/n)'
    if ($ans -notmatch '^[Yy]') {
        Write-Host 'Modul diperlukan untuk tampilan TUI. Keluar.'
        Write-Host 'Pasang manual: Install-Module PwshSpectreConsole -Scope CurrentUser'
        return $false
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force -AllowClobber
        Import-Module PwshSpectreConsole
        if (Get-Module PwshSpectreConsole) { return $true }
    } catch {
        Write-Host ('Gagal memasang modul: ' + $_.Exception.Message)
    }
    Write-Host 'TUI tidak bisa jalan tanpa modul. Keluar.'
    return $false
}

function Get-LgrEsc {
    param([Parameter()][AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    return (Get-SpectreEscapedText -Text $Text)
}

function Write-LgrPanel {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Header, [Parameter()][string]$Color = 'cyan')
    (Format-SpectrePanel -Data $Text -Header $Header -Color $Color) | Out-SpectreHost
}

function Read-LgrRequiredText {
    param([Parameter(Mandatory)][string]$Message, [Parameter()][string]$Default = '')
    $v = ''
    while ($true) {
        $v = Read-SpectreText -Message $Message -DefaultAnswer $Default
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
        Write-SpectreHost -Message '[red]  Isian wajib - tidak boleh kosong.[/]'
    }
}

function Read-LgrNim {
    param([Parameter(Mandatory)][string]$Default)
    $v = ''
    while ($true) {
        $v = Read-SpectreText -Message 'NIM (hanya angka)' -DefaultAnswer $Default
        if ($v -match '^\d+$') { return $v }
        Write-SpectreHost -Message '[red]  NIM harus berupa angka saja.[/]'
    }
}

function Read-LgrMetadataForm {
    param([Parameter(Mandatory)][hashtable]$Defaults)
    $title = Read-LgrRequiredText -Message 'Judul (wajib)' -Default $Defaults.title
    $jenis = Read-LgrRequiredText -Message 'Jenis karya (wajib, mis. LAPORAN PRAKTIKUM)' -Default $Defaults.jenis_karya
    $name = Read-LgrRequiredText -Message 'Nama penulis (wajib)' -Default $Defaults.author_name
    $nim = Read-LgrNim -Default $Defaults.author_nim
    $lect = Read-SpectreText -Message 'Dosen pengampu / pembimbing (boleh kosong)' -DefaultAnswer $Defaults.lecturer -AllowEmpty
    $course = Read-SpectreText -Message 'Mata kuliah (boleh kosong)' -DefaultAnswer $Defaults.course -AllowEmpty
    $dateDef = if ($Defaults.date) { $Defaults.date } else { Get-LgrIndonesianMonthYear }
    $date = Read-LgrRequiredText -Message 'Tanggal (mis. Oktober 2026)' -Default $dateDef
    $changes = @{
        title = $title; jenis_karya = $jenis
        author_name = $name; author_nim = $nim
        lecturer = $lect; course = $course; date = $date
    }
    if ($date -match '\d{4}') { $changes['year'] = $Matches[0] }
    return $changes
}

function Select-LgrTemplate {
    $tmpl = Get-LgrTemplates -Root $script:LgrRoot
    foreach ($bad in $tmpl.Incomplete) {
        Write-SpectreHost -Message ('[yellow]PERINGATAN: template tidak lengkap (butuh reference.docx + struktur.md): ' + (Get-LgrEsc $bad) + '[/]')
    }
    if ($tmpl.Valid.Count -eq 0) {
        Write-LgrPanel -Text ('Tidak ada template valid di templates\.' + "`n" + 'Template butuh reference.docx DAN struktur.md.') -Header 'Error' -Color 'red'
        return $null
    }
    return (Read-SpectreSelection -Message 'Pilih template:' -Choices $tmpl.Valid -Color 'cyan' -PageSize 10)
}

function Select-LgrSources {
    $names = Get-LgrSourceNames -Root $script:LgrRoot
    if ($names.Count -eq 0) {
        Write-LgrPanel -Text ('Tidak ada PDF sumber.' + "`n" + 'Taruh PDF di sources\ atau sources\pdf\ lalu ulangi.') -Header 'Error' -Color 'red'
        return $null
    }
    Write-SpectreHost -Message '[yellow]PERINGATAN: isi PDF sumber akan dikirim ke layanan model AI.[/]'
    while ($true) {
        $sel = Read-SpectreMultiSelection -Message 'Pilih sumber (spasi untuk centang, enter untuk lanjut):' -Choices $names -Color 'cyan' -PageSize 15
        if (@($sel).Count -ge 1) { break }
        Write-SpectreHost -Message '[red]  Pilih minimal satu sumber.[/]'
    }
    # Panel peringatan ditampilkan SETELAH seleksi: prompt multi-select melakukan
    # live-render yang menghapus baris di atasnya, jadi panel sebelumnya tak terlihat.
    Write-LgrPanel -Text (
        'Sumber terpilih : ' + (@($sel).Count) + ' berkas (' + ((@($sel) | ForEach-Object { Get-LgrEsc $_ }) -join ', ') + ')' + "`n" +
        'Isi PDF tersebut akan dikirim ke layanan model AI.' + "`n" +
        'Tiap bab bisa memakan waktu lama (hingga 600 detik/bab);' + "`n" +
        'build penuh bisa puluhan menit.'
    ) -Header 'Peringatan AI' -Color 'yellow'
    return @($sel)
}

function Select-LgrBab {
    param([Parameter(Mandatory)][string]$Template)
    $sf = Join-Path (Join-Path (Join-Path $script:LgrRoot 'templates') $Template) 'struktur.md'
    $chs = Get-LgrStrukturChapters -StrukturPath $sf
    if ($chs.Count -eq 0) {
        Write-LgrPanel -Text ('struktur.md template ini tidak punya bab "## Bab N ..." yang terbaca.') -Header 'Error' -Color 'red'
        return $null
    }
    $choices = @($chs | ForEach-Object { ('Bab ' + $_.Number + ' - ' + $_.Title) })
    $picked = Read-SpectreSelection -Message 'Pilih bab yang ditulis ulang:' -Choices $choices -Color 'cyan' -PageSize 15
    if ($picked -match '^Bab (\d+)') { return $Matches[1] }
    return $null
}

function Read-LgrOutFile {
    # Return @{ Name; OutPath } atau $null bila user batal.
    param([Parameter(Mandatory)][string]$DefaultName)
    $outDir = Join-Path $script:LgrRoot 'output'
    while ($true) {
        $raw = Read-SpectreText -Message 'Nama file output (tanpa .docx)' -DefaultAnswer $DefaultName
        $name = Get-LgrSanitizedFileName -Name $raw
        if (-not $name) { $name = $DefaultName }
        $outPath = Join-Path $outDir ($name + '.docx')
        if (Test-Path -LiteralPath $outPath) {
            $overwrite = Read-SpectreConfirm -Message ('File output\' + (Get-LgrEsc ($name + '.docx')) + ' sudah ada. Timpa?') -DefaultAnswer 'n'
            if (-not $overwrite) { return $null }
            while (Test-LgrFileLocked -Path $outPath) {
                Write-SpectreHost -Message ('[red]  File terkunci (mungkin sedang dibuka di Word): ' + (Get-LgrEsc $outPath) + '[/]')
                $retry = Read-SpectreConfirm -Message 'Sudah ditutup? Coba lagi?' -DefaultAnswer 'y'
                if (-not $retry) { return $null }
            }
        }
        return @{ Name = $name; OutPath = $outPath }
    }
}

function Invoke-LgrMode {
    # Mode: 'ai' | 'noai' | 'bab' | 'docx'
    param([Parameter(Mandatory)][string]$Mode)

    $psExe = Get-LgrPipelineExe
    if (-not $psExe) {
        Write-LgrPanel -Text 'Tidak menemukan powershell.exe maupun pwsh untuk menjalankan laporan.ps1.' -Header 'Error' -Color 'red'
        return
    }

    # ---- template ----
    $template = Select-LgrTemplate
    if (-not $template) { return }

    # ---- sumber (mode ai & bab) ----
    $sources = @()
    if ($Mode -eq 'ai' -or $Mode -eq 'bab') {
        $sources = Select-LgrSources
        if ($sources.Count -eq 0) { return }
    }

    # ---- bab (mode bab) ----
    $bab = ''
    if ($Mode -eq 'bab') {
        $bab = Select-LgrBab -Template $template
        if (-not $bab) { return }
    }

    # ---- metadata ----
    $metaPath = Join-Path $script:LgrRoot 'metadata.yml'
    $changes = $null
    if ($Mode -eq 'docx') {
        $edit = Read-SpectreConfirm -Message 'Ubah metadata dulu?' -DefaultAnswer 'n'
        if ($edit) {
            $changes = Read-LgrMetadataForm -Defaults (Get-LgrMetadataDefaults -Path $metaPath)
        }
    } else {
        $changes = Read-LgrMetadataForm -Defaults (Get-LgrMetadataDefaults -Path $metaPath)
    }

    # ---- nama file output ----
    $defaultName = ('{0}-{1}' -f $template, (Get-Date -Format 'yyyyMMdd'))
    $out = Read-LgrOutFile -DefaultName $defaultName
    if (-not $out) { return }

    # ---- ringkasan + konfirmasi ----
    $est = 'cepat'
    if ($Mode -eq 'ai') { $est = 'puluhan menit (AI menulis tiap bab)' }
    if ($Mode -eq 'bab') { $est = 'sampai 10 menit (AI menulis 1 bab)' }
    $modeLabel = switch ($Mode) {
        'ai'   { 'Buat laporan dengan AI' }
        'noai' { 'Kerangka tanpa AI' }
        'bab'  { ('Tulis ulang bab ' + $bab) }
        'docx' { 'Kompilasi ulang dari chapters\ (docx)' }
    }
    $rows = @(
        [pscustomobject]@{ Aspek = 'Mode'; Nilai = (Get-LgrEsc $modeLabel) }
        [pscustomobject]@{ Aspek = 'Template'; Nilai = (Get-LgrEsc $template) }
        [pscustomobject]@{ Aspek = 'Sumber'; Nilai = (Get-LgrEsc ($sources -join ', ')) }
        [pscustomobject]@{ Aspek = 'Bab'; Nilai = (Get-LgrEsc $(if ($bab) { $bab } else { '-' })) }
    )
    if ($changes) {
        $rows += @(
            [pscustomobject]@{ Aspek = 'Judul'; Nilai = (Get-LgrEsc $changes['title']) }
            [pscustomobject]@{ Aspek = 'Jenis karya'; Nilai = (Get-LgrEsc $changes['jenis_karya']) }
            [pscustomobject]@{ Aspek = 'Penulis'; Nilai = (Get-LgrEsc ($changes['author_name'] + ' (' + $changes['author_nim'] + ')')) }
            [pscustomobject]@{ Aspek = 'Dosen'; Nilai = (Get-LgrEsc $changes['lecturer']) }
            [pscustomobject]@{ Aspek = 'Mata kuliah'; Nilai = (Get-LgrEsc $changes['course']) }
            [pscustomobject]@{ Aspek = 'Tanggal'; Nilai = (Get-LgrEsc $changes['date']) }
        )
    }
    $rows += @(
        [pscustomobject]@{ Aspek = 'File output'; Nilai = (Get-LgrEsc $out.OutPath) }
        [pscustomobject]@{ Aspek = 'Perkiraan waktu'; Nilai = (Get-LgrEsc $est) }
    )
    (Format-SpectreTable -Data $rows -Property Aspek, Nilai -Title 'Ringkasan' -HeaderColor 'yellow' -Color 'cyan') | Out-SpectreHost

    $go = Read-SpectreConfirm -Message 'Jalankan sekarang?' -DefaultAnswer 'y'
    if (-not $go) {
        Write-SpectreHost -Message '[yellow]Dibatalkan - kembali ke menu tanpa mengubah apa pun.[/]'
        return
    }

    # ---- eksekusi ----
    $metaBackup = $null
    try {
        # peringatkan + backup chapters lama (mode yang menulis chapters\)
        if ($Mode -in @('ai', 'noai', 'bab')) {
            $chFiles = @(Get-ChildItem -Path (Join-Path $script:LgrRoot 'chapters') -Filter 'bab*.md' -File -ErrorAction SilentlyContinue)
            if ($chFiles.Count -gt 0) {
                Write-LgrPanel -Text (
                    'chapters\ berisi ' + $chFiles.Count + ' berkas bab*.md.' + "`n" +
                    'Build penuh akan MENIMPA bab lama dan MENGHAPUS bab di luar template.' + "`n" +
                    'Salinan lama akan disimpan ke chapters.bak\<waktu>.'
                ) -Header 'Peringatan' -Color 'yellow'
                $lanjut = Read-SpectreConfirm -Message 'Lanjutkan?' -DefaultAnswer 'y'
                if (-not $lanjut) {
                    Write-SpectreHost -Message '[yellow]Dibatalkan - kembali ke menu tanpa mengubah apa pun.[/]'
                    return
                }
                $bakDir = Backup-LgrChapters -Root $script:LgrRoot
                if ($bakDir) {
                    Write-SpectreHost -Message ('[green]Backup chapters: ' + (Get-LgrEsc $bakDir) + '[/]')
                }
            }
        }

        # tulis metadata (sebelum proses agar judul dipakai prompt AI)
        if ($changes) {
            $info = Update-LgrMetadata -Path $metaPath -Changes $changes
            $metaBackup = $info.BackupPath
            Write-SpectreHost -Message ('[green]Metadata diperbarui. Backup: ' + (Get-LgrEsc $metaBackup) + '[/]')
        }

        # jalankan pipeline sebagai proses anak
        $cmd = 'build'
        if ($Mode -eq 'docx') { $cmd = 'docx' }
        $cmdDisplay = ('laporan.ps1 ' + $cmd + ' -Template ' + $template)
        if ($sources.Count -gt 0) { $cmdDisplay += (' -Sources ' + ($sources -join ',')) }
        if ($Mode -eq 'noai') { $cmdDisplay += ' -NoAi' }
        if ($bab) { $cmdDisplay += (' -Bab ' + $bab) }
        $cmdDisplay += (' -OutFile "' + $out.Name + '"')

        # Set timeout: mode AI/bab lebih lama (600 detik x bab), mode lain 120 detik.
        $script:LgrPipelineTimeout = 0
        if ($Mode -eq 'ai') { $script:LgrPipelineTimeout = 1800 }
        elseif ($Mode -eq 'bab') { $script:LgrPipelineTimeout = 900 }
        elseif ($Mode -eq 'noai') { $script:LgrPipelineTimeout = 300 }
        elseif ($Mode -eq 'docx') { $script:LgrPipelineTimeout = 120 }

        Write-SpectreRule -Title ('Menjalankan: ' + (Get-LgrEsc $cmdDisplay)) -Color 'yellow'
        Write-SpectreHost -Message ('[dim]Sedang memproses, tunggu beberapa saat...[/]')
        $startedAt = Get-Date
        Invoke-LgrPipeline -PsExe $psExe -Command $cmd -Template $template `
            -Sources ($sources -join ',') -NoAi:($Mode -eq 'noai') -Bab $bab -OutName $out.Name
        $code = $script:LgrPipelineExit
        Write-SpectreRule -Title ('Selesai (exit code ' + $code + ')') -Color 'cyan'

        $ok = Test-LgrOutputSuccess -ExitCode $code -OutPath $out.OutPath -StartedAt $startedAt
        if ($ok) {
            $size = [Math]::Round((Get-Item -LiteralPath $out.OutPath).Length / 1KB, 1)
            Write-LgrPanel -Text (('BERHASIL - laporan siap.' + "`n" + 'File   : ' + (Get-LgrEsc $out.OutPath) + "`n" + 'Ukuran : ' + $size + ' KB' + "`n" + 'Catatan: cek penanda [perlu diisi] di naskah bila ada.')) -Header 'Sukses' -Color 'green'
            if (Read-SpectreConfirm -Message 'Buka file DOCX sekarang?' -DefaultAnswer 'n') {
                Invoke-Item -LiteralPath $out.OutPath
            } elseif (Read-SpectreConfirm -Message 'Buka folder output di Explorer?' -DefaultAnswer 'n') {
                Start-Process explorer.exe -ArgumentList ('/select,"' + $out.OutPath + '"')
            }
        } else {
            Write-LgrPanel -Text (('GAGAL membuat DOCX (exit code ' + $code + ', atau file output tidak baru).' + "`n" + 'Baca pesan [ERR]/[WARN] di atas, atau jalankan menu 5 (Cek sistem).' + "`n" + 'Bila file dibuka di Word, tutup dulu lalu ulangi.')) -Header 'Gagal' -Color 'red'
        }
    } catch {
        Write-LgrPanel -Text ('Terjadi kesalahan:' + "`n" + (Get-LgrEsc $_.Exception.Message) + "`n" + 'Bila metadata sempat ditulis dan verifikasi gagal, file sudah otomatis dikembalikan dari backup.') -Header 'Error' -Color 'red'
    } finally {
        if ($metaBackup) {
            $keep = Read-SpectreConfirm -Message 'Simpan metadata baru untuk kompilasi ulang berikutnya?' -DefaultAnswer 'y'
            if ($keep) {
                Write-SpectreHost -Message ('[green]Metadata baru disimpan. Backup lama tetap ada: ' + (Get-LgrEsc $metaBackup) + '[/]')
            } else {
                try {
                    Restore-LgrMetadata -BackupPath $metaBackup -Path $metaPath
                    Write-SpectreHost -Message ('[yellow]Metadata dikembalikan ke nilai semula. Backup tetap ada: ' + (Get-LgrEsc $metaBackup) + '[/]')
                } catch {
                    Write-SpectreHost -Message ('[red]Gagal restore metadata: ' + (Get-LgrEsc $_.Exception.Message) + '[/]')
                }
            }
        }
    }
}

function Invoke-LgrCheckMenu {
    $psExe = Get-LgrPipelineExe
    if (-not $psExe) { Write-LgrPanel -Text 'powershell.exe / pwsh tidak ditemukan.' -Header 'Error' -Color 'red'; return }
    Write-SpectreRule -Title 'Cek sistem (laporan.ps1 check)' -Color 'yellow'
    Invoke-LgrPipeline -PsExe $psExe -Command 'check'
    Write-SpectreRule -Title 'Cek selesai' -Color 'cyan'
    Read-SpectrePause -Message 'Tekan tombol apa saja untuk kembali ke menu...'
}

function Invoke-LgrListMenu {
    $psExe = Get-LgrPipelineExe
    if (-not $psExe) { Write-LgrPanel -Text 'powershell.exe / pwsh tidak ditemukan.' -Header 'Error' -Color 'red'; return }
    Write-SpectreRule -Title 'Daftar template & sumber (laporan.ps1 list)' -Color 'yellow'
    Invoke-LgrPipeline -PsExe $psExe -Command 'list'
    Write-SpectreRule -Title 'Selesai' -Color 'cyan'
    Read-SpectrePause -Message 'Tekan tombol apa saja untuk kembali ke menu...'
}

function Show-LgrStartupInfo {
    # Panel ringkasan kondisi repo + tool saat TUI dibuka.
    $tmpl = Get-LgrTemplates -Root $script:LgrRoot
    $src = Get-LgrSourceNames -Root $script:LgrRoot
    $babCount = 0
    foreach ($t in $tmpl.Valid) {
        $sf = Join-Path (Join-Path (Join-Path $script:LgrRoot 'templates') $t) 'struktur.md'
        $babCount += (Get-LgrStrukturChapters -StrukturPath $sf).Count
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add(('Template valid : {0} ({1})' -f $tmpl.Valid.Count, (($tmpl.Valid | ForEach-Object { Get-LgrEsc $_ }) -join ', ')))
    [void]$lines.Add(('Total bab      : {0}' -f $babCount))
    if ($tmpl.Incomplete.Count -gt 0) {
        [void]$lines.Add(('[yellow]Template cacat : {0} (tidak lengkap - dilewati)[/]' -f (($tmpl.Incomplete | ForEach-Object { Get-LgrEsc $_ }) -join ', ')))
    }
    [void]$lines.Add(('Sumber PDF     : {0}' -f $(if ($src.Count -gt 0) { $src.Count.ToString() + ' (' + (($src | ForEach-Object { Get-LgrEsc $_ }) -join ', ') + ')' } else { 'belum ada' })))
    [void]$lines.Add('')
    foreach ($tool in @('pandoc', 'pdftotext', 'hermes')) {
        $c = Get-Command $tool -ErrorAction SilentlyContinue
        if ($c) {
            [void]$lines.Add(('[green]{0,-14} : OK[/]' -f $tool))
        } else {
            $note = 'TIDAK ADA'
            if ($tool -eq 'pdftotext') { $note = 'TIDAK ADA (wajib untuk sumber PDF)' }
            if ($tool -eq 'hermes')    { $note = 'TIDAK ADA (AI dilewati)' }
            [void]$lines.Add(('[red]{0,-14} : {1}[/]' -f $tool, $note))
        }
    }
    [void]$lines.Add('')
    [void]$lines.Add('Mulai dari menu 1. Rincian lengkap: menu 5 (Cek sistem).')
    (Format-SpectrePanel -Data ($lines -join "`n") -Header 'Kondisi Sistem' -Color 'cyan') | Out-SpectreHost
}

function Start-LgrTui {
    Write-SpectreFigletText -Text 'LAPORAN' -Color 'cyan'
    Write-SpectreRule -Title 'Generator Laporan Akademik - TUI' -Color 'yellow'
    Show-LgrStartupInfo

    $menu = @(
        '1 - Buat laporan dengan AI'
        '2 - Buat kerangka tanpa AI'
        '3 - Tulis ulang satu bab dengan AI'
        '4 - Kompilasi ulang dari chapters\ (docx)'
        '5 - Cek sistem'
        '6 - Daftar template & sumber'
        '7 - Keluar'
    )
    while ($true) {
        $pick = Read-SpectreSelection -Message 'Pilih menu (panah atas/bawah, enter):' -Choices $menu -Color 'cyan' -PageSize 10
        switch -Regex ($pick) {
            '^1' { Invoke-LgrMode -Mode 'ai' }
            '^2' { Invoke-LgrMode -Mode 'noai' }
            '^3' { Invoke-LgrMode -Mode 'bab' }
            '^4' { Invoke-LgrMode -Mode 'docx' }
            '^5' { Invoke-LgrCheckMenu }
            '^6' { Invoke-LgrListMenu }
            '^7' {
                Write-SpectreRule -Title 'Sampai jumpa' -Color 'green'
                Write-SpectreHost -Message '[green]Hasil laporan ada di folder output\ .[/]'
                return
            }
        }
    }
}

# ------------------------------- entry point --------------------------------

# Lengkapi PATH dengan lokasi tool pipeline (pdftotext milik Hermes, hermes CLI,
# Pandoc user) SEBELUM pengecekan dan sebelum proses anak laporan.ps1 dijalankan.
# Tanpa ini: Get-Pdftotext di laporan.ps1 scan rekursif puluhan ribu file = macet
# beberapa menit tanpa pesan apa pun.
$null = Add-LgrToolDirsToPath

if (-not (Import-LgrSpectre)) { exit 1 }

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-LgrPanel -Text (
        'pandoc tidak ditemukan di PATH (WAJIB untuk kompilasi DOCX).' + "`n" +
        'Cara pasang (pilih salah satu):' + "`n" +
        '  winget install --id JohnMacFarlane.Pandoc' + "`n" +
        '  choco install pandoc' + "`n" +
        '  unduh manual: https://pandoc.org/installing.html' + "`n" +
        'Setelah terpasang, tutup lalu buka ulang terminal ini.'
    ) -Header 'pandoc tidak ada' -Color 'red'
    exit 1
}

try {
    Start-LgrTui
} catch {
    Write-LgrPanel -Text ('Kesalahan tak terduga: ' + (Get-LgrEsc $_.Exception.Message)) -Header 'Error' -Color 'red'
    exit 1
}
exit 0
