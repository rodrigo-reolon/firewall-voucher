# Mobile App - Firewall Voucher Hotspot

Aplicativo Flutter para gerenciamento de códigos de voucher do Hotspot Sophos.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Funcionalidades](#funcionalidades)
- [Estrutura](#estrutura)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Build](#build)
- [Telas](#telas)
- [Serviços](#serviços)
- [Modelos](#modelos)

---

## Visão Geral

O app mobile é a interface principal para os operadores gerenciarem vouchers de acesso ao Hotspot. Ele se comunica com o backend (middleware) via API REST.

### Stack Tecnológico

| Tecnologia | Versão | Propósito |
|------------|--------|-----------|
| Flutter | 3.16+ | Framework mobile |
| Dart | 3.0+ | Linguagem |
| http | 1.2.0 | Requisições HTTP |
| provider | 6.1.1 | Gerenciamento de estado |
| qr_flutter | 4.1.0 | Geração de QR Code |
| share_plus | 7.2.1 | Compartilhamento nativo |
| flutter_secure_storage | 9.0.0 | Armazenamento seguro |
| intl | 0.19.0 | Formatação de datas |

---

## Funcionalidades

### ✅ Implementadas

- [x] Login com autenticação JWT
- [x] Geração de códigos individuais
- [x] Geração em lote (1-100)
- [x] Seleção de período (1, 7, 15, 30, 90 dias)
- [x] Limite de dados configurável
- [x] Múltiplos dispositivos por código
- [x] Cópia de código para clipboard
- [x] Compartilhamento via WhatsApp
- [x] Geração de QR Code
- [x] Listagem de vouchers com status
- [x] Revogação de vouchers
- [x] Estatísticas em tempo real
- [x] Interface Material 3
- [x] Armazenamento seguro de token

### 📝 Futuras

- [ ] Notificações push
- [ ] Modo offline com sincronização
- [ ] Leitura de QR Code para validação
- [ ] Exportação de relatórios
- [ ] Tema escuro automático

---

## Estrutura

```
mobile/
├── lib/
│   ├── main.dart                    # Entry point + AuthWrapper
│   ├── models/
│   │   └── voucher.dart             # Modelos de dados
│   ├── services/
│   │   ├── auth_service.dart        # Autenticação + sessão
│   │   └── api_service.dart         # Comunicação API
│   └── screens/
│       ├── login_screen.dart        # Tela de login
│       └── home_screen.dart         # Tela principal (tabs)
├── pubspec.yaml                     # Dependências
├── android/                         # Config Android
│   └── app/
│       └── src/
│           └── main/
│               └── AndroidManifest.xml
└── ios/                             # Config iOS
    └── Runner/
        └── Info.plist
```

---

## Instalação

### Pré-requisitos

- Flutter 3.16+ instalado
- Dart SDK
- Android Studio / Xcode (para emuladores)
- Git

### Passo a Passo

```bash
# 1. Clonar o repositório (se ainda não fez)
git clone https://github.com/rodrigo-reolon/firewall-voucher.git
cd firewall-voucher/mobile

# 2. Instalar dependências
flutter pub get

# 3. Verificar ambiente
flutter doctor

# 4. Executar (emulador ou dispositivo)
flutter run
```

---

## Configuração

### URL do Backend

Na primeira execução, o app solicita a URL do servidor middleware:

```
Exemplo: http://192.168.130.50:8000
```

Para Android Emulator: `http://10.0.2.2:8000`
Para iOS Simulator: `http://localhost:8000`
Para dispositivo físico: IP do servidor na rede

### Configuração de Rede

#### Android (android/app/src/main/AndroidManifest.xml)

Para permitir HTTP (não-HTTPS) em desenvolvimento:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
</application>
```

#### iOS (ios/Runner/Info.plist)

Para permitir HTTP:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## Build

### Android APK

```bash
flutter build apk --release
```

Saída: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

⚠️ Requer macOS com Xcode.

---

## Telas

### LoginScreen

**Campos:**
- URL do servidor middleware
- Usuário
- Senha

**Ações:**
- Botão "Entrar"
- Loading indicator durante autenticação
- Mensagem de erro se credenciais inválidas

**Fluxo:**
1. Usuário preenche campos
2. Clica "Entrar"
3. AuthService envia POST /auth/login
4. Se sucesso: salva token e vai para HomeScreen
5. Se erro: exibe mensagem

---

### HomeScreen (3 tabs)

#### Tab 1: Gerar

**Componentes:**
- Campo quantidade (1-100)
- Campo nome do visitante (opcional)
- Seletor de validade (ChoiceChips)
- Dropdown limite de dados
- Dropdown dispositivos permitidos
- Campo observações
- Botão "Gerar Código"

**Resultado (após gerar):**
- Card verde com código em destaque
- Botão "Copiar"
- Botão "WhatsApp"
- QR Code com dados de acesso

#### Tab 2: Vouchers

**Componentes:**
- Lista de vouchers (RefreshIndicator)
- Cards com status visual
- Menu de ações (copiar/compartilhar/revogar)

**Status Cores:**
- 🟢 Ativo (verde)
- 🟠 Expirado (laranja)
- 🔴 Revogado (vermelho)
- 🔵 Usado (azul)

#### Tab 3: Estatísticas

**Componentes:**
- Cards com totais por status
- Atualização em tempo real

---

## Serviços

### AuthService

**Responsabilidade:** Gerenciar sessão e autenticação.

```dart
class AuthService extends ChangeNotifier {
  Future<void> init()           // Verifica token salvo
  Future<void> login()          // Autentica e salva token
  Future<void> logout()         // Limpa sessão
  bool get isAuthenticated      // Estado de autenticação
}
```

**Armazenamento:**
- Usa `flutter_secure_storage`
- Keychain (iOS) / KeyStore (Android)
- Token JWT criptografado em repouso

---

### ApiService

**Responsabilidade:** Comunicação HTTP com o backend.

```dart
class ApiService {
  Future<VoucherCode> generateVoucher(VoucherRequest request)
  Future<List<VoucherCode>> generateBatchVouchers(VoucherRequest request)
  Future<Map<String, dynamic>> listVouchers({String? status})
  Future<VoucherCode> getVoucher(String code)
  Future<void> revokeVoucher(String code)
  Future<VoucherStats> getStatistics()
}
```

**Tratamento de Erros:**
- 401 → Logout automático + redireciona para login
- 400/500 → Exibe mensagem ao usuário
- Timeout → Exibe "Erro de conexão"

---

## Modelos

### VoucherCode

```dart
class VoucherCode {
  final int? id;
  final String code;           // Ex: "AB3CD9F2"
  final String? description;   // Nome do visitante
  final int validityDays;      // Dias de validade
  final int dataLimitMb;       // Limite de dados
  final int devicesAllowed;    // Dispositivos
  final String status;         // active/expired/revoked/used
  final String createdAt;      // ISO 8601
  final String expiresAt;      // ISO 8601
}
```

### VoucherRequest

```dart
class VoucherRequest {
  final int quantity;
  final String? definitionName;
  final int validityDays;
  final int dataLimitMb;
  final int devicesAllowed;
  final String? visitorName;
  final String? notes;
}
```

### AuthResponse

```dart
class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String username;
  final String role;
}
```

---

## Gerenciamento de Estado

O app usa **Provider** para gerenciamento de estado:

```dart
// main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
  ],
  child: MaterialApp(...)
)

// Acesso ao estado
context.watch<AuthService>()    // Reconstrói ao mudar
context.read<AuthService>()     // Acesso sem reconstruir
```

---

## Comunicação com Backend

### Fluxo de uma Requisição

```
1. Usuário clica "Gerar Código"
2. HomeScreen chama ApiService.generateVoucher()
3. ApiService monta headers com JWT
4. Envia POST /api/v1/vouchers/generate
5. Backend processa e retorna JSON
6. ApiService converte para VoucherCode
7. HomeScreen exibe resultado
```

### Headers de Autenticação

```dart
Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${_authService.token}',
};
```

---

## Troubleshooting

### Erro de Conexão

- Verificar URL do servidor
- Verificar se backend está rodando
- Verificar rede (mesma rede WiFi)
- Para emulador Android: usar `10.0.2.2`

### Tela Branca / Crash

```bash
# Limpar cache
flutter clean
flutter pub get
flutter run
```

### Erro de Certificado SSL

Em desenvolvimento, configure `usesCleartextTraffic` (Android) ou `NSAllowsArbitraryLoads` (iOS).

### Build Falha

```bash
# Verificar ambiente
flutter doctor

# Atualizar Flutter
flutter upgrade

# Limpar build
flutter clean
flutter pub get
```

---

## Desenvolvimento

### Hot Reload

```bash
flutter run
# Pressione 'r' no terminal para hot reload
# Pressione 'R' para hot restart
```

### Adicionar Dependência

```bash
flutter add nome_pacote
```

### Gerar Ícones

```bash
flutter pub run flutter_launcher_icons:main
```

---

## Licença

Uso interno — SEDUC-PI

---

**Versão:** 1.0.0 | **Última atualização:** Agosto 2026
