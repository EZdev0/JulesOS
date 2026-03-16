#!/bin/bash
set -e

echo "Starting automated tests for Jules OS components..."

# 0. Run Unit Tests First
echo "[+] Running Unit Tests (GoogleTest)..."
cd jules-os
mkdir -p build_unit_tests
cd build_unit_tests
cmake -DBUILD_TESTING=ON -DSTATIC_BUILD=OFF ..
make -j$(nproc) jules_tests
./jules_tests
echo "[OK] Unit tests passed."
cd ..

# 1. Test Shell Compilation
echo "[+] Testing Shell Compilation..."
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

# 2.1 Test Edge Cases (Empty/Whitespace commands)
echo "[+] Testing empty command execution..."
EMPTY_OUT=$(./jules_shell -c "" 2>&1)
if [ -z "$EMPTY_OUT" ]; then
    echo "[OK] Empty command handled correctly (no output)."
else
    echo "[ERROR] Empty command produced output: $EMPTY_OUT"
    exit 1
fi

echo "[+] Testing whitespace-only command execution..."
WHITE_OUT=$(./jules_shell -c "   " 2>&1)
if [ -z "$WHITE_OUT" ]; then
    echo "[OK] Whitespace command handled correctly (no output)."
else
    echo "[ERROR] Whitespace command produced output: $WHITE_OUT"
    exit 1
fi

# 3. Test build script logic
echo "[+] Checking build script integrity..."
cd ..
bash -n scripts/build.sh
echo "[OK] build.sh syntax is valid."

# 4. Check init script logic
echo "[+] Checking init script integrity..."
sh -n scripts/init.sh
echo "[OK] init.sh syntax is valid."

# 5. Test new commands
echo "[+] Testing new fetch command..."
./build_test/jules_shell -c "fetch" > /dev/null
echo "[OK] 'fetch' command executed."

echo "[+] Testing new jupdate command..."
./build_test/jules_shell -c "jupdate" > /dev/null
echo "[OK] 'jupdate' command executed."

echo "[+] Testing enhanced boost command..."
./build_test/jules_shell -c "boost" > /dev/null 2>&1
echo "[OK] 'boost' command executed."

echo "================================================"
echo "[SUCCESS] All component tests passed."
echo "================================================"
