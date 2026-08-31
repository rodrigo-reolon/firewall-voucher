"""
Endpoints de autenticação e gerenciamento de operadores.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from datetime import timedelta

from app.models.schemas import LoginRequest, TokenResponse, ErrorResponse
from app.auth.jwt_handler import (
    authenticate_operator,
    create_access_token,
    get_current_operator
)
from app.config import get_settings

router = APIRouter(prefix="/auth", tags=["Autenticação"])


@router.post(
    "/login",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
    summary="Login do operador",
    description="Autentica um operador e retorna token JWT para acesso aos endpoints protegidos."
)
async def login(request: LoginRequest):
    """
    Realiza login com username e senha.
    
    Retorna um token JWT que deve ser enviado no header Authorization
    de todas as requisições protegidas.
    """
    operator = authenticate_operator(request.username, request.password)
    
    if not operator:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas. Verifique username e senha.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    settings = get_settings()
    access_token, expires_at = create_access_token(
        data={
            "sub": operator["username"],
            "role": operator["role"],
            "permissions": ["voucher:generate", "voucher:list", "voucher:revoke"]
        },
        expires_delta=timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        username=operator["username"],
        role=operator["role"]
    )


@router.get(
    "/me",
    summary="Dados do operador autenticado",
    description="Retorna informações do operador atualmente autenticado."
)
async def get_me(current_operator: dict = Depends(get_current_operator)):
    """Retorna dados do operador logado."""
    return {
        "username": current_operator["username"],
        "role": current_operator["role"],
        "permissions": current_operator["permissions"]
    }
