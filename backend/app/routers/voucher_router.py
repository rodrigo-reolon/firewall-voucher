"""
Endpoints para geração e gerenciamento de códigos de voucher do Hotspot Sophos.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional

from app.models.schemas import (
    HotspotVoucherCodeRequest,
    HotspotVoucherCodeResponse,
    HotspotVoucherListResponse,
    VoucherRevokeRequest,
    VoucherAuditEntry,
    VoucherStatistics,
    ErrorResponse
)
from app.auth.jwt_handler import get_current_operator
from app.services.voucher_service import get_voucher_service, VoucherCodeService

router = APIRouter(prefix="/vouchers", tags=["Hotspot Vouchers"])


@router.post(
    "/generate",
    response_model=HotspotVoucherCodeResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        500: {"model": ErrorResponse}
    },
    summary="Gerar código de voucher",
    description="Gera um novo código de voucher compatível com o Hotspot Sophos."
)
async def generate_voucher(
    request: HotspotVoucherCodeRequest,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """
    Gera um novo código de voucher para acesso ao Hotspot.
    
    - **quantity**: Quantidade de códigos (1-100)
    - **definition_name**: Nome da definição no Sophos (opcional)
    - **validity_days**: Dias de validade (1-730, padrão: 30)
    - **data_limit_mb**: Limite de dados em MB (0 = ilimitado)
    - **devices_allowed**: Dispositivos por código (1-5)
    - **visitor_name**: Nome/identificação do visitante
    - **notes**: Observações
    
    Retorna o código gerado no formato Sophos (8 caracteres alfanuméricos).
    """
    try:
        result = voucher_service.generate_voucher_code(
            definition_name=request.definition_name,
            validity_days=request.validity_days,
            data_limit_mb=request.data_limit_mb,
            devices_allowed=request.devices_allowed,
            description=request.visitor_name,
            created_by=current_operator["username"],
            notes=request.notes
        )
        
        return HotspotVoucherCodeResponse(**result)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao gerar voucher: {str(e)}"
        )


@router.post(
    "/generate-batch",
    response_model=list[HotspotVoucherCodeResponse],
    summary="Gerar múltiplos códigos",
    description="Gera vários códigos de voucher de uma vez."
)
async def generate_batch_vouchers(
    request: HotspotVoucherCodeRequest,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """Gera múltiplos códigos de voucher."""
    try:
        results = voucher_service.generate_multiple_codes(
            quantity=request.quantity,
            definition_name=request.definition_name,
            validity_days=request.validity_days,
            data_limit_mb=request.data_limit_mb,
            devices_allowed=request.devices_allowed,
            description_prefix=request.visitor_name,
            created_by=current_operator["username"]
        )
        
        return [HotspotVoucherCodeResponse(**r) for r in results]
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao gerar vouchers: {str(e)}"
        )


@router.get(
    "/list",
    response_model=HotspotVoucherListResponse,
    summary="Listar vouchers",
    description="Lista todos os códigos de voucher gerenciados."
)
async def list_vouchers(
    status_filter: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """
    Lista vouchers com filtros.
    
    - **status_filter**: Filtrar por status (active/expired/revoked/used)
    - **limit**: Limite de resultados (padrão: 50)
    - **offset**: Offset para paginação
    """
    result = voucher_service.list_vouchers(
        status=status_filter,
        limit=limit,
        offset=offset
    )
    
    vouchers = [HotspotVoucherCodeResponse(**v) for v in result["vouchers"]]
    
    return HotspotVoucherListResponse(
        total=result["total"],
        limit=result["limit"],
        offset=result["offset"],
        vouchers=vouchers
    )


@router.get(
    "/{code}",
    response_model=HotspotVoucherCodeResponse,
    summary="Buscar voucher",
    description="Busca um voucher pelo código."
)
async def get_voucher(
    code: str,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """Busca um voucher específico pelo código."""
    voucher = voucher_service.get_voucher(code)
    
    if not voucher:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Voucher {code} não encontrado"
        )
    
    return HotspotVoucherCodeResponse(**voucher)


@router.post(
    "/revoke",
    summary="Revogar voucher",
    description="Revoga um código de voucher (cancela acesso)."
)
async def revoke_voucher(
    request: VoucherRevokeRequest,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """Revoga um voucher pelo código."""
    voucher_service.revoke_voucher(
        code=request.code,
        revoked_by=current_operator["username"]
    )
    
    return {
        "status": "success",
        "message": f"Voucher {request.code} revogado com sucesso"
    }


@router.get(
    "/{code}/audit",
    response_model=list[VoucherAuditEntry],
    summary="Log de auditoria",
    description="Retorna o log de auditoria de um voucher."
)
async def get_voucher_audit(
    code: str,
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """Retorna log de auditoria de um voucher."""
    audit_log = voucher_service.get_audit_log(code)
    return [VoucherAuditEntry(**entry) for entry in audit_log]


@router.get(
    "/stats/summary",
    response_model=VoucherStatistics,
    summary="Estatísticas",
    description="Retorna estatísticas gerais dos vouchers."
)
async def get_statistics(
    current_operator: dict = Depends(get_current_operator),
    voucher_service: VoucherCodeService = Depends(get_voucher_service)
):
    """Retorna estatísticas dos vouchers."""
    stats = voucher_service.get_statistics()
    return VoucherStatistics(**stats)
