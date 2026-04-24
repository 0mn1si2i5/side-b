from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.main import limiter
from app.services import user_service

router = APIRouter()

AVAILABLE_AVATARS = [f"avatar_{i}" for i in range(1, 13)]


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=30)
    password: str = Field(min_length=8, max_length=128)
    displayName: str = Field(min_length=1, max_length=50)
    avatarName: str


class LoginRequest(BaseModel):
    username: str
    password: str


class UpdateProfileRequest(BaseModel):
    preferredPlatform: str | None = None


class UserResponse(BaseModel):
    id: str
    username: str
    displayName: str
    avatarName: str
    preferredPlatform: str | None = None

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    user: UserResponse
    token: str


def _user_to_response(user) -> UserResponse:
    return UserResponse(
        id=user.id,
        username=user.username,
        displayName=user.display_name,
        avatarName=user.avatar_name,
        preferredPlatform=user.preferred_platform,
    )


@router.post("/register", response_model=AuthResponse)
@limiter.limit("3/minute")
def register(request: Request, req: RegisterRequest, db: Session = Depends(get_db)):
    existing = user_service.get_user_by_username(db, req.username)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered",
        )
    if req.avatarName not in AVAILABLE_AVATARS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid avatar name. Choose from: {AVAILABLE_AVATARS}",
        )
    user = user_service.create_user(
        db=db,
        username=req.username,
        password=req.password,
        display_name=req.displayName,
        avatar_name=req.avatarName,
    )
    token = user_service.create_access_token(data={"sub": user.id})
    return AuthResponse(user=_user_to_response(user), token=token)


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
def login(request: Request, req: LoginRequest, db: Session = Depends(get_db)):
    user = user_service.authenticate_user(db, req.username, req.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    token = user_service.create_access_token(data={"sub": user.id})
    return AuthResponse(user=_user_to_response(user), token=token)


@router.get("/me", response_model=UserResponse)
def get_me(user=Depends(get_current_user)):
    return _user_to_response(user)


VALID_PLATFORMS = {"apple_music", "spotify", "qq_music", "netease_music"}


@router.put("/me", response_model=UserResponse)
def update_profile(
    req: UpdateProfileRequest,
    user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.preferredPlatform is not None and req.preferredPlatform not in VALID_PLATFORMS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid platform. Choose from: {sorted(VALID_PLATFORMS)}",
        )
    updated = user_service.update_preferred_platform(
        db, user.id, req.preferredPlatform
    )
    return _user_to_response(updated)


@router.get("/avatars")
def get_avatars():
    return {"avatars": AVAILABLE_AVATARS}
