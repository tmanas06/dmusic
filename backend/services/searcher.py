"""
wave. — Search service (wraps ytmusicapi)
All source references stay server-side. Client only sees wave internal IDs.
"""

import os
import uuid
import httpx
from typing import List, Optional
from sqlalchemy.orm import Session

from models import TrackMapping, TrackResponse

DATA_DIR = os.environ.get("DATA_DIR", "./data")
ART_DIR = os.path.join(DATA_DIR, "art")
os.makedirs(ART_DIR, exist_ok=True)


def _generate_internal_id() -> str:
    """Generate a unique wave internal ID."""
    return f"wv_{uuid.uuid4().hex[:12]}"


def _get_best_thumbnail(thumbnails: list) -> Optional[str]:
    """Pick the highest-resolution thumbnail URL from ytmusicapi results."""
    if not thumbnails:
        return None
    # ytmusicapi returns thumbnails sorted by size; pick the largest
    return thumbnails[-1].get("url", thumbnails[0].get("url"))


async def _download_artwork(url: str, internal_id: str) -> str:
    """Download artwork image and save locally. Returns filename."""
    filename = f"{internal_id}.jpg"
    filepath = os.path.join(ART_DIR, filename)
    
    if os.path.exists(filepath):
        return filename

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                with open(filepath, "wb") as f:
                    f.write(resp.content)
                return filename
    except Exception:
        pass  # If artwork download fails, we continue without it
    
    return ""


async def search_tracks(query: str, db: Session, base_url: str) -> List[TrackResponse]:
    """
    Search for tracks using ytmusicapi.
    Maps results to internal schema, stores mapping in DB.
    Returns ONLY internal wave data — zero source references.
    """
    try:
        from ytmusicapi import YTMusic
        ytmusic = YTMusic()
        raw_results = ytmusic.search(query, filter="songs", limit=20)
    except Exception:
        return []

    tracks: List[TrackResponse] = []

    for item in raw_results:
        if not item.get("videoId"):
            continue

        source_video_id = item["videoId"]

        # Check if we already have a mapping for this source video
        existing = db.query(TrackMapping).filter(
            TrackMapping.source_video_id == source_video_id
        ).first()

        if existing:
            internal_id = existing.internal_id
        else:
            internal_id = _generate_internal_id()

            # Extract metadata
            title = item.get("title", "Unknown")
            artists = item.get("artists", [])
            artist_name = artists[0]["name"] if artists else "Unknown Artist"
            album_info = item.get("album")
            album_name = album_info.get("name", "") if album_info else ""
            
            # Duration
            duration_text = item.get("duration", "0:00")
            duration_seconds = _parse_duration(duration_text)

            # Download artwork
            thumbnail_url = _get_best_thumbnail(item.get("thumbnails", []))
            artwork_filename = ""
            if thumbnail_url:
                artwork_filename = await _download_artwork(thumbnail_url, internal_id)

            # Store mapping in DB (source_video_id NEVER leaves the backend)
            mapping = TrackMapping(
                internal_id=internal_id,
                source_video_id=source_video_id,
                title=title,
                artist=artist_name,
                album=album_name,
                duration_seconds=duration_seconds,
                artwork_filename=artwork_filename,
            )
            db.add(mapping)
            db.commit()

            existing = mapping

        # Build response (NO source references)
        tracks.append(TrackResponse(
            id=existing.internal_id,
            title=existing.title,
            artist=existing.artist,
            album=existing.album,
            duration_seconds=existing.duration_seconds,
            artwork_url=f"{base_url}/art/{existing.internal_id}",
            quality_available=existing.quality_available.split(","),
        ))

    return tracks


def _parse_duration(duration_str: str) -> int:
    """Parse duration string like '3:45' or '1:02:30' to seconds."""
    if not duration_str:
        return 0
    try:
        parts = duration_str.split(":")
        if len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])
        elif len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    except (ValueError, IndexError):
        pass
    return 0
