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
