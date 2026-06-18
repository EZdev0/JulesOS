<#
.SYNOPSIS
    JulesOS Local Build & Test Script (Windows)

.DESCRIPTION
    Dieses Skript kompiliert JulesOS in einem isolierten Docker-Container (Ubuntu)
    und testet die resultierende .iso sofort danach lokal mit QEMU.
    Es umgeht WSL-Abhängigkeiten (wie fehlendes wget/tar), indem es Docker nutzt.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " JulesOS Local Build & QEMU Test Environment (Windows) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Dependencies
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "Docker Desktop is not installed or not running. Please start Docker!"
    exit 1
}

# 1.5. Cleanup old test containers
Write-Host "-> Checking for old jules-test-container copies..." -ForegroundColor DarkGray
docker rm -f jules-test-container 2>$null

# 2. Setup Build Environment (Docker)
Write-Host "`n[1/3] Preparing Docker Build Environment..." -ForegroundColor Green
$dockerfile = @"
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget tar cpio gzip xorriso syslinux syslinux-utils pv \
    dosfstools mtools qemu-utils grub-pc-bin grub-efi-amd64-bin \
    cargo rustc nasm g++ shellcheck cppcheck \
    qemu-system-x86 python3

# Kopiere den gesamten Code ins Image (Vermeidet Volume Mount Crash auf Windows)
WORKDIR /build
COPY . /build/

# Mache Skripte ausführbar
RUN chmod +x /build/jules-os/scripts/build.sh
"@

Set-Content -Path ".\Dockerfile.jules" -Value $dockerfile

# Build Docker Image (dies kopiert den Code)
Write-Host "-> Building Docker Image (jules-builder) and copying source code..." -ForegroundColor DarkGray
docker build -t jules-builder -f .\Dockerfile.jules .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker Build failed."
    exit 1
}

# 3. Build & Test ISO im isolierten Container (OHNE Volumes)
Write-Host "`n[2/4] Running Linting Tools and Building JulesOS ISO in absolute isolation..." -ForegroundColor Green
$containerId = "jules-test-container"

$containerScript = @"
mkdir -p /build/linting_logs
echo 'Running Shellcheck...'
shellcheck jules-os/scripts/*.sh > /build/linting_logs/shellcheck.log || true
echo 'Running Cppcheck...'
cppcheck --enable=all jules-os/src/legacy/ > /build/linting_logs/cppcheck.log 2>&1 || true
echo 'Running Cargo Clippy (Soft Mode)...'
cd /build/jules-os
cargo clippy --all-targets > /build/linting_logs/clippy.log 2>&1 || true

echo 'Building ISO...'
if ! bash scripts/build.sh; then
    echo 'CRITICAL ERROR: Build failed. Initiating Deep Diagnostics...'
    echo '=== 1. Environment ===' > /build/linting_logs/diagnostic.log
    rustc -vV >> /build/linting_logs/diagnostic.log
    cargo --version >> /build/linting_logs/diagnostic.log
    echo -e '\n=== 2. Verbose Build Trace ===' >> /build/linting_logs/diagnostic.log
    RUST_BACKTRACE=full cargo build --verbose --release --target x86_64-unknown-linux-musl 2>> /build/linting_logs/diagnostic.log || true
    echo -e '\n=== 3. Deep Linter Audit ===' >> /build/linting_logs/diagnostic.log
    cargo clippy --all-targets -- -W clippy::pedantic -W clippy::nursery -W clippy::unwrap_used 2>> /build/linting_logs/diagnostic.log || true
    exit 1
fi

echo 'Verifying Native Compilers in JulesOS RootFS...'
chroot build/rootfs /usr/bin/gcc --version
chroot build/rootfs /usr/bin/cargo --version

if ! python3 tests/qemu_boot_test.py; then
    echo 'CRITICAL ERROR: QEMU Boot Test failed.'
    echo '=== QEMU Boot Test Failed ===' > /build/linting_logs/diagnostic.log
    exit 1
fi
"@

docker create --name $containerId jules-builder bash -c $containerScript > $null

Write-Host "-> Running container processes..." -ForegroundColor DarkGray
docker start -a $containerId
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Build or QEMU Boot Test failed inside the container! Extracting Deep Diagnostic logs..."
    docker cp "${containerId}:/build/linting_logs" ".\"
    if (Test-Path ".\JulesOS_CrashLogs.zip") { Remove-Item ".\JulesOS_CrashLogs.zip" }
    Compress-Archive -Path ".\linting_logs\*" -DestinationPath ".\JulesOS_CrashLogs.zip" -Force
    Remove-Item -Recurse -Force ".\linting_logs"
    docker rm -f $containerId > $null
    Write-Error "Test failed. Deep diagnostics securely saved to JulesOS_CrashLogs.zip"
    exit 1
}

# 4. Extract Artifacts (ISO & Linting Logs)
Write-Host "`n[3/4] Extracting generated ISO to Windows Host..." -ForegroundColor Green
docker cp "${containerId}:/build/jules-os/JulesOS.iso" ".\JulesOS.iso"
Write-Host "-> ISO Extracted Successfully!" -ForegroundColor DarkGray

Write-Host "`n[4/4] Extracting Linting Logs..." -ForegroundColor Green
docker cp "${containerId}:/build/linting_logs" ".\"
if (Test-Path ".\JulesOS_Logs.zip") { Remove-Item ".\JulesOS_Logs.zip" }
Compress-Archive -Path ".\linting_logs\*" -DestinationPath ".\JulesOS_Logs.zip" -Force
Remove-Item -Recurse -Force ".\linting_logs"
Write-Host "-> Linting logs saved to .\JulesOS_Logs.zip" -ForegroundColor DarkGray

# Cleanup
docker rm -f $containerId > $null
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Local Test Completed. ISO & Logs are ready! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
