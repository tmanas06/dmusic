"""
wave. — Artwork routes
GET /art/{id} — serve proxied artwork images with cache headers.
"""

import os
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

DATA_DIR = os.environ.get("DATA_DIR", "./data")
ART_DIR = os.path.join(DATA_DIR, "art")

router = APIRouter()


@router.get("/art/{track_id}")
async def serve_artwork(track_id: str):
    """
    Serve the proxied artwork image.
    All artwork is served from our domain — client never sees external URLs.
    Cache for 7 days.
    """
    filepath = os.path.join(ART_DIR, f"{track_id}.jpg")

    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Artwork not found.")

    return FileResponse(
        path=filepath,
        media_type="image/jpeg",
        headers={
            "Cache-Control": "public, max-age=604800",  # 7 days
        },
    )
