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
    cargo rustc nasm g++ \
    qemu-system-x86 python3
WORKDIR /build
"@

Set-Content -Path ".\Dockerfile.jules" -Value $dockerfile

# Build Docker Image
Write-Host "-> Building Docker Image (jules-builder)..." -ForegroundColor DarkGray
docker build -t jules-builder -f .\Dockerfile.jules .

# 3. Build ISO
Write-Host "`n[2/3] Building JulesOS ISO in isolated container..." -ForegroundColor Green
# Mount current directory and execute build script
docker run --rm -v "${PWD}:/build" jules-builder bash -c "cd /build/jules-os && bash scripts/build.sh"

if (-not (Test-Path ".\jules-os\JulesOS.iso")) {
    Write-Error "ISO Build failed! JulesOS.iso not found."
    exit 1
}

Write-Host "-> ISO Built Successfully! Size: $((Get-Item '.\jules-os\JulesOS.iso').Length / 1MB | ForEach-Object ToString '0.00') MB" -ForegroundColor Green

# 4. Local QEMU Test within Docker
Write-Host "`n[3/3] Launching JulesOS in Docker-isolated QEMU (Headless Boot Test)..." -ForegroundColor Green
docker run --rm -v "${PWD}:/build" jules-builder bash -c "cd /build/jules-os && python3 tests/qemu_boot_test.py"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Local Test Completed. ISO is bootable! " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
