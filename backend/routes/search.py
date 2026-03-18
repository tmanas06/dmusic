"""
wave. — Search routes
GET /search?q={query} — returns tracks in internal wave schema.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import TrackResponse
from services.searcher import search_tracks

router = APIRouter()


@router.get("/search", response_model=List[TrackResponse])
async def search(
    request: Request,
    q: str = Query(..., min_length=1, max_length=200, description="Search query"),
    db: Session = Depends(get_db),
):
    """
    Search for tracks. Returns wave internal schema only.
    No source references are ever included in the response.
    """
    try:
        base_url = str(request.base_url).rstrip("/")
        results = await search_tracks(query=q, db=db, base_url=base_url)
        return results
    except Exception:
        # Generic error — never expose internal details
        raise HTTPException(
            status_code=500,
            detail="Search failed. Please try again.",
        )
