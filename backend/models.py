"""
wave. — Data models (SQLAlchemy ORM + Pydantic schemas)
Maps internal wave IDs to source video IDs. Source references NEVER leave the backend.
"""

from sqlalchemy import Column, String, Integer, DateTime, func
from database import Base
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


# ──────────────────────────────────────────────
# SQLAlchemy ORM model (internal DB only)
# ──────────────────────────────────────────────

class TrackMapping(Base):
    """Maps wave internal IDs to source video IDs. Never exposed to the client."""
    __tablename__ = "track_mappings"

    internal_id = Column(String, primary_key=True, index=True)    # wv_xxxxx
    source_video_id = Column(String, nullable=False)               # yt video id (NEVER sent to client)
    title = Column(String, nullable=False)
    artist = Column(String, nullable=False)
    album = Column(String, default="")
    duration_seconds = Column(Integer, default=0)
    artwork_filename = Column(String, default="")                  # local filename in /data/art/
    quality_available = Column(String, default="128kbps,256kbps,320kbps")
    created_at = Column(DateTime, server_default=func.now())


# ──────────────────────────────────────────────
# Pydantic schemas (client-facing — NO source fields)
# ──────────────────────────────────────────────

class TrackResponse(BaseModel):
    """Track data sent to Flutter. Zero source references."""
    id: str
    title: str
    artist: str
    album: str
    duration_seconds: int
    artwork_url: str
    quality_available: List[str]

    class Config:
        from_attributes = True


class DownloadRequest(BaseModel):
    id: str
    quality: str = "320kbps"


class DownloadResponse(BaseModel):
    job_id: str
    status: str = "queued"


class JobStatusResponse(BaseModel):
    status: str          # pending | processing | done | failed
    progress: int = 0    # 0-100


class ErrorResponse(BaseModel):
    """Generic error — never expose internal details."""
    detail: str
