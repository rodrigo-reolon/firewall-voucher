# Firewall Voucher System - Hotspot

Sistema completo para geração e gerenciamento de códigos de voucher do Hotspot no Sophos Firewall, composto por uma API intermediária (Middleware) e um Aplicativo Mobile Flutter.

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ARQUITETURA DO SISTEMA                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐         HTTPS          ┌──────────────────┐      │
│  │   MOBILE APP │ ──────────────────────▶│    MIDDLEWARE    │      │
│  │   (Flutter)  │    REST API (JSON)     │   (FastAPI)      │      │
│  │              │◀────────────────────── │   Python 3.11+   │      │
│  └──────────────┘                        └────────┬─────────┘      │
│                                                   │                 │
│                                                   │ HTTPS            │
│                                                   │                 │
│                                          ┌────────▼─────────┐      │
│                                          │  SOPHOS FIREWALL │      │
│                                          │  Hotspot Portal  │      │
│                                          │  Porta 223       │      │
│                                          └──────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 📁 Estrutura do Projeto

```
firewall-voucher/
├── backend/                    # API Middleware (FastAPI)
│   ├── app/
│   │   ├── auth/              # Autenticação JWT
│   │   │   └── jwt_handler.py
│   │   ├── models/            # Modelos Pydantic
│   │   │   └── schemas.py
│   │   ├── routers/           # Endpoints da API
│   │   │   ├── auth_router.py
│   │   │   └── voucher_router.py
│   │   ├── services/          # Serviço de Vouchers
│   │   │   └── voucher_service.py
│   │   ├── config.py          # Configurações
│   │   └── main.py            # App FastAPI
│   ├── .env.example           # Template de configuração
│   ├── requirements.txt
│   └── run.py
│
├── mobile/                     # Aplicativo Flutter
│   ├── lib/
│   │   ├── main.dart          # App principal
│   │   ├── models/            # Modelos de dados
│   │   │   └── voucher.dart
│   │   ├── services/          # Comunicação API
│   │   │   ├── auth_service.dart
│   │   │   └── api_service.dart
│   │   └── screens/           # Telas do app
│   │       ├── login_screen.dart
│   │       └── home_screen.dart
│   └── pubspec.yaml
│
└── docs/
    └── SOPHOS_CONFIG.md       # Guia de configuração SFOS
```

## 🚀 Início Rápido

### Pré-requisitos

- Python 3.11+
- Flutter 3.16+
- Sophos Firewall com Hotspot configurado

### Backend

```bash
cd backend

# Criar ambiente virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Instalar dependências
pip install -r requirements.txt

# Configurar variáveis de ambiente
cp .env.example .env
# Edite .env com seus dados

# Executar servidor
python run.py
# ou
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

A API estará disponível em: http://localhost:8000
Documentação Swagger: http://localhost:8000/docs

### Mobile

```bash
cd mobile

# Instalar dependências
flutter pub get

# Executar (emulador ou dispositivo)
flutter run

# Gerar APK
flutter build apk --release
```

## 📡 Endpoints da API

| Método | Endpoint | Auth | Descrição |
|--------|----------|------|-----------|
| POST | `/api/v1/auth/login` | Não | Login do operador |
| GET | `/api/v1/auth/me` | Sim | Dados do operador |
| POST | `/api/v1/vouchers/generate` | Sim | Gerar código voucher |
| POST | `/api/v1/vouchers/generate-batch` | Sim | Gerar múltiplos códigos |
| GET | `/api/v1/vouchers/list` | Sim | Listar vouchers |
| GET | `/api/v1/vouchers/{code}` | Sim | Buscar voucher |
| POST | `/api/v1/vouchers/revoke` | Sim | Revogar voucher |
| GET | `/api/v1/vouchers/{code}/audit` | Sim | Log de auditoria |
| GET | `/api/v1/vouchers/stats/summary` | Sim | Estatísticas |
| GET | `/api/v1/health` | Não | Health check |

### Exemplo: Gerar Voucher

```bash
curl -X POST http://localhost:8000/api/v1/vouchers/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SEU_TOKEN_JWT" \
  -d '{
    "quantity": 1,
    "validity_days": 30,
    "data_limit_mb": 500,
    "devices_allowed": 1,
    "visitor_name": "João Silva"
  }'
```

**Resposta:**
```json
{
  "id": 1,
  "code": "AB3CD9F2",
  "description": "João Silva",
  "validity_days": 30,
  "data_limit_mb": 500,
  "devices_allowed": 1,
  "status": "active",
  "created_at": "2024-08-31T14:30:22Z",
  "expires_at": "2024-09-30T14:30:22Z",
  "created_by": "admin"
}
```

## 🔐 Segurança

- **Autenticação JWT** com tokens de expiração configurável
- **Controle de acesso por IP** no middleware
- **Auditoria completa** de todas as operações
- **Códigos únicos** com verificação de duplicidade
- **Revogação** de vouchers comprometidos

## ⚙️ Configuração do Sophos

Veja o guia completo em [`docs/SOPHOS_CONFIG.md`](docs/SOPHOS_CONFIG.md)

Resumo rápido:
1. Criar Definição de Voucher: `Wireless > Hotspot voucher definition`
2. Configurar Hotspot: `Wireless > Hotspots` (Type: Voucher)
3. Criar grupo `HotspotVoucherManager` com permissões restritas
4. Criar usuário `svc_hotspot_voucher` no grupo
5. Liberar IP do middleware na ACL

## 📱 Funcionalidades do App

- ✅ Login com autenticação JWT
- ✅ Geração de códigos individuais ou em lote
- ✅ Seleção de período de validade (1, 7, 15, 30, 90 dias)
- ✅ Limite de dados configurável
- ✅ Múltiplos dispositivos por código
- ✅ Cópia de código com um toque
- ✅ Compartilhamento via WhatsApp com mensagem formatada
- ✅ Geração dinâmica de QR Code
- ✅ Listagem de vouchers com status
- ✅ Revogação de vouchers
- ✅ Estatísticas em tempo real
- ✅ Interface moderna e responsiva (Material 3)

## 🧪 Testes

### Backend

```bash
cd backend
pip install pytest pytest-asyncio httpx
pytest tests/
```

### Mobile

```bash
cd mobile
flutter test
```

## 📄 Licença

Uso interno - Projeto para automação de gestão de vouchers de acesso.

---

**Desenvolvido para SEDUC-PI** | Engenharia de Software & Segurança da Informação
