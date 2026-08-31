# Guia de Configuração - Sophos Firewall (SFOS)

## 📋 Visão Geral

Este guia descreve como configurar o Sophos Firewall para permitir a integração com o sistema de geração de vouchers via API XML.

---

## 1. Habilitar a API XML no SFOS

### Passo a Passo

1. **Acesse o WebAdmin do Sophos Firewall**
   - URL: `https://<IP_DO_FIREWALL>:4444`
   - Exemplo: `https://192.168.130.71:4444`

2. **Navegue até Backup & Firmware**
   - Menu: **Backup & Firmware** → **API**

3. **Habilitar API**
   - Marque a opção **"Enable API"**
   - Porta padrão: **4444** (HTTPS)
   - Clique em **Apply**

4. **Verificar Status**
   - A API deve mostrar status "Running"
   - Teste de acesso: `https://<IP>:4444/webconsole/APIController`

---

## 2. Criar Administrador com Privilégios Mínimos

### Objetivo
Criar uma conta de serviço dedicada para o middleware, com permissões restritas ao gerenciamento de usuários visitantes.

### Passo a Passo

1. **Acesse Administração de Usuários**
   - Menu: **Administrators** → **Administrator Groups**

2. **Criar Novo Grupo**
   - Clique em **Add** → **Administrator Group**
   - Nome: `VoucherManager`
   - Descrição: `Gerenciamento de vouchers de acesso`

3. **Configurar Permissões**
   - Aba **Permissions**:
     - ✅ **User Management** → **Guest Users** (Read/Write)
     - ✅ **User Management** → **Local Users** (Read)
     - ❌ **Network Configuration** (No Access)
     - ❌ **Firewall Rules** (No Access)
     - ❌ **System Configuration** (No Access)
     - ❌ **Backup & Restore** (No Access)

4. **Criar Usuário de Serviço**
   - Menu: **Administrators** → **Administrators**
   - Clique em **Add** → **Administrator**
   - **Username**: `svc_voucher`
   - **Password**: (senha forte - mínimo 12 caracteres)
   - **Administrator Group**: `VoucherManager`
   - **Email**: (opcional, para alertas)

5. **Salvar e Aplicar**
   - Clique em **Save** e depois **Apply**

---

## 3. Configurar Controle de Acesso IP (ACL)

### Objetivo
Restringir o acesso da API XML apenas ao IP do servidor middleware.

### Passo a Passo

1. **Acesse API Access Control**
   - Menu: **Backup & Firmware** → **API** → **API Access Control**

2. **Adicionar IP Autorizado**
   - Clique em **Add**
   - **IP Address**: IP do servidor middleware
     - Exemplo: `192.168.130.50` (IP do servidor onde roda o FastAPI)
   - **Subnet Mask**: `255.255.255.255` (host único)
   - **Description**: `Servidor Middleware Voucher`

3. **Bloquear Outros IPs (Opcional mas Recomendado)**
   - Adicione regra para bloquear `0.0.0.0/0` (negar tudo)
   - Certifique-se de que a regra de permissão está acima da negação

4. **Aplicar Configurações**
   - Clique em **Apply**

---

## 4. Configurar Perfil de Acesso para Visitantes

### Objetivo
Definir o perfil de rede que os visitantes terão ao se conectarem.

### Passo a Passo

1. **Acesse Profiles de Usuário**
   - Menu: **Users** → **User Profiles**

2. **Criar/Editar Perfil Guest**
   - Nome: `Guest`
   - **Idle Timeout**: 30 minutos
   - **Session Timeout**: 8 horas
   - **Data Quota**: 500 MB (padrão)
   - **Bandwidth**: Definir limite se necessário (ex: 5 Mbps)

3. **Configurar Autenticação Captive Portal**
   - Menu: **Wireless** → **Guest WiFi**
   - Habilitar **Captive Portal**
   - Método de autenticação: **Local Authentication**
   - Perfil padrão: `Guest`

---

## 5. Testar a Conexão

### Via cURL (do servidor middleware)

```bash
# Testar autenticação
curl -k -X POST https://192.168.130.71:4444/webconsole/APIController \
  -H "Content-Type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<Request>
  <Login>
    <Username>svc_voucher</Username>
    <Password>SuaSenhaAqui</Password>
  </Login>
  <Action>
    <Name>GetSystemStatus</Name>
  </Action>
</Request>'
```

### Via Python (teste rápido)

```python
import httpx
import xmltodict

url = "https://192.168.130.71:4444/webconsole/APIController"
xml = """<?xml version="1.0" encoding="UTF-8"?>
<Request>
  <Login>
    <Username>svc_voucher</Username>
    <Password>SuaSenhaAqui</Password>
  </Login>
  <Action>
    <Name>GetSystemStatus</Name>
  </Action>
</Request>"""

response = httpx.post(url, content=xml, verify=False)
print(xmltodict.parse(response.text))
```

---

## 6. Configuração do Middleware (.env)

Após configurar o Sophos, ajuste o arquivo `.env` do backend:

```env
# Sophos Firewall
SOPHOS_HOST=192.168.130.71
SOPHOS_PORT=4444
SOPHOS_USERNAME=svc_voucher
SOPHOS_PASSWORD=SuaSenhaAqui
SOPHOS_VERIFY_SSL=false
SOPHOS_TIMEOUT=30

# Controle de IPs
ALLOWED_IPS=127.0.0.1,192.168.130.50
```

---

## 7. Segurança - Boas Práticas

### ✅ Recomendações

1. **Senha Forte**: Use senha com 16+ caracteres, incluindo maiúsculas, minúsculas, números e símbolos
2. **IP Fixo**: Configure IP fixo para o servidor middleware
3. **HTTPS**: A API XML já opera via HTTPS por padrão
4. **Logs**: Monitore os logs de acesso do Sophos regularmente
5. **Rotação de Senhas**: Altere a senha do svc_voucher a cada 90 dias
6. **Firewall Interno**: Restrinja o acesso à porta 4444 apenas para o IP do middleware

### ⚠️ Alertas

- Nunca exponha a porta 4444 à internet
- Não use a conta admin padrão para o middleware
- Mantenha o SFOS atualizado com os últimos patches de segurança
- Desative a API quando não estiver em uso (manutenções)

---

## 8. Troubleshooting

### Erro: Connection Refused
- Verificar se a API está habilitada no SFOS
- Verificar se a porta 4444 está liberada no firewall local do servidor

### Erro: 401 Unauthorized
- Verificar credenciais (usuário/senha)
- Verificar se o IP está na ACL

### Erro: SSL Certificate
- O certificado do SFOS é autoassinado por padrão
- Configure `SOPHOS_VERIFY_SSL=false` no middleware
- Em produção, importe o certificado CA do SFOS

### Erro: Permission Denied
- Verificar permissões do grupo VoucherManager
- Verificar se o usuário pertence ao grupo correto

---

## 9. Referências

- [Sophos Firewall API Documentation](https://docs.sophos.com/nsg/sophos-firewall/19.5/Help/en-us/webhelp/onlinehelp/AdministratorHelp/APIGuide/)
- [SFOS XML API Reference](https://docs.sophos.com/nsg/sophos-firewall/19.5/Help/en-us/webhelp/onlinehelp/AdministratorHelp/API/)
