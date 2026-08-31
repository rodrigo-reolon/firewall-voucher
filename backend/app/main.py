"""
Aplicação principal Firewall Voucher Middleware.
Inicializa o FastAPI com todas as rotas e configurações.
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime
import logging
import time

from app.config import get_settings
from app.routers import auth_router, voucher_router
from app.models.schemas import HealthResponse, ErrorResponse

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    """Fábrica de criação da aplicação FastAPI."""
    
    settings = get_settings()
    
    app = FastAPI(
        title=settings.APP_NAME,
        description="""
## Firewall Voucher Middleware

API intermediária para geração e gerenciamento de vouchers de acesso (Guest Users)
no Sophos Firewall via XML API.

### Autenticação

Todos os endpoints de voucher requerem autenticação JWT via Bearer Token.
Use `/api/v1/auth/login` para obter o token.

### Segurança

- Comunicação com o firewall via HTTPS
- Certificados autoassinados configuráveis
- Controle de acesso por IP
- Tokens JWT com expiração
        """,
        version=settings.APP_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url=f"{settings.API_PREFIX}/openapi.json"
    )
    
    # ============================================
    # MIDDLEWARES
    # ============================================
    
    # CORS para permitir acesso do app mobile
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Restringir em produção
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Trusted Host (proteção contra ataques de host header)
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["*"]  # Configurar hosts específicos em produção
    )
    
    # Middleware de logging de requisições
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start_time = time.time()
        
        # Log da requisição
        client_ip = request.client.host if request.client else "unknown"
        logger.info(f"→ {request.method} {request.url.path} de {client_ip}")
        
        response = await call_next(request)
        
        # Log da resposta
        process_time = time.time() - start_time
        logger.info(
            f"← {request.method} {request.url.path} "
            f"| Status: {response.status_code} "
            f"| Tempo: {process_time:.3f}s"
        )
        
        response.headers["X-Process-Time"] = str(process_time)
        return response
    
    # ============================================
    # HANDLERS DE ERRO GLOBAIS
    # ============================================
    
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error(f"Erro não tratado: {exc}", exc_info=True)
        return JSONResponse(
            status_code=500,
            content=ErrorResponse(
                error="Internal Server Error",
                detail="Ocorreu um erro interno. Verifique os logs."
            ).model_dump()
        )
    
    @app.exception_handler(404)
    async def not_found_handler(request: Request, exc):
        return JSONResponse(
            status_code=404,
            content=ErrorResponse(
                error="Not Found",
                detail=f"Endpoint {request.url.path} não encontrado"
            ).model_dump()
        )
    
    # ============================================
    # ROTAS BASE
    # ============================================
    
    @app.get("/", tags=["Root"])
    async def root():
        """Endpoint raiz com informações da API."""
        return {
            "name": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "docs": "/docs",
            "health": f"{settings.API_PREFIX}/health"
        }
    
    @app.get(
        f"{settings.API_PREFIX}/health",
        response_model=HealthResponse,
        tags=["Health"]
    )
    async def health_check():
        """
        Health check endpoint.
        
        Verifica o status da API e conexão com o Sophos Firewall.
        """
        from app.services.sophos_service import get_sophos_service
        sophos = get_sophos_service()
        
        # Testar conexão com Sophos (sem bloquear)
        try:
            import asyncio
            # Fire and forget - não bloqueia a resposta
            asyncio.create_task(sophos.authenticate())
            sophos_status = "checking"
        except Exception:
            sophos_status = "unknown"
        
        return HealthResponse(
            status="healthy",
            version=settings.APP_VERSION,
            sophos_connection=sophos_status
        )
    
    # ============================================
    # REGISTRAR ROTERS
    # ============================================
    
    app.include_router(auth_router.router, prefix=settings.API_PREFIX)
    app.include_router(voucher_router.router, prefix=settings.API_PREFIX)
    
    return app


# Instância da aplicação
app = create_app()
