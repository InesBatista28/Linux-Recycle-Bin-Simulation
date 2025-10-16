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
  n ts=$(date +"%Y-%m-%d %H:%M:%S")
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
  if [ ! -d "$RECYCLE_BIN_DIR" ]; then
    mkdir "$RECYCLE_BIN_DIR"
    echo "Diretório $RECYCLE_BIN_DIR criado."
  fi

  # Criar subdiretório files se não existir
  if [ ! -d "$FILES_DIR" ]; then
    mkdir "$FILES_DIR"
    echo "Subdiretório $FILES_DIR criado."
  fi

  # Criar metadata.db com cabeçalho se não existir
  if [ ! -f "$METADATA_FILE" ]; then
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
    echo "Ficheiro metadata.db inicializado."
  fi

  # Criar ficheiro config com valores padrão se não existir
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
    echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
    echo "Ficheiro config criado com valores padrão."
  fi

  # Criar ficheiro de log vazio se não existir
  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    echo "Ficheiro de log criado."
  fi
}


#################################################
# Function: generate_id
# Description: Gera um ID único baseado em timestamp + Process ID(Identificador)
# Parameters: Nenhum
# Returns: ID na stdout
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
  avail_kb=$(df --output=avail "$RECYCLE_BIN_DIR" | tail -1)
}


