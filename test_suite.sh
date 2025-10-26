#!/bin/bash
# Complete Test Suite for Linux Recycle Bin Simulator
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ----------------------------------------
# Helper Functions
# ----------------------------------------
setup() {
    rm -rf "$TEST_DIR" ~/.recycle_bin
    mkdir -p "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR" ~/.recycle_bin
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

# ----------------------------------------
# Test Cases
# ----------------------------------------

test_help() {
    echo "=== Test: Help ==="
    setup
    $SCRIPT help > /dev/null 2>&1
    assert_success "Help command works"
}

test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null 2>&1
    assert_success "Recycle bin initialized"
    [ -d ~/.recycle_bin ] && echo "✓ Directory exists"
    [ -f ~/.recycle_bin/metadata.db ] && echo "✓ Metadata file exists"
}

test_delete_file() {
    echo "=== Test: Delete File ==="
    setup
    echo "file1" > "$TEST_DIR/file1.txt"
    echo "file2" > "$TEST_DIR/file2.txt"
    mkdir "$TEST_DIR/folder1"
    $SCRIPT delete "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt" "$TEST_DIR/folder1" > /dev/null 2>&1
    assert_success "Deleted multiple items"
    [ ! -f "$TEST_DIR/file1.txt" ] && echo "✓ file1.txt removed"
    [ ! -f "$TEST_DIR/file2.txt" ] && echo "✓ file2.txt removed"
    [ ! -d "$TEST_DIR/folder1" ] && echo "✓ folder1 removed"
}

test_delete_errors() {
    echo "=== Test: Delete Errors ==="
    setup
    touch "$TEST_DIR/protected.txt"
    chmod 000 "$TEST_DIR/protected.txt"
    $SCRIPT delete "$TEST_DIR/protected.txt" > /dev/null 2>&1
    assert_fail "Delete file without permission"

    $SCRIPT delete nonexistent.txt > /dev/null 2>&1
    assert_fail "Delete nonexistent file"

    $SCRIPT delete ~/.recycle_bin > /dev/null 2>&1
    assert_fail "Attempt to delete recycle bin itself"
}

test_list() {
    echo "=== Test: List ==="
    setup
    echo "file" > "$TEST_DIR/file.txt"
    $SCRIPT delete "$TEST_DIR/file.txt" > /dev/null 2>&1
    $SCRIPT list > /dev/null 2>&1
    assert_success "List recycle bin normal"
    $SCRIPT list --detailed > /dev/null 2>&1
    assert_success "List recycle bin detailed"
}

test_restore_file() {
    echo "=== Test: Restore File ==="
    setup
    echo "restore test" > "$TEST_DIR/file_restore.txt"
    $SCRIPT delete "$TEST_DIR/file_restore.txt" > /dev/null 2>&1
    ID=$($SCRIPT list | grep "file_restore" | awk '{print $1}')
    $SCRIPT restore "$ID" > /dev/null 2>&1
    assert_success "Restore by ID"
    [ -f "$TEST_DIR/file_restore.txt" ] && echo "✓ File restored"

    # Conflict: restore when file exists
    $SCRIPT delete "$TEST_DIR/file_restore.txt" > /dev/null 2>&1
    echo "existing" > "$TEST_DIR/file_restore.txt"
    echo "O" | $SCRIPT restore "$ID" > /dev/null 2>&1
    assert_success "Restore with overwrite"
}

test_search() {
    echo "=== Test: Search ==="
    setup
    echo "data" > "$TEST_DIR/fileA.txt"
    echo "more" > "$TEST_DIR/fileB.TXT"
    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.TXT" > /dev/null 2>&1

    $SCRIPT search "*.txt" > /dev/null 2>&1
    assert_success "Search normal"
    $SCRIPT search "*.TXT" -i > /dev/null 2>&1
    assert_success "Search case-insensitive"
    $SCRIPT search "nonexistent" > /dev/null 2>&1
    assert_success "Search no matches handled"
}

test_empty() {
    echo "=== Test: Empty Recycle Bin ==="
    setup
    echo "file" > "$TEST_DIR/file.txt"
    $SCRIPT delete "$TEST_DIR/file.txt" > /dev/null 2>&1
    $SCRIPT empty --force > /dev/null 2>&1
    assert_success "Empty all items with force"

    # Delete specific ID
    echo "file2" > "$TEST_DIR/file2.txt"
    $SCRIPT delete "$TEST_DIR/file2.txt" > /dev/null 2>&1
    ID=$($SCRIPT list | grep "file2" | awk '{print $1}')
    $SCRIPT empty "$ID" --force > /dev/null 2>&1
    assert_success "Empty specific item by ID"
}

test_limits() {
    echo "=== Test: Limits / MAX_SIZE_MB ==="
    setup
    echo "x" > "$TEST_DIR/largefile.dat"
    echo "MAX_SIZE_MB=0" > ~/.recycle_bin/config
    $SCRIPT delete "$TEST_DIR/largefile.dat" > /dev/null 2>&1
    assert_fail "Delete fails when recycle bin full"
}

test_permissions() {
    echo "=== Test: Permissions ==="
    setup
    touch "$TEST_DIR/protected.txt"
    chmod 000 "$TEST_DIR/protected.txt"
    $SCRIPT delete "$TEST_DIR/protected.txt" > /dev/null 2>&1
    assert_fail "Delete file without permission"
}

# ----------------------------------------
# Run All Tests
# ----------------------------------------
echo "========================================="
echo " Complete Recycle Bin Test Suite"
echo "========================================="

test_help
test_initialization
test_delete_file
test_delete_errors
test_list
test_restore_file
test_search
test_empty
test_limits
test_permissions

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1
