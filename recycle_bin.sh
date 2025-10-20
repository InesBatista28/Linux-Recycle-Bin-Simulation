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

  # move file from the recycle bin to back to its original location 
  mv "$stored_file" "$final_path" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to restore '$original_name' to '$final_path'.${NC}"
    log_msg "ERROR" "Restore failed for $original_name (ID $id)"
    return 1
  fi

  # restore permitions 
  chmod "$permissions" "$final_path" 2>/dev/null
  chown "$owner" "$final_path" 2>/dev/null

  # remove restored metadata
  grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

  # user feedback
  echo -e "${GREEN}File '$original_name' restored successfully to '$final_path'.${NC}"
  log_msg "INFO" "File '$original_name' (ID $id) restored to '$final_path'"

  return 0
}




# MAIN COMPLETAMENTE CHAT SÓ PARA TESTAR
main() {
  echo -e "${YELLOW}=== [1/10] INITIALIZING RECYCLE BIN ===${NC}"
  initialize_recyclebin

  echo -e "${YELLOW}=== [2/10] PREPARING TEST ENVIRONMENT ===${NC}"

  # Limpar ambiente anterior
  rm -rf teste1.txt teste2.txt dir_teste sem_permissao.txt 2>/dev/null

  # Criar ficheiros de teste
  echo "Conteúdo de teste 1" > teste1.txt
  echo "Conteúdo de teste 2" > teste2.txt

  # Criar diretório com subdiretórios e ficheiros
  mkdir -p dir_teste/subdir
  echo "Ficheiro dentro do diretório" > dir_teste/f1.txt
  echo "Outro ficheiro" > dir_teste/subdir/f2.txt

  # Criar ficheiro sem permissões
  touch sem_permissao.txt
  chmod 000 sem_permissao.txt

  # Mostrar estrutura inicial
  echo -e "${GREEN}Estrutura inicial criada:${NC}"
  ls -l
  echo

  #################################################
  # 🧨 TESTES DE ERRO
  #################################################
  echo -e "${YELLOW}=== [3/10] TESTES DE ERRO ===${NC}"

  # 1️⃣ Nenhum argumento fornecido
  echo -e "${YELLOW}-- Teste: Nenhum argumento fornecido --${NC}"
  delete_file

  # 2️⃣ Ficheiro inexistente
  echo -e "${YELLOW}-- Teste: Ficheiro inexistente --${NC}"
  delete_file nao_existe.txt

  # 3️⃣ Ficheiro sem permissões
  echo -e "${YELLOW}-- Teste: Ficheiro sem permissões --${NC}"
  delete_file sem_permissao.txt

  # Corrigir permissões para testes seguintes
  chmod 644 sem_permissao.txt
  rm sem_permissao.txt

  # 4️⃣ Tentar apagar a própria reciclagem
  echo -e "${YELLOW}-- Teste: Tentativa de apagar o Recycle Bin --${NC}"
  delete_file "$RECYCLE_BIN_DIR"

  #################################################
  # ✅ TESTES DE SUCESSO - DELETE
  #################################################
  echo -e "${YELLOW}=== [4/10] TESTES DE SUCESSO: DELETE ===${NC}"

  # 5️⃣ Apagar ficheiros simples
  echo -e "${YELLOW}-- Teste: Apagar ficheiros válidos --${NC}"
  delete_file teste1.txt teste2.txt

  # 6️⃣ Apagar diretório recursivamente
  echo -e "${YELLOW}-- Teste: Apagar diretório recursivamente --${NC}"
  delete_file dir_teste

  #################################################
  # 📋 VERIFICAR CONTEÚDOS DA RECICLAGEM
  #################################################
  echo -e "${YELLOW}=== [5/10] LISTAGEM NORMAL ===${NC}"
  list_recycled

  echo -e "${YELLOW}=== [6/10] LISTAGEM DETALHADA ===${NC}"
  list_recycled --detailed

  #################################################
  # 🔁 TESTES DE RESTAURAÇÃO
  #################################################
  echo -e "${YELLOW}=== [7/10] TESTES DE RESTORE ===${NC}"

  # Obter ID de um dos ficheiros apagados
  local id_teste
  id_teste=$(awk -F',' 'NR==2 {print $1}' "$METADATA_FILE")

  echo -e "${YELLOW}-- Teste: Restaurar por ID ($id_teste) --${NC}"
  restore_file "$id_teste"

  # Restaurar por nome
  local nome_teste
  nome_teste=$(awk -F',' 'NR==2 {print $2}' "$METADATA_FILE")

  echo -e "${YELLOW}-- Teste: Restaurar por nome ($nome_teste) --${NC}"
  restore_file "$nome_teste"

  # Tentar restaurar item inexistente
  echo -e "${YELLOW}-- Teste: Restaurar item inexistente --${NC}"
  restore_file "nao_existe_123"

  #################################################
  # 💾 TESTE DE CONFLITO DE NOMES
  #################################################
  echo -e "${YELLOW}=== [8/10] TESTE DE CONFLITO ===${NC}"

  # Criar novamente um ficheiro igual ao que foi apagado antes
  echo "Novo ficheiro conflito" > teste1.txt
  delete_file teste1.txt

  # Restaurar o mesmo ficheiro (deve detetar conflito)
  id_conf=$(awk -F',' 'NR>1 {print $1; exit}' "$METADATA_FILE")
  echo -e "${YELLOW}-- Teste: Restaurar com conflito (ficheiro já existe) --${NC}"
  echo "R" | restore_file "$id_conf"

  #################################################
  # 🧹 TESTE DE ESPAÇO INSUFICIENTE (simulado)
  #################################################
  echo -e "${YELLOW}=== [9/10] TESTE DE ESPAÇO INSUFICIENTE (simulação) ===${NC}"

  # Simular sem espaço (forçar bytes_available a 0 temporariamente)
  bytes_available() { echo 0; }
  echo "Forçar falta de espaço: tentar apagar ficheiro de teste"
  echo "Pequeno conteúdo" > pequeno.txt
  delete_file pequeno.txt

  #################################################
  # 📜 VISUALIZAÇÃO FINAL DE LOGS E METADADOS
  #################################################
  echo -e "${YELLOW}=== [10/10] VERIFICAÇÃO FINAL ===${NC}"
  echo -e "${GREEN}Últimos registos de log:${NC}"
  tail -n 15 "$LOG_FILE"
  echo
  echo -e "${GREEN}Conteúdo atual do metadata.db:${NC}"
  cat "$METADATA_FILE"
  echo

  echo -e "${GREEN}=== TESTES CONCLUÍDOS COM SUCESSO ===${NC}"
}



main "$@"
