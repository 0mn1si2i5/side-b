from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services import user_service

router = APIRouter()


class UserLookupResponse(BaseModel):
    id: str
    username: str
    displayName: str
    avatarName: str

    class Config:
        from_attributes = True


def _user_to_lookup_response(user: User) -> UserLookupResponse:
    return UserLookupResponse(
        id=user.id,
        username=user.username,
        displayName=user.display_name,
        avatarName=user.avatar_name,
    )


@router.get("/{username}", response_model=UserLookupResponse)
def lookup_user(
    username: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    found = user_service.get_user_by_username(db, username)
    if found is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return _user_to_lookup_response(found)
