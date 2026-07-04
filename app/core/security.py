"""
JWT-based authentication (OAuth2 password flow) for the inference API.

Design notes for the security review:
- Access tokens are short-lived (default 15 min, see Settings.ACCESS_TOKEN_EXPIRE_MINUTES)
- Tokens are signed with HS256 using a secret resolved from Azure Key Vault
- Passwords are never stored in plaintext; bcrypt hashing via passlib
- Role claims are embedded in the token for coarse-grained authorization
  (e.g. "ml_engineer" vs "service_client") aligned with the least-privilege
  access policy defined in Milestone 1.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from app.core.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")


class TokenData(BaseModel):
    subject: str
    role: str


# --------------------------------------------------------------------------
# Demo user "directory" — in production this MUST be replaced by a real
# identity provider (Azure AD / Entra ID) instead of a local user table.
# Passwords below are bcrypt hashes, never plaintext.
# --------------------------------------------------------------------------
_FAKE_USER_DB = {
    "svc-ml-engineer": {
        "role": "ml_engineer",
        # hash of a placeholder password, replace via Key Vault-managed secret rotation
        "hashed_password": pwd_context.hash("CHANGE_ME_IN_PRODUCTION"),
    }
}


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def authenticate_user(username: str, password: str) -> Optional[TokenData]:
    user = _FAKE_USER_DB.get(username)
    if not user or not verify_password(password, user["hashed_password"]):
        return None
    return TokenData(subject=username, role=user["role"])


def create_access_token(data: TokenData) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": data.subject, "role": data.role, "exp": expire}
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenData:
    settings = get_settings()
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        username: str = payload.get("sub")
        role: str = payload.get("role")
        if username is None or role is None:
            raise credentials_exception
        return TokenData(subject=username, role=role)
    except JWTError:
        raise credentials_exception


def require_role(*allowed_roles: str):
    """Dependency factory for coarse-grained, role-based authorization."""

    def _checker(current_user: TokenData = Depends(get_current_user)) -> TokenData:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this resource",
            )
        return current_user

    return _checker
