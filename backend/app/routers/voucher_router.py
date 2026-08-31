"""
Endpoints para geração e gerenciamento de vouchers de acesso.
"""
import qrcode
import io
import base64
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional

from app.models.schemas import (
    VoucherGenerateRequest,
    VoucherResponse,
    VoucherListResponse,
    VoucherInfo,
    ErrorResponse,
    ValidityPeriod
)
from app.auth.jwt_handler import get_current_operator
from app.services.sophos_service import get_sophos_service, SophosService

router = APIRouter(prefix="/vouchers", tags=["Vouchers"])


@router.post(
    "/generate",
    response_model=VoucherResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        502: {"model": ErrorResponse},
        503: {"model": ErrorResponse}
    },
    summary="Gerar novo voucher de acesso",
    description="Cria um novo usuário visitante no Sophos Firewall com tempo de validade e cota de dados definidos."
)
async def generate_voucher(
    request: VoucherGenerateRequest,
    current_operator: dict = Depends(get_current_operator),
    sophos: SophosService = Depends(get_sophos_service)
):
    """
    Gera um novo voucher de acesso para visitante.
    
    - **visitor_name**: Nome do visitante (opcional)
    - **validity_hours**: Tempo de validade em horas (1-168)
    - **data_quota_mb**: Cota de dados em MB (padrão: 500)
    - **access_profile**: Perfil de acesso no Sophos (padrão: Guest)
    
    Retorna as credenciais geradas (username, password) e dados de expiração.
    """
    try:
        result = await sophos.generate_guest_user(
            visitor_name=request.visitor_name,
            validity_hours=request.validity_hours,
            data_quota_mb=request.data_quota_mb or 500,
            access_profile=request.access_profile
        )
        
        # Gerar dados para QR Code
        qr_data = _generate_qr_data(result)
        
        return VoucherResponse(
            username=result["username"],
            password=result["password"],
            expires_at=result["expires_at"],
            validity_hours=result["validity_hours"],
            visitor_name=result["visitor_name"],
            access_profile=result["access_profile"],
            status="active",
            created_at=result["created_at"],
            qr_code_data=qr_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao gerar voucher: {str(e)}"
        )


@router.get(
    "/list",
    response_model=VoucherListResponse,
    summary="Listar vouchers ativos",
    description="Retorna todos os usuários visitantes ativos no Sophos Firewall."
)
async def list_vouchers(
    current_operator: dict = Depends(get_current_operator),
    sophos: SophosService = Depends(get_sophos_service)
):
    """Lista todos os vouchers/visitantes ativos."""
    guests = await sophos.list_active_guests()
    
    vouchers = []
    for guest in guests:
        vouchers.append(VoucherInfo(
            username=guest.get("Username", ""),
            expires_at=guest.get("ExpiresAt", ""),
            created_at=guest.get("CreatedAt", ""),
            access_profile=guest.get("Profile", "Guest"),
            status=guest.get("Status", "active"),
            visitor_name=guest.get("Description", "")
        ))
    
    return VoucherListResponse(total=len(vouchers), vouchers=vouchers)


@router.delete(
    "/revoke/{username}",
    summary="Revogar voucher",
    description="Remove um usuário visitante do Sophos Firewall."
)
async def revoke_voucher(
    username: str,
    current_operator: dict = Depends(get_current_operator),
    sophos: SophosService = Depends(get_sophos_service)
):
    """Revoga um voucher específico pelo username."""
    success = await sophos.revoke_guest_user(username)
    
    if success:
        return {"status": "success", "message": f"Voucher {username} revogado com sucesso"}
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao revogar voucher {username}"
        )


def _generate_qr_data(voucher_data: dict) -> str:
    """
    Gera dados formatados para QR Code.
    
    O QR Code contém instruções de acesso formatadas para fácil leitura
    pelo visitante ao escanear com o celular.
    """
    wifi_ssid = "Guest-WiFi"  # Deve ser configurado conforme ambiente
    
    qr_content = (
        f"REDE: {wifi_ssid}\n"
        f"USUÁRIO: {voucher_data['username']}\n"
        f"SENHA: {voucher_data['password']}\n"
        f"VALIDADE: {voucher_data['expires_at'].strftime('%d/%m/%Y %H:%M')}\n"
        f"PERFIL: {voucher_data['access_profile']}"
    )
    
    return qr_content


def generate_qr_code_image(data: str) -> str:
    """
    Gera imagem do QR Code em base64.
    
    Args:
        data: Dados a serem codificados no QR Code
        
    Returns:
        String base64 da imagem PNG
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)
    
    return base64.b64encode(buffer.getvalue()).decode()
