# Linux Recycle Bin System

## Author
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

## Features
* Move files and directories to a safe Recycle Bin instead of permanent deletion.
* Store detailed metadata (original path, deletion date, size, type, permissions, owner).
* List contents in normal or detailed mode.
* Restore files/directories to their original location with overwrite or renaming options.
* Search deleted items using patterns, supporting case-insensitive search.
* Empty all or specific items from the recycle bin with optional confirmation bypass.
* Logging of all operations for auditing purposes.
* Configuration file for maximum recycle bin size (MAX_SIZE_MB) and retention days (RETENTION_DAYS).

Optional features implemented:
* Detailed listing mode.
* Force deletion without confirmation.
* Automatic directory creation during restore if the original path no longer exists.

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

## Examples
[Detailed usage examples with screenshots]

## Known Issues
* Restoration prompts require interactive input if conflicts occur.
* Recursive restore of directories may not handle nested permissions perfectly in some environments.
* Limited testing on filesystems with very restricted permissions.
* MAX_SIZE_MB is enforced per Recycle Bin folder, not across entire filesystem.

## References
[Resources used]
