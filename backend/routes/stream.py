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

from httpx_client import client as shared_client

router = APIRouter()

@router.get("/file/{track_id}")
async def stream_file(
    track_id: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Stream the audio file. If not downloaded locally, proxies a direct stream URL with Range support.
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

    # Fallback to optimized direct streaming from YouTube (Proxy with Range support)
    stream_url = get_direct_stream_url(mapping.source_video_id)
    if not stream_url:
        raise HTTPException(status_code=404, detail="Streaming not available yet.")

    # Forward the Range header from client to upstream
    range_header = request.headers.get("Range")
    headers = {}
    if range_header:
        headers["Range"] = range_header

    # Initiate stream from upstream
    try:
        # Using a very long timeout for streaming
        req = shared_client.build_request("GET", stream_url, headers=headers)
        response = await shared_client.send(req, stream=True)
        
        # Determine status code (206 if range, 200 otherwise)
        status_code = response.status_code
        
        # Forward relevant headers back to client
        response_headers = {
            "Content-Type": response.headers.get("Content-Type", "audio/mpeg"),
            "Accept-Ranges": "bytes",
        }
        
        if "Content-Range" in response.headers:
            response_headers["Content-Range"] = response.headers["Content-Range"]
        if "Content-Length" in response.headers:
            response_headers["Content-Length"] = response.headers["Content-Length"]

        # Stream bit-by-bit
        async def stream_generator():
            try:
                async for chunk in response.aiter_bytes(chunk_size=16384 * 2):
                    yield chunk
            finally:
                await response.aclose()

        return StreamingResponse(
            stream_generator(), 
            status_code=status_code,
            headers=response_headers,
            media_type="audio/mpeg"
        )
    except Exception as e:
        print(f"[wave] Streaming error: {e}")
        raise HTTPException(status_code=500, detail="Playback failed due to network error.")
