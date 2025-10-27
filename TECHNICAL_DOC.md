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

**Schema Definition**
| **Column #** | **Field Name**     | **Description** |
|--------------:|-------------------|------------------|
| 1 | `ID` | Unique identifier composed of the timestamp (in nanoseconds) and process ID. |
| 2 | `ORIGINAL_NAME` | The file’s original name before deletion. |
| 3 | `ORIGINAL_PATH` | The absolute path to the file before deletion. |
| 4 | `DELETION_DATE` | Date and time when the file was moved to the Recycle Bin. |
| 5 | `FILE_SIZE` | Size of the file in bytes. |
| 6 | `FILE_TYPE` | Type of the deleted item — either `file` or `directory`. |
| 7 | `PERMISSIONS` | Original Unix permissions (e.g., `644` or `755`). |
| 8 | `OWNER` | Owner of the file in the format `user:group`. |

**Example Entry**
```csv
ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER
1698324850000000,mydoc.txt,/home/ines/docs/mydoc.txt,2025-10-27 15:12:45,1048576,file,644,ines:users
```

**Notes:**
* The header row is always preserved when cleaning or recreating metadata.db.
* Each line represents one deleted entity.
* File IDs are used internally for tracking and restoring items accurately.
* The metadata ensures reversibility, enabling full file restoration with original permissions and ownership.


## 4. Function Descriptions


## 5. Design Decisions and Rationale


## 6. Algorithm Explanations
### 6.1. Deletion Algorithm


### 6.2. Restore Algorithm


### 6.3. Search Algorithm


## 7. Flowcharts (ASCII)
### 7.1. Delete Operation


### 7.2. Restore Operation

