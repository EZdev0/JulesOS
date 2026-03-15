#!/bin/bash
set -e

echo "Starting automated tests for Jules OS components..."

# 1. Test Shell Compilation
echo "[+] Testing Shell Compilation..."
cd jules-os
mkdir -p build_test
cd build_test
cmake -DSTATIC_BUILD=OFF ..
make -j$(nproc)
echo "[OK] Shell compiled successfully."

# 2. Test Shell command execution (dry run)
echo "[+] Testing Shell command execution..."
./jules_shell -c "help" > /dev/null
echo "[OK] 'help' command executed."

./jules_shell -c "clear" > /dev/null
echo "[OK] 'clear' command executed."

# 3. Test build script logic
echo "[+] Checking build script integrity..."
cd ..
bash -n scripts/build.sh
echo "[OK] build.sh syntax is valid."

# 4. Check init script logic
echo "[+] Checking init script integrity..."
sh -n scripts/init.sh
echo "[OK] init.sh syntax is valid."

echo "================================================"
echo "[SUCCESS] All component tests passed."
echo "================================================"
