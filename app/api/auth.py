from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm

from app.core.limiter import limiter
from app.core.security import authenticate_user, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])

# Tighter limit than general API traffic — mitigates credential-stuffing /
# brute-force attempts against the token endpoint (found during Milestone 3
# pentest, remediated here).
LOGIN_RATE_LIMIT = "5/minute"


@router.post("/token")
@limiter.limit(LOGIN_RATE_LIMIT)
def login_for_access_token(request: Request, form_data: OAuth2PasswordRequestForm = Depends()):
    """
    OAuth2 password flow token issuance.

    NOTE: intended for service-to-service / internal clients (ML Engineer
    role, CI/CD pipelines). Human-facing access should be migrated to
    Azure AD (Entra ID) with OIDC before production go-live.
    """
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token(user)
    return {"access_token": token, "token_type": "bearer"}
