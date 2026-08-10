$RootPath = '\\YourSystem\FinancialApplication'  #\YourSystem\FinancialApplication - Replace with the relevant path

# Executables, installers, libraries, and script types
$ExecutableExtensions = @(
    '.exe', '.com', '.scr', '.pif', '.cpl',
    '.dll', '.ocx', '.sys', '.drv',
    '.msi', '.msp', '.mst',
    '.bat', '.cmd',
    '.ps1', '.psm1', '.psd1',
    '.vbs', '.vbe',
    '.js', '.jse',
    '.wsf', '.wsh',
    '.hta',
    '.jar'
)

if (-not (Test-Path -LiteralPath $RootPath)) {
    throw "Unable to access: $RootPath"
}

$Results = Get-ChildItem -LiteralPath $RootPath -File -Recurse -Force `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $ExecutableExtensions -contains $_.Extension
    } |
    Select-Object @{
        Name = 'FileName'
        Expression = { $_.Name }
    }, @{
        Name = 'FileType'
        Expression = { $_.Extension.ToLowerInvariant() }
    }, @{
        Name = 'FullPath'
        Expression = { $_.FullName }
    }, Length, CreationTime, LastWriteTime

$OutputFile = Join-Path $PWD (
    'SYSVOL_ExecutableFiles_{0}.csv' -f (Get-Date -Format 'yyyyMMdd_HHmmss')
)

$Results |
    Sort-Object FileType, FullPath |
    Export-Csv -LiteralPath $OutputFile -NoTypeInformation -Encoding UTF8

$Results | Format-Table FileType, FileName, LastWriteTime, FullPath -AutoSize

Write-Host "`nFiles found: $($Results.Count)" -ForegroundColor Cyan
Write-Host "Report saved to: $OutputFile" -ForegroundColor Green

Write-Host "`nSummary by file type:" -ForegroundColor Cyan
$Results |
    Group-Object FileType |
    Sort-Object Count -Descending |
    Select-Object Name, Count |
    Format-Table -AutoSize
