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
    mkdir "$RECYCLE_BIN_DIR"
    echo "Directory $RECYCLE_BIN_DIR created."
  fi

  # Create subdirectory 'files' if it doesn't exist
  if [ ! -d "$FILES_DIR" ]
  then
    mkdir "$FILES_DIR"
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
  avail=$(df --output=avail "$RECYCLE_BIN_DIR" 2>/dev/null | tail -1)
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


    # Determine type and size of the item to check if it fits in the bin
    if [ -d "$item" ]
    then
      type="directory"
      size=$(du -sb "$item" | awk '{print $1}')
    else
      type="file"
      size=$(stat -c %s "$item")
    fi

    # Check available space
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
    printf "${GREEN}%-35s | %-25s | %-20s | %-10s${NC}\n" "ID" "Original filename" "Deletion date and time" "File size"


    # Read metadata file ignoring header
    tail -n +2 "$METADATA_FILE" | while read line; do
      id=$(echo "$line" | cut -d',' -f1)
      original_name=$(echo "$line" | cut -d',' -f2)
      deletion_date=$(echo "$line" | cut -d',' -f4)
      size=$(echo "$line" | cut -d',' -f5)

      # Convert to readable size
      readable_size=$(transform_size "$size")
      printf "%-35s | %-25s | %-20s | %-10s\n" "$id" "$original_name" "$deletion_date" "$readable_size"
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



main() {
  echo -e "${YELLOW}=== Initializing Recycle Bin ===${NC}"
  initialize_recyclebin

  echo -e "${YELLOW}=== Creating test files and directories ===${NC}"
  # Create test files
  echo "File 1 content" > teste1.txt
  echo "File 2 content" > teste2.txt

  # Create test directory with subdirectory
  mkdir -p dir_teste/subdir
  echo "File inside directory" > dir_teste/arquivo1.txt
  echo "Another file" > dir_teste/subdir/arquivo2.txt

  # Create file without permissions
  touch sem_permissao.txt
  chmod 000 sem_permissao.txt

  echo -e "${YELLOW}=== Testing delete_file ===${NC}"
  
  # 1️⃣ Attempt to delete non-existent file
  delete_file arquivo_inexistente.txt

  # 2️⃣ Attempt to delete file without permissions
  delete_file sem_permissao.txt

  # Restore permissions and delete test file
  chmod 644 sem_permissao.txt
  rm sem_permissao.txt

  # 3️⃣ Delete valid files
  delete_file teste1.txt teste2.txt

  # 4️⃣ Delete recursive directory
  delete_file dir_teste

  echo -e "${YELLOW}=== Recycle Bin contents (normal mode) ===${NC}"
  list_recylced

  echo -e "${YELLOW}=== Recycle Bin contents (detailed mode) ===${NC}"
  list_recylced --detailed

  echo -e "${YELLOW}=== Recent logs ===${NC}"
  tail -n 20 "$LOG_FILE"

  echo -e "${YELLOW}=== Recent metadata ===${NC}"
  tail -n 10 "$METADATA_FILE"
}

# Run main
main "$@"
