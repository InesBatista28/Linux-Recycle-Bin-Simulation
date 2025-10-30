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
    if [ ! -e "$item" ] && [ ! -L "$item" ]
    then
      echo -e "${RED}ERROR: '$item' does not exist.${NC}"
      log_msg "ERROR" "Attempt to delete non-existent item: $item"
      continue
    fi

    if [[ "$item" == "$RECYCLE_BIN_DIR"* ]]
    then
      echo -e "${RED}ERROR: Cannot delete the Recycle Bin itself.${NC}"
      log_msg "ERROR" "Attempt to delete the Recycle Bin: $item"
      continue
    fi

    if [ ! -r "$item" ] || [ ! -w "$item" ]
    then  
      echo -e "${RED}ERROR: No permission to delete '$item'.${NC}"
      log_msg "ERROR" "No permission to delete $item"
      continue
    fi

    id=$(generate_id)

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

    if (( current_bin_size + size > max_bin_bytes ))
    then
      echo -e "${RED}ERROR: Recycle Bin limit exceeded (${MAX_SIZE_MB}MB). Cannot move '$item'.${NC}"
      log_msg "ERROR" "Recycle Bin full — limit ${MAX_SIZE_MB}MB exceeded when adding $item"
      continue
    fi

    available=$(bytes_available)
    available=${available:-0}  
    if [ "$available" -lt "$size" ]; then
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

    free_space=$(df -PB1 "$FILES_DIR" | awk 'NR==2 {print $4}')
    if [ "${free_space:-0}" -lt "$size" ]
    then
      needed_mb=$(( size / 1024 / 1024 ))
      avail_mb=$(( free_space / 1024 / 1024 ))
      echo -e "${RED}Insufficient disk space: need ${needed_mb} MB, only ${avail_mb} MB available.${NC}"
      log_msg "ERROR: Not enough space to move $item (needed: ${needed_mb} MB, available: ${avail_mb} MB)"
      continue
    fi

    if [ "$type" = "symlink" ]; then
      cp -P "$item" "$FILES_DIR/$id"
      if [ $? -ne 0 ]; then
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
    local target="$1"

    if [ -z "$target" ]
    then
        echo "Usage: restore_file <file_id_or_name>"
        return 1
    fi

    # Find matching entry (by ID or name)
    match=$(grep -m1 -E "^$target,|,$target," "$METADATA_FILE")

    if [ -z "$match" ]
    then
        echo "Error: Item not found in recycle bin." >&2
        log_msg "RESTORE_FAIL: Item not found ($target)"
        return 1
    fi

    # Extract metadata fields
    IFS=',' read -r id name path date size type perms owner <<< "$match"
    source_path="$FILES_DIR/$id"
    dest_path="$path"

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

    # ✅ Check available disk space before restoring
    required_space=$(du -sb "$source_path" | awk '{print $1}')
    available_space=$(df -P "$(dirname "$dest_path")" | awk 'NR==2 {print $4 * 1024}')

    if (( available_space < required_space ))
    then
        echo "Error: Not enough disk space to restore '$name'." >&2
        log_msg "RESTORE_FAIL: Insufficient disk space for $name ($id)"
        return 1
    fi

    # Attempt restore
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
    local target=""
    local force=false

    # Parse argumentos
    for arg in "$@"; do
        case "$arg" in
            --force) force=true ;;
            *) target="$arg" ;;
        esac
    done

    # Verifica se há algo para apagar
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
        echo "Recycle bin is already empty."
        log_msg "EMPTY_SKIP: Recycle bin already empty"
        return 0
    fi

    # MODO 1: Esvaziar tudo
    if [ -z "$target" ]; then
        if [ "$force" = false ]; then
            read -rp "This will permanently delete ALL items. Continue? (y/n): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; return 0; }
        fi

        # Conta linhas do metadata (sem cabeçalho)
        local line_count
        line_count=$(($(wc -l < "$METADATA_FILE") - 1))
        if (( line_count < 0 )); then line_count=0; fi

        # Tenta apagar ficheiros
        if rm -rf "$FILES_DIR"/* 2>/dev/null; then
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

    # MODO 2: Apagar item específico
    match=$(grep -m1 "^$target," "$METADATA_FILE")
    if [ -z "$match" ]; then
        echo "Error: Item ID '$target' not found."
        log_msg "EMPTY_FAIL: Item not found ($target)"
        return 1
    fi

    IFS=',' read -r id name path date size type perms owner <<< "$match"

    if [ "$force" = false ]; then
        read -rp "This will permanently delete '$name' ($id). Continue? (y/n): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Operation cancelled."; return 0; }
    fi

    # Apagar ficheiro e validar permissões
    if [ -e "$FILES_DIR/$id" ]; then
        if rm -rf "$FILES_DIR/$id" 2>/dev/null; then
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
# Description: Displays comprehensive usage information, available commands, examples, command-line options, and configuration file location.
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << 'EOF'
Recycle Bin Utility Help

Usage:
  ./recycle_bin.sh <command> [options] [arguments]

Commands:
  init                     Initialize recycle bin directory structure and configuration
  delete <path(s)>         Move file(s) or directory(ies) to recycle bin
  list [--detailed]        List recycled items in compact or detailed view
  restore <id|name>        Restore file by ID or filename
  search <pattern> [--ignore-case]
                           Search for items in the recycle bin (supports wildcards)
  empty [<id>] [--force]   Permanently delete all or specific recycled items
  help, -h, --help         Display this help message

Options:
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

Config Parameters:
  MAX_SIZE_MB=1024      # Maximum total recycle bin size (in MB)
  RETENTION_DAYS=30     # Number of days before automatic cleanup

Notes:
  • Use with caution — 'empty' and '--force' permanently remove files!
  • Restored files will regain original permissions and ownership.
  • Logs of all operations are stored in recyclebin.log.

EOF
}




# OPTIONAL FUNCTIONS

#################################################
# Function: show_statistics
# Description: Displays summary statistics about the Recycle Bin contents
# Parameters: None
# Returns: 0
#################################################
show_statistics() {
    # Verificar se há dados
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
        echo "Recycle bin is empty."
        log_msg "STATS: No data to display"
        return 0
    fi

    # Carregar configuração
    source "$CONFIG_FILE" 2>/dev/null
    local max_size_bytes=$((MAX_SIZE_MB * 1024 * 1024))

    # Variáveis temporárias
    local total_items=0
    local total_size=0
    local file_count=0
    local dir_count=0
    local oldest_date=""
    local newest_date=""

    # Ler metadados linha a linha (ignorando cabeçalho)
    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        ((total_items++))
        ((total_size += size))
        if [[ "$type" == "file" ]]; then
            ((file_count++))
        elif [[ "$type" == "directory" ]]; then
            ((dir_count++))
        fi

        # Determinar mais antigo e mais recente
        if [ -z "$oldest_date" ] || [[ "$date" < "$oldest_date" ]]; then
            oldest_date="$date"
        fi
        if [ -z "$newest_date" ] || [[ "$date" > "$newest_date" ]]; then
            newest_date="$date"
        fi
    done

    # Recalcular fora do subshell
    {
        total_items=$(tail -n +2 "$METADATA_FILE" | wc -l)
        total_size=$(tail -n +2 "$METADATA_FILE" | awk -F',' '{sum+=$5} END {print sum}')
        file_count=$(tail -n +2 "$METADATA_FILE" | awk -F',' '$6=="file"{count++} END {print count+0}')
        dir_count=$(tail -n +2 "$METADATA_FILE" | awk -F',' '$6=="directory"{count++} END {print count+0}')
        oldest_date=$(tail -n +2 "$METADATA_FILE" | awk -F',' 'NR==1 || $4<old{old=$4;name=$2} END{print old}')
        newest_date=$(tail -n +2 "$METADATA_FILE" | awk -F',' 'NR==1 || $4>new{new=$4;name=$2} END{print new}')
    }

    # Evitar divisão por zero
    local avg_size=0
    if (( total_items > 0 )); then
        avg_size=$((total_size / total_items))
    fi

    # Percentagem da quota
    local quota_pct=0
    if (( max_size_bytes > 0 )); then
        quota_pct=$(( (100 * total_size) / max_size_bytes ))
    fi

    # Mostrar resultados formatados
    echo "Recycle Bin Statistics"
    printf "%-25s %s\n" "Total items:" "$total_items"
    printf "%-25s %s (%d%% of quota)\n" "Total storage used:" "$(transform_size "$total_size")" "$quota_pct"
    printf "%-25s %s files, %s directories\n" "Type breakdown:" "$file_count" "$dir_count"
    printf "%-25s %s\n" "Oldest deletion:" "$oldest_date"
    printf "%-25s %s\n" "Newest deletion:" "$newest_date"
    printf "%-25s %s\n" "Average file size:" "$(transform_size "$avg_size")"

    log_msg "STATS: total=$total_items size=${total_size}B files=$file_count dirs=$dir_count"
}


#################################################
# Function: AUto Cleanup
# Description: 
# Parameters: 
# Returns: 
#################################################
auto_cleanup() {
    # Garantir que metadata existe
    if [ ! -f "$METADATA_FILE" ]; then
        echo "Recycle bin not initialized."
        log_msg "CLEANUP_FAIL: Recycle bin not initialized"
        return 1
    fi

    # Carregar configuração
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "Warning: Config file not found. Using default RETENTION_DAYS=30."
        RETENTION_DAYS=30
    fi

    # Verificar se há algo para limpar
    if [ "$(wc -l < "$METADATA_FILE")" -le 1 ]; then
        echo "Recycle bin is empty — nothing to clean."
        log_msg "CLEANUP_SKIP: Recycle bin empty"
        return 0
    fi

    # Calcular timestamp limite (em segundos)
    local cutoff_ts
    cutoff_ts=$(date -d "-${RETENTION_DAYS} days" +%s)

    local deleted_count=0
    local freed_space=0

    # Ler metadata linha a linha (ignorando cabeçalho)
    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name path date size type perms owner; do
        # Converter data de deleção para timestamp
        file_ts=$(date -d "$date" +%s 2>/dev/null || echo 0)

        # Se o ficheiro for mais antigo que o limite, elimina
        if (( file_ts > 0 && file_ts < cutoff_ts )); then
            if [ -e "$FILES_DIR/$id" ]; then
                if rm -rf "$FILES_DIR/$id" 2>/dev/null; then
                    ((deleted_count++))
                    ((freed_space += size))
                    log_msg "CLEANUP_DELETE: Removed $name ($id) — older than $RETENTION_DAYS days"
                else
                    log_msg "CLEANUP_FAIL: Permission denied deleting $name ($id)"
                fi
            else
                log_msg "CLEANUP_WARN: Missing data file for $name ($id)"
            fi

            # Remover entrada do metadata
            grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
        fi
    done

    # Recalcular totais (fora do subshell)
    deleted_count=$(grep -c "CLEANUP_DELETE" "$LOG_FILE")
    freed_space_bytes=$(awk -F',' '{sum+=$5} END{print sum}' "$METADATA_FILE")
    human_freed=$(transform_size "$freed_space")

    # Mostrar resumo
    echo "Auto Cleanup Summary"
    printf "%-25s %s days\n" "Retention period:" "$RETENTION_DAYS"
    printf "%-25s %s items\n" "Items deleted:" "$deleted_count"
    printf "%-25s %s\n" "Space freed:" "$human_freed"

    log_msg "CLEANUP_SUMMARY: deleted=$deleted_count freed=${freed_space}B retention=${RETENTION_DAYS}d"
}



#################################################
# Function: check_quota
# Description: Checks if the Recycle Bin exceeds MAX_SIZE_MB.
#              Displays a warning or triggers auto-cleanup if full.
# Parameters: None
# Returns: 0
#################################################
check_quota() {
    # Garantir que recycle bin existe
    if [ ! -d "$FILES_DIR" ]; then
        echo "Recycle bin not initialized."
        log_msg "QUOTA_FAIL: recycle bin not initialized"
        return 1
    fi

    # Carregar configuração
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "Warning: Config file not found. Using default MAX_SIZE_MB=1024"
        MAX_SIZE_MB=1024
    fi

    # Calcular uso atual em bytes
    local total_bytes
    total_bytes=$(du -sb "$FILES_DIR" 2>/dev/null | awk '{print $1}')
    total_bytes=${total_bytes:-0}
    local max_bytes=$((MAX_SIZE_MB * 1024 * 1024))

    # Calcular percentagem de uso
    local usage_pct=0
    if (( max_bytes > 0 )); then
        usage_pct=$(( (100 * total_bytes) / max_bytes ))
    fi

    # Converter para formato legível
    local total_hr
    total_hr=$(transform_size "$total_bytes")

    echo "Recycle Bin Quota Status"
    printf "%-25s %s\n" "Total used:" "$total_hr"
    printf "%-25s %s MB\n" "Quota limit:" "$MAX_SIZE_MB"
    printf "%-25s %s%%\n" "Usage:" "$usage_pct"

    # Verificar se excedeu a quota
    if (( total_bytes > max_bytes )); then
        echo "WARNING: Recycle bin exceeds quota limit!"
        log_msg "QUOTA_WARN: ${usage_pct}% used (limit ${MAX_SIZE_MB}MB)"

        # Acionar limpeza automática se disponível
        if declare -F auto_cleanup >/dev/null; then
            echo "Triggering automatic cleanup..."
            auto_cleanup
        fi
    else
        log_msg "QUOTA_OK: ${usage_pct}% used (${total_hr}/${MAX_SIZE_MB}MB)"
    fi
}


#################################################
# Function: preview_file
# Description: Displays a preview of a file stored in the Recycle Bin.
#              For text files, shows the first 10 lines.
#              For binary files, shows file type info.
# Parameters: $1 - File ID
# Returns: 0 if successful, 1 on error
#################################################
preview_file() {
    local id="$1"

    # Verificações básicas
    if [ -z "$id" ]; then
        echo "Usage: ./recycle_bin.sh preview <file_id>"
        return 1
    fi

    if [ ! -f "$METADATA_FILE" ]; then
        echo "Recycle bin not initialized."
        return 1
    fi

    # Procurar entrada no metadata
    local entry
    entry=$(grep "^$id," "$METADATA_FILE")

    if [ -z "$entry" ]; then
        echo "Error: No item found with ID '$id'."
        log_msg "PREVIEW_FAIL: ID not found ($id)"
        return 1
    fi

    local file_path="$FILES_DIR/$id"
    local original_name
    original_name=$(echo "$entry" | awk -F',' '{print $2}')

    if [ ! -f "$file_path" ]; then
        echo "Error: Recycled file not found ($file_path)"
        log_msg "PREVIEW_FAIL: Missing file for ID $id"
        return 1
    fi

    echo "Preview of: $original_name"

    # Determinar tipo de ficheiro
    local ftype
    ftype=$(file -b --mime-type "$file_path")

    # Mostrar conteúdo se for texto
    if [[ "$ftype" == text/* ]]; then
        head -n 10 "$file_path"
        echo "(Showing first 10 lines)"
    else
        echo "Binary or non-text file detected:"
        file "$file_path"
    fi

    log_msg "PREVIEW_OK: $original_name ($id) type=$ftype"
}


purge_corrupted() {
  initialize_recyclebin
  echo "Checking for corrupted entries..."

  local missing=0
  local tmpfile
  tmpfile=$(mktemp)

  # Mantém cabeçalho
  head -n 1 "$METADATA_FILE" > "$tmpfile"

  tail -n +2 "$METADATA_FILE" | while IFS=',' read -r id name _
  do
    if [ -e "$FILES_DIR/$id" ]
    then
        grep "^$id," "$METADATA_FILE" >> "$tmpfile"
    else
      echo "Removed corrupted entry for missing ID: $id"
      ((missing++))
    fi
  done

  mv "$tmpfile" "$METADATA_FILE"
  echo "Purged $missing corrupted entries."
  log_msg "INFO" "Purged $missing corrupted entries."
}



#################################################
# Function: main
# Description: Command dispatcher for all Recycle Bin operations
# Now includes 'stats' command for show_statistics()
#################################################
main() {
    # Check if at least one argument is provided
    if [ $# -lt 1 ]; then
        echo -e "${RED}ERROR: No command specified.${NC}"
        echo "Use './recycle_bin.sh help' to see available commands."
        exit 1
    fi

    local command="$1"
    shift  # Remove the command from the arguments list

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
            if [ $# -lt 1 ]; then
                echo -e "${RED}ERROR: No file ID specified to preview.${NC}"
                exit 1
            fi
            preview_file "$1"
            ;;

        purgecorrupted|purge_corrupted)
            purge_corrupted
            ;;

        auto_cleanup|autoclean)
            auto_cleanup
            ;;

        *)
            echo -e "${RED}ERROR: Unknown command: $command${NC}"
            echo "Use './recycle_bin.sh help' to see available commands."
            exit 1
            ;;


    esac
}


main "$@"
