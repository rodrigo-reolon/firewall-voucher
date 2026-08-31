# 📱 Guest WiFi Voucher

Aplicativo para gerar vouchers de acesso ao **Guest WiFi** conectando diretamente ao **Sophos Firewall** (User Portal, porta 223).

---

## 🚀 Como Funciona

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUXO DO SISTEMA                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. App conecta ao User Portal do Sophos (HTTPS)               │
│  2. Login com credenciais de administrador do hotspot          │
│  3. Seleciona Hotspot + Definição (ex: 30 dias, 500MB)        │
│  4. Clica "Gerar Vouchers"                                     │
│  5. Sophos cria os códigos VÁLIDOS no banco interno            │
│  6. App exibe códigos para copiar/compartilhar                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Vantagens

- **Sem servidor** — conexão direta ao Sophos
- **Códigos válidos** — gerados pelo próprio firewall
- **Formato correto** — aceito pelo Captive Portal
- **WhatsApp** — compartilha com um toque
- **QR Code** — visitante escaneia e acessa
- **Revogação** — cancela acesso quando quiser
- **Uso residencial** — simples e direto

---

## 📋 Configuração Necessária (Uma Vez)

### No Sophos Firewall:

```
1. Criar Definição de Voucher:
   Wireless > Hotspot voucher definition
   Nome: "30-dias-500mb"
   Validade: 30 days
   Data volume: 500 MB

2. Criar/Configurar Hotspot:
   Wireless > Hotspots
   Type: Voucher
   Voucher definitions: "30-dias-500mb"
   Administrative users: (conta para o app)

3. Habilitar User Portal (porta 223):
   Já vem habilitado por padrão
```

---

## 📱 Uso do App

### Primeira vez:
```
1. Abra o app
2. Portal URL: https://<IP_DO_FIREWALL>:223
3. Usuário: (conta admin do hotspot)
4. Senha: (senha do admin)
5. Clique "Conectar"
```

### Gerar vouchers:
```
1. Selecione o Hotspot
2. Selecione a Definição
3. Quantidade (1-50)
4. Descrição (opcional)
5. Clique "Gerar Vouchers"
6. Copie ou envie via WhatsApp
```

---

## 🛡️ Segurança

- Conexão HTTPS ao portal do Sophos
- Senhas salvas no SharedPreferences (criptografado pelo OS)
- Permissão de administrador necessária
- Sem servidor intermediário

---

## 📦 Tecnologias

- **Flutter** — Interface mobile
- **Provider** — Gerenciamento de estado
- **http** — Conexão com portal Sophos
- **qr_flutter** — Geração de QR Code
- **share_plus** — Compartilhamento WhatsApp

---

## 🔧 Build

```bash
cd mobile
flutter pub get
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## ❓ FAQ

**Precisa de servidor?**
Não! O app acessa diretamente o portal do Sophos (porta 223).

**Os códigos são válidos?**
Sim! São gerados pelo próprio Sophos no banco interno, aceitos pelo Captive Portal.

**Posso usar para múltiplos firewalls?**
Sim, basta desconectar e conectar em outro portal.

**Funciona offline?**
Não, precisa de rede para acessar o portal do Sophos.

---

**Versão:** 1.0.0 | **Uso:** Residencial
