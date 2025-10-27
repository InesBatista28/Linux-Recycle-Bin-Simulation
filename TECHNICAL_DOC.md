# Linux Recycle Bin Simulator — Technical Documentation
This project implements a Linux Recycle Bin Simulator using pure Bash scripting.
It replicates the behavior of a recycle bin, allowing users to delete, restore, search, list, and empty files or directories without permanent loss until explicitly emptied.

The system uses a hidden directory `~/.recycle_bin` containing structured subfolders and metadata to track deleted items safely.

## Authors
Inês Batista, 124877<br>
Maria Quinteiro, 124996

## 1. System Architecture
### 1.1. Directory Structure


### 1.2. ASCII Architecture Diagram


## 2. Data Flow Diagrams
### 2.1. Delete Operation


### 2.2. Restore Operation


### 2.3. Search Operation


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

> **Important:** This function is crucial for traceability and error tracking across the entire script. All operations — deletions, restorations, errors, and warnings — are recorded here. Other functions call `log_msg` to log their outcomes, making it the backbone of reliability in the system.

### 4.2. initialize_recyclebin
Sets up the necessary directories, files, and default configurations for the recycle bin system if they do not already exist.  
It checks and creates the main recycle bin directory, a subdirectory for files, the metadata database (with headers, see **3. Metadata Schema**), a default config file, and an empty log file.  

> **Critical:** This is the foundational setup function. It ensures the recycle bin infrastructure is ready before any operations. Without it, the script could not store or manage files safely, and functions like delete, list, and restore would fail.

### 4.3. generate_id
Generates a unique identifier for each deleted item using a combination of timestamp and process ID.  

> **Important:** Unique IDs are critical for tracking individual files in the metadata database and storage directory. They are used during deletion and later referenced by listing, restoring, searching, and emptying operations. Without unique IDs, the system cannot reliably distinguish between items, risking data loss.

### 4.4. bytes_available
Uses `df` to query disk space for the recycle bin directory, returning the available space in bytes (or 0 if the command fails).  

> **Note:** This function prevents disk overflow during deletions and restorations. It is called by `delete_file` and `restore_file` to ensure operations do not exceed available disk space, promoting system stability.

### 4.5. transform_size
Converts a byte value into a human-readable format (B, KB, MB, etc.), e.g., "512MB".  

> **Important:** This improves usability in user-facing displays such as `list_recycled` and `search_recycled`. It is called whenever sizes need to be presented, ensuring consistent and intuitive formatting across the script.

### 4.6. delete_file
Accepts one or more file or directory paths as arguments.  
It validates existence, permissions, recycle bin limits, and disk space; generates metadata (ID, name, path, etc., see **3. Metadata Schema**); and moves items to the recycle bin. Handles errors like non-existent files, full bin, or permission issues, and logs them.  

> **Warning:** This is the core delete operation, central to the recycle bin’s purpose. It integrates initialization, ID generation, space checks, and logging to safely move items. Other functions like `list_recycled`, `restore_file`, and `search_recycled` depend on the metadata it creates, making it indispensable.

### 4.7. list_recycled
Displays the contents of the recycle bin in two modes:  
- **Normal table mode:** shows key details (ID, name, date, size, type).  
- **Detailed mode (`--detailed`):** shows all metadata fields for each item, including totals for items and space used.  

> **Important:** Provides visibility into deleted items, enabling users to browse and make informed decisions. It relies on metadata from `delete_file`, uses `transform_size` for clarity, and integrates with `initialize_recyclebin`. The distinction between modes improves usability, offering quick overviews or detailed inspection.

### 4.8. restore_file
Takes an ID or filename, locates it in metadata, checks for conflicts, prompts for resolution (overwrite, rename, cancel), verifies space, moves the item back, restores permissions and ownership, and updates metadata. Handles directories recursively and errors like missing files.  

> **Critical:** This function reverses deletions, making the recycle bin fully recoverable. Without it, deleted files are permanently lost. Depends on metadata from `delete_file`, space checks from `bytes_available`, and logging.

### 4.9. search_recycled
Searches the recycle bin for items matching a pattern in name or path.  
Supports optional case-insensitivity and formats output similarly to `list_recycled`. Handles no matches gracefully.  

> **Important:** Enables efficient querying of large recycle bins. Relies on metadata and `transform_size` for display. Complements listing and restoration by helping users locate items quickly.

### 4.10. empty_recyclebin
Permanently deletes items from the recycle bin, either all or by specific ID, with confirmation prompts unless forced.  

> **Danger:** This operation cannot be undone. It integrates with metadata management and logging. Users should verify contents with `list_recycled` before executing.

### 4.11. display_help
Prints comprehensive help information, including usage, commands, options, examples, and configuration details.  

> **Helpful:** Acts as the built-in user guide. Essential for accessibility, ensuring users can operate the script without external documentation.

### 4.12. main
Takes command-line arguments, validates commands, and dispatches them to appropriate functions like `delete_file` or `display_help`. Handles unknown commands or missing arguments gracefully.  

> **Critical:** Orchestrates the entire script, tying all functions together. Without `main`, the script cannot respond to user input or execute operations.
### COMPLETAR COM AS FUNÇÕES OPCIONAIS QUE FALTAM


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
### 6.1. Deletion Algorithm


### 6.2. Restore Algorithm


### 6.3. Search Algorithm


## 7. Flowcharts (ASCII)
### 7.1. Delete Operation


### 7.2. Restore Operation

