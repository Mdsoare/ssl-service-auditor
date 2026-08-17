<#
.SYNOPSIS
    Script de Auditoria de Conectividade e Validade de SSL em Lote.
.DESCRIPTION
    Lê uma lista de sites de um arquivo texto, higieniza os inputs,
    verifica a conectividade HTTP/S e valida a expiração e confiabilidade do certificado SSL.
.NOTES
    Autor: Marcelo
    Data: Junho/2026    
    Versão: 2.1 (DevSecOps - Encoding Fixed / Add Finally Block / Persistent Query SSL/TLS)
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, HelpMessage="Caminho para o arquivo .txt com a lista de sites.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ArquivoSites
)

$ErrorActionPreference = "Stop"

# Nome do log em formato padrão ISO-like
$DataAtual = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = "Auditoria_Multi_$DataAtual.log"

# Função utilitária para gravação centralizada de log (UTF-8 Nativo sem BOM)
function Write-AuditLog {
    param (
        [string]$Mensagem,
        [string]$Path = $LogFile
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText((Resolve-Path -Path .\ -ErrorAction SilentlyContinue).Path + "\$Path", "$Mensagem`r`n", $utf8NoBom)
}

# Inicializa o log
Write-AuditLog "--- Inicio da Auditoria em Lote: $(Get-Date) ---"

# ==============================================================================
# FUNÇÕES DE AUDITORIA
# ==============================================================================

function Test-ServiceStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Alvo
    )

    Write-AuditLog "   [1] Checando status HTTP/S..."

    try {        
        $iwrParams = @{
            Uri        = "https://$Alvo"
            Method     = "Head"
            TimeoutSec = 5
        }
        if ($PSVersionTable.PSEdition -eq "Desktop") {
            $iwrParams["UseBasicParsing"] = $true
        }

        $Response = Invoke-WebRequest @iwrParams
        Write-AuditLog "       -> Status: OK (HTTP $($Response.StatusCode))"
    }
    catch {
        Write-AuditLog "       -> Status: ALERTA (Falha ou inacessível via HTTPS. Detalhe: $_)"
    }
}

function Test-SSLValidity {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Alvo
    )

    Write-AuditLog "   [2] Verificando validade do certificado SSL..."

    $TcpClient = $null
    $SslStream = $null

    try {
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        
        $connectTask = $TcpClient.ConnectAsync($Alvo, 443)
        if (-not $connectTask.Wait(3000)) {
            throw "Timeout ao tentar conectar na porta 443 (TCP)."
        }

        $isTrustworthy = $true
        $validationCallback = {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            if ($sslPolicyErrors -ne [System.Net.Security.SslPolicyErrors]::None) {
                $script:isTrustworthy = $false
            }
            return $true
        }

        $SslStream = New-Object System.Net.Security.SslStream($TcpClient.GetStream(), $false, $validationCallback)
        $SslStream.AuthenticateAsClient($Alvo)

        $Certificado = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SslStream.RemoteCertificate)
        $DataExpiracao = $Certificado.NotAfter

        Write-AuditLog "       -> Válido até: $DataExpiracao"
        
        if (-not $isTrustworthy) {
            Write-AuditLog "       -> ALERTA DE SEGURANÇA: O certificado não é confiável (Autoassinado, Erro de Cadeia ou Nome Incompatível)."
        } else {
            Write-AuditLog "       -> Cadeia SSL: Confiável (Validada com sucesso)"
        }
    }
    catch {
        Write-AuditLog "       -> ERRO: Falha ao obter ou validar o certificado SSL. Detalhe: $_"
    }
    finally {
        if ($null -ne $SslStream) { 
            $SslStream.Close()
            $SslStream.Dispose() 
        }
        if ($null -ne $TcpClient) { 
            $TcpClient.Close()
            $TcpClient.Dispose() 
        }
    }
}

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================

Write-Output "Processando sites do arquivo: $ArquivoSites..." -ForegroundColor Cyan
Write-Output "Acompanhe o progresso em tempo real no arquivo de log: $LogFile" -ForegroundColor Yellow

$Contador = 0

Get-Content -Path $ArquivoSites | ForEach-Object {
    $Linha = $_.Trim()
    
    if ([string]::IsNullOrEmpty($Linha) -or $Linha.StartsWith("#")) {
        return
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
        Write-AuditLog "   [ERRO DE INPUT] Não foi possível processar a linha: $Linha"
        return
    }

    $Contador++

    Write-AuditLog "`r`n=================================================="
    Write-AuditLog "Alvo #${Contador}: $Dominio"
    Write-AuditLog "=================================================="

    Test-ServiceStatus -Alvo $Dominio
    Test-SSLValidity -Alvo $Dominio
}

Write-AuditLog "`r`n--- Auditoria concluída para $Contador alvos. ---"
Write-Output "Auditoria concluída com sucesso! Log gerado: $LogFile" -ForegroundColor Green