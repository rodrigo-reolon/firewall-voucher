"""
Modelos Pydantic para validação de dados de entrada e saída.
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


class ValidityPeriod(int, Enum):
    """Períodos de validade disponíveis para vouchers."""
    ONE_HOUR = 1
    FOUR_HOURS = 4
    EIGHT_HOURS = 8
    TWENTY_FOUR_HOURS = 24
    SEVEN_DAYS = 168  # 7 * 24


class VoucherGenerateRequest(BaseModel):
    """Dados para geração de um novo voucher."""
    
    visitor_name: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Nome do visitante (opcional)",
        examples=["João Silva"]
    )
    
    validity_hours: int = Field(
        default=8,
        ge=1,
        le=168,
        description="Tempo de validade em horas (1-168)",
        examples=[8]
    )
    
    data_quota_mb: Optional[int] = Field(
        default=500,
        ge=10,
        le=10000,
        description="Cota de dados em MB (10-10000)",
        examples=[500]
    )
    
    access_profile: str = Field(
        default="Guest",
        description="Perfil de acesso no Sophos",
        examples=["Guest"]
    )
    
    @field_validator("visitor_name")
    @classmethod
    def validate_visitor_name(cls, v: Optional[str]) -> Optional[str]:
        if v and len(v.strip()) < 2:
            raise ValueError("Nome do visitante deve ter pelo menos 2 caracteres")
        return v.strip() if v else None


class VoucherResponse(BaseModel):
    """Resposta padronizada de um voucher gerado."""
    
    username: str = Field(description="Nome de usuário gerado")
    password: str = Field(description="Senha gerada")
    expires_at: datetime = Field(description="Data/hora de expiração")
    validity_hours: int = Field(description="Horas de validade")
    visitor_name: Optional[str] = Field(default=None, description="Nome do visitante")
    access_profile: str = Field(description="Perfil de acesso")
    status: str = Field(description="Status do voucher (active/expired/revoked)")
    created_at: datetime = Field(description="Data/hora de criação")
    qr_code_data: Optional[str] = Field(default=None, description="Dados para QR Code")


class VoucherInfo(BaseModel):
    """Informações de um voucher ativo."""
    
    username: str
    password: Optional[str] = None
    expires_at: datetime
    created_at: datetime
    access_profile: str
    status: str
    visitor_name: Optional[str] = None


class VoucherListResponse(BaseModel):
    """Lista de vouchers ativos."""
    
    total: int
    vouchers: List[VoucherInfo]


class ErrorResponse(BaseModel):
    """Resposta de erro padronizada."""
    
    error: str
    detail: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class LoginRequest(BaseModel):
    """Dados de login do operador."""
    
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=6, max_length=100)


class TokenResponse(BaseModel):
    """Resposta de autenticação com token JWT."""
    
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    username: str
    role: str


class HealthResponse(BaseModel):
    """Resposta de health check."""
    
    status: str
    version: str
    sophos_connection: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
