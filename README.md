# Linux Recycle Bin System
**Date:** 2025-10-28

## Authors
Inês Batista, 124877<br>
Maria Quinteiro, 124996

## Description
A Linux Recycle Bin Simulator implemented in Bash. It provides a safe deletion and restoration mechanism for files and directories, mimicking the behavior of a graphical Recycle Bin directly in the terminal.
The system maintains a metadata database, log file, configurable policies, and quota management, offering robust file lifecycle control.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/InesBatista28/Linux-Recycle-Bin-Simulation.git
   cd Linux-Recycle-Bin-Simulation
   ```

2. Ensure the main script is executable:
    ```bash
    chmod +x recycle_bin.sh
    ```

3. Add to your PATH for global use:
    ```bash
    export PATH="$PATH:$(pwd)"
    ```

## Usage
To run the Linux Recycle Bin System, use the following syntax:

```bash
./recycle_bin.sh <command> [options] [arguments]
```

Available Commands:
* ```help, -h, --help``` - Display usage information
* ```delete <file/dir> [...]``` - Move files or directories to the Recycle Bin
* ```list [--detailed]``` - List items in the Recycle Bin. Use --detailed for extra metadata.
* ```restore <ID|filename>``` - Restore a deleted item.
* ```search <pattern> [-i]``` - Search by name or path. Use -i for case-insensitive search.
* ```empty [ID] [--force]``` - Permanently delete items, either all or by ID. --force skips confirmation.
* ```stats``` -	Display Recycle Bin statistics (usage, item count, capacity)
* ```cleanup``` -	Trigger manual auto-cleanup of expired files
* ```preview <ID>``` -	Preview a deleted file’s content or type before restoring
* `purge_corrupted` or `purge` - Scan for and remove corrupted or orphaned metadata entries
* `quota` - Display current storage quota and utilization

## Features
* Safe deletion — files are moved, not permanently removed
* Detailed metadata tracking: original path, name, deletion date, type, size, permissions, and owner
* Listing in simple or detailed mode
* Search functionality with optional case-insensitivity
* Restore items to their original locations, with conflict handling (overwrite/rename)
* Empty the recycle bin fully or selectively
* Persistent logging of all actions for auditing and debugging
* Configurable limits for bin size and retention period
* Permission Preservation — Restored files keep original mode and ownership

**Optional Features Implemented:**
* **Statistics Dashboard:**
  - Displays total deleted items, storage usage, and quota utilization
  - Shows oldest and newest deletion timestamps
  - Reports average file size and total occupied space

* **Auto-Cleanup:**
  - Automatically removes files older than RETENTION_DAYS
  - Logs cleanup actions and space reclaimed
  - Triggered manually (cleanup) or automatically during deletion

* **Quota Management:**
  - Enforces maximum bin size (MAX_SIZE_MB)
  - Warns or triggers cleanup when space is exceeded
  - Prevents deletion if the limit is reached

* **File Preview:**
  - Displays the first 10 lines of text files directly from the bin
  - Identifies binary files safely without decoding
  - Helps verify files before restoring them

* **Metadata Integrity (purge_corrupted):**
  - Detects missing or invalid entries in the metadata database
  - Removes corrupted or orphaned records automatically
  - Ensures long-term data consistency between disk and metadata


## Configuration
The configuration file is located at:
```bash
$HOME/.recycle_bin/config
```

Default options:
```bash
MAX_SIZE_MB=1024    # Maximum recycle bin size in MB
RETENTION_DAYS=30   # Number of days to retain deleted files
```
These parameters can be customized to adapt to different disk sizes or retention policies.

## Examples
For detailed usage scenarios, command demonstrations, and output samples, see: [**TESTING.md**](./TESTING.md)

## Known Issues
* Interactive restore conflicts require terminal input (cannot be scripted).
* Permission restoration may fail on restricted filesystems.
* Quota checks apply only to `$HOME/.recycle_bin`, not to system-wide trash folders.
* File preview supports only text-based content for safety.
* Very long filenames (>255 chars) may not be supported on all filesystems.

## References
```bash
- GeeksforGeeks — `sed` Command in Linux/Unix (with examples)  
- GeeksforGeeks — `tail` Command Examples (used for log reading)  
- Baeldung — Reading and Printing Specific Lines from a File  
- StackOverflow — Removing Prefixes/Suffixes from Strings in Bash  
- Baeldung — Creating a Simple Select Menu in Shell Scripts  
- AskUbuntu — Creating Menus with `select` in Bash  
- StackOverflow — Case-Insensitive String Comparison in Shell Scripts  
- Tecmint — Implementing a Recycle Bin in Linux via CLI (Trash-CLI concept)  
- Red Hat — Bash Scripting Best Practices  
- GitHub: tonymorello/trash — Minimal Bash Recycle Bin implementation  
- StackOverflow — File locking in Bash using `.lock` files (for concurrent operations)  
- Linuxize — Reading CSV files line by line in Bash  
- GNU Bash Manual — Using `trap` to handle cleanup and exit conditions  
- OpenAI ChatGPT (GPT-5) — Technical explanation, debugging for Bash script design  
```