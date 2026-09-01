// Configuração do app - Ajuste aqui antes de buildar!
// 
// Este arquivo contém as configurações fixas do aplicativo.
// Altere os valores conforme necessário ANTES de gerar o APK.

class AppConfig {
  // =============================================
  // CONFIGURAÇÕES DO SOPHOS FIREWALL
  // =============================================
  
  // URL do User Portal (porta 223 do Sophos)
  // Formato: https://<IP_OU_HOSTNAME>:223
  static const String portalUrl = 'https://firewall.reolon.local:4436';
  
  // Usuário com permissão de gerar vouchers
  static const String username = 'hostspot';
  
  // Senha do usuário (deixar vazio para pedir ao usuário no app)
  // Se preencher, o app já conecta automaticamente sem pedir senha
  static const String password = 'Ajobeyin2009!';
  
  // =============================================
  // CONFIGURAÇÕES DO APP
  // =============================================
  
  // Nome da rede WiFi (SSID)
  static const String ssid = 'Reolon Visitantes';
  
  // Nome do app
  static const String appName = 'Reolon Visitantes';
  
  // Descrição do app
  static const String appDescription = 'WiFi para Visitantes';
  
  // =============================================
  // SEGURANÇA
  // =============================================
  
  // Verificar certificado SSL (false para certificados autoassinados)
  static const bool verifySsl = false;
}
