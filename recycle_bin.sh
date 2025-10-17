#!/bin/bash

#################################################
# Script Header Comment
# Author: Inês Batista, Maria Quinteiro
# Date: 2025-10-17
# Description: Linux Recycle Bin Simulator
# Version: 1.0
#################################################


RECYCLE_BIN_DIR="$HOME/.recycle_bin"     # Diretório principal da reciclagem
FILES_DIR="$RECYCLE_BIN_DIR/files"    # Subdiretório que vai armazenar os ficheiros que forem apagados
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"    # Base de dados que guardará informação sobre os ficheiros apagados
CONFIG_FILE="$RECYCLE_BIN_DIR/config"     # Ficheiro de configuração do sistema de reciclagem
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"    # Ficheiro de log para registar todas as operações realizadas

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


#################################################
# Function: log_msg
# Description: Função utilitária que será utilizada por outras de maneira a registar as operações que se realizarem no bin
# Parameters: $1 - Nível (INFO, ERROR), $2 - Mensagem a registar
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
# Description: Cria a estrutura inicial da reciclagem e ficheiros necessários, caso os mesmos ainda não existam
# Parameters: Nenhum
# Returns: 0 caso sucesso, 1 caso erro
#################################################
initialize_recyclebin() {
  # Criar diretório principal se não existir
  if [ ! -d "$RECYCLE_BIN_DIR" ]
  then
    mkdir "$RECYCLE_BIN_DIR"
    echo "Diretório $RECYCLE_BIN_DIR criado."
  fi

  # Criar subdiretório files se não existir
  if [ ! -d "$FILES_DIR" ]
  then
    mkdir "$FILES_DIR"
    echo "Subdiretório $FILES_DIR criado."
  fi

  # Criar metadata.db com cabeçalho se não existir
  if [ ! -f "$METADATA_FILE" ]
  then
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
    echo "Ficheiro metadata.db inicializado."
  fi

  # Criar ficheiro config com valores padrão se não existir
  if [ ! -f "$CONFIG_FILE" ]
  then
    echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
    echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
    echo "Ficheiro config criado com valores padrão."
  fi

  # Criar ficheiro de log vazio se não existir
  if [ ! -f "$LOG_FILE" ]
  then
    touch "$LOG_FILE"
    echo "Ficheiro de log criado."
  fi
}


#################################################
# Function: generate_id
# Description: Gera um ID único baseado em timestamp + Process ID(Identificador), que será o nome dos ficheiros eliminados dentro da pasta files
# Parameters: Nenhum
# Returns: ID gerados
#################################################
generate_id() {
  echo "$(date +%s%N)_$$"
}



#################################################
# Function: bytes_available
# Description: Retorna o espaço livre em bytes na partição do Recycle Bin
# Parameters: Nenhum
# Returns: número de bytes disponíveis
#################################################
bytes_available() {
  local avail
  avail=$(df --output=avail "$RECYCLE_BIN_DIR" 2>/dev/null | tail -1)
  # fallback caso esteja vazio
  if [ -z "$avail" ]; then
    avail=0
  fi
  echo "$avail"
}


#################################################
# Function: transform_size
# Description: Converte tamanho em bytes para formato legível (B, KB, MB, GB)
# Parameters: $1 - tamanho em bytes
# Returns: tamanho formatado
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
# Description: Move ficheiros ou diretórios para a "Recycle Bin", 
#              guardando metadata (nome original, caminho, data de eliminação, 
#              tamanho, tipo, permissões e dono) e registando todas as operações
#              no log. Suporta múltiplos argumentos, verificação de permissões,
#              espaço disponível e não permite apagar o próprio Recycle Bin.
#              Diretórios são apagados recursivamente.
# Parameters: $@ - lista de ficheiros/diretórios a eliminar
# Returns: 0 se pelo menos um item foi movido com sucesso, 1 se ocorreu um erro em todos os itens ou argumentos inválidos
#################################################
delete_file() {
  initialize_recyclebin

  # validar se foram passados argumentos
  if [ $# -eq 0 ]
  then  
    echo -e "${RED}ERRO: Nenhum ficheiro/diretoria especificado.${NC}"
    log_msg "ERROR" "Tentativa de apagar sem argumentos passados"
    return 1
  fi


  for item in "$@"
  do
    # validar existência do argumento passado
    if [ ! -e "$item" ]
    then
      echo -e "${RED}ERRO: '$item' não existe.${NC}"
      log_msg "ERROR" "Tentativa de apagar item não existente: $item"
      continue 
    fi

    # tentativa de eliminar o recycle bin
    if [[ "$item" == "$RECYCLE_BIN_DIR"* ]]
    then
      echo -e "${RED}ERRO: Não é possível eliminar o próprio Recycle Bin.${NC}"
      log_msg "ERROR" "Tentativa de eliminar o Recycle Bin: $item"
      continue
    fi

    #  verificar as permissões para apagar argumentos
    if [ ! -r "$item" ] || [ ! -w "$item" ]
    then  
      echo -e "${RED}ERRO: Sem permissão para eliminar '$item'.${NC}"
      log_msg "ERROR" "Sem permissão para eliminar $item"
      continue
    fi


    id=$(generate_id)


    # determinar tipo e tamanho do argumento passado para saber se cabe no bin
    if [ -d "$item" ]
    then
      type="directory"
      size=$(du -sb "$item" | awk '{print $1}')
    else
      type="file"
      size=$(stat -c %s "$item")
    fi

    # verificar espaço disponível no bin
    available=$(bytes_available)
    available=${available:-0}  
    if [ "$available" -lt "$size" ]; then
      echo -e "${RED}ERRO: Não há espaço suficiente para mover '$item'.${NC}"
      log_msg "ERROR" "Espaço insuficiente para $item, com $size bytes."
      continue
    fi



    # dados que serão guardados no metabase.db
    original_name=$(basename "$item")
    original_path=$(realpath "$item")
    deletion_date=$(date +"%Y-%m-%d %H:%M:%S")
    permissions=$(stat -c %a "$item")
    owner=$(stat -c %U:%G "$item")
    echo "$id,$original_name,$original_path,$deletion_date,$size,$type,$permissions,$owner" >> "$METADATA_FILE"

    # mover ficheiros de diretório
    mv "$item" "$FILES_DIR/$id" 2>/dev/null
    if [ $? -ne 0 ]
    then
      echo -e "${RED}ERRO: Falha ao mover '$item' para o Recycle Bin.${NC}"
      log_msg "ERROR" "Falha ao mover $item para o Recycle Bin"
      continue
    fi

    # sucesso no movimento de diretórios
    echo -e "${GREEN} '$original_name' movido para o Recycle Bin.${NC}"
    log_msg "INFO" "'$original_name' movido para o Recycle Bin com o ID $id"
  done

  return 0
}





#################################################
# Function: list_recycled
# Description: Lista o conteúdo atual do Recycle Bin em formato de tabela, suporta duas opções. Calcula também o total de itens e o espaço total utilizado.
# Parameters: $1 - "--detailed" para ativar o modo detalhado
# Returns: 0 em sucesso, 0 também se a reciclagem estiver vazia.
#################################################
list_recylced() {
  initialize_recyclebin

  # verificar se o ficheiro metabase, que contém os dados que queremos aceder, existe e não está vazio
  if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 1 ]
  then
    echo -e "${YELLOW}O Recycle Bin está vazio.${NC}"
    return 0
  fi

  # verifica se o utilizador pretende o detailed mode 
  local detailed=false
  if [ "$1" == "--detailed" ]
  then
    detailed=true
  fi


  local total_items
  local total_size

  total_items=$(($(wc -l < "$METADATA_FILE") - 1))  # subtrair o cabeçalho da contagem
  # define a vírgula como separador, ignora o cabeçalho, adiciona o valor da quinta coluna a sum, e imprime a soma total
  total_size=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$METADATA_FILE")

  echo -e "${YELLOW}Conteúdo da Reciclagem: ${NC}"
  # NORMAL MODE
  if [ "$detailed" = false ]
  then
    printf "${GREEN}%-35s | %-25s | %-20s | %-10s${NC}\n" "ID" "Original filename" "Deletion date and time" "File size"


    # ler o ficheiro metabase ignorando o cabeçalho
    tail -n +2 "$METADATA_FILE" | while read line; do
      # Separar os campos com cut
      id=$(echo "$line" | cut -d',' -f1)
      original_name=$(echo "$line" | cut -d',' -f2)
      deletion_date=$(echo "$line" | cut -d',' -f4)
      size=$(echo "$line" | cut -d',' -f5)

      #converter para tamanho real
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
      echo -e "${GREEN}Nome original:${NC}   $original_name"
      echo -e "${GREEN}Caminho original:${NC} $original_path"
      echo -e "${GREEN}Data eliminação:${NC}  $deletion_date"
      echo -e "${GREEN}Tamanho:${NC}          $readable_size"
      echo -e "${GREEN}Tipo:${NC}             $type"
      echo -e "${GREEN}Permissões:${NC}       $permissions"
      echo -e "${GREEN}Dono:${NC}             $owner"
      echo
    done
  fi

  readable_total=$(transform_size "$total_size")
  echo "Total de itens: $total_items"
  echo "Espaço total utilizado: $readable_total"

}



main() {
  echo -e "${YELLOW}=== Inicializando o Recycle Bin ===${NC}"
  initialize_recyclebin

  echo -e "${YELLOW}=== Criando ficheiros e diretórios de teste ===${NC}"
  # Criar ficheiros de teste
  echo "Conteúdo do ficheiro 1" > teste1.txt
  echo "Conteúdo do ficheiro 2" > teste2.txt

  # Criar diretório com subdiretórios
  mkdir -p dir_teste/subdir
  echo "Arquivo dentro do diretório" > dir_teste/arquivo1.txt
  echo "Outro arquivo" > dir_teste/subdir/arquivo2.txt

  # Criar ficheiro sem permissões
  touch sem_permissao.txt
  chmod 000 sem_permissao.txt

  echo -e "${YELLOW}=== Testando delete_file ===${NC}"
  
  # 1️⃣ Tentativa de apagar ficheiro inexistente
  delete_file arquivo_inexistente.txt

  # 2️⃣ Tentativa de apagar ficheiro sem permissões
  delete_file sem_permissao.txt

  # Restaurar permissões e apagar ficheiro de teste
  chmod 644 sem_permissao.txt
  rm sem_permissao.txt

  # 3️⃣ Apagar ficheiros válidos
  delete_file teste1.txt teste2.txt

  # 4️⃣ Apagar diretório recursivo
  delete_file dir_teste

  echo -e "${YELLOW}=== Conteúdo do Recycle Bin (modo normal) ===${NC}"
  list_recylced

  echo -e "${YELLOW}=== Conteúdo do Recycle Bin (modo detalhado) ===${NC}"
  list_recylced --detailed

  echo -e "${YELLOW}=== Logs recentes ===${NC}"
  tail -n 20 "$LOG_FILE"

  echo -e "${YELLOW}=== Metadados recentes ===${NC}"
  tail -n 10 "$METADATA_FILE"
}

# Executar main
main "$@"

