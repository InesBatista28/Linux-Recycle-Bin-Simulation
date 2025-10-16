#!/bin/bash

#################################################
# Script Header Comment
# Author: Inês Batista, Maria Quinteiro
# Date: 2025-10-16
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




#teste main muito simples do chat só para testar o delete_files
main() {
  echo -e "${YELLOW}A inicializar o sistema de reciclagem...${NC}"
  initialize_recyclebin

  echo -e "${YELLOW}Iniciando testes de erro...${NC}"

  #########################
  # 1️⃣ Nenhum argumento
  echo -e "${YELLOW}Teste 1: Nenhum argumento${NC}"
  delete_file

  #########################
  # 2️⃣ Ficheiro inexistente
  echo -e "${YELLOW}Teste 2: Ficheiro inexistente${NC}"
  delete_file ficheiro_inexistente.txt

  #########################
  # 3️⃣ Sem permissões
  echo -e "${YELLOW}Teste 3: Sem permissões${NC}"
  touch sem_permissao.txt
  chmod 000 sem_permissao.txt
  delete_file sem_permissao.txt
  chmod 644 sem_permissao.txt
  rm sem_permissao.txt

  #########################
  # 4️⃣ Apagar o próprio Recycle Bin
  echo -e "${YELLOW}Teste 4: Apagar o próprio Recycle Bin${NC}"
  delete_file "$RECYCLE_BIN_DIR"

  #########################
  # 5️⃣ Espaço insuficiente (simulado)
  echo -e "${YELLOW}Teste 5: Espaço insuficiente (simulado)${NC}"
  large_file="arquivo_grande.txt"
  echo "12345" > "$large_file"
  # Monkey patch bytes_available para retornar 0 bytes
  bytes_available_original=$(declare -f bytes_available)
  bytes_available() { echo 0; }
  delete_file "$large_file"
  rm "$large_file"
  eval "$bytes_available_original"

  #########################
  # 6️⃣ Ficheiro válido
  echo -e "${YELLOW}Teste 6: Ficheiro válido${NC}"
  echo "Ficheiro normal" > ficheiro_valido.txt
  delete_file ficheiro_valido.txt

  #########################
  # 7️⃣ Diretório com ficheiros (teste recursivo)
  echo -e "${YELLOW}Teste 7: Diretório recursivo${NC}"
  mkdir -p pasta_teste/subpasta
  echo "Ficheiro dentro da pasta" > pasta_teste/ficheiro1.txt
  echo "Outro ficheiro dentro da subpasta" > pasta_teste/subpasta/ficheiro2.txt
  delete_file pasta_teste

  echo -e "${GREEN}Testes de erro e sucesso concluídos.${NC}"

  # Visualização rápida
  echo -e "${YELLOW}Conteúdo atual da pasta de reciclagem:${NC}"
  ls -l "$FILES_DIR"

  echo -e "${YELLOW}Primeiras linhas do metadata.db:${NC}"
  head -n 5 "$METADATA_FILE"

  echo -e "${YELLOW}Últimas linhas do log:${NC}"
  tail -n 20 "$LOG_FILE"
}

main "$@"




