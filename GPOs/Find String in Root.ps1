### Find files which contain SYSVOL in NewRepo

$SearchRoot = '\\IrishBank.com\NewRepo'

$ContextBytes = 240
$OverlapBytes = 1024
$BufferSize = 1MB

# Preserve original byte values, including null-byte separators.
$ByteEncoding = [System.Text.Encoding]::GetEncoding(28591)

# Literal SYSVOL in common byte representations.
$Pattern = @(
    '(?<UTF32LE>s\x00\x00\x00y\x00\x00\x00s\x00\x00\x00v\x00\x00\x00o\x00\x00\x00l\x00\x00\x00)'
    '(?<UTF32BE>\x00\x00\x00s\x00\x00\x00y\x00\x00\x00s\x00\x00\x00v\x00\x00\x00o\x00\x00\x00l)'
    '(?<UTF16LE>s\x00y\x00s\x00v\x00o\x00l\x00)'
    '(?<UTF16BE>\x00s\x00y\x00s\x00v\x00o\x00l)'
    '(?<ASCII>sysvol)'
) -join '|'

$Options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
           [System.Text.RegularExpressions.RegexOptions]::CultureInvariant

$SysvolRegex = [regex]::new($Pattern, $Options)
$Utf32BE = [System.Text.UTF32Encoding]::new($true, $false)

$Stats = @{
    FilesAttempted = 0
    FilesScanned   = 0
    MatchingFiles  = 0
    ContentMatches = 0
    ReadErrors     = 0
}

# Keep failure details in memory only.
$ReadFailures = [System.Collections.Generic.List[object]]::new()

function ConvertTo-ExtendedPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Path.StartsWith('\\?\')) {
        return $Path
    }

    if ($Path.StartsWith('\\')) {
        return '\\?\UNC\' + $Path.Substring(2)
    }

    return '\\?\' + $Path
}

function Get-SysvolContext {
    param(
        [string]$Raw,
        [System.Text.RegularExpressions.Match]$Match
    )

    $width = 1
    $decoder = [System.Text.Encoding]::UTF8

    if ($Match.Groups['UTF32LE'].Success) {
        $width = 4
        $decoder = [System.Text.Encoding]::UTF32
    }
    elseif ($Match.Groups['UTF32BE'].Success) {
        $width = 4
        $decoder = $Utf32BE
    }
    elseif ($Match.Groups['UTF16LE'].Success) {
        $width = 2
        $decoder = [System.Text.Encoding]::Unicode
    }
    elseif ($Match.Groups['UTF16BE'].Success) {
        $width = 2
        $decoder = [System.Text.Encoding]::BigEndianUnicode
    }

    # Align context to the encoding of the matching string.
    $beforeLength = [Math]::Min($ContextBytes, $Match.Index)
    $beforeLength -= $beforeLength % $width

    $afterStart = $Match.Index + $Match.Length
    $afterLength = [Math]::Min(
        $ContextBytes,
        $Raw.Length - $afterStart
    )
    $afterLength -= $afterLength % $width

    $before = ''
    $after = ''

    if ($beforeLength -gt 0) {
        $before = $decoder.GetString(
            $ByteEncoding.GetBytes(
                $Raw.Substring(
                    $Match.Index - $beforeLength,
                    $beforeLength
                )
            )
        )
    }

    if ($afterLength -gt 0) {
        $after = $decoder.GetString(
            $ByteEncoding.GetBytes(
                $Raw.Substring($afterStart, $afterLength)
            )
        )
    }

    $matchedText = $decoder.GetString(
        $ByteEncoding.GetBytes($Match.Value)
    )

    # Stop at line breaks, null terminators and other control characters.
    # This prevents separate binary strings being joined together.
    $before = ($before -split '[\x00-\x08\x0A-\x1F\x7F]')[-1]
    $after = ($after -split '[\x00-\x08\x0A-\x1F\x7F]')[0]

    return ($before + $matchedText + $after).Trim()
}

function Find-SysvolReferences {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $Stats.FilesAttempted++
    $stream = $null
    $headerPrinted = $false

    try {
        Write-Progress -Id 1 `
            -Activity "Searching SYSVOL — file $($Stats.FilesAttempted)" `
            -Status "Opening: $($File.FullName)" `
            -PercentComplete 0

        # Include matches in the file name or folder path.
        if ($File.FullName -match '(?i)sysvol') {
            Write-Host "`nFile: $($File.Name)" -ForegroundColor Cyan
            Write-Host "Path: $($File.FullName)"
            Write-Host "Name/path match: $($File.FullName)" `
                -ForegroundColor Yellow

            $headerPrinted = $true
            $Stats.MatchingFiles++
        }

        $share = [System.IO.FileShare]::ReadWrite -bor
                 [System.IO.FileShare]::Delete

        # Extended-length UNC/local path for reading.
        $ReadPath = ConvertTo-ExtendedPath -Path $File.FullName

        $stream = [System.IO.File]::Open(
            $ReadPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            $share
        )

        $buffer = New-Object byte[] $BufferSize
        $tail = ''
        $totalRead = [long]0
        $nextMatchOffset = [long]0
        $fileSize = $stream.Length

        while ($true) {
            $count = $stream.Read($buffer, 0, $buffer.Length)
            $atEnd = ($count -eq 0)

            # Absolute offset of the combined overlap/new-data buffer.
            $baseOffset = $totalRead - $tail.Length
            $raw = $tail

            if ($count -gt 0) {
                $raw += $ByteEncoding.GetString($buffer, 0, $count)
                $totalRead += $count
            }

            # Defer end-of-buffer matches until following context is available.
            $scanLimit = if ($atEnd) {
                $raw.Length
            }
            else {
                [Math]::Max(0, $raw.Length - 512)
            }

            $percent = if ($fileSize -gt 0) {
                [int][Math]::Min(
                    100,
                    100 * $totalRead / $fileSize
                )
            }
            else {
                0
            }

            Write-Progress -Id 1 `
                -Activity "Searching SYSVOL — file $($Stats.FilesAttempted)" `
                -Status ("{0} | {1:N1}/{2:N1} MB" -f `
                    $File.FullName,
                    ($totalRead / 1MB),
                    ($fileSize / 1MB)) `
                -PercentComplete $percent

            foreach ($match in $SysvolRegex.Matches($raw)) {
                $absoluteOffset = $baseOffset + $match.Index

                # Avoid duplicate matches from overlapping buffers.
                if ($absoluteOffset -lt $nextMatchOffset) {
                    continue
                }

                if ($match.Index -ge $scanLimit) {
                    continue
                }

                if (-not $headerPrinted) {
                    Write-Host "`nFile: $($File.Name)" `
                        -ForegroundColor Cyan
                    Write-Host "Path: $($File.FullName)"

                    $headerPrinted = $true
                    $Stats.MatchingFiles++
                }

                $encodingName = 'ASCII / UTF-8'

                foreach ($name in @(
                    'UTF32LE', 'UTF32BE', 'UTF16LE', 'UTF16BE'
                )) {
                    if ($match.Groups[$name].Success) {
                        $encodingName = $name
                        break
                    }
                }

                $context = Get-SysvolContext -Raw $raw -Match $match

                Write-Host (
                    "String [{0}, byte offset {1}]: {2}" -f `
                    $encodingName, $absoluteOffset, $context
                ) -ForegroundColor Yellow

                $Stats.ContentMatches++
            }

            $nextMatchOffset = $baseOffset + $scanLimit

            if ($atEnd) {
                break
            }

            # Keep enough overlap for matches and surrounding context.
            $tailLength = [Math]::Min($OverlapBytes, $raw.Length)
            $tail = $raw.Substring($raw.Length - $tailLength)
        }

        $Stats.FilesScanned++
    }
    catch {
        $Stats.ReadErrors++

        $exception = $_.Exception.GetBaseException()

        $ReadFailures.Add(
            [PSCustomObject]@{
                Path      = $File.FullName
                ErrorType = $exception.GetType().Name
                Message   = $exception.Message
            }
        )

        Write-Warning (
            "INCOMPLETE SCAN: {0} — [{1}] {2}" -f `
            $File.FullName,
            $exception.GetType().Name,
            $exception.Message
        )
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

if (-not (Test-Path -LiteralPath $SearchRoot -PathType Container)) {
    Write-Error "Share unavailable or access denied: $SearchRoot"
    return
}

$EnumerationErrors = @()
$ScanTimer = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # No file-type exclusions and no DfsrPrivate exclusion.
    Get-ChildItem -LiteralPath $SearchRoot -File -Recurse -Force `
        -ErrorAction Continue `
        -ErrorVariable +EnumerationErrors |
    ForEach-Object {
        Find-SysvolReferences -File $_
    }
}
finally {
    Write-Progress -Id 1 -Activity 'Searching SYSVOL' -Completed
    $ScanTimer.Stop()
}

Write-Host "`n--- Scan summary ---" -ForegroundColor Green
Write-Host "Files attempted:            $($Stats.FilesAttempted)"
Write-Host "Files successfully scanned: $($Stats.FilesScanned)"
Write-Host "Files with matches:         $($Stats.MatchingFiles)"
Write-Host "Content occurrences:        $($Stats.ContentMatches)"
Write-Host "File read failures:         $($Stats.ReadErrors)"
Write-Host "Enumeration errors:         $($EnumerationErrors.Count)"
Write-Host "Elapsed time:               $($ScanTimer.Elapsed)"

if ($ReadFailures.Count -gt 0) {
    Write-Host "`n--- Read failures by error type ---" `
        -ForegroundColor Yellow

    $ReadFailures |
        Group-Object -Property ErrorType |
        Sort-Object -Property Count -Descending |
        ForEach-Object {
            Write-Host ("{0}: {1}" -f $_.Name, $_.Count)
        }
}

if ($Stats.ReadErrors -gt 0 -or $EnumerationErrors.Count -gt 0) {
    Write-Warning 'Coverage is incomplete. Review the errors above.'
}
else {
    Write-Host "`nNo file-read or enumeration errors reported." `
        -ForegroundColor Green
}
