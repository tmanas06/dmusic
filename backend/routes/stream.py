"""
wave. — File streaming routes
GET /file/{id} — stream the downloaded MP3 to the client.
"""

import os
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from database import get_db
from models import TrackMapping

DATA_DIR = os.environ.get("DATA_DIR", "./data")
AUDIO_DIR = os.path.join(DATA_DIR, "audio")

router = APIRouter()


@router.get("/file/{track_id}")
async def stream_file(
    track_id: str,
    db: Session = Depends(get_db),
):
    """
    Stream the audio file for download to the phone.
    Content-Disposition header uses clean title — no source references.
    """
    # Look up track
    mapping = db.query(TrackMapping).filter(
        TrackMapping.internal_id == track_id
    ).first()

    if not mapping:
        raise HTTPException(status_code=404, detail="Track not found.")

    # Check if file exists
    filepath = os.path.join(AUDIO_DIR, f"{track_id}.mp3")
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="File not ready yet.")

    # Clean filename for Content-Disposition
    safe_title = mapping.title.replace('"', "'")
    safe_artist = mapping.artist.replace('"', "'")
    filename = f"{safe_title} - {safe_artist}.mp3"

    return FileResponse(
        path=filepath,
        media_type="audio/mpeg",
        filename=filename,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )
