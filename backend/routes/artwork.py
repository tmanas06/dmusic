"""
wave. — Artwork routes
GET /art/{id} — serve proxied artwork images with cache headers.
"""

import os
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse, RedirectResponse
from sqlalchemy.orm import Session

from database import get_db
from models import TrackMapping

DATA_DIR = os.environ.get("DATA_DIR", "./data")
ART_DIR = os.path.join(DATA_DIR, "art")

router = APIRouter()


@router.get("/art/{track_id}")
async def serve_artwork(
    track_id: str,
    db: Session = Depends(get_db),
):
    """
    Serve the proxied artwork image. If not downloaded, redirects to source URL.
    This keeps the UI dynamic and saves server storage for temporary search results.
    """
    filepath = os.path.join(ART_DIR, f"{track_id}.jpg")

    if os.path.exists(filepath):
        return FileResponse(
            path=filepath,
            media_type="image/jpeg",
            headers={
                "Cache-Control": "public, max-age=604800",  # 7 days
            },
        )

    # If not downloaded, redirect to original source
    mapping = db.query(TrackMapping).filter(TrackMapping.internal_id == track_id).first()
    if mapping and mapping.source_thumbnail_url:
        return RedirectResponse(url=mapping.source_thumbnail_url)

    raise HTTPException(status_code=404, detail="Artwork not found.")
