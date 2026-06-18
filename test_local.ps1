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

# 2. Setup Build Environment (Docker)
Write-Host "`n[1/3] Preparing Docker Build Environment..." -ForegroundColor Green
$dockerfile = @"
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget tar cpio gzip xorriso syslinux syslinux-utils \
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
$containerId = docker create jules-builder bash -c "mkdir -p /build/linting_logs && echo 'Running Shellcheck...' && shellcheck jules-os/scripts/*.sh > /build/linting_logs/shellcheck.log || true && echo 'Running Cppcheck...' && cppcheck --enable=all jules-os/src/legacy/ > /build/linting_logs/cppcheck.log 2>&1 || true && echo 'Running Cargo Clippy...' && cd /build/jules-os && cargo clippy --all-targets -- -D warnings > /build/linting_logs/clippy.log 2>&1 || true && echo 'Building ISO...' && bash scripts/build.sh && python3 tests/qemu_boot_test.py"

Write-Host "-> Running container processes..." -ForegroundColor DarkGray
docker start -a $containerId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build or QEMU Boot Test failed inside the container!"
    docker rm $containerId > $null
    exit 1
}

# 4. Extract Artifacts (ISO & Linting Logs)
Write-Host "`n[3/4] Extracting generated ISO to Windows Host..." -ForegroundColor Green
docker cp "${containerId}:/build/jules-os/JulesOS.iso" ".\JulesOS.iso"
Write-Host "-> ISO Extracted Successfully!" -ForegroundColor DarkGray

Write-Host "`n[4/4] Extracting Linting Logs..." -ForegroundColor Green
docker cp "${containerId}:/build/linting_logs" ".\"
Write-Host "-> Linting logs saved to .\linting_logs\" -ForegroundColor DarkGray

# Cleanup
docker rm $containerId > $null
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Local Test Completed. ISO & Logs are ready! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
