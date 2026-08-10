@echo off
echo Menutup aplikasi yang mungkin sedang berjalan agar tidak error (Access is denied)...
set APP_VERSION=3.0

echo Menutup aplikasi yang mungkin sedang berjalan agar tidak error...
taskkill /F /IM Aplikasi_SPJ*.exe /T >nul 2>&1
echo.

echo Membangun aplikasi SPJ BOK Puskesmas versi PERMANEN...
echo Merapikan dependensi... & go mod tidy >nul 2>&1
echo Mohon tunggu sebentar (bisa memakan waktu beberapa detik)...
wails build -clean
echo.
echo Menyiapkan folder "release_artifacts" untuk unggah ke GitLab...
if not exist "release_artifacts" mkdir "release_artifacts"

echo Mengompres file .exe menjadi .zip...
powershell -command "Compress-Archive -Path 'build\bin\*.exe' -DestinationPath 'release_artifacts\Download_SPJ_Terbaru.zip' -Force"

echo Menghitung Hash Keamanan (SHA256)...
for /f "delims=" %%a in ('powershell -command "(Get-FileHash 'release_artifacts\Download_SPJ_Terbaru.zip' -Algorithm SHA256).Hash.ToLower()"') do set "FILE_HASH=%%a"

echo Memperbarui file update.json untuk Server...
(
echo {
echo   "versi": "3.0",
echo   "versi": "%APP_VERSION%",
echo   "url": "https://gitlab.com/ekmal29/spj-puskesmas-pro/-/releases/v%APP_VERSION%/downloads/Download_SPJ_Terbaru.zip",
echo   "changelog": "Versi 3.0:\n- Penyesuaian kewajiban input nomor surat SPT jika penandatangan bukan Kepala Puskesmas.\n- Peningkatan stabilitas dan perbaikan bug minor.\n\nVersi 2.8:\n- Penyesuaian versi dan peningkatan stabilitas sistem.\n\nVersi 2.7:\n- Penyesuaian versi dan peningkatan stabilitas sistem.\n\nVersi 2.6:\n- Penyesuaian versi dan peningkatan stabilitas sistem.\n\nVersi 2.5:\n- Penyesuaian versi dan peningkatan stabilitas sistem.\n\nVersi 2.4:\n1. Penambahan dropdown tahun pada list database perjadin dan belanja makan minum\n2. Update KOP surat sesuai instansi yang menandatangani\n3. Indikator data yang beririsan/duplikat\n4. Penambahan kode srikandi pada SPT Word sehingga SPT word tinggal upload ke srikandi\n5. Perbaikan bug",
echo   "checksum": "%FILE_HASH%"
echo }
) > "release_artifacts\update.json"
echo.
echo SELESAI! File rilis telah disiapkan di folder "release_artifacts".

REM --- TAHAP OTOMATISASI UPLOAD KE GITLAB ---
echo.
echo Memulai proses unggah otomatis ke GitLab...

REM 1. Tambahkan hanya file update.json dan skrip ini ke Git (untuk memastikan URL update terbaru)
git add "release_artifacts\update.json"
git add "%~nx0"

REM 2. Buat commit dengan pesan yang menyertakan versi aplikasi
git commit -m "Otomatis: Update rilis versi %APP_VERSION% dan skrip build"

REM 3. Dorong (push) commit ke repository GitLab Anda
git push origin main

REM 4. Buat Rilis baru di GitLab dan lampirkan file .zip menggunakan GitLab CLI
glab release create v%APP_VERSION% "release_artifacts\Download_SPJ_Terbaru.zip" --name "Rilis Versi %APP_VERSION%" --notes "Pembaruan otomatis versi %APP_VERSION%."

echo.
echo OTOMATISASI SELESAI! Versi %APP_VERSION% telah berhasil diunggah dan dirilis di GitLab.
pause