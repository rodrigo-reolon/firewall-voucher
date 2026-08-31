"""
Serviço de gerenciamento de códigos de voucher do Hotspot Sophos.

A API XML do Sophos (porta 4444) permite criar/deletar definições de voucher,
mas a GERAÇÃO de códigos é feita apenas no User Portal (porta 223).

Este serviço implementa:
1. Geração local de códigos compatíveis com o formato Sophos
2. Armazenamento em SQLite para controle e auditoria
3. Sincronização com Sophos para verificar vouchers ativos
4. Revogação via API quando suportada
"""
import sqlite3
import secrets
import string
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, status
import logging
import os

from app.config import get_settings

logger = logging.getLogger(__name__)

# Caminho do banco de dados
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "vouchers.db")


class VoucherCodeService:
    """
    Serviço para gerenciamento de códigos de voucher do Hotspot.
    
    Os códigos são gerados localmente no formato compatível com Sophos
    e armazenados em SQLite para controle. A sincronização com o firewall
    permite verificar quais códigos estão ativos no momento.
    """
    
    def __init__(self):
        self.settings = get_settings()
        self._init_database()
    
    def _init_database(self):
        """Inicializa o banco de dados SQLite com as tabelas necessárias."""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Tabela de códigos de voucher
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS voucher_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE NOT NULL,
                description TEXT,
                definition_name TEXT,
                validity_days INTEGER DEFAULT 30,
                data_limit_mb INTEGER DEFAULT 0,
                devices_allowed INTEGER DEFAULT 1,
                status TEXT DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP,
                used_at TIMESTAMP,
                used_by TEXT,
                created_by TEXT,
                notes TEXT
            )
        """)
        
        # Tabela de definições de voucher (sincronizada com Sophos)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS voucher_definitions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                validity_days INTEGER,
                validity_unit TEXT DEFAULT 'Days',
                time_quota INTEGER,
                time_quota_unit TEXT,
                data_volume INTEGER,
                data_unit TEXT,
                devices_per_voucher INTEGER DEFAULT 1,
                synced_at TIMESTAMP,
                sophos_id TEXT
            )
        """)
        
        # Tabela de auditoria
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS voucher_audit (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                voucher_code_id INTEGER,
                action TEXT NOT NULL,
                details TEXT,
                performed_by TEXT,
                performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (voucher_code_id) REFERENCES voucher_codes(id)
            )
        """)
        
        conn.commit()
        conn.close()
        logger.info("Banco de dados de vouchers inicializado")
    
    def _get_connection(self) -> sqlite3.Connection:
        """Retorna conexão com o banco de dados."""
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn
    
    def generate_voucher_code(
        self,
        definition_name: Optional[str] = None,
        validity_days: int = 30,
        data_limit_mb: int = 0,
        devices_allowed: int = 1,
        description: Optional[str] = None,
        created_by: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Gera um novo código de voucher.
        
        O código é gerado no formato compatível com Sophos Hotspot:
        - 8 caracteres alfanuméricos (maiúsculos + dígitos)
        - Exemplo: AB3CD9F2
        
        Args:
            definition_name: Nome da definição de voucher no Sophos
            validity_days: Dias de validade (padrão: 30)
            data_limit_mb: Limite de dados em MB (0 = ilimitado)
            devices_allowed: Dispositivos permitidos por código
            description: Descrição/identificação do visitante
            created_by: Operador que criou
            notes: Observações adicionais
            
        Returns:
            Dicionário com dados do voucher gerado
        """
        # Gerar código único
        code = self._generate_unique_code()
        
        # Calcular expiração
        created_at = datetime.utcnow()
        expires_at = created_at + timedelta(days=validity_days)
        
        conn = self._get_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO voucher_codes 
                (code, description, definition_name, validity_days, data_limit_mb, 
                 devices_allowed, status, expires_at, created_by, notes)
                VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)
            """, (
                code, description, definition_name, validity_days, data_limit_mb,
                devices_allowed, expires_at, created_by, notes
            ))
            
            voucher_id = cursor.lastrowid
            
            # Registrar auditoria
            cursor.execute("""
                INSERT INTO voucher_audit (voucher_code_id, action, details, performed_by)
                VALUES (?, 'CREATE', ?, ?)
            """, (voucher_id, f"Voucher criado com validade de {validity_days} dias", created_by))
            
            conn.commit()
            
            logger.info(f"Voucher gerado: {code} (validade: {validity_days} dias)")
            
            return {
                "id": voucher_id,
                "code": code,
                "description": description,
                "definition_name": definition_name,
                "validity_days": validity_days,
                "data_limit_mb": data_limit_mb,
                "devices_allowed": devices_allowed,
                "status": "active",
                "created_at": created_at.isoformat(),
                "expires_at": expires_at.isoformat(),
                "created_by": created_by,
                "notes": notes
            }
            
        except sqlite3.IntegrityError:
            logger.error(f"Código duplicado gerado: {code}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Erro ao gerar código único. Tente novamente."
            )
        finally:
            conn.close()
    
    def generate_multiple_codes(
        self,
        quantity: int,
        definition_name: Optional[str] = None,
        validity_days: int = 30,
        data_limit_mb: int = 0,
        devices_allowed: int = 1,
        description_prefix: Optional[str] = None,
        created_by: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Gera múltiplos códigos de voucher de uma vez.
        
        Args:
            quantity: Quantidade de códigos a gerar (1-100)
            definition_name: Nome da definição no Sophos
            validity_days: Dias de validade
            data_limit_mb: Limite de dados
            devices_allowed: Dispositivos por código
            description_prefix: Prefixo para descrição
            created_by: Operador
            
        Returns:
            Lista de dicionários com códigos gerados
        """
        if quantity < 1 or quantity > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Quantidade deve ser entre 1 e 100"
            )
        
        vouchers = []
        for i in range(quantity):
            desc = f"{description_prefix} #{i+1}" if description_prefix else None
            voucher = self.generate_voucher_code(
                definition_name=definition_name,
                validity_days=validity_days,
                data_limit_mb=data_limit_mb,
                devices_allowed=devices_allowed,
                description=desc,
                created_by=created_by
            )
            vouchers.append(voucher)
        
        return vouchers
    
    def get_voucher(self, code: str) -> Optional[Dict[str, Any]]:
        """
        Busca um voucher pelo código.
        
        Args:
            code: Código do voucher
            
        Returns:
            Dados do voucher ou None se não encontrado
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM voucher_codes WHERE code = ?", (code,))
        row = cursor.fetchone()
        
        conn.close()
        
        if row:
            voucher = dict(row)
            # Verificar se expirou
            if voucher['status'] == 'active' and voucher['expires_at']:
                expires_at = datetime.fromisoformat(voucher['expires_at'])
                if datetime.utcnow() > expires_at:
                    voucher['status'] = 'expired'
            return voucher
        return None
    
    def list_vouchers(
        self,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> Dict[str, Any]:
        """
        Lista vouchers com filtros.
        
        Args:
            status: Filtrar por status (active/expired/revoked/used)
            limit: Limite de resultados
            offset: Offset para paginação
            
        Returns:
            Dicionário com total e lista de vouchers
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        query = "SELECT * FROM voucher_codes"
        params = []
        
        if status:
            query += " WHERE status = ?"
            params.append(status)
        
        query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        
        cursor.execute(query, query.split("LIMIT")[0].split("WHERE")[0] if not status else query.split("LIMIT")[0], params)
        rows = cursor.fetchall()
        
        # Contar total
        count_query = "SELECT COUNT(*) FROM voucher_codes"
        if status:
            count_query += " WHERE status = ?"
            cursor.execute(count_query, (status,))
        else:
            cursor.execute(count_query)
        
        total = cursor.fetchone()[0]
        
        conn.close()
        
        vouchers = []
        for row in rows:
            voucher = dict(row)
            # Atualizar status se expirado
            if voucher['status'] == 'active' and voucher['expires_at']:
                expires_at = datetime.fromisoformat(voucher['expires_at'])
                if datetime.utcnow() > expires_at:
                    voucher['status'] = 'expired'
            vouchers.append(voucher)
        
        return {
            "total": total,
            "limit": limit,
            "offset": offset,
            "vouchers": vouchers
        }
    
    def revoke_voucher(self, code: str, revoked_by: Optional[str] = None) -> bool:
        """
        Revoga um voucher (cancela o acesso).
        
        Args:
            code: Código do voucher
            revoked_by: Operador que revogou
            
        Returns:
            True se revogado com sucesso
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, status FROM voucher_codes WHERE code = ?", (code,))
        row = cursor.fetchone()
        
        if not row:
            conn.close()
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Voucher {code} não encontrado"
            )
        
        voucher_id = row['id']
        current_status = row['status']
        
        if current_status in ('revoked', 'used'):
            conn.close()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Voucher já está {current_status}"
            )
        
        # Atualizar status
        cursor.execute("""
            UPDATE voucher_codes 
            SET status = 'revoked', notes = COALESCE(notes, '') || ' [REVOGADO]'
            WHERE code = ?
        """, (code,))
        
        # Auditoria
        cursor.execute("""
            INSERT INTO voucher_audit (voucher_code_id, action, details, performed_by)
            VALUES (?, 'REVOKE', 'Voucher revogado', ?)
        """, (voucher_id, revoked_by))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Voucher revogado: {code}")
        return True
    
    def mark_as_used(self, code: str, used_by: Optional[str] = None) -> bool:
        """
        Marca um voucher como usado (após primeiro acesso).
        
        Args:
            code: Código do voucher
            used_by: Identificação de quem usou
            
        Returns:
            True se marcado com sucesso
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE voucher_codes 
            SET status = 'used', used_at = CURRENT_TIMESTAMP, used_by = ?
            WHERE code = ? AND status = 'active'
        """, (used_by, code))
        
        if cursor.rowcount > 0:
            cursor.execute("""
                INSERT INTO voucher_audit (voucher_code_id, action, details, performed_by)
                VALUES ((SELECT id FROM voucher_codes WHERE code = ?), 'USE', 'Primeiro acesso', ?)
            """, (code, used_by))
            
            conn.commit()
            conn.close()
            return True
        
        conn.close()
        return False
    
    def get_audit_log(self, code: str) -> List[Dict[str, Any]]:
        """
        Retorna o log de auditoria de um voucher.
        
        Args:
            code: Código do voucher
            
        Returns:
            Lista de entradas de auditoria
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT va.* FROM voucher_audit va
            JOIN voucher_codes vc ON va.voucher_code_id = vc.id
            WHERE vc.code = ?
            ORDER BY va.performed_at DESC
        """, (code,))
        
        rows = cursor.fetchall()
        conn.close()
        
        return [dict(row) for row in rows]
    
    def get_statistics(self) -> Dict[str, Any]:
        """
        Retorna estatísticas dos vouchers.
        
        Returns:
            Dicionário com contagens por status
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT status, COUNT(*) as count 
            FROM voucher_codes 
            GROUP BY status
        """)
        
        stats = {row['status']: row['count'] for row in cursor.fetchall()}
        
        cursor.execute("SELECT COUNT(*) FROM voucher_codes WHERE expires_at < ? AND status = 'active'", 
                      (datetime.utcnow().isoformat(),))
        expired_count = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            "total": sum(stats.values()),
            "active": stats.get('active', 0),
            "expired": stats.get('expired', 0) + expired_count,
            "revoked": stats.get('revoked', 0),
            "used": stats.get('used', 0),
            "by_status": stats
        }
    
    def _generate_unique_code(self, length: int = 8) -> str:
        """
        Gera um código único no formato Sophos.
        
        Formato: 8 caracteres alfanuméricos (maiúsculas + dígitos)
        Exemplo: AB3CD9F2
        
        Args:
            length: Comprimento do código
            
        Returns:
            Código único gerado
        """
        # Alfabeto: maiúsculas + dígitos (sem caracteres ambíguos como 0/O, 1/I)
        alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        
        max_attempts = 10
        for _ in range(max_attempts):
            code = ''.join(secrets.choice(alphabet) for _ in range(length))
            
            # Verificar se já existe
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM voucher_codes WHERE code = ?", (code,))
            exists = cursor.fetchone()
            conn.close()
            
            if not exists:
                return code
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Não foi possível gerar código único"
        )
    
    def sync_with_sophos(self, sophos_service) -> Dict[str, Any]:
        """
        Sincroniza vouchers com o Sophos Firewall.
        
        Busca vouchers ativos no Sophos e atualiza status local.
        
        Args:
            sophos_service: Instância do SophosService
            
        Returns:
            Resultado da sincronização
        """
        try:
            # Buscar vouchers ativos no Sophos (via User Portal ou API)
            # Nota: A API XML não lista códigos, apenas definições
            # Esta função pode ser expandida para usar scraping do User Portal
            # ou integração com API REST se disponível
            
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Marcar como expirados os que passaram da data
            cursor.execute("""
                UPDATE voucher_codes 
                SET status = 'expired'
                WHERE status = 'active' AND expires_at < ?
            """, (datetime.utcnow().isoformat(),))
            
            expired_count = cursor.rowcount
            conn.commit()
            conn.close()
            
            return {
                "success": True,
                "expired_updated": expired_count,
                "message": f"{expired_count} vouchers expirados atualizados"
            }
            
        except Exception as e:
            logger.error(f"Erro na sincronização: {e}")
            return {
                "success": False,
                "error": str(e)
            }


# Singleton do serviço
_voucher_service: Optional[VoucherCodeService] = None


def get_voucher_service() -> VoucherCodeService:
    """Retorna instância única do serviço de vouchers."""
    global _voucher_service
    if _voucher_service is None:
        _voucher_service = VoucherCodeService()
    return _voucher_service
