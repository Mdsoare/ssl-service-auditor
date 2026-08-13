#!/bin/bash
################################################################################
# Autor: Marcelo                                                               #
# Data: Junho/2026                                                             #
# Versão: 2.1 (DevSecOps - Encoding Fixed / Add Cleanup & Timeout / Query SSL) #
# Descrição: Auditoria de Conectividade e Validação de SSL em Lote.            #
################################################################################

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

# Função utilitária centralizada para escrita em log
escrever_log() {
    local mensagem="$1"
    echo -e "$mensagem" >> "$LOG_FILE"
}

escrever_log "--- Inicio da Auditoria em Lote: $(date) ---"

# ==============================================================================
# FUNÇÕES DE AUDITORIA
# ==============================================================================

checar_status() {
    local alvo=$1
    escrever_log "   [1] Checando status HTTP/S..."
    
    # Captura o código HTTP real (Head request com timeout de 5s)
    local http_code
    http_code=$(curl -s -o /dev/null -I -w "%{http_code}" --max-time 5 "https://$alvo" 2>/dev/null || echo "000")
    
    if [ "$http_code" -ne "000" ]; then
        escrever_log "       -> Status: OK (HTTP $http_code)"
    else
        escrever_log "       -> Status: ALERTA (Falha ou inacessível via HTTPS)"
    fi
}

checar_ssl() {
    local alvo=$1
    escrever_log "   [2] Verificando validade do certificado SSL..."
    
    # Coleta a cadeia bruta do certificado com timeout rigoroso para evitar sockets órfãos
    local cert_output
    cert_output=$(timeout 5 openssl s_client -servername "$alvo" -connect "$alvo":443 -showcerts -connect_timeout 3 </dev/null 2>&1 || true)
    
    # Extrai a data de expiração
    local expiracao
    expiracao=$(echo "$cert_output" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//' || true)
    
    if [ -z "$expiracao" ]; then
        escrever_log "       -> ERRO: Falha ao obter ou validar o certificado SSL."
    else
        escrever_log "       -> Válido até: $expiracao"
        
        # Validação da cadeia de confiança
        local verify_code
        verify_code=$(echo "$cert_output" | grep -E "Verify return code:" | head -n1 || true)
        
        if echo "$verify_code" | grep -q "0 (ok)"; then
            escrever_log "       -> Cadeia SSL: Confiável (Validada com sucesso)"
        else
            escrever_log "       -> ALERTA DE SEGURANÇA: O certificado não é confiável (Autoassinado, Erro de Cadeia ou Nome Incompatível)."
        fi
    fi
}

# ==============================================================================
# LOOP PRINCIPAL (Leitura e Higienização do Arquivo)
# ==============================================================================

echo "Processando sites do arquivo: $ARQUIVO_SITES..."
echo "Acompanhe o progresso em tempo real no arquivo de log: $LOG_FILE"

CONTADOR=0

while IFS= read -r linha || [ -n "$linha" ]; do    
    # Remove retorno de carro (\r) e espaços nas extremidades
    linha=$(echo "$linha" | tr -d '\r' | xargs || true)
    
    # Ignora linhas em branco ou comentários (#)
    if [ -z "$linha" ] || [[ "$linha" =~ ^# ]]; then
        continue
    fi
    
    # Higienização de domínio/URI
    DOMINIO=$(echo "$linha" | sed -E 's|https?://||' | cut -d'/' -f1)
    
    CONTADOR=$((CONTADOR + 1))
        
    escrever_log "\n=================================================="
    escrever_log "Alvo #$CONTADOR: $DOMINIO"
    escrever_log "=================================================="
    
    checar_status "$DOMINIO"
    checar_ssl "$DOMINIO"

done < "$ARQUIVO_SITES"

# Finalizando a auditoria
escrever_log "\n--- Auditoria concluída para $CONTADOR alvos. ---"
echo "Auditoria concluída com sucesso! Log gerado: $LOG_FILE"