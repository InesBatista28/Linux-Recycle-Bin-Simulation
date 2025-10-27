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
**File:** `~/.recycle_bin/metadata.db`  
**Format:** CSV (Comma-Separated Values) with a header line.

**Schema Definition:**
| **#** | **Field Name** | **Description** |
|:---:|-------------------|------------------|
| 1 | `ID` | Unique identifier composed of the timestamp (in nanoseconds) and process ID. |
| 2 | `ORIGINAL_NAME` | The file’s original name before deletion. |
| 3 | `ORIGINAL_PATH` | The absolute path to the file before deletion. |
| 4 | `DELETION_DATE` | Date and time when the file was moved to the Recycle Bin. |
| 5 | `FILE_SIZE` | Size of the file in bytes. |
| 6 | `FILE_TYPE` | Type of the deleted item — either `file` or `directory`. |
| 7 | `PERMISSIONS` | Original Unix permissions (e.g., `644` or `755`). |
| 8 | `OWNER` | Owner of the file in the format `user:group`. |


**Example Entry:**
```csv
ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER
1698324850000000,mydoc.txt,/home/ines/docs/mydoc.txt,2025-10-27 15:12:45,1048576,file,644,ines:users
```
The unique ID value is ```1698324850000000```.
The ORIGINAL_NAME field stores the original name of the file — in this case, ```mydoc.txt``` — while ORIGINAL_PATH records the full absolute path to where the file was located before being moved to the recycle bin: ```/home/ines/docs/mydoc.txt```.

The date and time of deletion are recorded as ```2025-10-27 15:12:45```, allowing precise tracking of when the file was removed.
The file’s size is stored in FILE_SIZE, which in this example is ```1048576``` bytes.
The FILE_TYPE field specifies the type of the deleted item — here, ```file```, meaning it is a regular file rather than a directory.

The file’s original Unix permissions are preserved, with a value of ```644```, corresponding to access rights rw-r--r--.
Finally, the OWNER field represented here as ```ines:users```.

**Notes:**
* The header row is always preserved when cleaning or recreating metadata.db.
* Each line represents one deleted entity.
* File IDs are used internally for tracking and restoring items accurately.
* The metadata ensures reversibility, enabling full file restoration with original permissions and ownership.


## 4. Function Descriptions
### 4.1. log_msg
Takes two arguments — a log level (string) and a message (string) — and appends a formatted entry to the log file. It generates a timestamp using date.
It logs messages to a file with a timestamp and log level (e.g., INFO, ERROR) for auditing and debugging purposes.

This function is crucial for traceability and error tracking across the entire script. It ensures all operations (deletions, restorations, etc.) are recorded, allowing users to review history and troubleshoot issues. Without it, the system lacks accountability, as other functions call it to log successes, failures, and warnings, making it a backbone for reliability in a file management tool.

### 4.2. initialize_recyclebin
This function sets up the necessary directories, files, and default configurations for the recycle bin system if they don't already exist.
Checks and creates the main recycle bin directory, a subdirectory for files, a metadata database file (with headers), a config file (with defaults like max size and retention), and an empty log file. It handles file system permissions implicitly through mkdir and touch.

This is the foundational setup function, called at the start of most other functions. It ensures the recycle bin infrastructure is ready before any operations, preventing errors like missing directories. Without it, the script couldn't store or manage files safely, making it essential for initialization and consistency across delete, list, restore, and other operations.

### 4.3. generate_id
Generates a unique identifier for each deleted item using a combination of timestamp and process ID.

Unique IDs are critical for tracking individual files in the metadata database and storage directory. This function is called during deletion to assign IDs, which are then used in listing, restoring, searching, and emptying. Without unique IDs, the system couldn't distinguish between items, leading to data corruption or loss in operations like restore or empty.

### 4.4. bytes_available
Uses df to query disk space for the recycle bin directory, with a fallback to 0 if the command fails. Calculates the available disk space in bytes for the recycle bin's location.

Space checks are vital to prevent disk overflows during deletions and restorations. This function is invoked in delete_file and restore_file to ensure operations don't exceed available space, promoting system stability. It's a safety net that integrates with capacity limits, making the recycle bin robust against storage issues.

### 4.5. transform_size
Takes a byte value count as input and iteratively divides by 1024 until it fits a unit (B, KB, MB, etc.), outputting a string like "512MB".
User-facing displays (in list and search functions) rely on readable sizes instead of raw bytes for clarity. This utility enhances usability by making output more intuitive, and it's called whenever sizes need presentation, ensuring consistent formatting across the script.

### 4.6. delete_file
Accepts multiple file/directory paths as arguments. It validates existence, permissions, recycle bin limits (from config), and disk space; generates metadata (ID, name, path, etc. (check 3. Metadata Schema)); and moves items to the recycle bin. Handles errors like non-existent files, full bin, or permission issues, logging them.

This is the core delete operation, central to the recycle bin's purpose. It integrates with initialization, ID generation, space checks, and logging to safely delete items (actually moving them). Other functions (list, restore, search) depend on the metadata it creates, making it indispensable for the system's primary functionality.




## 5. Design Decisions and Rationale


## 6. Algorithm Explanations
### 6.1. Deletion Algorithm


### 6.2. Restore Algorithm


### 6.3. Search Algorithm


## 7. Flowcharts (ASCII)
### 7.1. Delete Operation


### 7.2. Restore Operation

