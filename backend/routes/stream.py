"""
wave. — File streaming routes
GET /file/{id} — stream the downloaded MP3 to the client.
"""

import os
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session
import httpx

from database import get_db
from models import TrackMapping
from services.streamer import get_direct_stream_url

DATA_DIR = os.environ.get("DATA_DIR", "./data")
AUDIO_DIR = os.path.join(DATA_DIR, "audio")

router = APIRouter()


@router.get("/file/{track_id}")
async def stream_file(
    track_id: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Stream the audio file. If not downloaded locally, proxies a direct stream URL.
    This ensures 'listen then download' flow works immediately and bypasses CORS/redirect issues.
    """
    # Look up track
    mapping = db.query(TrackMapping).filter(
        TrackMapping.internal_id == track_id
    ).first()

    if not mapping:
        raise HTTPException(status_code=404, detail="Track not found.")

    # Check if local file exists
    filepath = os.path.join(AUDIO_DIR, f"{track_id}.mp3")
    if os.path.exists(filepath):
        safe_title = mapping.title.replace('"', "'")
        safe_artist = mapping.artist.replace('"', "'")
        filename = f"{safe_title} - {safe_artist}.mp3"

        return FileResponse(
            path=filepath,
            media_type="audio/mpeg",
            filename=filename,
            headers={
                "Content-Disposition": f'inline; filename="{filename}"',
            },
        )

    # Fallback to direct streaming from YouTube (Proxy)
    stream_url = get_direct_stream_url(mapping.source_video_id)
    if not stream_url:
        raise HTTPException(status_code=404, detail="Streaming not available yet.")

    # Return a StreamingResponse that proxies the URL
    async def stream_proxy():
        async with httpx.AsyncClient() as client:
            async with client.stream("GET", stream_url) as response:
                async for chunk in response.aiter_bytes():
                    yield chunk

    return StreamingResponse(stream_proxy(), media_type="audio/mpeg")
