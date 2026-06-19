#!/bin/sh
echo '======================================================'
echo '  JULES OS - VOLLSTAENDIGER LOKALER TEST'
echo '======================================================'
echo ''

# --- Setup ---
echo '[1/7] Setup: Rust target + musl-tools'
rustup target add x86_64-unknown-linux-musl 2>&1 | tail -1
rustup component add clippy rustfmt 2>&1 | tail -1
apt-get update -qq 2>/dev/null
apt-get install -y -qq --no-install-recommends musl-tools 2>/dev/null
echo '  OK'
echo ''

# --- Rust Format Check ---
echo '[2/7] Format Check (cargo fmt)'
cargo fmt -- --check 2>&1
FMT_EXIT=$?
if [ $FMT_EXIT -eq 0 ]; then echo '  PASS: Code ist korrekt formatiert'; else echo '  FAIL: Code nicht formatiert'; fi
echo ''

# --- Clippy Lint (streng) ---
echo '[3/7] Clippy Lint (pedantic)'
cargo clippy --all-targets --target x86_64-unknown-linux-musl -- -W clippy::pedantic 2>&1
CLIP_EXIT=$?
if [ $CLIP_EXIT -eq 0 ]; then echo '  PASS: Keine Clippy-Warnings'; else echo '  WARN: Clippy hat Findings'; fi
echo ''

# --- Build (Release, statisch) ---
echo '[4/7] Build (Release + musl static)'
RUSTFLAGS='-C strip=symbols' cargo build --release --target x86_64-unknown-linux-musl 2>&1
BUILD_EXIT=$?
if [ $BUILD_EXIT -eq 0 ]; then echo '  PASS: Build erfolgreich'; else echo '  FAIL: Build fehlgeschlagen'; fi
echo ''

# --- Unit Tests ---
echo '[5/7] Unit Tests (cargo test)'
cargo test --target x86_64-unknown-linux-musl 2>&1
TEST_EXIT=$?
if [ $TEST_EXIT -eq 0 ]; then echo '  PASS: Alle Tests bestanden'; else echo '  FAIL: Tests fehlgeschlagen'; fi
echo ''

# --- Binary Verification ---
echo '[6/7] Binary Verification'
BINARY='target/x86_64-unknown-linux-musl/release/jules_shell'
if [ -f "$BINARY" ]; then
    echo '  Dateiinfo:'
    file "$BINARY"
    ls -lh "$BINARY"
    echo ''
    echo '  Statisch gelinkt?'
    file "$BINARY" | grep -qi 'static' && echo '  PASS: Statisch gelinkt' || echo '  WARN: Moeglicherweise dynamisch'
    echo ''
    echo '  Smoke Test (help):'
    "$BINARY" -c help 2>&1 | head -5
    SMOKE_EXIT=$?
    if [ $SMOKE_EXIT -eq 0 ]; then echo '  PASS: Smoke Test OK'; else echo '  FAIL: Smoke Test fehlgeschlagen'; fi
else
    echo '  FAIL: Binary nicht gefunden'
fi
echo ''

# --- Shell Script Syntax Check ---
echo '[7/7] Shell Script Syntax Check'
SHELL_FAIL=0
for script in scripts/init.sh scripts/build.sh scripts/install.sh scripts/boot.sh scripts/recovery_ui.sh; do
    if [ -f "$script" ]; then
        # Use bash for #!/bin/bash scripts, sh for #!/bin/sh
        SHEBANG=$(head -1 "$script")
        case "$SHEBANG" in
            *bash*) CHECKER="bash" ;;
            *)      CHECKER="sh" ;;
        esac
        $CHECKER -n "$script" 2>&1
        if [ $? -eq 0 ]; then
            echo "  PASS: $script ($CHECKER)"
        else
            echo "  FAIL: $script ($CHECKER)"
            SHELL_FAIL=$((SHELL_FAIL+1))
        fi
    fi
done
echo ''

# --- Zusammenfassung ---
echo '======================================================'
echo '  ERGEBNIS:'
echo '======================================================'
TOTAL_FAIL=0
[ $FMT_EXIT -ne 0 ] && echo '  FAIL: Format' && TOTAL_FAIL=$((TOTAL_FAIL+1))
[ $BUILD_EXIT -ne 0 ] && echo '  FAIL: Build' && TOTAL_FAIL=$((TOTAL_FAIL+1))
[ $TEST_EXIT -ne 0 ] && echo '  FAIL: Tests' && TOTAL_FAIL=$((TOTAL_FAIL+1))
[ $SHELL_FAIL -ne 0 ] && echo '  FAIL: Shell Scripts' && TOTAL_FAIL=$((TOTAL_FAIL+1))
if [ $TOTAL_FAIL -eq 0 ]; then
    echo '  ALLES BESTANDEN - Jules OS ist bereit.'
else
    echo "  $TOTAL_FAIL kritische Fehler gefunden"
fi
echo '======================================================'
