# Linux Recycle Bin System

## Authors
Inês Batista, 124877<br>
Maria Quinteiro, 124996

## Description
A Linux Recycle Bin Simulator implemented in Bash. This script provides a safe mechanism to delete, restore, search, and permanently remove files/directories, mimicking a graphical Recycle Bin behavior in the terminal. It also logs operations and maintains metadata for all deleted items.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/InesBatista28/Linux-Recycle-Bin-Simulation.git
   cd Linux-Recycle-Bin-Simulation

2. Ensure the main script is executable:
    ```bash
    chmod +x recycle_bin.sh

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
* ```purge``` -	Scan for and remove corrupted or orphaned metadata entries

## Features
* Safe deletion — files are moved, not permanently removed
* Detailed metadata tracking: original path, name, deletion date, type, size, permissions, and owner
* Listing in simple or detailed mode
* Search functionality with optional case-insensitivity
* Restore items to their original locations, with conflict handling (overwrite/rename)
* Empty the recycle bin fully or selectively
* Persistent logging of all actions for auditing and debugging
* Configurable limits for bin size and retention period

**Optional Features Implemented:**
* **Statistics Dashboard:**
  - Display total number of deleted items
  - Show total storage used and quota utilization
  - Separate counts for files and directories
  - Indicate oldest and most recent deletions
  - Report average file size and usage trends

* **Auto-Cleanup:**
  - Automatically delete files older than RETENTION_DAYS
  - Reads policy from configuration file
  - Logs cleanup actions and space recovered
  - Can run manually (cleanup) or automatically during delete

* **Quota Management:**
  - Enforces maximum bin size (MAX_SIZE_MB)
  - Displays warnings when quota is reached
  - Optionally triggers auto-cleanup to free space

* **File Preview:**
  - View first 10 lines of text files directly from the bin
  - Display file type for binary or non-readable files
  - Accepts file ID as input
  - Prevents accidental restoration of unwanted items

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
* Interactive prompts (e.g., during restore conflicts) require terminal input.
* Recursive directory restores may have limited permission compatibility on restricted filesystems.
* Quota checks apply to the configured recycle bin only (~/.recycle_bin/), not system-wide.
* Preview only supports plain text content for readability and safety.

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
```