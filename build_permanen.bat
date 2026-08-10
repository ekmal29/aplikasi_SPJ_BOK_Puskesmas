@echo off
setlocal

set APP_VERSION=3.1

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

REM PENTING: Perbarui versi aplikasi di wails.json agar versi di dalam .exe sesuai
echo Memperbarui versi internal aplikasi ke v%APP_VERSION%...
wails version %APP_VERSION%
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL memperbarui versi di wails.json. Pastikan Wails CLI terinstal dan ada di PATH.
    goto :error
)

REM Tambahkan versi pada judul aplikasi dengan memanggil skrip PowerShell yang bersih dan terpisah
echo Menambahkan versi ke judul aplikasi...
set "NEW_PRODUCT_NAME=Aplikasi SPJ BOK Puskesmas v%APP_VERSION%"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\update-wails-info.ps1" -AppName "%NEW_PRODUCT_NAME%"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL memperbarui productName di wails.json.
    goto :error
)

echo.
echo --- VERIFIKASI wails.json ---
echo Konten wails.json setelah diperbarui:
echo.
type wails.json
echo.
echo Periksa apakah "version" sudah benar-benar menjadi "v%APP_VERSION%".
pause
echo.

echo Mohon tunggu sebentar (bisa memakan waktu beberapa detik)...
wails build -clean
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL saat build aplikasi dengan Wails.
    goto :error
)
echo.

echo Menyiapkan folder "release_artifacts" untuk unggah ke GitLab...
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

echo Memperbarui file update.json untuk Server...
(
echo {
echo   "versi": "%APP_VERSION%",
echo   "url": "https://gitlab.com/ekmal29/spj-puskesmas-pro/-/releases/v%APP_VERSION%/downloads/Download_SPJ_Terbaru.zip",
echo   "changelog": "- Penambahan opsi penandatanganan SPT oleh Bupati.\n- Perbaikan bug minor.",
echo   "checksum": "%FILE_HASH%"
echo }
) > "release_artifacts\update.json"
echo.
echo SELESAI! File rilis telah disiapkan di folder "release_artifacts".

REM --- TAHAP OTOMATISASI UPLOAD KE GITLAB ---
echo.
echo Memulai proses unggah otomatis ke GitLab...

REM 1. Tambahkan file yang relevan ke Git. Termasuk wails.json untuk melacak versi.
git add wails.json "release_artifacts\update.json" "%~nx0" "update-wails-info.ps1"
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL menjalankan 'git add'. Pastikan Git terinstal dan ini adalah repo Git.
    goto :error
)

REM 2. Buat commit dengan pesan yang menyertakan versi aplikasi
git commit -m "chore(release): build and release v%APP_VERSION% [skip ci]"

REM 3. Dorong (push) commit ke repository GitLab Anda
git push origin master
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL menjalankan 'git push'. Cek koneksi, otentikasi Git, dan pastikan nama branch sudah benar (main/master).
    goto :error
)

REM 4. Hapus rilis lama (jika ada) untuk menghindari error duplikat aset. Opsi -y untuk konfirmasi otomatis.
echo Menghapus rilis lama v%APP_VERSION% di GitLab (jika ada)...
glab release delete v%APP_VERSION% -y >nul 2>&1

REM 5. Buat Rilis baru di GitLab dan lampirkan file .zip menggunakan GitLab CLI
echo Membuat rilis baru v%APP_VERSION% di GitLab...
glab release create v%APP_VERSION% "release_artifacts\Download_SPJ_Terbaru.zip" --name "Rilis Versi %APP_VERSION%" --notes "Pembaruan otomatis versi %APP_VERSION%."
if %errorlevel% neq 0 (
    echo [ERROR] GAGAL membuat rilis di GitLab. Pastikan 'glab' terinstal, terkonfigurasi, dan file zip ada.
    goto :error
)

echo.
echo OTOMATISASI SELESAI! Versi %APP_VERSION% telah berhasil diunggah dan dirilis di GitLab.
goto :end

:error
echo.
echo =================================================================
echo  SKRIP DIHENTIKAN KARENA TERJADI ERROR.
echo  Silakan periksa pesan error di atas untuk menemukan penyebabnya.
echo =================================================================
echo.

:end
pause