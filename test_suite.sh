#!/bin/bash
# Test Suite for Recycle Bin System
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test Helper Functions
setup() {
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

teardown() {
    rm -rf "$TEST_DIR"
    rm -rf ~/.recycle_bin
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

# Test Cases

test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d ~/.recycle_bin ] && echo "✓ Directory created"
    [ -f ~/.recycle_bin/metadata.db ] && echo "✓ Metadata file created"
}

test_delete_single_file() {
    echo "=== Test: Delete Single File ==="
    setup
    echo "test content" > "$TEST_DIR/file1.txt"
    $SCRIPT delete "$TEST_DIR/file1.txt"
    assert_success "Delete single file"
    [ ! -f "$TEST_DIR/file1.txt" ] && echo "✓ File removed"
}

test_delete_multiple_files() {
    echo "=== Test: Delete Multiple Files ==="
    setup
    echo "A" > "$TEST_DIR/fileA.txt"
    echo "B" > "$TEST_DIR/fileB.txt"
    $SCRIPT delete "$TEST_DIR/fileA.txt" "$TEST_DIR/fileB.txt"
    assert_success "Delete multiple files"
    [ ! -f "$TEST_DIR/fileA.txt" ] && [ ! -f "$TEST_DIR/fileB.txt" ] && echo "✓ All files removed"
}

test_delete_empty_directory() {
    echo "=== Test: Delete Empty Directory ==="
    setup
    mkdir -p "$TEST_DIR/emptydir"
    $SCRIPT delete "$TEST_DIR/emptydir"
    assert_success "Delete empty directory"
    [ ! -d "$TEST_DIR/emptydir" ] && echo "✓ Empty directory removed"
}

test_delete_directory_with_contents() {
    echo "=== Test: Delete Directory with Contents ==="
    setup
    mkdir -p "$TEST_DIR/dirA"
    echo "file" > "$TEST_DIR/dirA/fileA.txt"
    $SCRIPT delete "$TEST_DIR/dirA"
    assert_success "Delete directory recursively"
    [ ! -d "$TEST_DIR/dirA" ] && echo "✓ Directory with contents removed"
}

test_list_empty() {
    echo "=== Test: List Empty Bin ==="
    setup
    $SCRIPT list | grep -q "empty"
    assert_success "List empty recycle bin"
}

test_list_with_items() {
    echo "=== Test: List Bin With Items ==="
    setup
    echo "X" > "$TEST_DIR/fileX.txt"
    $SCRIPT delete "$TEST_DIR/fileX.txt"
    $SCRIPT list | grep -q "fileX.txt"
    assert_success "List recycle bin with items"
}

test_restore_single_file() {
    echo "=== Test: Restore Single File ==="
    setup
    echo "restore content" > "$TEST_DIR/restore.txt"
    $SCRIPT delete "$TEST_DIR/restore.txt"
    ID=$($SCRIPT list | grep "restore.txt" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore single file"
    [ -f "$TEST_DIR/restore.txt" ] && echo "✓ File restored"
}

test_restore_to_nonexistent_path() {
    echo "=== Test: Restore to Non-existent Path ==="
    setup
    mkdir -p "$TEST_DIR/sub"
    echo "test" > "$TEST_DIR/sub/file.txt"
    $SCRIPT delete "$TEST_DIR/sub/file.txt"
    ID=$($SCRIPT list | grep "file.txt" | awk '{print $1}')
    rm -rf "$TEST_DIR/sub"
    $SCRIPT restore "$ID"
    assert_success "Restore to non-existent original path"
    [ -f "$TEST_DIR/sub/file.txt" ] && echo "✓ File restored and path recreated"
}

test_empty_recycle_bin() {
    echo "=== Test: Empty Entire Recycle Bin ==="
    setup
    echo "f1" > "$TEST_DIR/f1.txt"
    $SCRIPT delete "$TEST_DIR/f1.txt"
    $SCRIPT empty
    assert_success "Empty recycle bin"
}

test_search_existing_file() {
    echo "=== Test: Search Existing File ==="
    setup
    echo "find me" > "$TEST_DIR/findme.txt"
    $SCRIPT delete "$TEST_DIR/findme.txt"
    $SCRIPT search "findme.txt" | grep -q "findme.txt"
    assert_success "Search for existing file"
}

test_search_nonexistent_file() {
    echo "=== Test: Search Non-existent File ==="
    setup
    $SCRIPT search "nonexistentfile" | grep -q "No matches"
    assert_success "Search for non-existent file"
}

test_help() {
    echo "=== Test: Display Help ==="
    $SCRIPT help | grep -q "Usage"
    assert_success "Help information displayed"
}

test_delete_nonexistent_file() {
    echo "=== Test: Delete Non-existent File ==="
    setup
    $SCRIPT delete "$TEST_DIR/fakefile.txt"
    assert_fail "Delete non-existent file"
}

test_delete_file_no_permission() {
    echo "=== Test: Delete File Without Permission ==="
    setup
    FILE="$TEST_DIR/noperm.txt"
    echo "restricted content" > "$FILE"
    chmod 000 "$FILE"

    $SCRIPT delete "$FILE"
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: Delete file without permissions"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: Delete file without permissions"
        ((FAIL++))
    fi
    chmod 644 "$FILE" 2>/dev/null
}

test_restore_existing_filename() {
    echo "=== Test: Restore When Destination Exists ==="
    setup
    echo "content" > "$TEST_DIR/newfile.txt"
    $SCRIPT delete "$TEST_DIR/newfile.txt"
    ID=$($SCRIPT list | grep "newfile.txt" | awk '{print $1}')
    touch "$TEST_DIR/newfile.txt"  # Simulate existing file
    $SCRIPT restore "$ID"
    assert_success "Restore with existing filename"
}

test_restore_invalid_id() {
    echo "=== Test: Restore Non-existent ID ==="
    setup
    $SCRIPT restore "999999"
    assert_fail "Restore with invalid ID"
}

test_special_characters() {
    echo "=== Test: Filenames with Spaces and Special Characters ==="
    setup
    FILE="$TEST_DIR/complex !@#$.txt"
    echo "special" > "$FILE"
    $SCRIPT delete "$FILE"
    assert_success "Delete file with special chars"
    ID=$($SCRIPT list | grep "complex !@#$.txt" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore file with special chars"
}

# Run all tests
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="

test_initialization
test_delete_single_file
test_delete_multiple_files
test_delete_empty_directory
test_delete_directory_with_contents
test_list_empty
test_list_with_items
test_restore_single_file
test_restore_to_nonexistent_path
test_empty_recycle_bin
test_search_existing_file
test_search_nonexistent_file
test_help
test_delete_nonexistent_file
test_delete_file_no_permission
test_restore_existing_filename
test_restore_invalid_id
test_special_characters

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ $FAIL -eq 1 ]; then
    echo -e "${YELLOW}Note: It's normal for the 'Delete file without permissions' test to fail if the script cannot delete a read-only file.${NC}"
fi

[ $FAIL -eq 0 ] && exit 0 || exit 1
