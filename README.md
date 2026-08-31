# 🔥 Firewall Voucher Hotspot

Sistema completo para **geração e gerenciamento de códigos de voucher** do Hotspot Sophos Firewall, substituindo o processo manual pelo App Mobile.

## ✨ Por que este sistema?

| ❌ Processo Manual (Antes) | ✅ Com o Sistema |
|-----------------------------|------------------|
| Acessar User Portal (porta 223) | Abrir o App Mobile |
| Login com admin | Login rápido com JWT |
| Navegar menus | Um toque para gerar |
| Copiar códigos manualmente | Copiar/WhatsApp automático |
| Sem registro de quem gerou | Auditoria completa |
| Difícil de revogar | Revogação instantânea |

---

## 📚 Documentação

| Documento | Descrição |
|-----------|-----------|
| **[Arquitetura](docs/ARCHITECTURE.md)** | Documento completo do sistema |
| **[Configuração Sophos](docs/SOPHOS_CONFIG.md)** | Guia passo a passo no firewall |
| **[Backend](backend/README.md)** | Documentação da API |
| **[Mobile](mobile/README.md)** | Documentação do app |

---

## 🏗️ Arquitetura Resumida

```
App Mobile (Flutter) ──REST API──▶ Middleware (FastAPI) ──SQLite──▶ Banco de dados
                                         │
                                         └── Sophos Firewall (porta 223)
```

---

## 🚀 Início Rápido

### 1. Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env && nano .env  # Configure
python run.py
```

API disponível em: http://localhost:8000/docs

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

### 3. Sophos (Configuração única)

1. Criar definição: `Wireless > Hotspot voucher definition`
2. Configurar Hotspot: `Wireless > Hotspots` → Type: **Voucher**
3. Liberar IP do middleware na ACL

---

## 📱 Funcionalidades do App

- ✅ **Gerar códigos** — individual ou em lote (1-100)
- ✅ **Períodos** — 1, 7, 15, 30, 90 dias
- ✅ **Limite de dados** — ilimitado, 100MB, 500MB, 1GB, 5GB
- ✅ **Multi-dispositivo** — 1-5 dispositivos por código
- ✅ **Copiar** — código para clipboard
- ✅ **WhatsApp** — mensagem formatada pronta
- ✅ **QR Code** — para acesso rápido
- ✅ **Revogar** — cancelar código a qualquer momento
- ✅ **Estatísticas** — dashboard com status
- ✅ **Auditoria** — registro de todas as ações

---

## 🔐 Segurança

- **JWT** — Tokens com expiração (8h)
- **HTTPS** — Comunicação criptografada
- **ACL de IP** — Apenas IPs autorizados
- **Armazenamento seguro** — Keychain/KeyStore no mobile
- **Auditoria** — Log de todas as operações

---

## 📊 Formato dos Códigos

Os códigos são gerados no formato compatível com Sophos Hotspot:

```
Formato: XXXXXXXX (8 caracteres)
Alfabeto: ABCDEFGHJKLMNPQRSTUVWXYZ23456789
Exemplo: AB3CD9F2

Nota: Sem caracteres ambíguos (0/O, 1/I)
```

---

## 🛠️ Tecnologias

| Camada | Tecnologia |
|--------|------------|
| **Backend** | Python, FastAPI, SQLite |
| **Mobile** | Flutter, Dart |
| **Auth** | JWT, bcrypt |
| **Dados** | SQLite, Pydantic |

---

## 📄 Licença

Uso interno — SEDUC-PI

---

**Desenvolvido por:** Rodrigo Reolon
**Contato:** digomagali@gmail.com
