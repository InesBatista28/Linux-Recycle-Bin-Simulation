#!/bin/bash

#################################################
# Script Header Comment
# Author: Inês Batista, Maria Quinteiro
# Date: 2025-10-17
# Description: Linux Recycle Bin Simulator
# Version: 1.0
#################################################


RECYCLE_BIN_DIR="$HOME/.recycle_bin"     # Main recycle bin directory
FILES_DIR="$RECYCLE_BIN_DIR/files"       # Subdirectory to store deleted files
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"    # Database file to store information about deleted files
CONFIG_FILE="$RECYCLE_BIN_DIR/config"     # Configuration file for the recycle system
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"    # Log file to record all operations

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


#################################################
# Function: log_msg
# Description: Utility function used by others to log operations performed in the recycle bin
# Parameters: $1 - Level (INFO, ERROR), $2 - Message to log
# Returns: 0
#################################################
log_msg() {
  local level="$1"
  local msg="$2"
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}


#################################################
# Function: initialize_recyclebin
# Description: Creates the initial recycle bin structure and required files, if they do not exist
# Parameters: None
# Returns: 0 if success, 1 if error
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
# Description: Generates a unique ID based on timestamp + process ID, used as the filename for deleted items in the files folder
# Parameters: None
# Returns: Generated ID
#################################################
generate_id() {
  echo "$(date +%s%N)_$$"
}



#################################################
# Function: bytes_available
# Description: Returns available space in bytes on the recycle bin partition
# Parameters: None
# Returns: Number of available bytes
#################################################
bytes_available() {
  local avail
  avail=$(($(df --output=avail "$RECYCLE_BIN_DIR" 2>/dev/null | tail -1) * 1024))
  # Fallback in case it's empty
  if [ -z "$avail" ]; then
    avail=0
  fi
  echo "$avail"
}


#################################################
# Function: transform_size
# Description: Converts size in bytes to a human-readable format (B, KB, MB, GB)
# Parameters: $1 - size in bytes
# Returns: formatted size
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
# Description: Moves files or directories to the "Recycle Bin",
#              saving metadata (original name, path, deletion date,
#              size, type, permissions, and owner) and logging all operations.
#              Supports multiple arguments, permission checking,
#              available space validation, and prevents deleting the Recycle Bin itself.
#              Directories are deleted recursively.
# Parameters: $@ - list of files/directories to delete
# Returns: 0 if at least one item was successfully moved, 1 if all failed or invalid args
#################################################
delete_file() {
  initialize_recyclebin

  # Load configuration (MAX_SIZE_MB)
  if [ -f "$CONFIG_FILE" ]
  then
    # Search inside of the file the line that starts with "MAX_SIZE_MB" to pass on to cut in order to get just the number
    MAX_SIZE_MB=$(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" | cut -d'=' -f2)
  else
    MAX_SIZE_MB=1024  # Default fallback
  fi

  # Calculate current recycle bin size and maximum limit (in bytes)
  local current_bin_size 
  local max_bin_bytes
  current_bin_size=$(du -sb "$FILES_DIR" 2>/dev/null | awk '{print $1}')
  max_bin_bytes=$((MAX_SIZE_MB * 1024 * 1024))

  # Check if arguments were provided
  if [ $# -eq 0 ]
  then  
    echo -e "${RED}ERROR: No file/directory specified.${NC}"
    log_msg "ERROR" "Attempt to delete with no arguments provided"
    return 1
  fi


  for item in "$@"
  do
    # Check if item exists
    if [ ! -e "$item" ]
    then
      echo -e "${RED}ERROR: '$item' does not exist.${NC}"
      log_msg "ERROR" "Attempt to delete non-existent item: $item"
      continue 
    fi

    # Prevent deletion of the recycle bin itself
    if [[ "$item" == "$RECYCLE_BIN_DIR"* ]]
    then
      echo -e "${RED}ERROR: Cannot delete the Recycle Bin itself.${NC}"
      log_msg "ERROR" "Attempt to delete the Recycle Bin: $item"
      continue
    fi

    # Check delete permissions
    if [ ! -r "$item" ] || [ ! -w "$item" ]
    then  
      echo -e "${RED}ERROR: No permission to delete '$item'.${NC}"
      log_msg "ERROR" "No permission to delete $item"
      continue
    fi


    id=$(generate_id)

    # Determine type and size of the item
    if [ -d "$item" ]
    then
      type="directory"
      size=$(du -sb "$item" | awk '{print $1}')
    else
      type="file"
      size=$(stat -c %s "$item")
    fi

    # Check recycle bin capacity (MAX_SIZE_MB)
    if (( current_bin_size + size > max_bin_bytes ))
    then
      echo -e "${RED}ERROR: Recycle Bin limit exceeded (${MAX_SIZE_MB}MB). Cannot move '$item'.${NC}"
      log_msg "ERROR" "Recycle Bin full — limit ${MAX_SIZE_MB}MB exceeded when adding $item"
      continue
    fi

    # Check available disk space
    available=$(bytes_available)
    available=${available:-0}  
    if [ "$available" -lt "$size" ]; then
      echo -e "${RED}ERROR: Not enough space to move '$item'.${NC}"
      log_msg "ERROR" "Insufficient space for $item, size $size bytes."
      continue
    fi

    # Data to store in metadata.db
    original_name=$(basename "$item")
    original_path=$(realpath "$item")
    deletion_date=$(date +"%Y-%m-%d %H:%M:%S")
    permissions=$(stat -c %a "$item")
    owner=$(stat -c %U:%G "$item")
    echo "$id,$original_name,$original_path,$deletion_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"

    # Move file or directory
    mv "$item" "$FILES_DIR/$id" 2>/dev/null
    if [ $? -ne 0 ]
    then
      echo -e "${RED}ERROR: Failed to move '$item' to Recycle Bin.${NC}"
      log_msg "ERROR" "Failed to move $item to Recycle Bin"
      continue
    fi

    # Update recycle bin size (for multi-file operations)
    current_bin_size=$((current_bin_size + size))

    # Successful move
    echo -e "${GREEN} '$original_name' moved to Recycle Bin.${NC}"
    log_msg "INFO" "'$original_name' moved to Recycle Bin with ID $id"
  done

  return 0
}





#################################################
# Function: list_recycled
# Description: Lists the current Recycle Bin contents in a table format.
#              Supports a detailed mode. Also calculates total items and total used space.
# Parameters: $1 - "--detailed" to enable detailed mode
# Returns: 0 on success, also 0 if the bin is empty
#################################################
list_recycled() {
  initialize_recyclebin

  # Check if metadata file exists and is not empty
  if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
  then
    echo -e "${YELLOW}Recycle Bin is empty.${NC}"
    return 0
  fi

  # Check if detailed mode is requested
  local detailed=false
  if [ "$1" == "--detailed" ]
  then
    detailed=true
  fi


  local total_items
  local total_size

  total_items=$(($(wc -l < "$METADATA_FILE") - 1))  # subtract header
  # Set comma as delimiter, ignore header, sum fifth column, and print total
  total_size=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$METADATA_FILE")

  echo -e "${YELLOW}Recycle Bin Contents: ${NC}"
  # NORMAL MODE
  if [ "$detailed" = false ]
  then
  printf "${GREEN}%-35s | %-25s | %-30s | %-12s${NC}\n" "ID" "Original filename" "Deletion date and time" "File size"


    # Read metadata file ignoring header
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
# Description: Restores a file or directory from the Recycle Bin to its original location. 
#              Accepts either the file ID or the original filename as parameter.
#              Handles naming conflicts, directory recreation, permission restoration, metadata cleanup, and logs all operations.
# Parameters: $1 - File ID or original filename
# Returns: 0 if restored successfully, 1 otherwise
#################################################
restore_file() {
  initialize_recyclebin

  local query="$1"

  # validate de id input 
  if [ -z "$query" ]
  then
    echo -e "${RED}ERROR: No ID or name specified.${NC}"
    log_msg "ERROR" "Attempt to restore without specifying ID or name"
    return 1
  fi

  # locate the entry in the metadata (search by id or filename)
  local line
  line=$(awk -F',' -v q="$query" 'NR>1 && ($1==q || $2==q) {print; exit}' "$METADATA_FILE")

  # cases where no metabase is found by the id/filename given
  if [ -z "$line" ]
  then
    echo -e "${RED}ERROR: No matching entry found for '$query'.${NC}"
    log_msg "ERROR" "Restore failed: no matching entry for '$query'"
    return 1
  fi


  
  # extract metadata fields 
  local id original_name original_path size type permissions owner
  id=$(echo "$line" | cut -d',' -f1)
  original_name=$(echo "$line" | cut -d',' -f2)
  original_path=$(echo "$line" | cut -d',' -f3)
  size=$(echo "$line" | cut -d',' -f5)
  type=$(echo "$line" | cut -d',' -f6)
  permissions=$(echo "$line" | cut -d',' -f7)
  owner=$(echo "$line" | cut -d',' -f8)

  # Path to the stored file inside the recycle bin
  local stored_file="$FILES_DIR/$id"



  # verify stored file exists 
  if [ ! -e "$stored_file" ]
  then
    echo -e "${RED}ERROR: File '$id' missing from Recycle Bin storage.${NC}"
    log_msg "ERROR" "Missing stored file for ID: $id"
    return 1
  fi

  # check if destination directory exists
  local dest_dir
  dest_dir=$(dirname "$original_path")

  if [ ! -d "$dest_dir" ]
  then
    echo -e "${YELLOW}Destination directory missing. Creating: $dest_dir${NC}"
    mkdir -p "$dest_dir" 2>/dev/null
    if [ $? -ne 0 ]
    then
      echo -e "${RED}ERROR: Failed to create directory '$dest_dir'.${NC}"
      log_msg "ERROR" "Failed to create restore directory $dest_dir for $id"
      return 1
    fi
  fi



  # if file already exists at the destination
  local final_path="$original_path"
  if [ -e "$final_path" ]
  then
    echo -e "${YELLOW}Conflict: File already exists at destination: '$final_path'${NC}"
    echo "Choose action:"
    echo "  [O] Overwrite existing file"
    echo "  [R] Restore with new name (append timestamp)"
    echo "  [C] Cancel restoration"
    read -rp "Your choice [O/R/C]: " choice

    case "$choice" in
      [Oo])
        # User chose to overwrite existing file
        echo "Overwriting existing file..."
        ;;
      [Rr])
        # Append timestamp to new filename to avoid conflict
        local ts
        ts=$(date +%Y%m%d_%H%M%S)
        final_path="${dest_dir}/${original_name}_restored_${ts}"
        echo "Restoring as '$final_path'"
        ;;
      [Cc])
        # User cancels operation
        echo -e "${YELLOW}Restoration cancelled by user.${NC}"
        log_msg "INFO" "Restoration of '$original_name' (ID $id) cancelled by user"
        return 0
        ;;
      *)
        # Invalid choice entered
        echo -e "${RED}Invalid choice. Operation cancelled.${NC}"
        return 1
        ;;
    esac
  fi


  # check avaliable disk space before restoring the file selected 
  local available
  available=$(bytes_available)
  available=${available:-0}
  if [ "$available" -lt "$size" ]
  then
    echo -e "${RED}ERROR: Not enough space to restore '$original_name'.${NC}"
    log_msg "ERROR" "Insufficient space to restore $original_name (ID $id)"
    return 1
  fi

  if [ "$type" == "directory" ]
  then
    for f in "$FILES_DIR/$id/"*; do
      restore_file "$(basename "$f")"
    done
  fi


  # move file from the recycle bin to back to its original location 
  mv "$stored_file" "$final_path" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to restore '$original_name' to '$final_path'.${NC}"
    log_msg "ERROR" "Restore failed for $original_name (ID $id)"
    return 1
  fi

  # restore permitions 
  chmod "$permissions" "$final_path" 2>/dev/null || log_msg "WARNING" "Failed to restore permissions for $final_path"
  chown "$owner" "$final_path" 2>/dev/null || log_msg "WARNING" "Failed to restore owner for $final_path"

  # remove restored metadata
  grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

  # user feedback
  echo -e "${GREEN}File '$original_name' restored successfully to '$final_path'.${NC}"
  log_msg "INFO" "File '$original_name' (ID $id) restored to '$final_path'"

  return 0
}






#################################################
# Function: search_recycled
# Description: Searches metadata by filename or path using a wildcard pattern.
#              Supports case-insensitive searching.
# Parameters: $1 - Search pattern (e.g., "*.txt", "report").
#             $2 - (Optional) "-i" for case-insensitive search (can be $1 or $2).
# Returns: 0 on success, 1 on error.
#################################################
search_recycled() {
    initialize_recyclebin

    local pattern
    local case_flag=""

    # Handle arguments. Pattern is mandatory, -i is optional.
    if [ "$1" == "-i" ]
    then
        case_flag="-i"
        pattern="$2"
    elif [ "$2" == "-i" ]
    then
        case_flag="-i"
        pattern="$1"
    else
        pattern="$1"
    fi

    # Requirement 1: Check for pattern
    if [ -z "$pattern" ]
    then
        echo -e "${RED}ERROR: No search pattern specified.${NC}"
        log_msg "ERROR" "Search attempt with no pattern."
        return 1
    fi

    # Requirement 6: Case-insensitive search option
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
    # This avoids running the 'while' loop in a subshell,
    # so variables (match_found, line_count) retain their values.
    while IFS=',' read -r id name path date size type perms owner; do
        
        # Requirement 2 & 3: Search name (col 2) and path (col 3) using the wildcard pattern
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

    # Requirement 5: Show message if no matches found
    if [ "$match_found" = false ]
    then
        echo -e "${YELLOW}No matches found for '$pattern'.${NC}"
        log_msg "INFO" "Search for '$pattern' found 0 matches."
    else
        # Requirement 4: Display table format
        echo -e "${YELLOW}Search results for '$pattern':${NC}"
        # Print header
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
# Description: Permanently deletes items from the Recycle Bin.
#              Supports deleting all items or a specific one by ID.
#              Requires user confirmation unless --force is provided.
# Parameters: $1 - (optional) ID or "--force"
#             $2 - (optional) "--force" if not the first parameter
# Returns: 0 on success, 1 on error
#################################################
empty_recyclebin() {
  initialize_recyclebin

  local target_id=""
  local force_mode=false

  for arg in "$@"
  do
    case "$arg" in
      --force)
        force_mode=true
        ;;
      *)
        target_id="$arg"
        ;;
      esac
    done


    # if the metadata file is empty means recycle bin is also empty
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
    then
      echo -e "${YELLOW}Recycle Bin is already empty.${NC}"
      log_msg "INFO" "Attempted to empty an already empty Recycle Bin."
      return 0
    fi

    # if theres no id given we assume the full empty method
    if [ -z "$target_id" ]
    then
      if [ "$force_mode" = false ]
      then
        read -rp "Are you sure you want to remove all items from the Recylce Bin? (Y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]
        then
          echo -e "${YELLOW}Operation Cancelled.${NC}"
          log_msg "INFO" "Empty Recycle Bin cancelled"
          return 0
        fi
      fi

      local count_before
      count_before=$(($(wc -l < "$METADATA_FILE") - 1))
      rm -rf "${FILES_DIR:?}/"* 2>/dev/null
      echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"

      echo -e "${GREEN}All $count_before items permanently deleted.${NC}"
      log_msg "INFO" "Emptied entire Recycle Bin ($count_before items deleted)."
      return 0
    fi


    # theres an id given 
    local line
    line=$(awk -F',' -v id="$target_id" 'NR>1 && $1==id {print}' "$METADATA_FILE")
    if [ -z "$line" ]
    then
      echo -e "${RED}ERROR: No item found with the given ID.${NC}"
      log_msg "ERROR" "Attempted to empty non-existent item ID: $target_id"
      return 1
    fi


    local file_path="$FILES_DIR/$target_id"
    local original_name

    original_name=$(echo "$line" | cut -d',' -f2)

    if [ "$force_mode" = false ]
    then
    read -rp "Permanently delete '$original_name'? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]
    then
      echo -e "${YELLOW}Operation cancelled.${NC}"
      log_msg "INFO" "Deletion of item $target_id ($original_name) cancelled by user."
      return 0
    fi
  fi

  # deleting the file
  rm -rf "$file_path" 2>/dev/null
  if [ $? -ne 0 ]
  then
    echo -e "${RED}ERROR: Failed to permanently delete '$original_name'.${NC}"
    log_msg "ERROR" "Failed to delete item ID $target_id ($original_name)"
    return 1
  fi

  grep -v "^$target_id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

  echo -e "${GREEN}Item '$original_name' (ID $target_id) permanently deleted.${NC}"
  log_msg "INFO" "Item '$original_name' (ID $target_id) permanently deleted."
  return 0
}






#################################################
# Function: display_help
# Description: Displays comprehensive usage information, available commands, examples, command-line options, and configuration file location.
# Parameters: None
# Returns: 0
#################################################
display_help() {
  echo -e "${YELLOW}Linux Recycle Bin Simulator - Help System${NC}"
  echo
  echo -e "${GREEN}Usage:${NC}"
  echo "  ./recycle_bin.sh <command> [options] [arguments]"
  echo
  echo -e "${GREEN}Available Commands:${NC}"
  echo "  help, -h, --help           Display this help message"
  echo "  delete <file/dir> [...]    Move files or directories to the Recycle Bin"
  echo "  list [--detailed]          List items in the Recycle Bin"
  echo "  restore <ID|filename>      Restore a file/directory from the Recycle Bin"
  echo "  search <pattern> [-i]      Search for items by name or path, optional case-insensitive"
  echo "  empty [ID] [--force]       Permanently delete items, all or by ID, optional force"
  echo
  echo -e "${GREEN}Command-Line Options:${NC}"
  echo "  -h, --help                  Show help information"
  echo "  --detailed                  Show detailed listing of Recycle Bin contents"
  echo "  -i                          Case-insensitive search"
  echo "  --force                     Skip confirmation prompts for deletion"
  echo
  echo -e "${GREEN}Examples:${NC}"
  echo "  ./recycle_bin.sh help"
  echo "  ./recycle_bin.sh --help"
  echo "  ./recycle_bin.sh -h"
  echo "  ./recycle_bin.sh delete file1.txt file2.txt"
  echo "  ./recycle_bin.sh list --detailed"
  echo "  ./recycle_bin.sh restore 1698324850000000"
  echo "  ./recycle_bin.sh search '*.txt' -i"
  echo "  ./recycle_bin.sh empty --force"
  echo
  echo -e "${GREEN}Configuration File:${NC}"
  echo "  The recycle bin configuration file is located at: $CONFIG_FILE"
  echo "  Default options:"
  echo "    MAX_SIZE_MB    = 1024  # Maximum recycle bin size in MB"
  echo "    RETENTION_DAYS = 30    # Number of days to keep deleted files"
  echo
  echo -e "${YELLOW}For more information, use the commands above with the appropriate arguments.${NC}"
}



#################################################
# Function: main
# Description: Command dispatcher that calls appropriate functions based on user input
#################################################
main() {
    # Check if at least one argument is provided
    if [ $# -lt 1 ]; then
        echo -e "${RED}ERROR: No command specified.${NC}"
        echo "Use './recycle_bin.sh help' to see available commands."
        exit 1
    fi

    # Extract the first argument as the command
    local command="$1"
    shift  # Remove the command from the argument list

    case "$command" in
        help|-h|--help)
            display_help
            ;;
        delete)
          if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
            echo -e "${YELLOW}Usage: ./recycle_bin.sh delete <file/dir> [...]${NC}"
            exit 0
          fi
          delete_file "$@"
          ;;

        list)
            list_recycled "$@"
            ;;
        restore)
            if [ $# -lt 1 ]; then
                echo -e "${RED}ERROR: No ID or filename specified to restore.${NC}"
                exit 1
            fi
            restore_file "$1"
            ;;
        search)
            if [ $# -lt 1 ]; then
                echo -e "${RED}ERROR: No search pattern specified.${NC}"
                exit 1
            fi
            search_recycled "$@"
            ;;
        empty)
            empty_recyclebin "$@"
            ;;
        *)
            echo -e "${RED}ERROR: Unknown command: $command${NC}"
            echo "Use './recycle_bin.sh help' to see available commands."
            exit 1
            ;;
    esac
}


main "$@"
