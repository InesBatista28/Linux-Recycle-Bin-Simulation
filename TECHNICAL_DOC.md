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


## 5. Design Decisions and Rationale


## 6. Algorithm Explanations
### 6.1. Deletion Algorithm


### 6.2. Restore Algorithm


### 6.3. Search Algorithm


## 7. Flowcharts (ASCII)
### 7.1. Delete Operation


### 7.2. Restore Operation

