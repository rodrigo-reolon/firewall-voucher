"""
Configuração central do backend FastAPI.
Gerencia variáveis de ambiente e constantes da aplicação.
"""
from pydantic_settings import BaseSettings
from typing import List
from functools import lru_cache


class Settings(BaseSettings):
    """Configurações carregadas de variáveis de ambiente (.env)."""
    
    # Aplicação
    APP_NAME: str = "Firewall Voucher Middleware"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    API_PREFIX: str = "/api/v1"
    
    # Servidor
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # JWT
    JWT_SECRET_KEY: str = "change-this-in-production-use-secret-key-min-32-chars"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 480  # 8 horas
    
    # Sophos Firewall
    SOPHOS_HOST: str = "192.168.130.71"
    SOPHOS_PORT: int = 4444  # Porta padrão da API XML do SFOS
    SOPHOS_USERNAME: str = "admin"
    SOPHOS_PASSWORD: str = ""
    SOPHOS_VERIFY_SSL: bool = False  # False para certificados autoassinados
    SOPHOS_TIMEOUT: int = 30
    
    # Controle de acesso IP (lista de IPs autorizados)
    ALLOWED_IPS: List[str] = ["127.0.0.1", "192.168.130.0/24"]
    
    # Operadores padrão (devem ser alterados em produção)
    DEFAULT_OPERATORS: List[dict] = [
        {"username": "admin", "password": "admin123", "role": "admin"},
    ]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """Retorna instância única das configurações."""
    return Settings()
