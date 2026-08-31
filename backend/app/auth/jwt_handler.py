"""
Módulo de autenticação JWT para operadores do sistema.
Gerencia criação, validação e verificação de tokens de acesso.
"""
from datetime import datetime, timedelta
from typing import Optional, Tuple
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.config import get_settings

# Contexto de hash de senhas
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Esquema de segurança HTTP Bearer
security = HTTPBearer()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica se a senha corresponde ao hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Gera hash bcrypt da senha."""
    return pwd_context.hash(password)


def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None
) -> Tuple[str, datetime]:
    """
    Cria um token JWT com os dados fornecidos.
    
    Args:
        data: Dados a serem codificados no token
        expires_delta: Tempo de expiração customizado
        
    Returns:
        Tupla (token_jwt, datetime_expiracao)
    """
    settings = get_settings()
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "access"
    })
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )
    
    return encoded_jwt, expire


def decode_token(token: str) -> dict:
    """
    Decodifica e valida um token JWT.
    
    Args:
        token: Token JWT a ser decodificado
        
    Returns:
        Payload decodificado
        
    Raises:
        HTTPException: Se o token for inválido ou expirado
    """
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token inválido: sujeito não encontrado",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        exp = payload.get("exp")
        if exp and datetime.utcnow() > datetime.fromtimestamp(exp):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token expirado",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return payload
        
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido ou expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_operator(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """
    Dependência FastAPI para obter o operador autenticado.
    
    Args:
        credentials: Credenciais HTTP Bearer
        
    Returns:
        Dados do operador autenticado
    """
    token = credentials.credentials
    payload = decode_token(token)
    
    return {
        "username": payload.get("sub"),
        "role": payload.get("role", "operator"),
        "permissions": payload.get("permissions", [])
    }


def authenticate_operator(username: str, password: str) -> Optional[dict]:
    """
    Autentica um operador com username e senha.
    
    Args:
        username: Nome de usuário
        password: Senha
        
    Returns:
        Dados do operador se autenticado, None caso contrário
    """
    settings = get_settings()
    
    for operator in settings.DEFAULT_OPERATORS:
        if operator["username"] == username:
            if verify_password(password, get_password_hash(operator["password"])):
                return {
                    "username": operator["username"],
                    "role": operator["role"]
                }
            # Verificação direta para senhas não hasheadas (desenvolvimento)
            if password == operator["password"]:
                return {
                    "username": operator["username"],
                    "role": operator["role"]
                }
    
    return None
