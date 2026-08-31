# Firewall Voucher Middleware - Backend (Hotspot)

API intermediária para geração e gerenciamento de códigos de voucher do Hotspot Sophos.

## Estrutura do Projeto

```
backend/
├── app/
│   ├── auth/          # Autenticação JWT
│   ├── models/        # Modelos Pydantic
│   ├── routers/       # Endpoints da API
│   ├── services/      # Serviço de Vouchers (SQLite)
│   ├── config.py      # Configurações
│   └── main.py        # Aplicação FastAPI
├── requirements.txt
└── run.py
```

## Instalação

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

## Configuração

Copie `.env.example` para `.env` e ajuste as variáveis:

```bash
cp .env.example .env
```

## Execução

```bash
python run.py
# ou
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/api/v1/auth/login` | Login do operador |
| GET | `/api/v1/auth/me` | Dados do operador |
| POST | `/api/v1/vouchers/generate` | Gerar código voucher |
| POST | `/api/v1/vouchers/generate-batch` | Gerar múltiplos |
| GET | `/api/v1/vouchers/list` | Listar vouchers |
| GET | `/api/v1/vouchers/{code}` | Buscar voucher |
| POST | `/api/v1/vouchers/revoke` | Revogar voucher |
| GET | `/api/v1/vouchers/{code}/audit` | Auditoria |
| GET | `/api/v1/vouchers/stats/summary` | Estatísticas |
| GET | `/api/v1/health` | Health check |
