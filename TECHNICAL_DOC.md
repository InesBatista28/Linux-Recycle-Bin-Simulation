# Linux Recycle Bin System — Technical Documentation
This project implements a Linux Recycle Bin Simulator using pure Bash scripting.
It replicates the behavior of a recycle bin, allowing users to delete, restore, search, list, and empty files or directories without permanent loss until explicitly emptied.

The system uses a hidden directory `~/.recycle_bin` containing structured subfolders and metadata to track deleted items safely.

**Date:** 2025-10-30

## Authors
Inês Batista, 124877<br>
Maria Quinteiro, 124996

## 1. System Architecture
### 1.1. Project Directory Structure
The project directory represents how the development and documentation files are organized in the local repository.

```bash
LINUX-RECYCLE-BIN-SIMULATION/
├── recycle_bin.sh 
├── test_suite.sh 
├── README.md 
├── TECHNICAL_DOC.md 
├── TESTING.md 
├── screenshots/ 
└── ~/.recycle_bin/ 
```

**Description:**
- `recycle_bin.sh` — Implements all main functionalities of the recycle bin simulator.  
- `test_suite.sh` — Runs automated tests for core operations.  
- `README.md` — Provides introduction, installation, and usage information.  
- `TECHNICAL_DOC.md` — Contains the system’s architecture and technical details.  
- `TESTING.md` — Includes manual and automated test reports.  
- `screenshots/` — Stores images for documentation purposes.  
- `~/.recycle_bin/` — Automatically created at runtime by the simulator script.

---

### 1.2. Runtime Directory Structure
When the simulator runs for the first time, it automatically creates the following structure inside the user’s home directory:

```bash
$HOME/.recycle_bin/
├── files/ 
├── metadata.db 
├── config 
└── recyclebin.log 
```

**Details:**
- `files/` — Contains deleted files renamed with unique identifiers.  
- `metadata.db` — Records original attributes (name, path, date, size, etc.).  
- `config` — Stores configuration parameters set by the user.  
- `recyclebin.log` — Logs all performed operations and potential errors.

---

### 1.3. ASCII Architecture Diagram
The ASCII diagram below provides a structural and functional overview of the **Linux Recycle Bin Simulator**.  
It illustrates the main program (`recycle_bin.sh`), its internal modular functions, and how they interact with the runtime data directory (`$HOME/.recycle_bin`) and the user command layer.

This representation focuses on the core logic layer, showing the *public functions* that implement the simulator’s key features.  
Other helper and utility functions (e.g., log_action(), generate_unique_id(), update_metadata()) also exist within the same script, but are not shown here, as they are internal mechanisms supporting the higher-level operations.

```bash
+-------------------------------------------------------------+
|      Linux Recycle Bin Simulator (recycle_bin.sh)           |
+-------------------------------------------------------------+
| • main()                  → Command dispatcher              |
| • initialize_recyclebin() → Creates structure if missing    |
| • delete_file()           → Moves files to recycle bin      |
| • list_recycled()         → Displays current contents       |
| • restore_file()          → Restores deleted files          |
| • search_recycled()       → Searches items in recycle bin   |
| • empty_recyclebin()      → Permanently removes files       |
| • show_statistics()       → Displays usage statistics       |
| • auto_cleanup()          → Removes files by retention rule |
| • check_quota()           → Enforces recycle bin size limit |
| • preview_file()          → Previews file content           |
| • purge_corrupted()       → Removes broken metadata entries |
| • display_help()          → Shows help and usage info       |
+-------------------------------------------------------------+
            |
            v
+-------------------------------------------------------------+
|      ~/.recycle_bin/ (Runtime Directory)                    |
+-------------------------------------------------------------+
|  files/         → Deleted files                             |
|  metadata.db    → Metadata database                         |
|  config         → User config                               |
|  recyclebin.log → Operation logs                            |
+-------------------------------------------------------------+
```

## 2. Data Flow Diagrams
This section illustrates the internal data flow for the most common operations in the Linux Recycle Bin Simulator.  
Each diagram shows the sequence of interactions between the **user**, the **core script** (`recycle_bin.sh`), and the **runtime data directory** (`~/.recycle_bin/`).
While the main() dispatcher in `recycle_bin.sh` supports several additional commands, only a subset of these operations directly interacts with the recycle bin’s persistent data structures — namely, the **delete**, **restore**, **search**, and **cleanup** processes.

The purpose of this section is to visualize how data moves through the system during these primary actions, highlighting the flow between user input, script logic, and file system persistence.

### 2.1. Delete Operation
The delete operation moves one or more files from the filesystem to the simulated recycle bin. This process includes generating a unique identifier, storing metadata, and logging the event.

#### Data Flow Description
1. **User Input:** The user executes `./recycle_bin.sh delete <file1> [file2 ...]`.
2. **Validation:** The script checks if the recycle bin exists (`initialize_recyclebin()`).
3. **Unique ID Generation:** A new ID is created for each file (`generate_unique_id()`).
4. **Move Operation:** Files are moved to `$HOME/.recycle_bin/files/`.
5. **Metadata Update:** Original name, path, size, and deletion timestamp are stored in `metadata.db`.
6. **Logging:** The action is written to `recyclebin.log`.
7. **Result Output:** The script confirms successful deletion to the user.


#### ASCII Diagram
```bash
User
│
│ delete <file>
▼
+-------------------------------+
| recycle_bin.sh                |
| ├─ check arguments            |
| ├─ initialize_recyclebin()    |
| ├─ generate_unique_id()       |
| ├─ move file to bin           |
| ├─ update metadata.db         |
| ├─ log_action("delete")       |
| └─ echo "File deleted"        |    
+-------------------------------+
│
▼
+-------------------------------+
| ~/.recycle_bin/               |
| ├─ files/<UUID>.deleted       |
| ├─ metadata.db (updated)      |
| └─ recyclebin.log (append)    |
+-------------------------------+
```

---

### 2.2. Restore Operation
The restore operation retrieves a deleted file from the recycle bin and restores it to its original location.

#### Data Flow Description
1. **User Input:** The user runs `./recycle_bin.sh restore <ID|filename>`.
2. **Lookup:** The script searches `metadata.db` for the matching entry.
3. **Validation:** Confirms the file exists in `$HOME/.recycle_bin/files/`.
4. **Move Back:** The file is moved from the recycle bin to its original path.
5. **Metadata Update:** The entry is removed or marked as “restored” in `metadata.db`.
6. **Logging:** The action is appended to `recyclebin.log`.
7. **Result Output:** Confirmation message shown to the user.

#### ASCII Diagram
```bash
User
│
│ restore <ID|filename>
▼
+-------------------------------+
| recycle_bin.sh                |
| ├─ search metadata.db         |
| ├─ verify file existence      |
| ├─ restore to original path   |
| ├─ update metadata.db         |
| ├─ log_action("restore")      |
| └─ echo "File restored"       | 
+-------------------------------+
│
▼
+-------------------------------+
| ~/.recycle_bin/               |
| ├─ files/ (file removed)      |
| ├─ metadata.db (updated)      |
| └─ recyclebin.log (append)    |
+-------------------------------+
```

---

### 2.3. Search Operation
The search operation allows the user to look up deleted files based on name patterns or metadata filters.


#### Data Flow Description
1. **User Input:** The user executes `./recycle_bin.sh search <pattern> [-i]`.
2. **Read Metadata:** The script opens and parses `metadata.db`.
3. **Pattern Matching:** Each record is matched against the user’s search pattern.
4. **Filtering:** If the `-i` flag is provided, case-insensitive search is applied.
5. **Output:** Matching entries are displayed in a formatted list.

#### ASCII Diagram
```bash
User
│
│ search <pattern>
▼
+---------------------------------+
| recycle_bin.sh                  |
| ├─ open metadata.db             |
| ├─ parse each entry             |
| ├─ apply pattern filter         |
| ├─ print matching records       |
| ├─ log_action("search")         |
| └─ echo results                 |
+---------------------------------+
│
▼
+---------------------------------+
| ~/.recycle_bin/                 |
| ├─ metadata.db (read only)      |
| └─ recyclebin.log (append)      |
+---------------------------------+
```

---

### 2.4. Empty / Cleanup Operation
The empty (manual) and cleanup (automatic) operations permanently remove files from the recycle bin.  
These operations are responsible for freeing space and enforcing retention rules defined in the configuration file.

Both processes follow the same core data flow:  
they locate files to be deleted, remove them from the `files/` directory, update `metadata.db`, and record the action in `recyclebin.log`.

#### Data Flow Description

1. **User Input:** Manual cleanup: `./recycle_bin.sh empty [--force]` / Automatic cleanup: triggered internally via `auto_cleanup()` when size or time limits are exceeded.
2. **Initialization:** The script checks that the recycle bin exists and reads configuration parameters from `$HOME/.recycle_bin/config`.
3. **File Selection:** For *empty*, all files in `$HOME/.recycle_bin/files/` are selected. / For *cleanup*, only files exceeding retention time or size limits are targeted.
4. **Deletion Process:** Each selected file is permanently removed from the filesystem using `rm -f`.
5. **Metadata Update:** The corresponding entries are removed (or flagged as deleted) in `metadata.db`.
6. **Logging:** Each deletion is logged in `recyclebin.log` with a timestamp and action tag (`[EMPTY]` or `[CLEANUP]`).
7. **Result Output:** A summary is displayed showing the number of deleted items and total freed space.

#### ASCII Diagram
```bash
User
│
│ empty [--force] or (auto_cleanup trigger)
▼
+--------------------------------------+
| recycle_bin.sh                       |
| ├─ read_config()                     |
| ├─ check_quota() / retention rules   |
| ├─ list target files                 |
| ├─ rm -f selected items              |
| ├─ update metadata.db                |
| ├─ log_action("empty"/"cleanup")     |
| └─ echo summary to user              |
+--------------------------------------+
│
▼
+--------------------------------------+
| ~/.recycle_bin/                      |
| ├─ files/ (removed items)            |
| ├─ metadata.db (entries updated)     |
| └─ recyclebin.log (append entries)   | 
+--------------------------------------+
```


## 3. Metadata Schema
This section describes the structure and purpose of the metadata database used by the recycle bin system.  
It explains each field stored in `metadata.db`, why it is necessary, and how it supports accurate tracking, restoration, and auditing of deleted files.

**File:** `~/.recycle_bin/metadata.db`  
**Format:** CSV (Comma-Separated Values) with a header line.

**Schema Definition:**
| **#** | **Field Name** | **Description** |
|:---:|-------------------|------------------|
| 1 | ID | Unique identifier composed of the timestamp (in nanoseconds) and process ID. |
| 2 | `ORIGINAL_NAME` | The file’s original name before deletion. |
| 3 | ORIGINAL_PATH | The absolute path to the file before deletion. |
| 4 | `DELETION_DATE` | Date and time when the file was moved to the Recycle Bin. |
| 5 | FILE_SIZE | Size of the file in bytes. |
| 6 | `FILE_TYPE` | Type of the deleted item — either `file` or `directory`. |
| 7 | PERMISSIONS | Original Unix permissions (e.g., `644` or `755`). |
| 8 | `OWNER` | Owner of the file in the format `user:group`. |


**Example Entry:**
```csv
ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER
1698324850000000,mydoc.txt,/home/ines/docs/mydoc.txt,2025-10-27 15:12:45,1048576,file,644,ines:users
```
The unique ID value is **1698324850000000**.
The ORIGINAL_NAME field stores the original name of the file — in this case, **mydoc.txt** — while ORIGINAL_PATH records the full absolute path to where the file was located before being moved to the recycle bin: **/home/ines/docs/mydoc.txt**.

The date and time of deletion are recorded as **2025-10-27 15:12:45**, allowing precise tracking of when the file was removed.
The file’s size is stored in FILE_SIZE, which in this example is **1048576** bytes.
The FILE_TYPE field specifies the type of the deleted item — here, **file**, meaning it is a regular file rather than a directory.

The file’s original Unix permissions are preserved, with a value of **644**, corresponding to access rights rw-r--r--.
Finally, the OWNER field represented here as **ines:users**.

**Notes:**
* The header row is always preserved when cleaning or recreating metadata.db.
* Each line represents one deleted entity.
* File IDs are used internally for tracking and restoring items accurately.
* The metadata ensures reversibility, enabling full file restoration with original permissions and ownership.


## 4. Function Descriptions
This section describes all core functions used by the recycle bin script.  
Each function contributes to file management, logging, and recovery processes, ensuring traceability and system reliability.

### 4.1. log_msg
Takes two arguments — a log level (string) and a message (string) — and appends a formatted entry to the log file. It generates a timestamp automatically.  
It logs messages with a timestamp and log level (e.g., INFO, ERROR) for auditing and debugging purposes.  

> This function is crucial for traceability and error tracking across the entire script. All operations — deletions, restorations, errors, and warnings — are recorded here. Other functions call `log_msg` to log their outcomes, making it the backbone of reliability in the system.

### 4.2. initialize_recyclebin
Sets up the necessary directories, files, and default configurations for the recycle bin system if they do not already exist.  
It checks and creates the main recycle bin directory, a subdirectory for files, the metadata database (with headers, see **3. Metadata Schema**), a default config file, and an empty log file.  

> This is the foundational setup function. It ensures the recycle bin infrastructure is ready before any operations. Without it, the script could not store or manage files safely, and functions like delete, list, and restore would fail.

### 4.3. generate_id
Generates a unique identifier for each deleted item using a combination of timestamp and process ID.  

> Unique IDs are critical for tracking individual files in the metadata database and storage directory. They are used during deletion and later referenced by listing, restoring, searching, and emptying operations. Without unique IDs, the system cannot reliably distinguish between items, risking data loss.

### 4.4. bytes_available
Uses `df` to query disk space for the recycle bin directory, returning the available space in bytes (or 0 if the command fails).  

> This function prevents disk overflow during deletions and restorations. It is called by `delete_file` and `restore_file` to ensure operations do not exceed available disk space, promoting system stability.

### 4.5. transform_size
Converts a byte value into a human-readable format (B, KB, MB, etc.), e.g., "512MB".  

> This improves usability in user-facing displays such as `list_recycled` and `search_recycled`. It is called whenever sizes need to be presented, ensuring consistent and intuitive formatting across the script.

### 4.6. delete_file
Accepts one or more file or directory paths as arguments.  
It validates existence, permissions, recycle bin limits, and disk space; generates metadata (ID, name, path, etc., see **3. Metadata Schema**); and moves items to the recycle bin. Handles errors like non-existent files, full bin, or permission issues, and logs them.  

> This is the core delete operation, central to the recycle bin’s purpose. It integrates initialization, ID generation, space checks, and logging to safely move items. Other functions like `list_recycled`, `restore_file`, and `search_recycled` depend on the metadata it creates, making it indispensable.

### 4.7. list_recycled
Displays the contents of the recycle bin in two modes:  
- **Normal table mode:** shows key details (ID, name, date, size, type).  
- **Detailed mode (`--detailed`):** shows all metadata fields for each item, including totals for items and space used.  

> Provides visibility into deleted items, enabling users to browse and make informed decisions. It relies on metadata from `delete_file`, uses `transform_size` for clarity, and integrates with `initialize_recyclebin`. The distinction between modes improves usability, offering quick overviews or detailed inspection.

### 4.8. restore_file
Takes an ID or filename, locates it in metadata, checks for conflicts, prompts for resolution (overwrite, rename, cancel), verifies space, moves the item back, restores permissions and ownership, and updates metadata. Handles directories recursively and errors like missing files.  

> This function reverses deletions, making the recycle bin fully recoverable. Without it, deleted files are permanently lost. Depends on metadata from `delete_file`, space checks from `bytes_available`, and logging.

### 4.9. search_recycled
Searches the recycle bin for items matching a pattern in name or path.  
Supports optional case-insensitivity and formats output similarly to `list_recycled`. Handles no matches gracefully.  

> Enables efficient querying of large recycle bins. Relies on metadata and `transform_size` for display. Complements listing and restoration by helping users locate items quickly.

### 4.10. empty_recyclebin
This function permanently deletes items from the recycle bin, either all or by a specific ID, ensuring complete cleanup when necessary.  
Before execution, it requests confirmation to avoid accidental data loss, unless the `--force` flag is provided, which allows non-interactive or automated cleanups.  
When called without arguments, it empties the entire bin; when provided with an item ID, it removes only that specific entry, updating both the filesystem and the metadata database.  
It logs all operations for auditability and maintains system integrity by verifying that the recycle bin is initialized before deletion.

> This function provides irreversible cleanup operations, making it essential for safe and controlled space management.

### 4.11. display_help
This function prints a comprehensive help guide that lists all available commands, options, and their usage examples.  
It details configuration parameters, command syntax, and expected behavior, ensuring users can operate the recycle bin system confidently without external documentation.  
This built-in help system makes the script self-documenting and accessible for both beginners and advanced users, acting as a quick reference tool directly from the command line.

> This function ensures accessibility and self-documentation by serving as the integrated manual of the recycle bin system.

### 4.12. show_statistics
This function displays summarized statistics about the recycle bin’s current state, providing an overview of total items, total space used, number of files and directories, and capacity utilization.  
It may also include the oldest and most recent deletions, giving insight into storage patterns and cleanup needs.  
By converting raw byte data into readable formats and combining totals from metadata, it allows users or administrators to monitor usage and plan maintenance proactively.

> This function delivers a clear, data-driven view of the recycle bin’s condition, supporting informed maintenance decisions.

### 4.13. auto_cleanup
This function automatically removes files that exceed the configured retention period (`RETENTION_DAYS`), ensuring the recycle bin doesn’t grow uncontrollably over time.  
It reads the policy from the configuration file, checks each entry in the metadata database, and deletes expired items, updating logs and metadata accordingly.  
This automation promotes efficiency and prevents manual intervention, especially in systems that handle frequent deletions or have limited disk space.

> This function enforces retention policies, maintaining stability and efficiency through automated cleanup.

### 4.14. check_quota
This function checks the recycle bin’s total disk usage against the configured quota (`MAX_SIZE_MB`) to ensure it doesn’t exceed its storage limit.  
It calculates the total occupied space, compares it to the defined threshold, and warns the user when capacity is close to full.  
If necessary, it can trigger the `auto_cleanup` process to free space automatically, preventing failures in future deletion or restoration operations.

> This function protects system stability by preventing disk overuse and ensuring automatic compliance with configured limits.

### 4.15. preview_file
This function allows users to preview the contents of a deleted file before restoring it, reducing the risk of restoring unwanted items.  
It accepts a file ID, verifies that the file exists in the recycle bin, and determines its type.  
For text files, it shows the first few lines, while for binary files, it simply reports the file type.  
Each preview attempt is logged for accountability and traceability.

> This function enhances usability and safety by letting users confirm a file’s identity before restoration.

### 4.16. purge_corrupted
This function scans the metadata database for entries that reference files no longer present in the recycle bin's storage directory. It identifies and removes these orphaned or corrupted entries, maintaining the integrity and consistency of the recycle bin system. The function logs all removed entries and provides a summary of the cleanup operation.

> This function ensures long-term data consistency by automatically detecting and resolving metadata-file mismatches, preventing potential restoration errors and system corruption.

### 4.17. main
This function serves as the core entry point and orchestrator of the entire recycle bin system.  
It parses command-line arguments, validates commands, and calls the corresponding function (e.g., `delete_file`, `list_recycled`, `restore_file`, etc.).  
The `main` function ensures structured execution flow, consistent user feedback, and error handling for invalid or incomplete commands.  
It also displays help information when needed, acting as the script’s command dispatcher and control hub.

> This function unifies all operations, acting as the central command dispatcher that coordinates every part of the system.


## 5. Design Decisions and Rationale
This section explains the key design choices behind the recycle bin script, and the reasoning that guided each decision.  
Understanding these decisions helps clarify why the system behaves the way it does and highlights the trade-offs considered during development.

| **Design Choice** | **Rationale** |
|-------------------|---------------|
| Hidden recycle bin directory (`~/.recycle_bin`) | > Mimics real systems (e.g., `.Trash` in Linux desktops) to keep user directories clean. Hiding the directory prevents accidental tampering and reduces clutter in the home folder. |
| Metadata stored as CSV | > Using CSV makes the metadata **human-readable**, portable, and easy to parse with standard Unix tools (`awk`, `cut`, etc.). It also allows debugging without specialized software. |
| Unique ID based on timestamp + PID | > Ensures **zero collision** even if multiple deletions occur simultaneously. Unique IDs are essential for accurate tracking, restoring, and avoiding metadata conflicts. |
| Separate files/folder for each item | > Prevents filename conflicts between deleted items. Each file is stored in its own path within the recycle bin, simplifying restoration and reducing the risk of overwriting files with identical names. |
| Configuration file (`config`) | > Allows **flexible tuning** of parameters like max size and retention days without changing the script. This makes the system adaptable to different user requirements or system constraints. |
| Logging system (`log_msg`) | > Provides **auditability** and **traceability**, supporting debugging and monitoring. Logging all operations ensures accountability and helps identify issues if something goes wrong. |
| Interactive prompts (restore, empty) | > Prevents accidental destructive actions by requiring user confirmation, mirroring the behavior of graphical interfaces. Improves user confidence and reduces mistakes. |
| Portable Bash-only implementation | > Ensures the script runs on **any Linux environment** without dependencies. This increases portability, maintainability, and ease of deployment, even on minimal systems. |
| Metadata validation before operations | > Validates the integrity of the metadata database before performing any action, preventing corruption or inconsistencies that could break restore or delete operations. |
| Default retention policy | > Automatically removes files older than a configurable period, preventing the recycle bin from growing indefinitely and simplifying system maintenance. |
| Error handling and graceful exit | > All functions handle errors (missing files, permission issues, insufficient space) and provide clear messages to the user, preventing silent failures and ensuring predictable script behavior. |


## 6. Algorithm Explanations

This section provides a conceptual overview of the algorithms that implement the key operations in the **Linux Recycle Bin Simulator**.  
Each algorithm corresponds directly to a **data flow diagram** described earlier in **Section 2**, which visually represents the same process in greater detail.

To avoid redundancy, this section focuses on **high-level logic and design goals**, while referencing the appropriate diagrams for full operational context.

### 6.1. Deletion Algorithm
The Deletion Algorithm governs how files are safely moved to the recycle bin instead of being permanently removed.  
It ensures data integrity, traceability, and consistency between the filesystem and metadata.

- **Related Data Flow:** See [Section 2.1 – Delete Operation](#21-delete-operation).  
- **Purpose:** Capture and preserve deleted files securely with full metadata registration.  
- **Core Steps:**  
  1. Validate user input and file accessibility.  
  2. Assign unique IDs and move files to `~/.recycle_bin/files/`.  
  3. Record file details in `metadata.db`.  
  4. Log the operation in `recyclebin.log`.  
- **Design Goal:** Guarantee that no user data is lost until explicitly purged.

#### Pseudocode
```bash
delete_file() {
    for file in "$@"; do
        # Validate input
        if [[ ! -e "$file" ]]; then
            echo "Warning: File not found -> $file"
            continue
        fi

        # Ensure recycle bin structure exists
        mkdir -p "$HOME/.recycle_bin/files"

        # Generate a unique ID (timestamp + random)
        id="$(date +%s)_$RANDOM"

        # Target path inside recycle bin
        target="$HOME/.recycle_bin/files/$id"

        # Move file to recycle bin
        mv "$file" "$target" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            # Append entry to metadata
            echo "$id|$file|$(date +'%Y-%m-%d %H:%M:%S')|$(stat -c%s "$target")" >> "$HOME/.recycle_bin/metadata.db"
            # Log action
            echo "$(date +'%F %T') [DELETE] $file → $id" >> "$HOME/.recycle_bin/recyclebin.log"
        else
            echo "Error: Failed to move $file"
        fi
    done
}
```

---

### 6.2. Restore Algorithm
The Restore Algorithm retrieves deleted files from the recycle bin and places them back in their original or user-specified location.

- **Related Data Flow:** See [Section 2.2 – Restore Operation](#22-restore-operation).  
- **Purpose:** Revert the deletion process with metadata validation.  
- **Core Steps:**  
  1. Look up the file ID or name in `metadata.db`.  
  2. Move the file from `files/` back to its original location.  
  3. Remove its metadata record and log the restoration.  
- **Design Goal:** Provide seamless file recovery while maintaining log accuracy.

#### Pseudocode
```bash
restore_file() {
    local id="$1"
    local metadata_file="$HOME/.recycle_bin/metadata.db"

    # Look up entry in metadata
    local entry
    entry=$(grep "^$id|" "$metadata_file")

    if [[ -z "$entry" ]]; then
        echo "Error: No entry found for ID $id"
        return 1
    fi

    # Parse original path
    local original_path
    original_path=$(echo "$entry" | cut -d'|' -f2)
    local file_path="$HOME/.recycle_bin/files/$id"

    # Recreate directory if needed
    mkdir -p "$(dirname "$original_path")"

    # Move file back
    if mv "$file_path" "$original_path"; then
        # Remove metadata entry
        grep -v "^$id|" "$metadata_file" > "$metadata_file.tmp" && mv "$metadata_file.tmp" "$metadata_file"
        # Log action
        echo "$(date +'%F %T') [RESTORE] $id → $original_path" >> "$HOME/.recycle_bin/recyclebin.log"
        echo "Restored: $original_path"
    else
        echo "Error: Failed to restore $id"
    fi
}
```

---

### 6.3. Search Algorithm
The Search Algorithm provides a way to locate files currently in the recycle bin based on name, pattern, or date range.

- **Related Data Flow:** See [Section 2.3 – Search Operation](#23-search-operation).  
- **Purpose:** Query metadata to display relevant entries without modifying system state.  
- **Core Steps:**  
  1. Parse search parameters and filters.  
  2. Scan `metadata.db` for matches.  
  3. Display results in a structured format.  
- **Design Goal:** Efficient, read-only search across all deleted file records.

#### Pseudocode
```bash
search_recycled() {
    local pattern="$1"
    local metadata_file="$HOME/.recycle_bin/metadata.db"

    if [[ -z "$pattern" ]]; then
        echo "Usage: search_recycled <pattern>"
        return 1
    fi

    echo "Search results for pattern: '$pattern'"
    echo "------------------------------------------------"

    local matches
    matches=$(grep -i "$pattern" "$metadata_file")

    if [[ -n "$matches" ]]; then
        echo "$matches" | awk -F'|' '{ printf "ID: %s | File: %s | Deleted: %s | Size: %s bytes\n", $1, $2, $3, $4 }'
    else
        echo "No matches found."
    fi
}
```

---

### 6.4. Cleanup Algorithm
The Cleanup Algorithm (used in both manual and automatic modes) permanently removes expired or oversized files from the recycle bin.

- **Related Data Flow:** See [Section 2.4 – Empty / Cleanup Operation](#24-empty--cleanup-operation).  
- **Purpose:** Maintain storage efficiency and enforce retention limits.  
- **Core Steps:**  
  1. Load configuration (size and retention policy).  
  2. Identify expired or excess files via `metadata.db`.  
  3. Delete corresponding entries and files from disk.  
  4. Log actions with `[CLEANUP]` or `[AUTO_CLEANUP]` tags.  
- **Design Goal:** Automatically manage storage while ensuring metadata consistency.

#### Pseudocode
```bash
auto_cleanup() {
    local metadata_file="$HOME/.recycle_bin/metadata.db"
    local recycle_dir="$HOME/.recycle_bin/files"
    local retention_days=30   # Default retention (configurable)
    local max_size_mb=500     # Default max bin size (MB)

    # Load configuration if present
    if [[ -f "$HOME/.recycle_bin/config" ]]; then
        source "$HOME/.recycle_bin/config"
    fi

    local now
    now=$(date +%s)
    local freed_space=0
    local removed_count=0

    echo "Running automatic cleanup..."

    while IFS='|' read -r id original_path deletion_date size; do
        local file="$recycle_dir/$id"

        # Convert deletion date to epoch seconds
        local deletion_time
        deletion_time=$(date -d "$deletion_date" +%s 2>/dev/null)

        # Compute file age in days
        local age=$(( (now - deletion_time) / 86400 ))

        # Check expiration or missing files
        if (( age > retention_days )) || [[ ! -f "$file" ]]; then
            rm -f "$file"
            freed_space=$((freed_space + size))
            removed_count=$((removed_count + 1))
            grep -v "^$id|" "$metadata_file" > "$metadata_file.tmp" && mv "$metadata_file.tmp" "$metadata_file"
            echo "$(date +'%F %T') [CLEANUP] Removed $id ($original_path)" >> "$HOME/.recycle_bin/recyclebin.log"
        fi
    done < "$metadata_file"

    echo "Cleanup complete: $removed_count files removed, freed $freed_space bytes."
}
```


## 7. Flowcharts (ASCII)

This section presents the **ASCII flowcharts** that illustrate the internal control flow of the main operations implemented in `recycle_bin.sh`.  
While the **data flow diagrams (Section 2)** focus on how data moves between files and components, these flowcharts focus on **the logical steps and decisions** performed *inside the script itself*.

### 7.1. Delete Operation
This flowchart illustrates how a file deletion request is processed internally.  
The script validates the input, creates a unique identifier for each file, moves it into the recycle bin directory, and updates the metadata and log files to ensure the deletion can be reversed safely later.

```bash
+---------------------+
| User triggers del   |
+---------+-----------+
|
v
+---------------------+
| Validate file(s)    |
+---------+-----------+
|
v
+---------------------+
| Create .recycle_bin |
| if not existing     |
+---------+-----------+
|
v
+---------------------+
| Generate unique ID  |
+---------+-----------+
|
v
+---------------------+
| Move file to ~/...  |
| .recycle_bin/files/ |
+---------+-----------+
|
v
+---------------------+
| Update metadata.db  |
| & recyclebin.log    |
+---------+-----------+
|
v
+---------------------+
| Operation Complete  |
+---------------------+
```

---

### 7.2. Restore Operation
This flowchart shows how a deleted file is restored from the recycle bin.  
The script locates the file’s metadata entry using its ID or name, verifies its presence, and moves it back to its original directory while cleaning up its metadata and logging the event.

```bash
+---------------------+
| User runs restore   |
| (by ID or name)     |
+---------+-----------+
|
v
+---------------------+
| Lookup in metadata  |
| for matching entry  |
+---------+-----------+
|
v
+---------------------+
| Verify file exists  |
| in recycle_bin/files|
+---------+-----------+
|
v
+---------------------+
| Recreate original   |
| directory structure |
+---------+-----------+
|
v
+---------------------+
| Move file back to   |
| original location   |
+---------+-----------+
|
v
+---------------------+
| Update metadata.db  |
| and log RESTORE     |
+---------+-----------+
|
v
+---------------------+
| Operation Complete  |
+---------------------+
```

---

### 7.3. Search Operation
This flowchart represents how the system searches for deleted files.  
The command queries the metadata database (`metadata.db`) using a keyword or pattern, filters the results, and displays a structured summary of matching entries.

```bash
+----------------------+
| User runs search     |
| (pattern or name)    |
+----------+-----------+
|
v
+----------------------+
| Read metadata.db     |
+----------+-----------+
|
v
+----------------------+
| Filter entries by    |
| pattern (grep/awk)   |
+----------+-----------+
|
v
+----------------------+
| Display matches in   |
| formatted output     |
+----------+-----------+
|
v
+----------------------+
| Operation Complete   |
+----------------------+
```

---

### 7.4. Empty / Cleanup Operation
This flowchart outlines how the system automatically or manually cleans up the recycle bin.  
It loads configuration parameters (e.g., maximum size, retention days), iterates over metadata entries, and permanently removes expired or oversized files while keeping the database and logs consistent.

```bash
+-----------------------+
| User or cron triggers |
| empty/cleanup action  |
+-----------+-----------+
|
v
+-----------------------+
| Load config (size &   |
| retention policy)     |
+-----------+-----------+
|
v
+-----------------------+
| Iterate metadata.db   |
| entries               |
+-----------+-----------+
|
v
+-----------------------+
| Check if expired or   |
| exceeds size limit    |
+-----------+-----------+
|               |
|               |
v               v
+-----------+ +----------------+
| Keep file | | Delete file &  |
| (not due) | | update metadata|
+-----------+ +----------------+
|
v
+------------------------+
| Log [CLEANUP] action   |
+-----------+------------+
|
v
+------------------------+
| Operation Complete     |
+------------------------+
```


