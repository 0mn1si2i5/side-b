import hashlib
from datetime import datetime, timedelta, timezone

from jose import jwt, JWTError
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def get_user_by_username(db: Session, username: str) -> User | None:
    return db.query(User).filter(User.username == username).first()


def get_user_by_id(db: Session, user_id: str) -> User | None:
    return db.query(User).filter(User.id == user_id).first()


def create_user(
    db: Session,
    username: str,
    password: str,
    display_name: str,
    avatar_name: str,
) -> User:
    hashed_password = pwd_context.hash(password)
    user = User(
        username=username,
        display_name=display_name,
        avatar_name=avatar_name,
        hashed_password=hashed_password,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, username: str, password: str) -> User | None:
    user = get_user_by_username(db, username)
    if user is None:
        return None
    if not pwd_context.verify(password, user.hashed_password):
        return None
    return user


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.JWT_EXPIRATION_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def update_preferred_platform(
    db: Session, user_id: str, platform: str | None
) -> User | None:
    user = get_user_by_id(db, user_id)
    if user is None:
        return None
    user.preferred_platform = platform
    db.commit()
    db.refresh(user)
    return user


def update_password(db: Session, user_id: str, new_password: str) -> User | None:
    user = get_user_by_id(db, user_id)
    if user is None:
        return None
    user.hashed_password = pwd_context.hash(new_password)
    db.commit()
    db.refresh(user)
    return user


def verify_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError:
        return None


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def revoke_token(db: Session, token: str) -> None:
    from app.models.revoked_token import RevokedToken

    token_hash = hash_token(token)
    if not db.query(RevokedToken).filter(RevokedToken.token_hash == token_hash).first():
        db.add(RevokedToken(token_hash=token_hash))
        db.commit()


def is_token_revoked(db: Session, token: str) -> bool:
    from app.models.revoked_token import RevokedToken

    return db.query(RevokedToken).filter(RevokedToken.token_hash == hash_token(token)).first() is not None
