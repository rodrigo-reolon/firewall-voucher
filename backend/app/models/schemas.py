"""
Modelos Pydantic para validação de dados de entrada e saída.
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


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


# =============================================
# NOVOS MODELOS - HOTSPOT VOUCHER CODES
# =============================================


class HotspotVoucherCodeRequest(BaseModel):
    """Dados para gerar código de voucher do Hotspot."""
    
    quantity: int = Field(
        default=1,
        ge=1,
        le=100,
        description="Quantidade de códigos a gerar",
        examples=[1]
    )
    
    definition_name: Optional[str] = Field(
        default=None,
        description="Nome da definição de voucher no Sophos",
        examples=["30-dias"]
    )
    
    validity_days: int = Field(
        default=30,
        ge=1,
        le=730,
        description="Dias de validade do voucher",
        examples=[30]
    )
    
    data_limit_mb: int = Field(
        default=0,
        ge=0,
        description="Limite de dados em MB (0 = ilimitado)",
        examples=[500]
    )
    
    devices_allowed: int = Field(
        default=1,
        ge=1,
        le=5,
        description="Dispositivos permitidos por código",
        examples=[1]
    )
    
    visitor_name: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Nome/identificação do visitante",
        examples=["João Silva"]
    )
    
    notes: Optional[str] = Field(
        default=None,
        max_length=255,
        description="Observações",
        examples=["Acesso para visitante do setor X"]
    )


class HotspotVoucherCodeResponse(BaseModel):
    """Resposta de código de voucher gerado."""
    
    id: int
    code: str
    description: Optional[str] = None
    definition_name: Optional[str] = None
    validity_days: int
    data_limit_mb: int
    devices_allowed: int
    status: str
    created_at: str
    expires_at: str
    created_by: Optional[str] = None


class HotspotVoucherListResponse(BaseModel):
    """Lista de códigos de voucher."""
    
    total: int
    limit: int
    offset: int
    vouchers: List[HotspotVoucherCodeResponse]


class VoucherRevokeRequest(BaseModel):
    """Dados para revogar um voucher."""
    
    code: str = Field(
        min_length=6,
        max_length=20,
        description="Código do voucher a ser revogado",
        examples=["AB3CD9F2"]
    )


class VoucherAuditEntry(BaseModel):
    """Entrada de auditoria de voucher."""
    
    id: int
    action: str
    details: Optional[str] = None
    performed_by: Optional[str] = None
    performed_at: str


class VoucherStatistics(BaseModel):
    """Estatísticas dos vouchers."""
    
    total: int
    active: int
    expired: int
    revoked: int
    used: int
    by_status: dict
