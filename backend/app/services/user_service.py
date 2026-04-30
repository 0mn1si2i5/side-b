import hashlib
from datetime import datetime, timedelta, timezone

import jwt
from jwt.exceptions import InvalidTokenError as JWTError
import bcrypt
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User


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
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
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


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))


def authenticate_user(db: Session, username: str, password: str) -> User | None:
    user = get_user_by_username(db, username)
    if user is None:
        return None
    if not bcrypt.checkpw(password.encode('utf-8'), user.hashed_password.encode('utf-8')):
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


def update_profile(
    db: Session,
    user_id: str,
    *,
    display_name: str | None = None,
    avatar_name: str | None = None,
    preferred_platform: str | None = None,
) -> User | None:
    user = get_user_by_id(db, user_id)
    if user is None:
        return None
    if display_name is not None:
        user.display_name = display_name
    if avatar_name is not None:
        user.avatar_name = avatar_name
    user.preferred_platform = preferred_platform
    db.commit()
    db.refresh(user)
    return user


def update_password(db: Session, user_id: str, new_password: str) -> User | None:
    user = get_user_by_id(db, user_id)
    if user is None:
        return None
    user.hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
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
