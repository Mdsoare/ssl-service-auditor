<#
.SYNOPSIS
    Script de Auditoria de Conectividade e Validação de SSL em Lote.
.DESCRIPTION
    Lê uma lista de sites de um arquivo texto, higieniza os inputs,
    verifica a conectividade HTTP/S e valida a expiração do certificado SSL.
.NOTES
    Autor: Marcelo
    Data: Junho/2026    
    Versão: 1.0 (PowerShell Edition)
#>

$ErrorActionPreference = "Stop"

# 1. Validação do Input (Parâmetro)
Param(
    [Parameter(Mandatory=$true, HelpMessage="Caminho para o arquivo .txt com a lista de sites.")]
    [string]$ArquivoSites
)

# 2. Verifica se o arquivo existe
if (-not (Test-Path -Path $ArquivoSites -PathType Leaf)) {
    Write-Error "Erro: O arquivo '$ArquivoSites' não foi encontrado."
    exit 1
}

# Nome do log em formato padrão ISO-like
$DataAtual = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = "Auditoria_Multi_$DataAtual.log"

"--- Inicio da Auditoria em Lote: $(Get-Date) ---" | Out-File -FilePath $LogFile -Encoding utf8

# ==============================================================================
# FUNÇÕES DE AUDITORIA
# ==============================================================================

function Test-ServiceStatus {
    param ([string]$Alvo)
    "   [1] Checando status HTTP/S..." | Out-File -FilePath $LogFile -Append -Encoding utf8

    try {        
        $Response = Invoke-WebRequest -Uri "https://$Alvo" -Method Head -TimeoutSec 5 -UseBasicParsing
        "       -> Status: OK (HTTP $($Response.StatusCode))" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
    catch {
        "       -> Status: ALERTA (Falha ou inacessível via HTTPS. Detalhe: $_)" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

function Test-SSLValidity {
    param ([string]$Alvo)
    "   [2] Verificando validade do certificado SSL..." | Out-File -FilePath $LogFile -Append -Encoding utf8

    try {
        # Cria uma conexão TCP nativa com a porta 443 do alvo
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $TcpClient.Connect($Alvo, 443)

        # Cria o stream SSL e valida o certificado remoto
        $SslStream = New-Object System.Net.Security.SslStream($TcpClient.GetStream(), $false, ({ $true }))
        $SslStream.AuthenticateAsClient($Alvo)

        # Extrai o certificado e a data de expiração
        $Certificado = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SslStream.RemoteCertificate)
        $DataExpiracao = $Certificado.NotAfter

        "       -> Válido até: $DataExpiracao" | Out-File -FilePath $LogFile -Append -Encoding utf8

        # Fecha as conexões de forma limpa
        $SslStream.Close()
        $TcpClient.Close()
    }
    catch {
        "       -> ERRO: Falha ao obter ou validar o certificado SSL. Detalhe: $_" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

# ==============================================================================
# LOOP PRINCIPAL (Leitura e Higienização do Arquivo)
# ==============================================================================

Write-Host "Processando sites do arquivo: $ArquivoSites..." -ForegroundColor Cyan
Write-Host "Acompanhe o progresso em tempo real no arquivo de log: $LogFile" -ForegroundColor Yellow

$Contador = 0

Get-Content -Path $ArquivoSites | ForEach-Object {
    $Linha = $_.Trim()
    
    if ([string]::IsNullOrEmpty($Linha) -or $Linha.StartsWith("#")) {
        return # Equivalente ao 'continue' do Bash dentro do ForEach-Object
    }

    try {
        if (-not ($Linha -match "^https?://")) {
            $UriValida = New-Object System.Uri("https://$Linha")
        } else {
            $UriValida = New-Object System.Uri($Linha)
        }
        $Dominio = $UriValida.Host
    }
    catch {
        "   [ERRO DE INPUT] Não foi possível processar a linha: $Linha" | Out-File -FilePath $LogFile -Append -Encoding utf8
        return
    }

    $Contador++

    # Escrita visual no arquivo de log
    "`n==================================================" | Out-File -FilePath $LogFile -Append -Encoding utf8
    "Alvo #$Contador: $Dominio" | Out-File -FilePath $LogFile -Append -Encoding utf8
    "==================================================" | Out-File -FilePath $LogFile -Append -Encoding utf8

    # Executa as validações
    Test-ServiceStatus -Alvo $Dominio
    Test-SSLValidity -Alvo $Dominio
}

# Finalização
"`n--- Auditoria concluída para $Contador alvos. ---" | Out-File -FilePath $LogFile -Append -Encoding utf8
Write-Host "Auditoria concluída com sucesso! Log gerado: $LogFile" -ForegroundColor Green