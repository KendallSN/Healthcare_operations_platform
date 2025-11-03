# PowerShell script to convert all shell scripts and config files to Unix (LF) line endings
# Automatically works from powershell/ subfolder by searching parent directory

Write-Host "Converting shell scripts and config files to Unix (LF) line endings..." -ForegroundColor Green

# Get project root (parent of script directory)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Get all .sh and .env files recursively from project root
$shFiles = Get-ChildItem -Path $projectRoot -Filter *.sh -Recurse
$envFiles = Get-ChildItem -Path $projectRoot -Filter *.env -Recurse
$files = $shFiles + $envFiles

foreach ($file in $files) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Yellow

    # Read content and convert CRLF to LF
    $content = Get-Content $file.FullName -Raw
    $content = $content -replace "`r`n", "`n"

    # Write back without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
}

Write-Host "`nConversion complete! Total files processed: $($files.Count)" -ForegroundColor Green
Write-Host "  - Shell scripts (.sh): $($shFiles.Count)" -ForegroundColor Cyan
Write-Host "  - Config files (.env): $($envFiles.Count)" -ForegroundColor Cyan
Write-Host "`nYou can now run deployment again." -ForegroundColor Green
