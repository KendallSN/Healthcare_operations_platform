# PowerShell script to convert all shell scripts to Unix (LF) line endings
# Automatically works from powershell/ subfolder by searching parent directory

Write-Host "Converting all shell scripts to Unix (LF) line endings..." -ForegroundColor Green

# Get all .sh files recursively from project root (parent directory)
$files = Get-ChildItem -Path .. -Filter *.sh -Recurse

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
Write-Host "You can now run 'vagrant up primary' again." -ForegroundColor Cyan
