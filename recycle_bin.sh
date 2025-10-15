#!/bin/bash


RECYCLE_BIN_DIR="$HOME/.recycle_bin"    # variável guarda o caminho para a pasta do bin
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"    # onde vai ser guardada a informação sobre os ficheiros apagados



initialize_recyclebin() {
  # Definir variáveis (se ainda não definidas no script)
  RECYCLE_BIN_DIR="$HOME/.recycle_bin"
  FILES_DIR="$RECYCLE_BIN_DIR/files"
  METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
  CONFIG_FILE="$RECYCLE_BIN_DIR/config"
  LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

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
