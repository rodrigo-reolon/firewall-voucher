# 📱 Guest WiFi Voucher

Aplicativo para gerar vouchers de acesso ao **Guest WiFi** conectando diretamente ao **Sophos Firewall**.

---

## 🚀 Início Rápido

### 1. Configurar a senha (opcional)

Edite o arquivo `mobile/lib/config.dart`:

```dart
static const String password = 'SUA_SENHA_AQUI'; // Deixe vazio para pedir no app
```

Se preencher a senha, o app conecta automaticamente sem pedir ao usuário.

### 2. Buildar o APK

```bash
cd mobile
flutter pub get
flutter build apk --release
```

O APK estará em: `build/app/outputs/flutter-apk/app-release.apk`

### 3. Instalar no celular

Instale o APK e abra o app. Se a senha não foi configurada no código, ela será solicitada na primeira execução.

---

## 📱 Fluxo do App

```
1. TELA DE CONEXÃO
   - Mostra: Rede "Reolon Visitantes"
   - Mostrar: Portal firewall.reolon.local:4436
   - Mostrar: Usuário hostspot
   - Pedir:  Senha do hotspot
   
2. TELA PRINCIPAL (3 abas)
   - Gerar:   Seleciona definição, quantidade, gera vouchers
   - Vouchers: Lista com copiar/compartilhar/revogar
   - Status:   Info da conexão
```

---

## ⚙️ Configurações

Todas as configurações estão em `mobile/lib/config.dart`:

| Campo | Valor | Descrição |
|-------|-------|-----------|
| `portalUrl` | `https://firewall.reolon.local:4436` | URL do portal |
| `username` | `hostspot` | Usuário admin |
| `password | `''` (vazio) | Senha (vazia = pedir no app) |
| `ssid` | `Reolon Visitantes` | Nome da rede |
| `verifySsl` | `false` | Ignora SSL autoassinado |

---

## 📋 Pré-requisitos no Sophos

Configuração única no firewall:

```
1. Wireless > Hotspot voucher definition
   - Criar definição (ex: "30-dias-500mb")
   - Validade: 30 days
   - Data volume: 500 MB

2. Wireless > Hotspots
   - Type: Voucher
   - Administrative users: hostspot
```

---

## 🔐 Segurança

- Senha pode ser embutida no código (para facilitar) ou pedida no app
- Conexão HTTPS (ignora SSL autoassinado do Sophos)
- Sem servidor intermediário — direto ao firewall

---

## ❓ FAQ

**A senha fica exposta?**
Se você preencher no `config.dart`, sim, estará no código. Para mais segurança, deixe vazio e peça ao usuário.

**Funciona fora da rede?**
Não — precisa estar na mesma rede que o Sophos (ou com VPN).

**Posso usar outro SIM card para internet?**
Sim, desde que o celular consiga acessar o firewall na rede local.

---

**Versão:** 1.0.0 | **Uso:** Residencial
