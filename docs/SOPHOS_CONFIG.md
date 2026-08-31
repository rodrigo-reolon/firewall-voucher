# Guia de Configuração - Sophos Firewall Hotspot com Vouchers

## 📋 Visão Geral

Este guia descreve como configurar o Sophos Firewall para trabalhar com códigos de voucher do Hotspot, integrados ao sistema de geração automática.

---

## 1. Habilitar o Hotspot com Vouchers no SFOS

### Passo a Passo

1. **Acesse o WebAdmin do Sophos Firewall**
   - URL: `https://<IP_DO_FIREWALL>:4444`
   - Exemplo: `https://192.168.130.71:4444`

2. **Navegue até Wireless > Hotspot**
   - Clique em **Add** para criar um novo Hotspot

3. **Configurar o Hotspot**
   ```
   Nome: Guest-Hotspot
   Interfaces: Selecione a interface Guest (ex: GuestAP)
   Hotspot Type: Voucher
   ```

4. **Selecionar Definição de Voucher**
   - Em **Voucher Definitions**, selecione a definição criada
   - (ex: "30-dias" para vouchers de 30 dias)

5. **Configurações do Portal**
   - **Captive Portal**: Habilitado
   - **Método de Autenticação**: Voucher
   - **Customização**: Upload do HTML customizado (já existente)

6. **Aplicar**
   - Clique em **Save** e depois **Apply**

---

## 2. Criar Definição de Voucher

### Passo a Passo

1. **Navegue até** `Wireless > Hotspot voucher definition`

2. **Criar Nova Definição**
   - Clique em **Add**
   - **Nome**: `30-dias`
   - **Descrição**: `Voucher com validade de 30 dias`
   - **Validity Period**: `30`
   - **Validity Unit**: `Days`
   - **Time Quota**: (opcional, para limite de tempo online)
   - **Data Volume**: (opcional, para limite de dados em MB)
   - **Status**: `Enable`

3. **Salvar e Aplicar**

---

## 3. Criar Administrador com Privilégios Mínimos

### Objetivo
Criar uma conta de serviço dedicada para o middleware, com permissões restritas.

### Passo a Passo

1. **Acesse Administração de Usuários**
   - Menu: **Administrators** → **Administrator Groups**

2. **Criar Novo Grupo**
   - Clique em **Add** → **Administrator Group**
   - Nome: `HotspotVoucherManager`
   - Descrição: `Gerenciamento de vouchers do Hotspot`

3. **Configurar Permissões**
   - Aba **Permissions**:
     - ✅ **User Management** → **Hotspot** (Read/Write)
     - ✅ **User Management** → **Hotspot Voucher Definition** (Read)
     - ✅ **User Management** → **Guest Users** (Read)
     - ❌ **Network Configuration** (No Access)
     - ❌ **Firewall Rules** (No Access)

4. **Criar Usuário de Serviço**
   - Menu: **Administrators** → **Administrators**
   - Clique em **Add** → **Administrator**
   - **Username**: `svc_hotspot_voucher`
   - **Password**: (senha forte)
   - **Administrator Group**: `HotspotVoucherManager`

5. **Salvar e Aplicar**

---

## 4. Configurar Controle de Acesso IP (ACL)

### Objetivo
Restringir o acesso da User Portal (porta 223) apenas ao IP do middleware.

### Passo a Passo

1. **Acesse User Portal Settings**
   - Menu: **Backup & Firmware** → **API** → **API Access Control**

2. **Adicionar IP Autorizado**
   - Clique em **Add**
   - **IP Address**: IP do servidor middleware (ex: `192.168.130.50`)
   - **Subnet Mask**: `255.255.255.255`
   - **Description**: `Servidor Middleware Voucher`

3. **Aplicar**

---

## 5. Testar a Geração de Vouchers Manualmente

### Via User Portal (porta 223)

1. Acesse `https://<IP_DO_FIREWALL>:223/userportal/`
2. Faça login com credenciais de administrador
3. No menu lateral, selecione **Hotspot**
4. No painel central:
   - **Profile**: Selecione "30-dias"
   - **Days**: 30
   - **Quantity**: 5 (ou quantos precisar)
5. Clique em **Generate**
6. Os códigos serão gerados e podem ser visualizados/impressos

---

## 6. Configuração do Middleware

Após configurar o Sophos, ajuste o arquivo `.env` do backend:

```env
# Aplicação
APP_NAME=Firewall Voucher Middleware - Hotspot
DEBUG=true
PORT=8000

# JWT - ALTERAR EM PRODUÇÃO!
JWT_SECRET_KEY=sua-chave-secreta-de-32-caracteres-minimo
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=480

# Controle de IPs
ALLOWED_IPS=127.0.0.1,192.168.130.50
```

---

## 7. Geração de Códigos via Sistema

### Funcionamento

O sistema gera códigos no formato compatível com o Sophos Hotspot:
- **Formato**: 8 caracteres alfanuméricos (maiúsculas + dígitos)
- **Exemplo**: `AB3CD9F2`
- **Sem caracteres ambíguos**: 0/O, 1/I são excluídos

### Como usar

1. **Acesse o App Mobile** ou **API diretamente**
2. Selecione:
   - Quantidade de códigos
   - Período de validade (1, 7, 15, 30, 90 dias)
   - Limite de dados (opcional)
   - Nome do visitante (opcional)
3. Clique em **Gerar Código**
4. Compartilhe via WhatsApp ou copie o código

### Integração com Sophos

- Os códigos gerados são **independentes** (armazenados localmente no banco SQLite)
- O sistema **sincroniza status** com o Sophos para verificar uso/expiração
- Para códigos usados no Hotspot, o status é atualizado automaticamente

---

## 8. Segurança - Boas Práticas

### ✅ Recomendações

1. **Senha Forte**: Use senha com 16+ caracteres
2. **IP Fixo**: Configure IP fixo para o servidor middleware
3. **HTTPS**: O Sophos usa HTTPS por padrão
4. **Logs**: Monitore logs de acesso regularmente
5. **Rotação de Senhas**: Altere a senha do svc_hotspot_voucher periodicamente
6. **User Portal**: Restrinja acesso à porta 223 apenas para IPs autorizados

### ⚠️ Alertas

- Nunca exponha a porta 223 à internet
- Não use a conta admin padrão
- Mantenha o SFOS atualizado
- Desabilite acessos não utilizados

---

## 9. Troubleshooting

### Erro: Código não aceito no Hotspot
- Verificar se a definição de voucher está ativa
- Verificar se o Hotspot está usando a definição correta
- Verificar se o código não expirou

### Erro: Sem conexão com o servidor
- Verificar IP do middleware na ACL
- Verificar se a porta 223 está liberada
- Verificar certificado SSL

### Erro: Permissão negada
- Verificar permissões do grupo HotspotVoucherManager
- Verificar se o usuário pertence ao grupo correto

---

## 10. Referências

- [Sophos Firewall - Hotspot Voucher](https://docs.sophos.com/nsg/sophos-firewall/20.0/Help/en-us/webhelp/onlinehelp/VPNAndUserPortalHelp/UserPortal/Hotspots/HotspotTypeVoucher/)
- [Provide guest access using a hotspot voucher](https://docs.sophos.com/nsg/sophos-firewall/22.0/Help/en-us/webhelp/onlinehelp/AdministratorHelp/Wireless/HowToArticles/WirelessProvideGuestAccessVoucher/)
