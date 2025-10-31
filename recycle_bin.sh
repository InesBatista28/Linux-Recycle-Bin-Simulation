#!/bin/bash

#################################################
# Script Header Comment
# Author: Inês Batista, Maria Quinteiro
# Date: 2025-10-30
# Description: Linux Recycle Bin Simulator
# Version: 2.1.
#################################################

set -euo pipefail
#################################################
# Function: cleanup
# Purpose: Handles unexpected script interruptions (Ctrl+C or kill signals) and performs safe cleanup before exiting.
# Parameters: None
# Returns: Always exits with code 1 after performing cleanup actions.
#################################################
cleanup() {
  echo "Script interrupted. Performing safe cleanup..."
  echo "Cleanup complete. Exiting safely."
  exit 1
}


# Trap SIGINT (Ctrl+C) and SIGTERM (kill) signals and call cleanup()
trap cleanup SIGINT SIGTERM


#################################################
# Function: show_version
# Purpose: Display script name, version, last update date, and author information.
# Parameters: None
# Returns: 0
#################################################
show_version() {
    echo "=========================================="
    echo " Linux Recycle Bin Simulator"
    echo "------------------------------------------"
    echo " Version:     1.6"
    echo " Last Update: 2025-10-30"
    echo " Authors:     Inês Batista, Maria Quinteiro"
    echo "=========================================="
}



RECYCLE_BIN_DIR="$HOME/.recycle_bin"     # Root directory used to store recycle bin data
FILES_DIR="$RECYCLE_BIN_DIR/files"       # Directory that holds the actual deleted file payloads
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"    # CSV-style metadata store for recycled items
CONFIG_FILE="$RECYCLE_BIN_DIR/config"     # Configuration file for recycle bin behavior
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"    # Log file recording operations and errors

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


#################################################
# Function: log_msg
# Purpose: Append a timestamped log entry to the log file.
# Parameters:
#   $1 - Log level (e.g., INFO, ERROR)
#   $2 - Message to record
# Returns:
#   0 (always - writes to $LOG_FILE)
#################################################
log_msg() {
    local level="${1:-INFO}"  # Default to INFO if $1 is empty
    local msg="${2:-}"        # Empty string if $2 is not provided
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}


#################################################
# Function: initialize_recyclebin
# Purpose: Ensure the recycle bin directory structure and default files exist.
# - Creates $RECYCLE_BIN_DIR, $FILES_DIR
# - Initializes metadata header, config with defaults, and the log file if missing
# Parameters: None
# Returns:
#   0 on success; function does not explicitly return non-zero on failure but will produce messages if directories/files cannot be created.
#################################################
initialize_recyclebin() {
  # Create main directory if it doesn't exist
  if [ ! -d "$RECYCLE_BIN_DIR" ]
  then
    mkdir -p "$RECYCLE_BIN_DIR"
    echo "Directory $RECYCLE_BIN_DIR created."
  fi

  # Create subdirectory 'files' if it doesn't exist
  if [ ! -d "$FILES_DIR" ]
  then
    mkdir -p "$FILES_DIR"
    echo "Subdirectory $FILES_DIR created."
  fi

  # Create metadata.db with header if it doesn't exist
  if [ ! -f "$METADATA_FILE" ]
  then
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
    echo "metadata.db file initialized."
  fi

  # Create config file with default values if it doesn't exist
  if [ ! -f "$CONFIG_FILE" ]
  then
    echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
    echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
    echo "Config file created with default values."
  fi

  # Create empty log file if it doesn't exist
  if [ ! -f "$LOG_FILE" ]
  then
    touch "$LOG_FILE"
    echo "Log file created."
  fi
}



#################################################
# Function: generate_id
# Purpose: Produce a unique identifier for a recycled item. Uses nanosecond epoch plus the current PID to reduce collision risk.
# Parameters: None
# Returns: Writes the generated ID to stdout.
#################################################
generate_id() {
  echo "$(date +%s%N)_$$"
}




#################################################
# Function: bytes_available
# Purpose: Compute available free space (in bytes) on the filesystem containing the recycle bin.
# Parameters: None
# Returns: Prints number of available bytes to stdout. Returns 0 and prints 0 on error.
#################################################
bytes_available() {
  local avail
  avail=$(($(df --output=avail "$RECYCLE_BIN_DIR" 2>/dev/null | tail -1) * 1024))
  # Fallback in case the command returned nothing
    if [ -z "$avail" ]
    then
    avail=0
  fi
  echo "$avail"
}



#################################################
# Function: transform_size
# Purpose: Convert a size in bytes to a human-friendly unit (B, KB, MB, GB, TB).
# Parameters:
#   $1 - Size in bytes
# Returns: Formatted size 
#################################################
transform_size() {
  local bytes="$1"
  local units=("B" "KB" "MB" "GB" "TB")
  local i=0
  while ((bytes >= 1024 && i < 4)); do
    bytes=$((bytes/1024))
    ((i++))
  done
  echo "${bytes}${units[$i]}"
}


#################################################
# Function: delete_file
# Purpose:
#   Move one or more files/directories into the recycle bin:
#   - Validates existence, permissions, and available space
#   - Prevents deleting the recycle bin itself
#   - Records metadata (id, original name, original path, deletion timestamp, size, type, permissions, owner) in $METADATA_FILE
#   - Supports symlinks, files, and directories (directories moved recursively)
# Parameters:
#   $@ - One or more file or directory paths to remove
# Returns:
#   0 if at least one item was processed successfully; 1 if called with no arguments
#################################################
delete_file() {
  initialize_recyclebin

  if [ -f "$CONFIG_FILE" ]
  then
    MAX_SIZE_MB=$(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" | cut -d'=' -f2)
  else
    MAX_SIZE_MB=1024
  fi

  local current_bin_size 
  local max_bin_bytes
  current_bin_size=$(du -sb "$FILES_DIR" 2>/dev/null | awk '{print $1}')
  max_bin_bytes=$((MAX_SIZE_MB * 1024 * 1024))

  if [ $# -eq 0 ]
  then  
    echo -e "${RED}ERROR: No file/directory specified.${NC}"
    log_msg "ERROR" "Attempt to delete with no arguments provided"
    return 1
  fi

  for item in "$@"
  do
    # Validate existence (regular/symlink)
    if [ ! -e "$item" ] && [ ! -L "$item" ]
    then
      echo -e "${RED}ERROR: '$item' does not exist.${NC}"
      log_msg "ERROR" "Attempt to delete non-existent item: $item"
      continue
    fi

    # Protect against deleting the recycle bin directory itself
    if [[ "$item" == "$RECYCLE_BIN_DIR"* ]]
    then
      echo -e "${RED}ERROR: Cannot delete the Recycle Bin itself.${NC}"
      log_msg "ERROR" "Attempt to delete the Recycle Bin: $item"
      continue
    fi

    # Ensure user has read and write permission on the target
    if [ ! -r "$item" ] || [ ! -w "$item" ]
    then  
      echo -e "${RED}ERROR: No permission to delete '$item'.${NC}"
      log_msg "ERROR" "No permission to delete $item"
      continue
    fi

    id=$(generate_id)
    # Determine type and size
    if [ -L "$item" ]
    then
      type="symlink"
      size=$(stat -c %s "$item")
    elif [ -d "$item" ]
    then
      type="directory"
      size=$(du -sb "$item" | awk '{print $1}')
    else
      type="file"
      size=$(stat -c %s "$item")
    fi


    # Check against configured recycle bin quota
    if (( current_bin_size + size > max_bin_bytes ))
    then
      echo -e "${RED}ERROR: Recycle Bin limit exceeded (${MAX_SIZE_MB}MB). Cannot move '$item'.${NC}"
      log_msg "ERROR" "Recycle Bin full — limit ${MAX_SIZE_MB}MB exceeded when adding $item"
      continue
    fi

    # Confirm there is available disk space on the underlying filesystem
    available=$(bytes_available)
    available=${available:-0} 


    if [ "$available" -lt "$size" ]
    then
      echo -e "${RED}ERROR: Not enough space to move '$item'.${NC}"
      log_msg "ERROR" "Insufficient space for $item, size $size bytes."
      continue
    fi

    original_name=$(basename "$item")
    original_path=$(realpath -s "$item")
    deletion_date=$(date +"%Y-%m-%d %H:%M:%S")
    permissions=$(stat -c %a "$item")
    owner=$(stat -c %U:%G "$item")
    echo "$id,$original_name,$original_path,$deletion_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"
    # check free bytes on the filesystem containing $FILES_DIR
    free_space=$(df -PB1 "$FILES_DIR" | awk 'NR==2 {print $4}')
    if [ "${free_space:-0}" -lt "$size" ]
    then
      needed_mb=$(( size / 1024 / 1024 ))
      avail_mb=$(( free_space / 1024 / 1024 ))
      echo -e "${RED}Insufficient disk space: need ${needed_mb} MB, only ${avail_mb} MB available.${NC}"
      log_msg "ERROR: Not enough space to move $item (needed: ${needed_mb} MB, available: ${avail_mb} MB)"
      continue
    fi


    # Move/copy the item into the recycle bin storage area
    if [ "$type" = "symlink" ]
    then
      cp -P "$item" "$FILES_DIR/$id"
      if [ $? -ne 0 ]
      then
        echo -e "${RED}ERROR: Failed to copy symlink '$item' to Recycle Bin.${NC}"
        log_msg "ERROR" "Failed to copy symlink $item to Recycle Bin"
        continue
      fi
      rm "$item"
    else
      mv "$item" "$FILES_DIR/$id" 2>/dev/null
      if [ $? -ne 0 ]
      then
        echo -e "${RED}ERROR: Failed to move '$item' to Recycle Bin.${NC}"
        log_msg "ERROR" "Failed to move $item to Recycle Bin"
        continue
      fi
    fi

    current_bin_size=$((current_bin_size + size))

    echo -e "${GREEN} '$original_name' moved to Recycle Bin.${NC}"
    log_msg "INFO" "'$original_name' moved to Recycle Bin with ID $id"
  done

  return 0
}







#################################################
# Function: list_recycled
# Purpose:
#   Display the contents of the recycle bin in a tabular format.
#   If '--detailed' is provided, show full metadata for each item.
#   Also prints totals for number of items and total size used.
# Parameters:
#   $1 - Optional flag '--detailed' to enable detailed view
# Returns:
#   0 on success (also returns 0 when bin is empty)
#################################################
list_recycled() {
  initialize_recyclebin

    # Check if metadata file exists and is not empty
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
    then
        echo -e "${YELLOW}Recycle Bin is empty.${NC}"
        return 0
    fi

  # Check if detailed mode is requested - FIX: handle no arguments
    local detailed=false
    if [ $# -gt 0 ] && [ "$1" == "--detailed" ]
    then
        detailed=true
    fi





  local total_items
  local total_size

  total_items=$(($(wc -l < "$METADATA_FILE") - 1))  
  # subtract header
  # Set comma as delimiter, ignore header, sum fifth column, and print total
  total_size=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$METADATA_FILE")

  echo -e "${YELLOW}Recycle Bin Contents: ${NC}"
  # NORMAL MODE
  if [ "$detailed" = false ]
  then
  printf "${GREEN}%-35s | %-25s | %-30s | %-12s${NC}\n" "ID" "Original filename" "Deletion date and time" "File size"


    # Read metadata file ignoring header and print rows
    tail -n +2 "$METADATA_FILE" | while read line; do
      id=$(echo "$line" | cut -d',' -f1)
      original_name=$(echo "$line" | cut -d',' -f2)
      deletion_date=$(echo "$line" | cut -d',' -f4)
      size=$(echo "$line" | cut -d',' -f5)

      # Convert to readable size
      readable_size=$(transform_size "$size")
      printf "%-35s | %-25s | %-30s | %-12s\n" "$id" "$original_name" "$deletion_date" "$readable_size"
    done 

  # DETAILED MODE
  else
    tail -n +2 "$METADATA_FILE" | while read line
    do

      id=$(echo "$line" | cut -d',' -f1)
      original_name=$(echo "$line" | cut -d',' -f2)
      original_path=$(echo "$line" | cut -d',' -f3)
      deletion_date=$(echo "$line" | cut -d',' -f4)
      size=$(echo "$line" | cut -d',' -f5)
      type=$(echo "$line" | cut -d',' -f6)
      permissions=$(echo "$line" | cut -d',' -f7)
      owner=$(echo "$line" | cut -d',' -f8)

      readable_size=$(transform_size "$size")
      echo -e "${GREEN}ID:${NC}               $id"
      echo -e "${GREEN}Original name:${NC}   $original_name"
      echo -e "${GREEN}Original path:${NC}   $original_path"
      echo -e "${GREEN}Deletion date:${NC}   $deletion_date"
      echo -e "${GREEN}Size:${NC}            $readable_size"
      echo -e "${GREEN}Type:${NC}            $type"
      echo -e "${GREEN}Permissions:${NC}     $permissions"
      echo -e "${GREEN}Owner:${NC}           $owner"
      echo
    done
  fi

  readable_total=$(transform_size "$total_size")
  echo "Total items: $total_items"
  echo "Total space used: $readable_total"

}



#################################################
# Function: restore_file
# Purpose:
#   Restore an item from the recycle bin back to its original location.
#   Accepts either the recycle ID or the original filename to find the entry.
#   Handles destination conflicts (overwrite, rename, cancel), recreates parent
#   directories when necessary, restores permissions, and removes metadata entry
#   on successful restore.
# Parameters:
#   $1 - Recycle ID or original filename
# Returns:
#   0 on success; 1 on error or if the item is not found
#################################################
restore_file() {
    local target="$1"

    if [ -z "$target" ]
    then
        echo "Usage: restore_file <file_id_or_name>"
        return 1
    fi




    # Find the first matching metadata entry by ID or by name field
    match=$(grep -m1 -E "^$(printf '%s' "$target"),|,$(printf '%s' "$target")," "$METADATA_FILE")

    if [ -z "$match" ]
    then
        echo "Error: Item not found in recycle bin." >&2
        log_msg "RESTORE_FAIL: Item not found ($target)"
        return 1
    fi

    # parse CSV fields into local variables
    IFS=',' read -r id name path date size type perms owner <<< "$match"
    source_path="$FILES_DIR/$id"
    dest_path="$path"

    if [ ! -w "$(dirname "$dest_path")" ]
    then
      echo "Error: Cannot restore to read-only directory." >&2
      log_msg "RESTORE_FAIL: Read-only directory for $name ($id)"
      return 1
    fi



    # Check if source exists
    if [ ! -e "$source_path" ]
    then
        echo "Error: Recycled file data missing for '$name'." >&2
        log_msg "RESTORE_FAIL: Missing source file ($id)"
        return 1
    fi

    # Handle existing destination
    if [ -e "$dest_path" ]
    then
        echo "File already exists at destination:"
        echo "  $dest_path"
        read -rp "Overwrite (o), rename (r), or cancel (c)? " choice
        case "$choice" in
            o|O)
                ;;
            r|R)
                timestamp=$(date +%s)
                dest_dir=$(dirname "$dest_path")
                base_name=$(basename "$dest_path")
                dest_path="${dest_dir}/${base_name}_restored_${timestamp}"
                ;;
            *)
                echo "Restore cancelled."
                log_msg "RESTORE_CANCELLED: $name ($id)"
                return 0
                ;;
        esac
    fi

    # Ensure destination directory exists
    mkdir -p "$(dirname "$dest_path")" 2>/dev/null || {
        echo "Error: Cannot create destination directory." >&2
        log_msg "RESTORE_FAIL: Cannot create directory for $name ($id)"
        return 1
    }


    # Check available space at the destination filesystem before moving
    required_space=$(du -sb "$source_path" | awk '{print $1}')
    available_space=$(df -P "$(dirname "$dest_path")" | awk 'NR==2 {print $4 * 1024}')

    if (( available_space < required_space ))
    then
        echo "Error: Not enough disk space to restore '$name'." >&2
        log_msg "RESTORE_FAIL: Insufficient disk space for $name ($id)"
        return 1
    fi






    # Perform the restore: move payload back  and restore permissions  andf update metadata
    if mv "$source_path" "$dest_path"
    then
        chmod "$perms" "$dest_path" 2>/dev/null
        grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
        echo "Restored '$name' to '$dest_path'"
        log_msg "RESTORE_SUCCESS: $name ($id) -> $dest_path"
    else
        echo "Error: Failed to move '$name' back to destination." >&2
        log_msg "RESTORE_FAIL: mv command failed for $name ($id)"
        return 1
    fi
}







#################################################
# Function: search_recycled
# Purpose:
#   Search the metadata records for matches against filename or original path.
#   Supports shell-style wildcard patterns and an optional case-insensitive mode.
# Implementation notes:
#   - Uses process substitution to avoid subshell variable scoping issues.
# Parameters:
#   $1 - Search pattern (e.g., "*.txt" or "report")
#   $2 - Optional "-i" to enable case-insensitive matching (may be provided as $1 or $2)
# Returns:
#   0 on success; 1 on error (e.g., no pattern supplied)
#################################################
search_recycled() {
    initialize_recyclebin

    local pattern=""
    local case_flag=""

    # Handle arguments safely - FIXED
    if [ $# -eq 0 ]
    then
        echo -e "${RED}ERROR: No search pattern specified.${NC}"
        log_msg "ERROR" "Search attempt with no pattern."
        return 1
    fi

    # Handle case where only -i is provided
    if [ "$1" == "-i" ]
    then
        case_flag="-i"
        pattern="${2:-}"  # Use empty if $2 not provided
        if [ -z "$pattern" ]
        then
            echo -e "${RED}ERROR: No search pattern specified.${NC}"
            log_msg "ERROR" "Search attempt with no pattern."
            return 1
        fi
    elif [ $# -ge 2 ] && [ "$2" == "-i" ]
    then
        case_flag="-i"
        pattern="$1"
    else
        pattern="$1"
    fi

    # Check for pattern (should not be empty after above processing)
    if [ -z "$pattern" ]
    then
        echo -e "${RED}ERROR: No search pattern specified.${NC}"
        log_msg "ERROR" "Search attempt with no pattern."
        return 1
    fi

    # Case-insensitive search option
    local shopt_reset=false
    if [ "$case_flag" == "-i" ]
    then
        # Check if nocasematch is already set, so we can reset it properly
        shopt -q nocasematch || shopt_reset=true
        shopt -s nocasematch # Enable case-insensitive globbing
    fi

    local match_found=false
    local line_count=0
    local results_body="" # Store formatted lines

    # Use process substitution < <(command) to read from the 'tail' command
    # This avoids running the 'while' loop in a subshell, so variables (match_found, line_count) retain their values.   <<<<<<--------IMPORTANT
    while IFS=',' read -r id name path date size type perms owner; do
        
        # Search name and path using the wildcard pattern
        if [[ "$name" =~ $pattern || "$path" =~ $pattern ]]
        then
            match_found=true
            line_count=$((line_count + 1))
            
            local readable_size
            readable_size=$(transform_size "$size")
            # Append the formatted line (including its newline) to the results variable
            results_body+=$(printf "%-35s | %-25s | %-30s | %-12s\n" "$id" "$name" "$date" "$readable_size")
        fi
    done < <(tail -n +2 "$METADATA_FILE") # Read from metadata, skip header

    # Reset shell option if we changed it
    if [ "$shopt_reset" = true ]
    then
        shopt -u nocasematch
    fi

    # Show message if no matches found
    if [ "$match_found" = false ]
    then
        echo -e "${YELLOW}No matches found for '$pattern'.${NC}"
        log_msg "INFO" "Search for '$pattern' found 0 matches."
    else
        # Display table format
        echo -e "${YELLOW}Search results for '$pattern':${NC}"


        printf "${GREEN}%-35s | %-25s | %-30s | %-12s${NC}\n" "ID" "Original filename" "Deletion date and time" "File size"
        # Print the stored body
        echo "$results_body"
        echo "Total matches found: $line_count"
        log_msg "INFO" "Search for '$pattern' found $line_count matches."
    fi
    
    return 0
}



#################################################
# Function: empty_recyclebin
# Purpose: Permanently remove items from the recycle bin. Modes:
#     - No argument: prompt and delete all entries
#     - ID provided: prompt and delete the specific entry and payload
#             Supports --force to skip confirmation prompts.
# Parameters:
#   $1 - Optional ID of item to remove or --force
#   $2 - Optional --force if not given as $1
# Returns:
#   0 on success; 1 on error
#################################################
empty_recyclebin() {
    local target=""
    local force=false

    # capture a target ID or the --force flag
    for arg in "$@"; do
        case "$arg" in
            --force) force=true ;;
            *) target="$arg" ;;
        esac
    done

    # If metadata missing or contains only header, nothing to do
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
    then
        echo "Recycle bin is already empty."
        log_msg "EMPTY_SKIP: Recycle bin already empty"
        return 0
    fi

    # MODO 1: Empty entire bin
    if [ -z "$target" ]
    then
        if [ "$force" = false ]
        then
            read -rp "This will permanently delete ALL items. Continue? (y/n): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; return 0; }
        fi

        # Count metadata rows excluding header
        local line_count
        line_count=$(($(wc -l < "$METADATA_FILE") - 1))
        if (( line_count < 0 ))
        then
            line_count=0; fi




        # Try to remove payload files and reinitialize metadata header
        if rm -rf "$FILES_DIR"/* 2>/dev/null
        then
            echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
            echo "Emptied recycle bin ($line_count items)."
            log_msg "EMPTY_BIN: Deleted all ($line_count items)"
        else
            echo "Error: Could not delete some files. Check permissions." >&2
            log_msg "EMPTY_FAIL: Permission error deleting all items"
            return 1
        fi
        return 0
    fi





    # MODO 2: Delete a specific item by ID
    match=$(grep -m1 "^$target," "$METADATA_FILE")
    if [ -z "$match" ]
    then 
        echo "Error: Item ID '$target' not found."
        log_msg "EMPTY_FAIL: Item not found ($target)"
        return 1
    fi

    IFS=',' read -r id name path date size type perms owner <<< "$match"

    if [ "$force" = false ]
    then
        read -rp "This will permanently delete '$name' ($id). Continue? (y/n): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; return 0; }
    fi

    # Remove payload and update metadata accordingly
    if [ -e "$FILES_DIR/$id" ]
    then
        if rm -rf "$FILES_DIR/$id" 2>/dev/null
        then
            grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
            echo "Permanently deleted '$name' ($id)."
            log_msg "EMPTY_ITEM: Permanently deleted $name ($id)"


        else
            echo "Error: Failed to delete '$name' due to permission issues." >&2
            log_msg "EMPTY_FAIL: Permission denied deleting $name ($id)"
            return 1
        fi


    else
        echo "Warning: File data not found for '$name' ($id). Cleaning metadata."
        grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
        log_msg "EMPTY_WARN: Missing data file for $name ($id) removed from metadata"
    fi
}







#################################################
# Function: display_help
# Purpose: Print comprehensive usage help, available commands, options, examples, and file locations.
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << 'EOF'
Usage:
  ./recycle_bin.sh <command> [options] [arguments]

Avaliable Commands:
  init                     Initialize recycle bin directory structure and configuration
  delete <path(s)>         Move file(s) or directory(ies) to recycle bin
  list [--detailed]        List recycled items in compact or detailed view
  restore <id|name>        Restore file by ID or filename
  search <pattern> [--ignore-case]
                           Search for items in the recycle bin (supports wildcards)
  empty [<id>] [--force]   Permanently delete all or specific recycled items
  help, -h, --help         Display this help message

Command Line Options:
  --detailed               Show full information when listing items
  --ignore-case            Make searches case-insensitive
  --force                  Skip confirmation prompts (dangerous!)
  -h, --help               Show this help message

Examples:
  ./recycle_bin.sh init
  ./recycle_bin.sh delete myfile.txt
  ./recycle_bin.sh delete file1.txt file2.txt Documents/
  ./recycle_bin.sh list
  ./recycle_bin.sh list --detailed
  ./recycle_bin.sh restore 1696234567_abc123
  ./recycle_bin.sh search "report"
  ./recycle_bin.sh search "*.pdf" --ignore-case
  ./recycle_bin.sh empty
  ./recycle_bin.sh empty 1696234567_abc123
  ./recycle_bin.sh empty --force

Configuration:
  Config file:   ~/.recycle_bin/config
  Log file:      ~/.recycle_bin/recyclebin.log
  Metadata file: ~/.recycle_bin/metadata.db
  Files folder:  ~/.recycle_bin/files/

Configuration Parameters:
  MAX_SIZE_MB=1024      # Maximum total recycle bin size (in MB)
  RETENTION_DAYS=30     # Number of days before automatic cleanup
EOF
}




# OPTIONAL FUNCTIONS

#################################################
# Function: show_statistics
# Purpose: Print aggregated statistics about the recycle bin:
#   - Total items, total storage used, breakdown by type
#   - Oldest and newest deletion timestamps
#   - Average file size and quota utilization percentage
# Parameters: None
# Returns: 0
#################################################
show_statistics() {
    # If metadata absent or only header, report empty
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
    then
        echo "Recycle bin is empty."
        log_msg "STATS" "No data to display"
        return 0
    fi

    echo "Recycle Bin Statistics"



    # Simple count
    local total_items=$(($(wc -l < "$METADATA_FILE") - 1))
    echo "Total items: $total_items"
    
    # Simple size calculation
    local total_size=0
    if [ $total_items -gt 0 ]
    then
        total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum+=$5} END {print sum}')
        echo "Total size: $(transform_size "$total_size")"
    fi
    
    log_msg "STATS" "Displayed statistics: $total_items items, ${total_size}B"
}




#################################################
# Function: auto_cleanup
# Purpose: Remove recycled items older than the retention period (RETENTION_DAYS).
#   - Loads RETENTION_DAYS from config (defaults to 30)
#   - Deletes payloads older than the cutoff and removes their metadata entries
#   - Logs deletions and summarizes results
# Parameters: None
# Returns: 0 on success; 1 if recycle bin not initialized
#################################################
auto_cleanup() {
    # Ensure metadata exists
    if [ ! -f "$METADATA_FILE" ]
    then
        echo "Recycle bin not initialized."
        log_msg "CLEANUP_FAIL: Recycle bin not initialized"
        return 1
    fi



    # Load configuration or fall back to 30 days
    local RETENTION_DAYS=30
    if [ -f "$CONFIG_FILE" ]
    then
      RETENTION_DAYS=$(grep -E '^RETENTION_DAYS=' "$CONFIG_FILE" | cut -d'=' -f2)
      RETENTION_DAYS="${RETENTION_DAYS:-30}"
    else
        echo "Warning: Config file not found. Using default RETENTION_DAYS=30."
        RETENTION_DAYS=30
    fi

    # If there are no entries, nothing to do
    if [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
    then
        echo "Recycle bin is empty — nothing to clean."
        log_msg "CLEANUP_SKIP: Recycle bin empty"

        return 0
    fi

    # Compute cutoff timestamp in seconds
    local cutoff_ts
    cutoff_ts=$(date -d "-${RETENTION_DAYS} days" +%s)



    local deleted_count=0
    local freed_space=0




    # Iterate metadata and delete items older than cutoff
    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        # Convert deletion date into timestamp (fallback to 0 on parse error)
        file_ts=$(date -d "$date" +%s 2>/dev/null || echo 0)

        if (( file_ts > 0 && file_ts < cutoff_ts ))
        then

            if [ -e "$FILES_DIR/$id" ]
            then


                if rm -rf "$FILES_DIR/$id" 2>/dev/null
                then
                    ((deleted_count++))
                    ((freed_space += size))
                    log_msg "CLEANUP_DELETE: Removed $name ($id) — older than $RETENTION_DAYS days"

                else
                    log_msg "CLEANUP_FAIL: Permission denied deleting $name ($id)"
                fi


            else
                log_msg "CLEANUP_WARN: Missing data file for $name ($id)"
            fi

            # Remove metadata entry for the deleted item
            grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
        fi
    done

    # Recompute summary values in a reliable manner (outside the loop)
    deleted_count=$(grep -c "CLEANUP_DELETE" "$LOG_FILE")
    freed_space_bytes=$(awk -F',' '{sum+=$5} END{print sum}' "$METADATA_FILE")
    human_freed=$(transform_size "$freed_space")

    # Summarize results to the user
    echo "Auto Cleanup Summary"
    printf "%-25s %s days\n" "Retention period:" "$RETENTION_DAYS"
    printf "%-25s %s items\n" "Items deleted:" "$deleted_count"
    printf "%-25s %s\n" "Space freed:" "$human_freed"

    log_msg "CLEANUP_SUMMARY: deleted=$deleted_count freed=${freed_space}B retention=${RETENTION_DAYS}d"
}




#################################################
# Function: check_quota
# Purpose: Evaluate current recycle bin usage against configured MAX_SIZE_MB:
#   - Reports total used, quota limit, and percentage used
#   - If quota exceeded, log warning and attempt auto_cleanup if available
# Parameters: None
# Returns: 0 on success; 1 if recycle bin not initialized
#################################################
check_quota() {
    # Ensure recycle bin exists
    if [ ! -d "$FILES_DIR" ]
    then
        echo "Recycle bin not initialized."
        log_msg "QUOTA_FAIL: recycle bin not initialized"
        return 1
    fi

    # Load configuration or set default
    if [ -f "$CONFIG_FILE" ]
    then
      MAX_SIZE_MB=$(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" | cut -d'=' -f2)
      MAX_SIZE_MB="${MAX_SIZE_MB:-1024}"


    else
        echo "Warning: Config file not found. Using default MAX_SIZE_MB=1024"
        MAX_SIZE_MB=1024
    fi

    # Compute current usage in bytes
    local total_bytes
    total_bytes=$(du -sb "$FILES_DIR" 2>/dev/null | awk '{print $1}')
    total_bytes=${total_bytes:-0}
    local max_bytes=$((MAX_SIZE_MB * 1024 * 1024))

    # Compute usage percentage
    local usage_pct=0
    if (( max_bytes > 0 ))
    then
        usage_pct=$(( (100 * total_bytes) / max_bytes ))
    fi




    # Convert total to a human-readable string
    local total_hr
    total_hr=$(transform_size "$total_bytes")

    echo "Recycle Bin Quota Status"
    printf "%-25s %s\n" "Total used:" "$total_hr"
    printf "%-25s %s MB\n" "Quota limit:" "$MAX_SIZE_MB"
    printf "%-25s %s%%\n" "Usage:" "$usage_pct"




    # If quota exceeded, notify and optionally trigger cleanup
    if (( total_bytes > max_bytes ))
    then
        echo "WARNING: Recycle bin exceeds quota limit!"
        log_msg "QUOTA_WARN: ${usage_pct}% used (limit ${MAX_SIZE_MB}MB)"

        # Trigger automatic cleanup if the function is defined
        if declare -F auto_cleanup >/dev/null
        then
            echo "Triggering automatic cleanup..."
            auto_cleanup
        fi


    else
        log_msg "QUOTA_OK: ${usage_pct}% used (${total_hr}/${MAX_SIZE_MB}MB)"
    fi
}


#################################################
# Function: preview_file
# Purpose: Provide a short preview of a recycled file:
#   - If text/* mime type, show first 10 lines
#   - Otherwise display file type information
# Parameters: $1 - Recycle ID
# Returns: 0 on success; 1 on error
#################################################
preview_file() {
    local id="$1"

    # Basic argument validation
    if [ -z "$id" ]
    then
        echo "Usage: ./recycle_bin.sh preview <file_id>"
        return 1
    fi
    if [ ! -f "$METADATA_FILE" ]
    then
        echo "Recycle bin not initialized."
        return 1
    fi

    # Lookup metadata entry by ID
    local entry
    entry=$(grep "^$id," "$METADATA_FILE")

    if [ -z "$entry" ]
    then
        echo "Error: No item found with ID '$id'."
        log_msg "PREVIEW_FAIL: ID not found ($id)"
        return 1
    fi




    local file_path="$FILES_DIR/$id"
    local original_name



    original_name=$(echo "$entry" | awk -F',' '{print $2}')

    if [ ! -f "$file_path" ]
    then
        echo "Error: Recycled file not found ($file_path)"
        log_msg "PREVIEW_FAIL: Missing file for ID $id"
        return 1
    fi

    echo "Preview of: $original_name"



    # Determine MIME type to decide how to preview
    local ftype
    ftype=$(file -b --mime-type "$file_path")

    # If text, show first lines; else show file information
    if [[ "$ftype" == text/* ]]
    then
        head -n 10 "$file_path"
        echo "(Showing first 10 lines)"

    else
        echo "Binary or non-text file detected:"
        file "$file_path"
    fi



    log_msg "PREVIEW_OK: $original_name ($id) type=$ftype"
}





#################################################
# Function: purge_corrupted
# Purpose: Identifies and removes corrupted or partially created Docker resources that may cause build failures, inconsistent states, or deployment issues.
# Parameters: None
# Returns:  0 if the cleanup completes successfully. Non-zero exit code if any Docker command fails.
#################################################
#################################################
# Function: purge_corrupted
# Purpose: Identifies and removes metadata entries for files that no longer exist in the recycle bin
# Parameters: None
# Returns: 0 on success, 1 on error
#################################################
purge_corrupted() {
    initialize_recyclebin
    echo -e "${YELLOW}Checking for corrupted entries...${NC}"

    # Check if metadata file exists and has content beyond header
    if [ ! -f "$METADATA_FILE" ] || [ ! -s "$METADATA_FILE" ]
    then
        echo "No metadata found - nothing to purge."
        return 0
    fi

    local line_count=$(wc -l < "$METADATA_FILE" 2>/dev/null)
    if [ "$line_count" -le 1 ]
    then
        echo "Metadata file has only header - nothing to purge."
        return 0
    fi

    local missing=0
    local tmpfile
    tmpfile=$(mktemp 2>/dev/null || echo "/tmp/purge_$$.tmp")
    
    # Start with header
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$tmpfile"

    # Use process substitution to avoid subshell issues
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Extract ID (first field)
        local id=$(echo "$line" | cut -d',' -f1)
        
        # Check if the file exists in the recycle bin
        if [ -e "$FILES_DIR/$id" ]
        then
            # File exists, keep the entry
            echo "$line" >> "$tmpfile"
        else
            # File is missing, count as corrupted
            echo "Removed corrupted entry for missing ID: $id"
            ((missing++))
            log_msg "INFO" "Purged corrupted entry: $id"
        fi
    done < <(tail -n +2 "$METADATA_FILE")

    # Only replace the metadata file if we found corrupted entries
    if [ $missing -gt 0 ]
    then
        if mv "$tmpfile" "$METADATA_FILE" 2>/dev/null
        then
            echo "Purged $missing corrupted entries."
            log_msg "INFO" "Purged $missing corrupted entries"
        else
            echo "Error: Failed to update metadata file."
            log_msg "ERROR" "Failed to update metadata file during purge"
            rm -f "$tmpfile"
            return 1
        fi
    else
        echo "No corrupted entries found."
        rm -f "$tmpfile"
    fi
    
    return 0
}



#################################################
# Function: main
# Purpose: Top-level dispatcher that parses the first CLI argument as a command and routes to the corresponding function. Commands supported include: init, delete, list, restore, search, empty, stats, cleanup, quota, preview, purgecorrupted, and help.
# Parameters: arguments passed to the script
# Returns: Exits with non-zero on usage errors or unknown commands
#################################################
main() {


    if [ ! -d "$RECYCLE_BIN_DIR" ]
    then
        echo "A criar estrutura inicial da reciclagem em $RECYCLE_BIN_DIR ..."
        mkdir -p "$FILES_DIR"

        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
        touch "$LOG_FILE"

        echo "Estrutura da reciclagem criada com sucesso."
    fi

    chmod 700 "$RECYCLE_BIN_DIR" "$FILES_DIR" 2>/dev/null


    exec 200>"$RECYCLE_BIN_DIR/lockfile" || exit 1
    flock -n 200 || {
        echo -e "${RED}Script já em execução. A sair.${NC}"
        exit 1
    }
    trap 'flock -u 200; rm -f "$RECYCLE_BIN_DIR/lockfile"' EXIT



    if [ $# -lt 1 ]
    then
        echo -e "${RED}ERRO: Nenhum comando especificado.${NC}"
        echo "Use './recycle_bin.sh help' para ver comandos disponíveis."
        exit 1
    fi

    local command="$1"
    shift 



    case "$command" in

        help|-h|--help)
            display_help
            ;;

        init)
            initialize_recyclebin
            ;;

        delete)
            if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
                echo -e "${YELLOW}Uso: ./recycle_bin.sh delete <ficheiro/pasta> [...]${NC}"
                exit 0
            fi
            delete_file "$@"
            ;;

        list)
            list_recycled "$@"
            ;;

        restore)
            if [ $# -lt 1 ]; then
                echo -e "${RED}ERRO: Nenhum ID ou nome especificado para restaurar.${NC}"
                exit 1
            fi
            restore_file "$1"
            ;;

        search)
            if [ $# -lt 1 ]
            then
                echo -e "${RED}ERRO: Nenhum termo de pesquisa especificado.${NC}"
                exit 1
            fi
            search_recycled "$@"
            ;;

        empty)
            empty_recyclebin "$@"
            ;;

        stats|statistics)
            show_statistics
            ;;

        cleanup|auto-cleanup)
            auto_cleanup
            ;;

        quota|check-quota)
            check_quota
            ;;

        preview)
            if [ $# -lt 1 ]
            then
                echo -e "${RED}ERRO: Nenhum ID especificado para pré-visualizar.${NC}"
                exit 1
            fi
            preview_file "$1"
            ;;

        purge|purgecorrupted|purge_corrupted)
            purge_corrupted
            ;;

        version|--version|-v)
            show_version
            ;;

        *)
            echo -e "${RED}ERRO: Comando desconhecido '${command}'.${NC}"
            echo "Use './recycle_bin.sh help' para ver a lista de comandos disponíveis."
            exit 1
            ;;
    esac

    flock -u 200
    rm -f "$RECYCLE_BIN_DIR/lockfile"
}


main "$@"
