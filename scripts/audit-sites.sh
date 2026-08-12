#!/bin/bash
##########################################
# autor: Marcelo                       ###
# data: jun/2026                       ###
# versão: 1.0                          ###
##########################################

set -euo pipefail

# 1. Validação do Input
ARQUIVO_SITES="${1:-}"

if [ -z "$ARQUIVO_SITES" ]; then
    echo "Erro: Forneça o caminho do arquivo .txt com os sites."
    echo "Uso: $0 lista_sites.txt"
    exit 1
fi

if [ ! -f "$ARQUIVO_SITES" ]; then
    echo "Erro: O arquivo '$ARQUIVO_SITES' não foi encontrado."
    exit 1
fi

# Nome do log em formato padrão ISO-like
LOG_FILE="Auditoria_Multi_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "--- Inicio da Auditoria em Lote: $(date) ---" > "$LOG_FILE"

# ==============================================================================
# FUNÇÕES DE AUDITORIA (Adaptadas para receber o alvo como argumento local)
# ==============================================================================

checar_status(){
    local alvo=$1
    echo "   [1] Checando status HTTP/S..." >> "$LOG_FILE"
        
    if curl -s -L --max-time 5 "https://$alvo" &> /dev/null; then
        echo "       -> Status: OK" >> "$LOG_FILE"
    else
        echo "       -> Status: ALERTA (Falha ou inacessível via HTTPS)" >> "$LOG_FILE"
    fi
}

checar_ssl(){
    local alvo=$1
    echo "   [2] Verificando validade do certificado SSL..." >> "$LOG_FILE"
    
    # Coleta a data de expiração de forma segura
    local expiracao
    expiracao=$(echo | openssl s_client -servername "$alvo" -connect "$alvo":443 2>/dev/null | openssl x509 -noout -enddate | sed 's/notAfter=//' || true)
    
    if [ -z "$expiracao" ]; then
        echo "       -> ERRO: Falha ao obter o certificado SSL." >> "$LOG_FILE"
    else
        echo "       -> Válido até: $expiracao" >> "$LOG_FILE"
    fi
}

# ==============================================================================
# LOOP PRINCIPAL (Leitura do arquivo)
# ==============================================================================

echo "Processando sites do arquivo: $ARQUIVO_SITES..."
echo "Acompanhe o progresso em tempo real no arquivo de log: $LOG_FILE"

CONTADOR=0

while IFS= read -r linha || [ -n "$linha" ]; do    
    linha=$(echo "$linha" | tr -d '\r' | xargs)
    
    if [ -z "$linha" ] || [[ "$linha" =~ ^# ]]; then
        continue
    fi
    
    DOMINIO=$(echo "$linha" | sed -E 's|https?://||' | cut -d'/' -f1)
    
    CONTADOR=$((CONTADOR + 1))
        
    echo -e "\n==================================================" >> "$LOG_FILE"
    echo "Alvo #$CONTADOR: $DOMINIO" >> "$LOG_FILE"
    echo "==================================================" >> "$LOG_FILE"
    
    checar_status "$DOMINIO"
    checar_ssl "$DOMINIO"

done < "$ARQUIVO_SITES"

# Finalizando o script
echo -e "\n--- Auditoria concluída para $CONTADOR alvos. Verifique o log: $LOG_FILE ---"