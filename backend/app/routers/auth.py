from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.services import user_service

router = APIRouter()

AVAILABLE_AVATARS = [f"avatar_{i}" for i in range(1, 13)]


class RegisterRequest(BaseModel):
    username: str
    password: str
    displayName: str
    avatarName: str


class LoginRequest(BaseModel):
    username: str
    password: str


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
def register(req: RegisterRequest, db: Session = Depends(get_db)):
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
def login(req: LoginRequest, db: Session = Depends(get_db)):
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


@router.get("/avatars")
def get_avatars():
    return {"avatars": AVAILABLE_AVATARS}
