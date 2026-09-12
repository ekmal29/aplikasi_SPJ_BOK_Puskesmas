# update-wails-info.ps1
# Skrip ini memperbarui properti 'productName' di wails.json.
# Didesain agar tangguh, memastikan properti ada sebelum mencoba mengaturnya.
param (
    [string]$AppName,
    [string]$Version
)

$wailsJsonPath = Join-Path (Get-Location) "wails.json"

if (-not (Test-Path $wailsJsonPath)) {
    Write-Error "ERROR: File wails.json tidak ditemukan di '$wailsJsonPath'. Pastikan file tersebut ada."
    exit 1
}

try {
    $wailsConfig = Get-Content $wailsJsonPath -Raw | ConvertFrom-Json

    # Periksa apakah properti 'productName' ada. Jika tidak, tambahkan.
    if (-not $wailsConfig.PSObject.Properties.Name.Contains('productName')) {
        $wailsConfig | Add-Member -MemberType NoteProperty -Name "productName" -Value $AppName
    } else {
        $wailsConfig.productName = $AppName
    }

    # Periksa dan perbarui properti 'version'.
    if (-not $wailsConfig.PSObject.Properties.Name.Contains('version')) {
        $wailsConfig | Add-Member -MemberType NoteProperty -Name "version" -Value $Version
    } else {
        $wailsConfig.version = $Version
    }

    $wailsConfig | ConvertTo-Json -Depth 100 | Set-Content $wailsJsonPath -NoNewline
}
catch {
    Write-Error "ERROR: Gagal memperbarui wails.json. Pesan: $($_.Exception.Message)"
    exit 1
}