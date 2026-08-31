# Arquitetura do Sistema - Firewall Voucher Hotspot

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura Técnica](#arquitetura-técnica)
3. [Componentes do Sistema](#componentes-do-sistema)
4. [Fluxo de Dados](#fluxo-de-dados)
5. [Modelo de Dados](#modelo-de-dados)
6. [API Reference](#api-reference)
7. [Segurança](#segurança)
8. [Implantação](#implantação)
9. [Troubleshooting](#troubleshooting)

---

## 1. Visão Geral

### Propósito

O **Firewall Voucher Hotspot** é um sistema completo para gerenciamento de códigos de acesso (vouchers) para redes Wi-Fi de visitantes, integrado ao **Sophos Firewall**.

O sistema resolve o problema de **gerar, distribuir e controlar** códigos de acesso temporários de forma automatizada, substituindo o processo manual de geração de vouchers pelo User Portal do Sophos.

### Problema Resolvido

**Antes (Processo Manual):**
1. Operador acessa `https://firewall:223/userportal/`
2. Faz login com credenciais de administrador
3. Navega até Hotspot > Gerar Vouchers
4. Seleciona definição, dias, quantidade
5. Copia códigos manualmente
6. Envia para visitantes por WhatsApp/email

**Depois (Processo Automatizado):**
1. Operador abre o App Mobile
2. Seleciona parâmetros (validade, dados, dispositivos)
3. Clica em "Gerar Código"
4. Compartilha via WhatsApp com um toque

### Funcionalidades Principais

| Funcionalidade | Descrição |
|----------------|-----------|
| **Geração de Códigos** | Cria códigos únicos no formato Sophos (8 caracteres alfanuméricos) |
| **Geração em Lote** | Gera de 1 a 100 códigos de uma vez |
| **Controle de Validade** | Define dias de validade (1 a 730 dias) |
| **Limite de Dados** | Configura cotas de dados por voucher (MB/GB) |
| **Multi-dispositivo** | Permite 1-5 dispositivos por código |
| **Revogação** | Cancela acesso a qualquer momento |
| **Auditoria** | Registro completo de todas as operações |
| **Estatísticas** | Dashboard com totais por status |
| **QR Code** | Geração de QR Code com dados de acesso |
| **WhatsApp** | Compartilhamento com mensagem formatada |
| **Autenticação JWT** | Segurança com tokens de expiração |

---

## 2. Arquitetura Técnica

### Diagrama de Alto Nível

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           ARQUITETURA DO SISTEMA                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         CAMADA DE APRESENTAÇÃO                         │   │
│   │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│   │  │                    MOBILE APP (Flutter)                        │   │   │
│   │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │   │   │
│   │  │  │  Tela Login │  │  Tela Home  │  │  Tela Stats │           │   │   │
│   │  │  └─────────────┘  └─────────────┘  └─────────────┘           │   │   │
│   │  └─────────────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────┬───────────────────────────────────────┘   │
│                                     │ HTTP/HTTPS (REST API)                     │
│                                     ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         CAMADA DE SERVIÇO (Middleware)                  │   │
│   │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│   │  │                   API REST (FastAPI)                            │   │   │
│   │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │   │   │
│   │  │  │  Auth Router │  │ Voucher Router│  │ Health Router│        │   │   │
│   │  │  └──────────────┘  └──────────────┘  └──────────────┘        │   │   │
│   │  └─────────────────────────────────────────────────────────────────┘   │   │
│   │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│   │  │                   CAMADA DE NEGÓCIO                            │   │   │
│   │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │   │   │
│   │  │  │ Auth Service │  │Voucher Service│  │ QR Generator │        │   │   │
│   │  │  └──────────────┘  └──────────────┘  └──────────────┘        │   │   │
│   │  └─────────────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────┬───────────────────────────────────────┘   │
│                                     │ SQLite                                    │
│                                     ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         CAMDA DE DADOS                                 │   │
│   │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│   │  │                      SQLite Database                            │   │   │
│   │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │   │   │
│   │  │  │voucher_codes │  │  definitions │  │   audit_log  │        │   │   │
│   │  │  └──────────────┘  └──────────────┘  └──────────────┘        │   │   │
│   │  └─────────────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                      SOPHOS FIREWALL (Externo)                         │   │
│   │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│   │  │  Hotspot Portal (Porta 223) - Captive Portal Customizado       │   │   │
│   │  │  Os códigos gerados são inseridos pelo usuário no portal        │   │   │
│   │  └─────────────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Tecnologias Utilizadas

#### Backend (Middleware)
| Tecnologia | Versão | Propósito |
|------------|--------|-----------|
| **Python** | 3.11+ | Linguagem principal |
| **FastAPI** | 0.115.0 | Framework web assíncrono |
| **Uvicorn** | 0.30.6 | Servidor ASGI |
| **Pydantic** | 2.9.2 | Validação de dados |
| **python-jose** | 3.3.0 | JWT (JSON Web Tokens) |
| **passlib** | 1.7.4 | Hash de senhas (bcrypt) |
| **SQLite3** | built-in | Banco de dados local |
| **python-dotenv** | 1.0.1 | Variáveis de ambiente |

#### Mobile
| Tecnologia | Versão | Propósito |
|------------|--------|-----------|
| **Flutter** | 3.16+ | Framework mobile |
| **Dart** | 3.0+ | Linguagem |
| **http** | 1.2.0 | Requisições HTTP |
| **provider** | 6.1.1 | Gerenciamento de estado |
| **qr_flutter** | 4.1.0 | Geração de QR Code |
| **share_plus** | 7.2.1 | Compartilhamento nativo |
| **flutter_secure_storage** | 9.0.0 | Armazenamento seguro |

---

## 3. Componentes do Sistema

### 3.1 Backend (Middleware)

#### Estrutura de Diretórios

```
backend/
├── app/
│   ├── auth/
│   │   ├── __init__.py
│   │   └── jwt_handler.py          # Autenticação JWT
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py              # Modelos Pydantic
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth_router.py          # Endpoints de auth
│   │   └── voucher_router.py       # Endpoints de voucher
│   ├── services/
│   │   ├── __init__.py
│   │   └── voucher_service.py      # Lógica de negócio
│   ├── config.py                   # Configurações
│   ├── main.py                     # Aplicação FastAPI
│   └── __init__.py
├── .env.example                    # Template de configuração
├── .env                            # Configurações reais (não commit)
├── requirements.txt                # Dependências
├── run.py                          # Script de inicialização
└── vouchers.db                     # Banco SQLite (gerado)
```

#### Componentes Principais

##### 3.1.1 - Autenticação JWT (`app/auth/jwt_handler.py`)

**Responsabilidade:** Gerenciar autenticação e autorização de operadores.

```python
# Fluxo de autenticação:
# 1. Operador envia username/senha via POST /auth/login
# 2. Sistema verifica credenciais contra DEFAULT_OPERATORS
# 3. Se válido, gera JWT com expiração configurável
# 4. Retorna token para o cliente
# 5. Cliente inclui token no header Authorization: Bearer <token>
# 6. Endpoints protegidos validam o token via Depends(get_current_operator)
```

**Funções principais:**
- `authenticate_operator()` - Verifica credenciais
- `create_access_token()` - Gera JWT
- `decode_token()` - Valida e decodifica JWT
- `get_current_operator()` - Dependência FastAPI para endpoints protegidos

**Configurações de JWT:**
```python
JWT_SECRET_KEY = "change-in-production"  # Chave de assinatura
JWT_ALGORITHM = "HS256"                  # Algoritmo
JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 480    # 8 horas
```

##### 3.1.2 - Serviço de Vouchers (`app/services/voucher_service.py`)

**Responsabilidade:** Toda a lógica de negócio relacionada a vouchers.

**Banco de Dados SQLite:**

```sql
-- Tabela principal de códigos
CREATE TABLE voucher_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT UNIQUE NOT NULL,           -- Código (ex: AB3CD9F2)
    description TEXT,                     -- Nome do visitante
    definition_name TEXT,                 -- Definição no Sophos
    validity_days INTEGER DEFAULT 30,     -- Dias de validade
    data_limit_mb INTEGER DEFAULT 0,      -- Limite de dados (0=ilimitado)
    devices_allowed INTEGER DEFAULT 1,    -- Dispositivos permitidos
    status TEXT DEFAULT 'active',         -- active/expired/revoked/used
    created_at TIMESTAMP,
    expires_at TIMESTAMP,
    used_at TIMESTAMP,
    used_by TEXT,
    created_by TEXT,
    notes TEXT
);

-- Tabela de definições sincronizadas com Sophos
CREATE TABLE voucher_definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    validity_days INTEGER,
    validity_unit TEXT DEFAULT 'Days',
    time_quota INTEGER,
    time_quota_unit TEXT,
    data_volume INTEGER,
    data_unit TEXT,
    devices_per_voucher INTEGER DEFAULT 1,
    synced_at TIMESTAMP,
    sophos_id TEXT
);

-- Log de auditoria
CREATE TABLE voucher_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    voucher_code_id INTEGER,
    action TEXT NOT NULL,         -- CREATE/REVOKE/USE/SYNC
    details TEXT,
    performed_by TEXT,
    performed_at TIMESTAMP,
    FOREIGN KEY (voucher_code_id) REFERENCES voucher_codes(id)
);
```

**Algoritmo de Geração de Código:**

```python
# Formato: 8 caracteres alfanuméricos
# Alfabeto: ABCDEFGHJKLMNPQRSTUVWXYZ23456789
# (sem caracteres ambíguos: 0/O, 1/I, etc.)

def _generate_unique_code(self, length=8):
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        code = ''.join(secrets.choice(alphabet) for _ in range(length))
        if not self._code_exists(code):
            return code
```

**Operações CRUD:**

| Método | Descrição |
|--------|-----------|
| `generate_voucher_code()` | Gera um código único |
| `generate_multiple_codes()` | Gera N códigos (1-100) |
| `get_voucher()` | Busca por código |
| `list_vouchers()` | Lista com filtros e paginação |
| `revoke_voucher()` | Revoga um código |
| `mark_as_used()` | Marca como usado |
| `get_audit_log()` | Retorna log de auditoria |
| `get_statistics()` | Totais por status |

##### 3.1.3 - Roteadores (`app/routers/`)

**Auth Router (`auth_router.py`):**
| Endpoint | Método | Auth | Descrição |
|----------|--------|------|-----------|
| `/api/v1/auth/login` | POST | Não | Retorna JWT |
| `/api/v1/auth/me` | GET | Sim | Dados do operador |

**Voucher Router (`voucher_router.py`):**
| Endpoint | Método | Auth | Descrição |
|----------|--------|------|-----------|
| `/api/v1/vouchers/generate` | POST | Sim | Gera 1 código |
| `/api/v1/vouchers/generate-batch` | POST | Sim | Gera N códigos |
| `/api/v1/vouchers/list` | GET | Sim | Lista códigos |
| `/api/v1/vouchers/{code}` | GET | Sim | Busca código |
| `/api/v1/vouchers/revoke` | POST | Sim | Revoga código |
| `/api/v1/vouchers/{code}/audit` | GET | Sim | Log de auditoria |
| `/api/v1/vouchers/stats/summary` | GET | Sim | Estatísticas |

##### 3.1.4 - Modelos de Dados (`app/models/schemas.py`)

**Request Models:**
```python
HotspotVoucherCodeRequest:
  - quantity: int (1-100)
  - definition_name: Optional[str]
  - validity_days: int (1-730)
  - data_limit_mb: int (0=ilimitado)
  - devices_allowed: int (1-5)
  - visitor_name: Optional[str]
  - notes: Optional[str]
```

**Response Models:**
```python
HotspotVoucherCodeResponse:
  - id: int
  - code: str (ex: "AB3CD9F2")
  - description: Optional[str]
  - definition_name: Optional[str]
  - validity_days: int
  - data_limit_mb: int
  - devices_allowed: int
  - status: str
  - created_at: str (ISO 8601)
  - expires_at: str (ISO 8601)
  - created_by: Optional[str]
```

---

### 3.2 Mobile App (Flutter)

#### Estrutura de Diretórios

```
mobile/
├── lib/
│   ├── main.dart                    # Entry point + AuthWrapper
│   ├── models/
│   │   └── voucher.dart             # Modelos (VoucherCode, AuthResponse, etc.)
│   ├── services/
│   │   ├── auth_service.dart        # Autenticação + armazenamento seguro
│   │   └── api_service.dart         # Comunicação com backend
│   └── screens/
│       ├── login_screen.dart        # Tela de login
│       └── home_screen.dart         # Tela principal com tabs
├── pubspec.yaml                     # Dependências
└── android/ios/                     # Configurações de plataforma
```

#### Componentes Principais

##### 3.2.1 - AuthService (`lib/services/auth_service.dart`)

**Responsabilidade:** Gerenciar sessão e autenticação.

```python
# Fluxo:
# 1. init() - Verifica se há token salvo no SecureStorage
# 2. login() - Envia credenciais para /api/v1/auth/login
# 3. Salva token JWT no SecureStorage (criptografado)
# 4. logout() - Remove token e limpa estado
```

**Armazenamento Seguro:**
- Usa `flutter_secure_storage` (Keychain no iOS, KeyStore no Android)
- Token JWT criptografado em repouso

##### 3.2.2 - ApiService (`lib/services/api_service.dart`)

**Responsabilidade:** Comunicação HTTP com o backend.

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `generateVoucher()` | POST /vouchers/generate | Gera código |
| `generateBatchVouchers()` | POST /vouchers/generate-batch | Gera lote |
| `listVouchers()` | GET /vouchers/list | Lista |
| `getVoucher()` | GET /vouchers/{code} | Busca |
| `revokeVoucher()` | POST /vouchers/revoke | Revoga |
| `getStatistics()` | GET /vouchers/stats/summary | Stats |

**Tratamento de Erros:**
- 401 → Redireciona para login
- 400/500 → Exibe mensagem ao usuário
- Timeout → Exibe "Erro de conexão"

##### 3.2.3 - Telas

**LoginScreen:**
- Campos: Servidor, Usuário, Senha
- Botão "Entrar"
- Loading indicator durante autenticação

**HomeScreen (3 tabs):**
1. **Gerar** - Formulário de geração
2. **Vouchers** - Lista com status e ações
3. **Estatísticas** - Cards com totais

---

## 4. Fluxo de Dados

### 4.1 - Geração de Voucher

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUXO: GERAR VOUCHER                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  MOBILE                    BACKEND                     DATABASE             │
│  ──────                    ───────                     ────────             │
│     │                         │                          │                  │
│     │  POST /vouchers/generate                          │                  │
│     │  { validity_days: 30 }                            │                  │
│     │────────────────────────▶│                          │                  │
│     │                         │                          │                  │
│     │                         │  _generate_unique_code() │                  │
│     │                         │  (alphanum 8 chars)      │                  │
│     │                         │                          │                  │
│     │                         │  INSERT INTO voucher_codes│                  │
│     │                         │  (code, expires_at, ...)  │                  │
│     │                         │─────────────────────────▶│                  │
│     │                         │                          │                  │
│     │                         │  INSERT INTO voucher_audit│                 │
│     │                         │  (action: 'CREATE')       │                  │
│     │                         │─────────────────────────▶│                  │
│     │                         │                          │                  │
│     │                         │  RETURN voucher_data     │                  │
│     │                         │◀─────────────────────────│                  │
│     │                         │                          │                  │
│     │  200 OK                 │                          │                  │
│     │  { code: "AB3CD9F2",    │                          │                  │
│     │    expires_at: "..." }  │                          │                  │
│     │◀────────────────────────│                          │                  │
│     │                         │                          │                  │
│     │  Exibe resultado:       │                          │                  │
│     │  - Código em destaque   │                          │                  │
│     │  - Botão Copiar         │                          │                  │
│     │  - Botão WhatsApp       │                          │                  │
│     │  - QR Code              │                          │                  │
│     │                         │                          │                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 - Compartilhamento via WhatsApp

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUXO: COMPARTILHAR VIA WHATSAPP                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  USUÁRIO                   MOBILE APP                  WHATSAPP             │
│  ───────                   ──────────                  ────────              │
│     │                         │                          │                  │
│     │  Clica "WhatsApp"       │                          │                  │
│     │────────────────────────▶│                          │                  │
│     │                         │                          │                  │
│     │                         │  Formata mensagem:       │                  │
│     │                         │  "Código: AB3CD9F2       │                  │
│     │                         │   Validade: 30/09/2024   │                  │
│     │                         │   Limite: 500 MB"        │                  │
│     │                         │                          │                  │
│     │                         │  Share.share(mensagem)   │                  │
│     │                         │─────────────────────────▶│                  │
│     │                         │                          │                  │
│     │                         │  Abre WhatsApp com       │                  │
│     │                         │  mensagem pré-preenchida │                  │
│     │                         │                          │                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 - Autenticação

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUXO: AUTENTICAÇÃO JWT                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  MOBILE                    BACKEND                     SECURE STORAGE       │
│  ──────                    ───────                     ─────────────        │
│     │                         │                          │                  │
│     │  Login (user, pass)     │                          │                  │
│     │────────────────────────▶│                          │                  │
│     │                         │                          │                  │
│     │                         │  authenticate_operator() │                  │
│     │                         │  (verifica credenciais)  │                  │
│     │                         │                          │                  │
│     │                         │  create_access_token()   │                  │
│     │                         │  (gera JWT com exp)      │                  │
│     │                         │                          │                  │
│     │  Token JWT              │                          │                  │
│     │◀────────────────────────│                          │                  │
│     │                         │                          │                  │
│     │  Salva token            │                          │                  │
│     │─────────────────────────────────────────────────────▶                  │
│     │                         │                          │                  │
│     │  (em requests futuras)  │                          │                  │
│     │  Authorization: Bearer  │                          │                  │
│     │  eyJhbGc...             │                          │                  │
│     │                         │                          │                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Modelo de Dados

### 5.1 - Entidades

#### VoucherCode (Código de Acesso)

| Campo | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| `id` | INTEGER PK | Identificador único | 1 |
| `code` | TEXT UNIQUE | Código de acesso (8 chars) | "AB3CD9F2" |
| `description` | TEXT | Nome do visitante | "João Silva" |
| `definition_name` | TEXT | Definição no Sophos | "30-dias" |
| `validity_days` | INTEGER | Dias de validade | 30 |
| `data_limit_mb` | INTEGER | Limite de dados (0=ilimitado) | 500 |
| `devices_allowed` | INTEGER | Dispositivos por código | 1 |
| `status` | TEXT | Status atual | "active" |
| `created_at` | TIMESTAMP | Data de criação | "2024-08-31T14:30:22Z" |
| `expires_at` | TIMESTAMP | Data de expiração | "2024-09-30T14:30:22Z" |
| `used_at` | TIMESTAMP | Data de primeiro uso | "2024-09-01T10:15:00Z" |
| `used_by` | TEXT | Quem usou (MAC/user) | "AA:BB:CC:DD:EE:FF" |
| `created_by` | TEXT | Operador que criou | "admin" |
| `notes` | TEXT | Observações | "Setor X" |

**Status Possíveis:**
- `active` - Código válido e utilizável
- `expired` - Passou da data de expiração
- `revogado` - Cancelado pelo operador
- `used` - Já foi utilizado no Hotspot

#### VoucherDefinition (Definição)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INTEGER PK | Identificador |
| `name` | TEXT UNIQUE | Nome no Sophos |
| `description` | TEXT | Descrição |
| `validity_days` | INTEGER | Dias de validade |
| `validity_unit` | TEXT | Minutes/Hours/Days |
| `time_quota` | INTEGER | Limite de tempo online |
| `data_volume` | INTEGER | Limite de dados |
| `devices_per_voucher` | INTEGER | Dispositivos |
| `synced_at` | TIMESTAMP | Última sincronização |

#### VoucherAudit (Auditoria)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | INTEGER PK | Identificador |
| `voucher_code_id` | FK | Referência ao código |
| `action` | TEXT | CREATE/REVOKE/USE/SYNC |
| `details` | TEXT | Detalhes da ação |
| `performed_by` | TEXT | Operador |
| `performed_at` | TIMESTAMP | Data |

---

## 6. API Reference

### 6.1 - Autenticação

#### POST `/api/v1/auth/login`

**Request:**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 28800,
  "username": "admin",
  "role": "admin"
}
```

**Error (401):**
```json
{
  "detail": "Credenciais inválidas. Verifique username e senha."
}
```

### 6.2 - Geração de Voucher

#### POST `/api/v1/vouchers/generate`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request:**
```json
{
  "quantity": 1,
  "definition_name": "30-dias",
  "validity_days": 30,
  "data_limit_mb": 500,
  "devices_allowed": 1,
  "visitor_name": "João Silva",
  "notes": "Visitante do setor X"
}
```

**Response (200):**
```json
{
  "id": 1,
  "code": "AB3CD9F2",
  "description": "João Silva",
  "definition_name": "30-dias",
  "validity_days": 30,
  "data_limit_mb": 500,
  "devices_allowed": 1,
  "status": "active",
  "created_at": "2024-08-31T14:30:22.123456Z",
  "expires_at": "2024-09-30T14:30:22.123456Z",
  "created_by": "admin"
}
```

### 6.3 - Listar Vouchers

#### GET `/api/v1/vouchers/list?status=active&limit=50&offset=0`

**Response (200):**
```json
{
  "total": 150,
  "limit": 50,
  "offset": 0,
  "vouchers": [
    {
      "id": 1,
      "code": "AB3CD9F2",
      "status": "active",
      "...": "..."
    }
  ]
}
```

### 6.4 - Revogar Voucher

#### POST `/api/v1/vouchers/revoke`

**Request:**
```json
{
  "code": "AB3CD9F2"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Voucher AB3CD9F2 revogado com sucesso"
}
```

### 6.5 - Estatísticas

#### GET `/api/v1/vouchers/stats/summary`

**Response (200):**
```json
{
  "total": 500,
  "active": 120,
  "expired": 250,
  "revoked": 30,
  "used": 100,
  "by_status": {
    "active": 120,
    "expired": 250,
    "revoked": 30,
    "used": 100
  }
}
```

---

## 7. Segurança

### 7.1 - Autenticação e Autorização

```
┌──────────────────────────────────────────────────────────────┐
│                    CAMADAS DE SEGURANÇA                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. HTTPS (Transporte)                                      │
│     └─ Comunicação criptografada entre app e middleware      │
│                                                              │
│  2. JWT (Autenticação)                                      │
│     └─ Tokens com expiração de 8 horas (configurável)        │
│     └─ Assinatura HS256 com chave secreta                    │
│                                                              │
│  3. ACL de IP (Rede)                                        │
│     └─ Apenas IPs autorizados acessam a API                  │
│                                                              │
│  4. Armazenamento Seguro (Mobile)                           │
│     └─ Token salvo no Keychain/KeyStore                      │
│                                                              │
│  5. Hash de Senhas (Backend)                                │
│     └─ bcrypt para senhas de operadores                      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.2 - Boas Práticas

| Prática | Implementação |
|---------|---------------|
| **Rotação de Senhas** | Alterar senhas de operadores periodicamente |
| **Expiração de Token** | Tokens JWT expiram em 8 horas |
| **ACL de IP** | Restringir acesso à API por IP |
| **Auditoria** | Todas as ações são registradas |
| **Revogação** | Códigos podem ser cancelados a qualquer momento |
| **HTTPS** | Comunicação sempre criptografada |
| **Validação** | Dados validados com Pydantic |

### 7.3 - Variáveis de Ambiente Sensíveis

```env
# PRODUÇÃO: Alterar estes valores!
JWT_SECRET_KEY=use-uma-chave-de-32-caracteres-minimo
SOPHOS_PASSWORD=senha-forte-aqui
```

---

## 8. Implantação

### 8.1 - Requisitos

| Componente | Requisito |
|------------|-----------|
| **OS** | Linux (recomendado), Windows, macOS |
| **Python** | 3.11+ |
| **Redis** | Não necessário (usa SQLite) |
| **Espaço** | ~50MB para o backend |
| **Rede** | Acesso à rede do Sophos Firewall |

### 8.2 - Instalação

```bash
# 1. Clonar repositório
git clone https://github.com/rodrigo-reolon/firewall-voucher.git
cd firewall-voucher/backend

# 2. Criar ambiente virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 3. Instalar dependências
pip install -r requirements.txt

# 4. Configurar ambiente
cp .env.example .env
nano .env  # Editar valores

# 5. Executar
python run.py
```

### 8.3 - Produção

```bash
# Usando Gunicorn com Uvicorn workers
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### 8.4 - Docker (Opcional)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "run.py"]
```

### 8.5 - Configuração no Sophos

1. Criar Definição de Voucher: `Wireless > Hotspot voucher definition`
2. Configurar Hotspot: `Wireless > Hotspots` → Type: Voucher
3. Criar grupo `HotspotVoucherManager` com permissões restritas
4. Liberar IP do middleware na ACL

---

## 9. Troubleshooting

### Problemas Comuns

| Problema | Causa | Solução |
|----------|-------|---------|
| **401 Unauthorized** | Token expirado ou inválido | Fazer login novamente |
| **403 Forbidden** | IP não autorizado | Verificar ACL no Sophos |
| **Código duplicado** | Colisão aleatória | Sistema tenta novamente automaticamente |
| **Timeout** | Rede lenta ou firewall | Verificar conectividade |
| **SSL Error** | Certificado autoassinado | `SOPHOS_VERIFY_SSL=false` |

### Logs do Sistema

```bash
# Backend logs (tempo real)
tail -f backend/vouchers.db  # Banco de dados
# Logs são exibidos no console do Uvicorn
```

### Comandos Úteis

```bash
# Verificar se API está rodando
curl http://localhost:8000/api/v1/health

# Testar geração de voucher
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Listar vouchers
curl http://localhost:8000/api/v1/vouchers/list \
  -H "Authorization: Bearer <token>"
```

---

## 10. Roadmap Futuro

- [ ] Sincronização automática com Sophos via API XML
- [ ] Exportação de vouchers em PDF
- [ ] Envio de vouchers por email
- [ ] Dashboard web (admin)
- [ ] Integração com LDAP/AD
- [ ] Suporte a múltiplos Sophos Firewalls
- [ ] API para integração com sistemas externos (EMR, etc.)
- [ ] Notificações push quando voucher está para expirar
- [ ] Relatórios avançados (CSV, PDF)
- [ ] Agendamento de geração automática

---

**Documentação atualizada em:** Agosto 2026
**Versão do Sistema:** 1.0.0
