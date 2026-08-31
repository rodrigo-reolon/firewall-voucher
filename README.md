# Firewall Voucher System

Sistema completo para geração e extração de códigos de acesso de visitantes (vouchers) no Sophos Firewall, composto por uma API intermediária (Middleware) e um Aplicativo Mobile.

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
│                                                   │ HTTPS/XML        │
│                                                   │                 │
│                                          ┌────────▼─────────┐      │
│                                          │  SOPHOS FIREWALL │      │
│                                          │  (SFOS XML API)  │      │
│                                          │  Porta 4444      │      │
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
│   │   ├── services/          # Serviço Sophos XML
│   │   │   └── sophos_service.py
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
- Sophos Firewall com API XML habilitada
- Rede com acesso ao firewall

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
| POST | `/api/v1/vouchers/generate` | Sim | Gerar voucher |
| GET | `/api/v1/vouchers/list` | Sim | Listar vouchers |
| DELETE | `/api/v1/vouchers/revoke/{username}` | Sim | Revogar voucher |
| GET | `/api/v1/health` | Não | Health check |

### Exemplo: Gerar Voucher

```bash
curl -X POST http://localhost:8000/api/v1/vouchers/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SEU_TOKEN_JWT" \
  -d '{
    "visitor_name": "João Silva",
    "validity_hours": 8,
    "data_quota_mb": 500,
    "access_profile": "Guest"
  }'
```

**Resposta:**
```json
{
  "username": "guest_20240831143022",
  "password": "xK9mP2nQ7rT4",
  "expires_at": "2024-08-31T22:30:22Z",
  "validity_hours": 8,
  "visitor_name": "João Silva",
  "access_profile": "Guest",
  "status": "active",
  "created_at": "2024-08-31T14:30:22Z",
  "qr_code_data": "REDE: Guest-WiFi\nUSUÁRIO: guest_20240831143022\n..."
}
```

## 🔐 Segurança

- **Autenticação JWT** com tokens de expiração configurável
- **HTTPS** para comunicação com o Sophos (XML API)
- **Controle de acesso por IP** no middleware
- **Certificado SSL** autoassinado configurável para ambiente de desenvolvimento
- **Privilégios mínimos** - conta de serviço dedicada no Sophos
- **ACL no Sophos** - apenas IPs autorizados acessam a API

## ⚙️ Configuração do Sophos

Veja o guia completo em [`docs/SOPHOS_CONFIG.md`](docs/SOPHOS_CONFIG.md)

Resumo rápido:
1. Habilitar API XML: **Backup & Firmware > API**
2. Criar grupo `VoucherManager` com permissões restritas
3. Criar usuário `svc_voucher` no grupo
4. Liberar IP do middleware na ACL

## 📱 Funcionalidades do App

- ✅ Login com autenticação JWT
- ✅ Seleção de tempo de validade (1h, 4h, 8h, 24h, 7 dias)
- ✅ Campo opcional para nome do visitante
- ✅ Geração de credenciais (usuário + senha)
- ✅ Cópia de credenciais com um toque
- ✅ Compartilhamento via WhatsApp com mensagem formatada
- ✅ Geração dinâmica de QR Code
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
