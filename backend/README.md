# Backend - Firewall Voucher Middleware

API REST em FastAPI para gerenciamento de códigos de voucher do Hotspot Sophos.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Execução](#execução)
- [Endpoints](#endpoints)
- [Banco de Dados](#banco-de-dados)
- [Segurança](#segurança)
- [Testes](#testes)

---

## Visão Geral

O middleware é responsável por:

1. **Gerar códigos** no formato Sophos (8 caracteres alfanuméricos)
2. **Armazenar em SQLite** para controle e auditoria
3. **Expor API REST** para o app mobile
4. **Autenticar operadores** via JWT
5. **Gerenciar ciclo de vida** dos vouchers

### Stack Tecnológico

| Tecnologia | Versão | Propósito |
|------------|--------|-----------|
| Python | 3.11+ | Runtime |
| FastAPI | 0.115.0 | Framework web |
| Uvicorn | 0.30.6 | Servidor ASGI |
| SQLite3 | built-in | Banco de dados |
| Pydantic | 2.9.2 | Validação |
| python-jose | 3.3.0 | JWT |
| passlib | 1.7.4 | Hash bcrypt |

---

## Instalação

### Pré-requisitos

- Python 3.11 ou superior
- pip (gerenciador de pacotes)
- Git

### Passo a Passo

```bash
# 1. Clonar o repositório (se ainda não fez)
git clone https://github.com/rodrigo-relon/firewall-voucher.git
cd firewall-voucher/backend

# 2. Criar ambiente virtual
python -m venv venv

# 3. Ativar ambiente virtual
# Linux/Mac:
source venv/bin/activate
# Windows:
venv\Scripts\activate

# 4. Instalar dependências
pip install -r requirements.txt

# 5. Verificar instalação
python -c "import fastapi; print(fastapi.__version__)"
```

---

## Configuração

### Variáveis de Ambiente

Copie o template e ajuste:

```bash
cp .env.example .env
```

Edite o `.env`:

```env
# ===========================================
# CONFIGURAÇÃO DO BACKEND
# ===========================================

# Aplicação
APP_NAME=Firewall Voucher Middleware - Hotspot
APP_VERSION=1.0.0
DEBUG=true
API_PREFIX=/api/v1
HOST=0.0.0.0
PORT=8000

# ===========================================
# JWT - ALTERAR EM PRODUÇÃO!
# ===========================================
JWT_SECRET_KEY=sua-chave-secreta-de-32-caracteres-minimo-aqui
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=480

# ===========================================
# CONTROLE DE ACESSO
# ===========================================
ALLOWED_IPS=127.0.0.1,192.168.130.0/24
```

### Operadores Padrão

Os operadores são definidos em `app/config.py`:

```python
DEFAULT_OPERATORS = [
    {"username": "admin", "password": "admin123", "role": "admin"},
]
```

⚠️ **Em produção**, altere estas valores ou implemente autenticação via banco de dados/LDAP.

---

## Execução

### Desenvolvimento

```bash
# Com reload automático
python run.py

# Ou diretamente com uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Produção

```bash
# Com gunicorn (recomendado)
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

# Variável de ambiente para produção
export DEBUG=false
```

### Verificação

Após iniciar, acesse:
- **API**: http://localhost:8000
- **Documentação Swagger**: http://localhost:8000/docs
- **Documentação ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/api/v1/health

---

## Endpoints

### Autenticação

#### POST `/api/v1/auth/login`

Realiza login e retorna token JWT.

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
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 28800,
  "username": "admin",
  "role": "admin"
}
```

**Uso:** Incluir header `Authorization: Bearer <token>` em requisições protegidas.

---

#### GET `/api/v1/auth/me`

Retorna dados do operador autenticado.

**Response (200):**
```json
{
  "username": "admin",
  "role": "admin",
  "permissions": ["voucher:generate", "voucher:list", "voucher:revoke"]
}
```

---

### Vouchers

#### POST `/api/v1/vouchers/generate`

Gera um novo código de voucher.

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
  "created_at": "2024-08-31T14:30:22Z",
  "expires_at": "2024-09-30T14:30:22Z",
  "created_by": "admin"
}
```

---

#### POST `/api/v1/vouchers/generate-batch`

Gera múltiplos códigos de uma vez (1-100).

**Request:**
```json
{
  "quantity": 10,
  "validity_days": 7,
  "visitor_name": "Evento"
}
```

**Response (200):**
```json
[
  {
    "id": 2,
    "code": "CD4EF5G6",
    ...
  },
  {
    "id": 3,
    "code": "HI7JK8L9",
    ...
  }
]
```

---

#### GET `/api/v1/vouchers/list`

Lista vouchers com filtros.

**Query Params:**
| Parâmetro | Tipo | Default | Descrição |
|-----------|------|---------|-----------|
| `status_filter` | string | null | active/expired/revoked/used |
| `limit` | int | 50 | Limite de resultados |
| `offset` | int | 0 | Offset para paginação |

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
      "description": "João Silva",
      "status": "active",
      "...": "..."
    }
  ]
}
```

---

#### GET `/api/v1/vouchers/{code}`

Busca um voucher específico.

**Response (200):**
```json
{
  "id": 1,
  "code": "AB3CD9F2",
  "status": "active",
  "...": "..."
}
```

---

#### POST `/api/v1/vouchers/revoke`

Revoga um voucher (cancela acesso).

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

---

#### GET `/api/v1/vouchers/{code}/audit`

Retorna log de auditoria de um voucher.

**Response (200):**
```json
[
  {
    "id": 1,
    "action": "CREATE",
    "details": "Voucher criado com validade de 30 dias",
    "performed_by": "admin",
    "performed_at": "2024-08-31T14:30:22Z"
  }
]
```

---

#### GET `/api/v1/vouchers/stats/summary`

Retorna estatísticas gerais.

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

### Health Check

#### GET `/api/v1/health`

Verifica status da API.

**Response (200):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "sophos_connection": "local_mode",
  "timestamp": "2024-08-31T14:30:22Z"
}
```

---

## Banco de Dados

### Estrutura

O banco SQLite é criado automaticamente na primeira execução:

```
backend/vouchers.db
```

### Tabelas

#### voucher_codes

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | INTEGER PK | Auto-incremento |
| code | TEXT UNIQUE | Código (ex: AB3CD9F2) |
| description | TEXT | Nome do visitante |
| definition_name | TEXT | Definição no Sophos |
| validity_days | INTEGER | Dias de validade |
| data_limit_mb | INTEGER | Limite de dados |
| devices_allowed | INTEGER | Dispositivos |
| status | TEXT | active/expired/revoked/used |
| created_at | TIMESTAMP | Criação |
| expires_at | TIMESTAMP | Expiração |
| used_at | TIMESTAMP | Primeiro uso |
| created_by | TEXT | Operador |
| notes | TEXT | Observações |

#### voucher_definitions

Definições sincronizadas com Sophos (para referência).

#### voucher_audit

Log de todas as operações realizadas.

### Backup

```bash
# Backup simples (cópia do arquivo)
cp vouchers.db vouchers.backup.$(date +%Y%m%d).db

# Via SQLite CLI
sqlite3 vouchers.db ".backup vouchers.backup.db"
```

---

## Segurança

### Autenticação JWT

- **Algoritmo**: HS256
- **Expiração**: 480 minutos (8 horas)
- **Secret**: Definido em JWT_SECRET_KEY

### Controle de IP

A variável `ALLOWED_IPS` restringe acesso:

```env
ALLOWED_IPS=127.0.0.1,192.168.130.50,10.0.0.0/24
```

⚠️ **Nota**: A validação de IP não está implementada no código atual. Para produção, adicione middleware de IP ou use firewall externo.

### Senhas

Senhas de operadores são hasheadas com bcrypt:

```python
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
hash = pwd_context.hash("senha")
```

### Recomendações para Produção

1. **Alterar JWT_SECRET_KEY** para uma chave forte
2. **Desativar DEBUG** (`DEBUG=false`)
3. **Restringir ALLOWED_IPS**
4. **Usar HTTPS** (proxy reverso com nginx)
5. **Implementar rate limiting**
6. **Configurar logs para SIEM**
7. **Backup periódico do SQLite**

---

## Testes

### Instalar dependências de teste

```bash
pip install pytest pytest-asyncio httpx
```

### Executar testes

```bash
# Todos os testes
pytest tests/ -v

# Com coverage
pytest tests/ --cov=app --cov-report=html
```

### Estrutura de Testes

```
tests/
├── conftest.py          # Fixtures
├── test_auth.py         # Testes de autenticação
├── test_vouchers.py     # Testes de vouchers
└── test_health.py       # Testes de health check
```

---

## Troubleshooting

### API não inicia

```bash
# Verificar porta em uso
netstat -ano | findstr :8000  # Windows
lsof -i :8000                 # Linux/Mac

# Alterar porta
PORT=9000 python run.py
```

### Banco de dados corrompido

```bash
# Remover e recriar (ATENÇÃO: perde dados)
rm vouchers.db
python run.py  # Recria automaticamente
```

### Erro de dependências

```bash
pip install --upgrade -r requirements.txt
```

---

## Estrutura do Projeto

```
backend/
├── app/
│   ├── auth/
│   │   └── jwt_handler.py          # JWT + bcrypt
│   ├── models/
│   │   └── schemas.py              # Pydantic models
│   ├── routers/
│   │   ├── auth_router.py          # /auth endpoints
│   │   └── voucher_router.py       # /vouchers endpoints
│   ├── services/
│   │   └── voucher_service.py      # Lógica de negócio
│   ├── config.py                   # Settings
│   └── main.py                     # FastAPI app
├── .env                            # Configurações (não commit)
├── .env.example                    # Template
├── requirements.txt                # Dependências
├── run.py                          # Entry point
└── vouchers.db                     # SQLite (gerado)
```

---

**Versão:** 1.0.0 | **Última atualização:** Agosto 2026
