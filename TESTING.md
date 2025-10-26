# TESTING.md
This document describes test cases for the Linux Recycle Bin Simulator.

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
   ´´´
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


