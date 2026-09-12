@echo off
setlocal

cd /d "%~dp0"
if %errorlevel% neq 0 (
    echo [ERROR] Gagal masuk ke folder project.
    goto :error
)

set APP_VERSION=3.4
set "PATH=%ProgramFiles%\Go\bin;%USERPROFILE%\go\bin;%PATH%"

echo Menutup aplikasi yang mungkin sedang berjalan agar tidak error...
taskkill /F /IM Aplikasi_SPJ*.exe /T >nul 2>&1
echo.

echo Membangun aplikasi SPJ BOK Puskesmas versi PERMANEN...
echo Merapikan dependensi...
go mod tidy >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Gagal menjalankan 'go mod tidy'. Pastikan Go terinstal dan ada di PATH.
    goto :error
)

REM Validasi keberadaan file wails.json
if not exist "wails.json" (
    echo [ERROR] File 'wails.json' tidak ditemukan. Skrip tidak dapat dilanjutkan.
    goto :error
)

REM Perbarui versi internal dan judul aplikasi di wails.json menggunakan skrip PowerShell
echo Memperbarui versi internal dan judul aplikasi ke v%APP_VERSION%...
set "NEW_PRODUCT_NAME=Aplikasi SPJ BOK Puskesmas v%APP_VERSION%"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\update-wails-info.ps1" -AppName "%NEW_PRODUCT_NAME%" -Version "%APP_VERSION%"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL memperbarui wails.json menggunakan skrip PowerShell.
    goto :error
)

echo.
echo --- VERIFIKASI wails.json ---
echo Konten wails.json setelah diperbarui:
echo.
type wails.json
echo.
echo Periksa apakah "version" sudah benar-benar menjadi "v%APP_VERSION%".
echo.

echo Mohon tunggu sebentar (bisa memakan waktu beberapa detik)...
REM Gunakan -ldflags untuk menyuntikkan nomor versi ke dalam variabel Go.
REM Ganti 'main.AppVersion' jika variabel Anda ada di paket yang berbeda (mis. 'app.Version').
wails build -clean -ldflags="-X 'main.AppVersion=%APP_VERSION%'"

if %errorlevel% neq 0 (
    echo [ERROR] GAGAL saat build aplikasi dengan Wails.
    goto :error
)
echo.

echo Menyiapkan folder "release_artifacts" untuk unggah ke GitHub...
if not exist "release_artifacts" mkdir "release_artifacts"

echo Mengompres file .exe menjadi .zip...
powershell -command "Compress-Archive -Path 'build\bin\*.exe' -DestinationPath 'release_artifacts\Download_SPJ_Terbaru.zip' -Force"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL mengompres file .exe. Mungkin proses build gagal?
    goto :error
)

echo Menghitung Hash Keamanan (SHA256)...
for /f "delims=" %%a in ('powershell -command "(Get-FileHash 'release_artifacts\Download_SPJ_Terbaru.zip' -Algorithm SHA256).Hash.ToLower()"') do set "FILE_HASH=%%a"
if not defined FILE_HASH (
    echo [ERROR] GAGAL menghitung hash file. Mungkin file .zip tidak berhasil dibuat.
    goto :error
)

echo Memperbarui file update.json untuk Server dari changelog.txt...
set "CHANGELOG_FILE=changelog.txt"
if not exist "%CHANGELOG_FILE%" (
    echo [ERROR] File changelog '%CHANGELOG_FILE%' tidak ditemukan. Buat file tersebut dengan isi catatan rilis.
    goto :error
)

powershell -NoProfile -Command "$changelogContent = (Get-Content -Path '%CHANGELOG_FILE%' -Encoding UTF8 -Raw) -replace '`r`n|`n|`r', '\n'; $updateInfo = [ordered]@{ 'versi' = '%APP_VERSION%'; 'url' = 'https://github.com/ekmal29/aplikasi_SPJ_BOK_Puskesmas/releases/download/v%APP_VERSION%/Download_SPJ_Terbaru.zip'; 'changelog' = $changelogContent; 'checksum' = '%FILE_HASH%'; }; $json = $updateInfo | ConvertTo-Json -Depth 3; [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'release_artifacts\update.json'), $json, (New-Object System.Text.UTF8Encoding($false)))"

echo.
echo SELESAI! File rilis telah disiapkan di folder "release_artifacts".

REM --- TAHAP OTOMATISASI UPLOAD KE GITHUB ---
echo.
echo Memulai proses unggah otomatis ke GitHub...

set "GH_EXE=gh"
if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GH_EXE=%ProgramFiles%\GitHub CLI\gh.exe"
where gh >nul 2>&1
if %errorlevel% neq 0 if not exist "%GH_EXE%" (
    echo [ERROR] GitHub CLI 'gh' tidak ditemukan. Instal dari https://cli.github.com/ lalu jalankan 'gh auth login'.
    goto :error
)
"%GH_EXE%" auth status >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] GitHub CLI belum terautentikasi. Jalankan 'gh auth login' terlebih dahulu.
    goto :error
)

REM 1. Tambahkan file yang relevan ke Git. Termasuk wails.json untuk melacak versi.
git add wails.json "release_artifacts\update.json" "%~nx0" "update-wails-info.ps1" "%CHANGELOG_FILE%"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL menjalankan 'git add'. Pastikan Git terinstal dan ini adalah repo Git.
    goto :error
)

REM 2. Buat commit dengan pesan yang menyertakan versi aplikasi
git commit -m "chore(release): build and release v%APP_VERSION% [skip ci]"

REM 3. Dorong (push) commit ke repository GitHub Anda
git push origin master:main
if not %errorlevel% equ 0 goto :push_error

REM 4. Hapus rilis lama (jika ada) untuk menghindari error duplikat aset. Opsi -y untuk konfirmasi otomatis.
echo Menghapus rilis lama v%APP_VERSION% di GitHub (jika ada)...
"%GH_EXE%" release delete v%APP_VERSION% --yes >nul 2>&1

REM 5. Buat rilis baru di GitHub dan lampirkan file .zip menggunakan GitHub CLI
echo Membuat rilis baru v%APP_VERSION% di GitHub...
"%GH_EXE%" release create v%APP_VERSION% "release_artifacts\Download_SPJ_Terbaru.zip" --target main --title "Rilis Versi %APP_VERSION%" --notes-file "%CHANGELOG_FILE%"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL membuat rilis di GitHub. Pastikan 'gh' terinstal, terkonfigurasi, dan file zip ada.
    goto :error
)

echo.
echo OTOMATISASI SELESAI! Versi %APP_VERSION% telah berhasil diunggah dan dirilis di GitHub.
goto :end

:push_error
echo [ERROR] GAGAL menjalankan 'git push'. Cek koneksi, otentikasi Git, dan pastikan nama branch sudah benar (main/master).
goto :error

:error
echo.
echo =================================================================
echo  SKRIP DIHENTIKAN KARENA TERJADI ERROR.
echo  Silakan periksa pesan error di atas untuk menemukan penyebabnya.
echo =================================================================
echo.

:end