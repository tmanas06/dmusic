"""
wave. — Search routes
GET /search?q={query} — returns tracks in internal wave schema.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import TrackResponse
from services.searcher import search_tracks, get_trending_tracks

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
    except Exception as e:
        import traceback
        traceback.print_exc()
        # Generic error — never expose internal details
        raise HTTPException(
            status_code=500,
            detail="Search failed. Please try again.",
        )


@router.get("/trending", response_model=List[TrackResponse])
async def trending(
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Get trending tracks. Returns wave internal schema only.
    """
    try:
        base_url = str(request.base_url).rstrip("/")
        results = await get_trending_tracks(db=db, base_url=base_url)
        return results
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Failed to fetch trending tracks.",
        )


@router.get("/moods")
async def get_moods():
    """
    Get dynamic mood categories with premium background images.
    Stored on CDNs (somewhere else) to keep the app lightweight.
    """
    return [
        {
            "title": "Late Night",
            "emoji": "🌙",
            "query": "late night lo-fi beats", 
            "colors": ["#1A1B4B", "#2D325A"],
            "image": "https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=400&q=80"
        },
        {
            "title": "Energy",
            "emoji": "🔥",
            "query": "high energy gym motivation",
            "colors": ["#4B1A1A", "#5A2D2D"],
            "image": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=400&q=80"
        },
        {
            "title": "Chill", 
            "emoji": "💜",
            "query": "chill aesthetic vibes",
            "colors": ["#1A4B4B", "#2D5A5A"],
            "image": "https://images.unsplash.com/photo-1494232410401-ad00d5433cfa?auto=format&fit=crop&w=400&q=80"
        },
        {
            "title": "Focus",
            "emoji": "🌿",
            "query": "deep focus ambient music",
            "colors": ["#1A4B1A", "#2D5A2D"],
            "image": "https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=400&q=80"
        },
        {
            "title": "Party",
            "emoji": "🎉",
            "query": "house party hits",
            "colors": ["#4B1A4B", "#5A2D5A"],
            "image": "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=400&q=80"
        },
    ]
