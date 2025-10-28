# Linux Recycle Bin System — Testing
This document describes test cases for the Linux Recycle Bin Simulator.

## Authors
Inês Batista, 124877<br>
Maria Quinteiro, 124996

---

### Test Case 1: Help Command
**Objective:** Verify that the help command displays usage information correctly  

**Steps:**
1. Run: `./recycle_bin.sh help`  
2. Check that usage information is displayed  

**Expected Result:**
- Help message is printed  
- List of commands, options, examples, and config file location are shown  

**Actual Result:**  
- Help message displayed exactly as defined in `display_help()` function, including usage, commands, examples, and configuration file location  

**Status:** ☑ Pass ☐ Fail  

**Screenshots:** 
![Command Help Screenshot](screenshots/command_help.png)

---

### Test Case 2: Initialization of Recycle Bin
**Objective:** Ensure the recycle bin structure is created on first run  

**Steps:**
1. Remove any existing recycle bin: `rm -rf ~/.recycle_bin`  
2. Run any command, e.g.: `./recycle_bin.sh help`  
3. Verify that `~/.recycle_bin/` directory is created  
4. Check for `files/`, `metadata.db`, `config`, and `recyclebin.log`  

**Expected Result:**
- Directories and files are created  

**Actual Result:**  
- `~/.recycle_bin/` created  
- Subdirectory `files/` created  
- Metadata file initialized with header  
- Config file created with defaults  
- Empty log file created  

**Status:** ☑ Pass ☐ Fail  

**Screenshots:** 
![Initialization of Recycle Bin Screenshot](screenshots/initialization_recycle_bin.png)

---

### Test Case 3: Delete Single File
**Objective:** Verify that a single file can be deleted successfully  

**Steps:**
1. Create test file: `echo "test" > test.txt`  
2. Run: `./recycle_bin.sh delete test.txt`  
3. Verify file is removed from current directory  
4. Run: `./recycle_bin.sh list`  
5. Verify file appears in recycle bin  

**Expected Result:**
- File is moved to `~/.recycle_bin/files/`  
- Metadata entry is created  
- Success message is displayed  
- File appears in list output  

**Actual Result:**  
- `'test.txt' moved to Recycle Bin` printed in green  
- File removed from current directory  
- Metadata entry added to `metadata.db`  
- Appears in `list` output with ID, deletion date, and size  

**Status:** ☑ Pass ☐ Fail  

**Screenshots:** 
![Delete a Single File Screenshot](screenshots/delete_single_file.png)

---

### Test Case 4: Delete Multiple Files/Directories
**Objective:** Verify deletion of multiple items at once  

**Steps:**
1. Create files and directories:  
   ```bash
   echo "a" > file1.txt
   echo "b" > file2.txt
   mkdir folder1
2. Run: `./recycle_bin.sh delete file1.txt file2.txt folder1`  
3. Verify items are removed from original locations 
4. Run: `./recycle_bin.sh list`  
5. Verify all items appear in recycle bin  

**Expected Result:**
- All items moved to recycle bin
- Metadata entries exist for each

**Actual Result:**  
- All items removed from current directory
- Each item successfully moved with unique ID
- Metadata updated with ID, path, size, type, permissions, owner
- List shows all items 

**Status:** ☑ Pass ☐ Fail  

**Screenshots:** 
![Delete Multiple Files/Directories Screenshot](screenshots/delete_multiple_files.png)

---

### Test Case 5: Delete Nonexistent File
**Objective:** Ensure proper error handling for nonexistent files

**Steps:**
1. Run: `./recycle_bin.sh delete nonexistent.txt`   

**Expected Result:**
- Error message displayed
- Exit code indicates failure

**Actual Result:**  
- `"ERROR: 'nonexistent.txt' does not exist."` printed in red
- Entry logged in recyclebin.log
- Exit code 0 (loop continues, overall function returns 0 if at least one valid deletion occurred; returns 1 if none)

**Status:** ☑ Pass ☐ Fail  

**Screenshots:** 
![Delete Nonexistent File Screenshot](screenshots/nonexistent_file.png)

---

### Test Case 6: List Recycle Bin Contents

**Objective:** Verify listing of recycle bin items

**Steps:**
1. Delete a test file
2. Run: `./recycle_bin.sh list`
3. Run: `./recycle_bin.sh list --detailed`

**Expected Result:**
- Normal list shows ID, filename, deletion date, size
- Detailed list shows path, permissions, owner, type

**Actual Result:**
- List prints table with ID, name, date, size
- List --detailed prints full metadata with colors for labels
- Total items and total size shown

**Status:** ☑ Pass ☐ Fail

**Screenshots:**
![List Recycle Bin Content Screenshot](screenshots/list_recycle_bin.png)

---

A PARTIR DAQUI AINDA NÃO TEMOS SCREESHOTS 
### Test Case 7: Restore File by ID

**Objective:** Verify file restoration using its ID

**Steps:**
1. Delete a file
2. Get its ID from ./recycle_bin.sh list
3. Run: `./recycle_bin.sh restore <ID>`

**Expected Result:**
- File restored to original location
- Metadata entry removed
- Permissions and owner restored

**Actual Result:**
- File restored successfully
- 'File '<name>' restored successfully to '<path>' printed in green
- Metadata entry removed from metadata.db
- Original permissions and owner set

**Status:** ☑ Pass ☐ Fail

**Screenshots:** 
![Restore File by ID](screenshots/retore_file_id.png)

---

### Test Case 8: Restore FIle with Name Conflict

**Objective:** Test conflict  handling when restoring to a location with already existing file

**Steps:**
1. Delete a file
2. Create a file with the same name as the deleted one at itś otiginal location
3. Run: `./recycle_bin.sh restore <ID>`
4. Test options: overwrite, restore with timestamp, cancel   ????

**Expected Result:**
- Overwrite replaces file
- Timestamp restores with modified name
- Cancel leaves file in recycle bin

**Actual Result:**
- Conflict message shown in yellow
- Prompt allows [O/R/C] choice
- Behavior corresponds to user selection: overwrite, append timestamp, or cancel

**Status:** ☑ Pass ☐ Fail

**Screenshots:**
![Restore File with Name Conflicts](screenshots/name_conflits.png)

---

### Test Case 9: Search Recycle Bin

**Objective:** Search by filename or path, case-sensitive and case-insensitive

**Steps:**
1. Delete multiple files
2. Run: `./recycle_bin.sh search '*.txt'`
3. Run: `./recycle_bin.sh search '*.TXT' -i`

**Expected Result:**
- Matching items displayed in table
- Correct total matches

**Actual Result:**
- Table with ID, name, date, size printed
- Total matches shown
- Case-insensitive works correctly with -i
- Log entry created

**Status:** ☑ Pass ☐ Fail

**Screenshots:**
![Search Recycle Bin](screenshots/search_recycle_bin.png)

---

### Test Case 10: Empty Recycle Bin (All Items)

**Objective:** Permanently delete all items

**Steps:**
1. Delete multiple files
2. Run: `./recycle_bin.sh empty --force`
3. Verify `~/.recycle_bin/files/` is empty
4. Verify metadata cleared

**Expected Result:**
- Items permanently deleted
- Metadata reset
- Log entry created

**Actual Result:**
- All files removed from files/
- Metadata reset to header only
- Green message "All X items permanently deleted"
- Log updated

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]

---

### Test Case 11: Empty Recycle Bin (Single Item)

**Objective:** Delete a specific item by ID

**Steps:**
1. Delete a file
2. Get its ID
3. Run: `./recycle_bin.sh empty <ID>`
4. Verify only that file removed

**Expected Result:**
- Selected file permanently deleted
- Metadata updated
- Other items unaffected

**Actual Result:**
- Item removed from files/
- Metadata entry removed
- Confirmation prompt respected if no --force

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]

---

### Test Case 12: Recycle Bin Size Limit

**Objective:** Verify deletion fails if recycle bin exceeds MAX_SIZE_MB

**Steps:**
1. Set MAX_SIZE_MB=1 in config
2. Try to delete a file larger than 1MB

**Expected Result:**
- Error message displayed
- File not moved

**Actual Result:**
- "ERROR: Recycle Bin limit exceeded (1MB). Cannot move '<file>'" in red
- Log entry created

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]

---

### Test Case 13: Permissions Handling

**Objective:** Verify deletion fails if file has no read/write permissions

**Steps:**
1. Create a file and remove read/write permissions: chmod 000 file.txt
2. Run: `./recycle_bin.sh delete file.txt`

**Expected Result:**
- Error message about permissions
- File remains in original location

**Actual Result:**
- "ERROR: No permission to delete 'file.txt'." printed in red
- Log entry created
- File remains untouched

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]

---

### Test Case 14: Invalid Commands

**Objective:** Ensure unknown commands produce error messages

**Steps:**
Run: `./recycle_bin.sh unknown`

**Expected Result:**
- Error about unknown command
- Suggest using help

**Actual Result:**
- "ERROR: Unknown command: unknown" printed in red
- "Use './recycle_bin.sh help' to see available commands." printed
- Exit code 1

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]