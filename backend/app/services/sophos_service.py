"""
Serviço de comunicação com o Sophos Firewall via XML API.
Gerencia autenticação, envio de comandos e parsing das respostas.
"""
import httpx
import xmltodict
from typing import Optional, Dict, Any, Tuple
from datetime import datetime, timedelta
from fastapi import HTTPException, status
import logging

from app.config import get_settings

logger = logging.getLogger(__name__)


class SophosService:
    """
    Serviço para comunicação com o Sophos Firewall via XML API.
    
    A API XML do SFOS opera na porta de gerenciamento (padrão 4444)
    e utiliza autenticação via credenciais no próprio payload XML.
    """
    
    def __init__(self):
        self.settings = get_settings()
        self.base_url = (
            f"https://{self.settings.SOPHOS_HOST}:{self.settings.SOPHOS_PORT}"
        )
        self._auth_token: Optional[str] = None
        self._token_expiry: Optional[datetime] = None
    
    def _build_xml_payload(self, action: str, params: Dict[str, Any] = None) -> str:
        """
        Constrói o payload XML para envio ao Sophos.
        
        O formato segue o padrão da API XML do SFOS:
        <?xml version="1.0" encoding="UTF-8"?>
        <Request>
            <Login>
                <Username>admin</Username>
                <Password>senha</Password>
            </Login>
            <Action>
                <Name>nome_acao</Name>
                <Param>...</Param>
            </Action>
        </Request>
        """
        xml_parts = ['<?xml version="1.0" encoding="UTF-8"?>']
        xml_parts.append("<Request>")
        
        # Credenciais de login
        xml_parts.append("<Login>")
        xml_parts.append(f"<Username>{self.settings.SOPHOS_USERNAME}</Username>")
        xml_parts.append(f"<Password>{self.settings.SOPHOS_PASSWORD}</Password>")
        xml_parts.append("</Login>")
        
        # Ação
        xml_parts.append("<Action>")
        xml_parts.append(f"<Name>{action}</Name>")
        
        if params:
            for key, value in params.items():
                xml_parts.append(f"<{key}>{value}</{key}>")
        
        xml_parts.append("</Action>")
        xml_parts.append("</Request>")
        
        return "\n".join(xml_parts)
    
    async def _send_request(self, xml_payload: str) -> Dict[str, Any]:
        """
        Envia requisição XML ao Sophos Firewall e retorna resposta parseada.
        
        Args:
            xml_payload: String XML completa
            
        Returns:
            Dicionário com dados da resposta
            
        Raises:
            HTTPException: Em caso de erro de conexão ou resposta inválida
        """
        url = f"{self.base_url}/webconsole/APIController"
        
        headers = {
            "Content-Type": "application/xml",
            "Accept": "application/xml"
        }
        
        try:
            async with httpx.AsyncClient(
                verify=self.settings.SOPHOS_VERIFY_SSL,
                timeout=self.settings.SOPHOS_TIMEOUT
            ) as client:
                logger.info(f"Enviando requisição para {url}")
                logger.debug(f"Payload XML:\n{xml_payload}")
                
                response = await client.post(
                    url,
                    content=xml_payload,
                    headers=headers
                )
                
                logger.info(f"Resposta recebida: {response.status_code}")
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Sophos retornou status {response.status_code}: {response.text[:500]}"
                    )
                
                # Parse XML para dicionário
                response_data = xmltodict.parse(response.text)
                return response_data
                
        except httpx.ConnectError as e:
            logger.error(f"Erro de conexão com Sophos: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Não foi possível conectar ao Sophos Firewall em {self.settings.SOPHOS_HOST}:{self.settings.SOPHOS_PORT}. "
                       f"Verifique se o firewall está acessível e a API está habilitada."
            )
        except httpx.TimeoutException:
            logger.error("Timeout na comunicação com Sophos")
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="Timeout na comunicação com o Sophos Firewall"
            )
        except Exception as e:
            logger.error(f"Erro inesperado na comunicação com Sophos: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Erro na comunicação com Sophos: {str(e)}"
            )
    
    def _parse_response(self, response: Dict[str, Any]) -> Dict[str, Any]:
        """
        Faz o parsing da resposta XML do Sophos para formato padronizado.
        
        O Sophos retorna respostas no formato:
        <Response>
            <Status>OK</Status>
            <Result>...</Result>
        </Response>
        """
        try:
            response_root = response.get("Response", {})
            
            status = response_root.get("Status", "UNKNOWN")
            message = response_root.get("Message", "")
            result = response_root.get("Result", {})
            
            return {
                "status": status,
                "message": message,
                "data": result,
                "success": status.upper() in ("OK", "SUCCESS")
            }
        except Exception as e:
            logger.error(f"Erro ao parsear resposta: {e}")
            return {
                "status": "ERROR",
                "message": f"Erro ao processar resposta: {str(e)}",
                "data": response,
                "success": False
            }
    
    async def authenticate(self) -> bool:
        """
        Testa a autenticação no Sophos Firewall.
        
        Returns:
            True se autenticação bem sucedida
        """
        xml_payload = self._build_xml_payload("GetSystemStatus")
        response = await self._send_request(xml_payload)
        parsed = self._parse_response(response)
        
        if parsed["success"]:
            logger.info("Autenticação no Sophos bem sucedida")
            return True
        else:
            logger.warning(f"Falha na autenticação: {parsed['message']}")
            return False
    
    async def generate_guest_user(
        self,
        visitor_name: Optional[str],
        validity_hours: int,
        data_quota_mb: int = 500,
        access_profile: str = "Guest"
    ) -> Dict[str, Any]:
        """
        Gera um usuário visitante (Guest User) no Sophos Firewall.
        
        Args:
            visitor_name: Nome do visitante
            validity_hours: Horas de validade
            data_quota_mb: Cota de dados em MB
            access_profile: Perfil de acesso
            
        Returns:
            Dicionário com username, password e dados do voucher
        """
        # Calcular data de expiração
        expires_at = datetime.utcnow() + timedelta(hours=validity_hours)
        expires_str = expires_at.strftime("%Y-%m-%d %H:%M:%S")
        
        # Gerar identificador único
        timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
        username = f"guest_{timestamp}"
        
        # Parâmetros para criação do Guest User
        params = {
            "Username": username,
            "Password": self._generate_password(),
            "Description": f"Voucher: {visitor_name or 'Visitante'}",
            "Profile": access_profile,
            "ExpiresAt": expires_str,
            "DataQuotaMB": str(data_quota_mb),
            "UserType": "Guest"
        }
        
        xml_payload = self._build_xml_payload("AddUser", params)
        response = await self._send_request(xml_payload)
        parsed = self._parse_response(response)
        
        if parsed["success"]:
            logger.info(f"Guest user criado: {username}")
            return {
                "success": True,
                "username": username,
                "password": params["Password"],
                "expires_at": expires_at,
                "validity_hours": validity_hours,
                "visitor_name": visitor_name,
                "access_profile": access_profile,
                "data_quota_mb": data_quota_mb,
                "created_at": datetime.utcnow()
            }
        else:
            logger.error(f"Falha ao criar guest user: {parsed['message']}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Falha ao criar usuário no Sophos: {parsed['message']}"
            )
    
    async def list_active_guests(self) -> list:
        """
        Lista todos os usuários visitantes ativos.
        
        Returns:
            Lista de dicionários com dados dos visitantes
        """
        xml_payload = self._build_xml_payload("GetUsers", {"UserType": "Guest"})
        response = await self._send_request(xml_payload)
        parsed = self._parse_response(response)
        
        if parsed["success"]:
            users_data = parsed["data"]
            # Normalizar para lista
            if isinstance(users_data, dict):
                users = users_data.get("User", [])
                if isinstance(users, dict):
                    users = [users]
            else:
                users = []
            
            return users
        else:
            logger.error(f"Falha ao listar guests: {parsed['message']}")
            return []
    
    async def revoke_guest_user(self, username: str) -> bool:
        """
        Revoga/remove um usuário visitante.
        
        Args:
            username: Nome do usuário a ser revogado
            
        Returns:
            True se revogado com sucesso
        """
        xml_payload = self._build_xml_payload("DeleteUser", {"Username": username})
        response = await self._send_request(xml_payload)
        parsed = self._parse_response(response)
        
        return parsed["success"]
    
    def _generate_password(self, length: int = 12) -> str:
        """
        Gera uma senha aleatória segura.
        
        Args:
            length: Comprimento da senha
            
        Returns:
            Senha gerada
        """
        import secrets
        import string
        
        alphabet = string.ascii_letters + string.digits
        # Garantir pelo menos 1 maiúscula, 1 minúscula e 1 dígito
        password = [
            secrets.choice(string.ascii_uppercase),
            secrets.choice(string.ascii_lowercase),
            secrets.choice(string.digits),
        ]
        password += [secrets.choice(alphabet) for _ in range(length - 3)]
        secrets.SystemRandom().shuffle(password)
        
        return "".join(password)


# Singleton do serviço
_sophos_service: Optional[SophosService] = None


def get_sophos_service() -> SophosService:
    """Retorna instância única do serviço Sophos."""
    global _sophos_service
    if _sophos_service is None:
        _sophos_service = SophosService()
    return _sophos_service
