# 🛡️ SSL & Service Health Auditor

<p align="left">
  <!-- Badge do Status do Workflow de Segurança -->
  <a href="https://github.com/Mdsoare/ssl-service-auditor/actions/workflows/security-scan.yml">
    <img src="https://github.com/Mdsoare/ssl-service-auditor/actions/workflows/security-scan.yml/badge.svg" alt="DevSecOps Security Scan Status">
  </a>
  <!-- Suas Badges Personalizadas -->
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/DevSecOps-Hardened-brightgreen?style=for-the-badge" alt="DevSecOps">
</p>

---

Ferramenta automatizada em **Bash** e **PowerShell** para auditoria de saúde de serviços web e verificação da validade de certificados SSL/TLS em lote.

Projetada com foco em **segurança (DevSecOps)**, a ferramenta realiza a sanitização de _inputs_ para prevenir _command injection_, trata erros de conexão de forma limpa e processa listas de domínios via arquivo de texto.

---

## ✨ Funcionalidades

- **Auditoria de Conectividade:** Checa disponibilidade de serviços web via requisições HTTPS (com suporte a timeouts configurados).
- **Validação de Certificado SSL/TLS:** Extrai e grava no log a data de expiração exata (`notAfter`) do certificado remoto.
- **Processamento em Lote (Batch):** Lê múltiplos alvos de um único arquivo `.txt` ignorando comentários, linhas em branco e caracteres invisíveis de quebra de linha (`\r`).
- **Sanitização de Input:** Trata automaticamente URLs com `http://`, `https://` ou caminhos longos para extrair apenas o FQDN/Host.
- **Auditoria Segura:** Logs formatados com marcação de data/hora (padrão `ISO-8601`) para evitar substituição de arquivos e contaminação de escopo.

---

## 🚀 Requisitos

### Para o Script Bash (`audit-sites.sh`)

- Sistema operacional Linux / macOS / WSL
- Utilitários nativos: `curl`, `openssl`, `sed`, `tr`

### Para o Script PowerShell (`Audit-Sites.ps1`)

- Windows PowerShell 5.1+ ou PowerShell Core 7.x+ (Cross-platform)
- Permissão de execução local habilitada no PowerShell

---

## 📂 Estrutura do Repositório

```text
.
├── .gitignore
├── LICENSE
├── README.md            # Documentação do projeto
└── scripts/
    ├── audit-sites.sh
    └── Audit-Sites.ps1
```

---

## 🛠️ Estrutura do Arquivo de Entrada (`sites.txt`)

Crie um arquivo `.txt` contendo a lista de domínios ou URLs que deseja auditar. O interpretador aceita comentários iniciados com `#`:

```text
# Lista de Produção
www.google.com
https://github.com
www.microsoft.com/pt-br

# Ambientes de Homologação
exemplo.org
```

---

## 💻 Como Usar

### 1. Executando via Bash (Linux/macOS)

Dê permissão de execução ao script e passe o arquivo de texto como argumento:

```bash
# Conceder permissão de execução
chmod +x scripts/audit-sites.sh

# Executar a auditoria
./scripts/audit-sites.sh sites.txt
```

### 2. Executando via PowerShell (Windows/Linux)

Abra o terminal do PowerShell e execute o script passando o parâmetro -ArquivoSites:

```powershell
# Habilitar execução de scripts na sessão atual (se necessário no Windows)
Set-ExecutionPolicy RemoteSigned -Scope Process

# Executar a auditoria
.\scripts\Audit-Sites.ps1 -ArquivoSites "sites.txt"
```

### Possíveis Bloqueios de Execução (PowerShell)

> **Nota**: O atributo `Zone.Identifier` (MOTW - Mark of the Web) pode bloquear a execução do script caso ele seja baixado da internet/mídia externa, mesmo com a política `RemoteSigned` ativa (`Set-ExecutionPolicy RemoteSigned -Scope Process`). Nesses casos, o PowerShell identifica o arquivo como remoto e exige uma assinatura digital.

#### Como Resolver

1. **Opção 1: Desbloquear o arquivo do script (Recomendado)**

   ```powershell
   Unblock-File -Path .\Audit-Sites.ps1
   .\Audit-Sites.ps1 -ArquivoSites "sites.txt"
   ```

2. **Opção 2: Ajustar a ExecutionPolicy no escopo do Processo**

   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\Audit-Sites.ps1 -ArquivoSites "sites.txt"
   ```

---

## 📊 Exemplo de Output (Log de Auditoria)

Após a execução, um arquivo de log será gerado no mesmo diretório (ex: Auditoria_Multi_2026-08-11_22-00-00.log) contendo o resultado detalhado:

```text
--- Inicio da Auditoria em Lote: 08/13/2026 10:05:04 ---

==================================================
Alvo #1: www.google.com
==================================================
   [1] Checando status HTTP/S...
       -> Status: OK (HTTP 200)
   [2] Verificando validade do certificado SSL...
       -> Válido até: 02/04/2027 10:32:19
       -> Cadeia SSL: Confiável (Validada com sucesso)

==================================================
Alvo #2: github.com
==================================================
   [1] Checando status HTTP/S...
       -> Status: OK (HTTP 200)
   [2] Verificando validade do certificado SSL...
       -> Válido até: 02/09/2027 13:03:18
       -> Cadeia SSL: Confiável (Validada com sucesso)

--- Auditoria concluída para 2 alvos. ---
```

---

## 🔒 Boas Práticas de DevSecOps Aplicadas

- `set -euo pipefail` (Bash): Força o término imediato em caso de falhas críticas não tratadas.

- Tratamento de Exceções `Try/Catch` (PowerShell): Captura erros de DNS, portas fechadas e timeouts sem interromper a execução global.

- Uso de Parâmetros Locais: Variáveis de escopo fechado evitam vazamento de dados entre os alvos auditados.

- Parsing via `.NET / sed` Seguro: Neutraliza tentativas de injeção de comandos maliciosos via arquivo de input.

---

## 📜 Licença

Este projeto está sob a licença [MIT](LICENSE).

---

_Desenvolvido por **Marcelo Soares** | Especialista em Segurança da Informação e Computação Forense._
