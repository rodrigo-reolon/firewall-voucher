# 📱 Guest WiFi Voucher

Aplicativo **simples e direto** para gerar códigos de acesso ao Guest WiFi (Hotspot Sophos).

---

## ⚡ Por que simples?

**Sem servidor. Sem middleware. Sem complicação.**

O app gera códigos únicos localmente e salva no celular. Você compartilha com visitantes via WhatsApp ou QR Code. Pronto.

---

## 🚀 Como Usar

### 1. Instale o APK no celular

```bash
cd mobile
flutter pub get
flutter build apk --release
```

O APK estará em: `build/app/outputs/flutter-apk/app-release.apk`

### 2. Abra o app

Na primeira execução, configure:
- IP do Sophos (opcional, para referência)
- SSID da rede Guest WiFi

### 3. Gere e compartilhe

```
1. Abra o app
2. Selecione validade (1, 7, 15, 30, 90 dias)
3. Opcional: nome do visitante, limite de dados
4. Clique "Gerar Código"
5. Copie ou envie via WhatsApp
```

---

## 📱 Funcionalidades

| Função | Descrição |
|--------|-----------|
| **Gerar** | Cria código único de 8 caracteres (ex: AB3CD9F2) |
| **Copiar** | Um toque para copiar o código |
| **WhatsApp** | Mensagem formatada pronta para enviar |
| **QR Code** | Escaneie e acesse direto |
| **Histórico** | Lista todos os códigos gerados |
| **Revogar** | Cancele um código a qualquer momento |
| **Estatísticas** | Total, ativos, expirados, revogados |

---

## 🎯 Formato dos Códigos

```
Formato: XXXXXXXX (8 caracteres)
Alfabeto: ABCDEFGHJKLMNPQRSTUVWXYZ23456789
Exemplo: AB3CD9F2

- Sem caracteres ambíguos (0/O, 1/I)
- Compatível com Sophos Hotspot
- Geração segura com Random.secure()
```

---

## 🔧 Configuração no Sophos (Uma Vez)

1. **Criar Definição de Voucher**: `Wireless > Hotspot voucher definition`
   - Nome: `guest-30-dias`
   - Validade: 30 dias

2. **Criar Hotspot**: `Wireless > Hotspots`
   - Type: `Voucher`
   - Voucher Definitions: `guest-30-dias`

3. **Configurar Captive Portal**: Portal customizado (opcional)

4. **Pronto!** Use os códigos gerados pelo app

---

## 📊 Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                     CELULAR (App Flutter)                   │
│                                                              │
│   ┌─────────────┐    ┌─────────────────────────────────┐   │
│   │   Tela UI   │───▶│  LocalVoucherService            │   │
│   │             │    │  - Gera código único (8 chars)  │   │
│   │  Gerar      │    │  - Salva no SharedPreferences   │   │
│   │  Listar     │    │  - Controla status/revogação    │   │
│   │  Compartilhar│   │                                 │   │
│   └─────────────┘    └─────────────────────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                 SOPHOS FIREWALL (Na sua rede)                │
│                                                              │
│   ┌────────────────────────────────────────────────────┐    │
│   │  Hotspot + Voucher (Porta 223)                    │    │
│   │  - Aceita os códigos gerados pelo app             │    │
│   │  - Controla expiração automaticamente             │    │
│   └────────────────────────────────────────────────────┘    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Segurança

- Códigos com 8 caracteres = 2,8 trilhões de combinações
- Geração criptograficamente segura (`Random.secure()`)
- Sem caracteres ambíguos para evitar erros de digitação
- Armazenamento local seguro (SharedPreferences)

---

## 📦 Tecnologias

| Camada | Tecnologia |
|--------|------------|
| **App** | Flutter + Dart |
| **Dados** | SharedPreferences (local) |
| **QR Code** | qr_flutter |
| **WhatsApp** | share_plus |

---

## 🎯 Para que serve?

- ✅ Residências com visitas
- ✅ Pequenos escritórios
- ✅ Consultórios
- ✅ Qualquer lugar com Sophos Hotspot

---

## ❓ FAQ

**Precisa de internet para gerar os códigos?**
Não! O app funciona 100% offline. Os códigos são gerados localmente.

**Os códigos funcionam no Sophos?**
Sim! Desde que você tenha criado a definição de voucher e o hotspot correspondente no firewall.

**Posso gerar vários códigos de uma vez?**
Sim, até 100 códigos por vez.

**O que acontece quando o código expira?**
O próprio Sophos bloqueia o acesso após a data de expiração.

**Posso revogar um código?**
Sim, pelo app. Mas note que a revogação é local — o código continua válido no Sophos até expirar. Para bloqueio imediato, remova o voucher no Sophos.

---

## 📄 Licença

Uso pessoal — Projeto para simplificar o acesso de visitantes à rede Guest WiFi.
