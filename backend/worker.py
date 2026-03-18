"""
wave. — Celery worker
Background tasks for downloading and processing audio.
"""

import os
from celery import Celery
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Redis URL from environment
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
DATA_DIR = os.environ.get("DATA_DIR", "./data")

# Celery app
celery_app = Celery(
    "wave",
    broker=REDIS_URL,
    backend=REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    result_expires=3600,  # Results expire after 1 hour
)

# Database session for worker (separate from FastAPI's)
DATABASE_URL = f"sqlite:///{DATA_DIR}/wave.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
WorkerSession = sessionmaker(bind=engine)


@celery_app.task(bind=True, name="download_track_task")
def download_track_task(self, internal_id: str, quality: str):
    """
    Background task: download, convert, and sanitize a track.
    Updates progress via Celery state.
    """
    from models import TrackMapping
    from services.downloader import download_track

    # Update progress: started
    self.update_state(state="PROGRESS", meta={"progress": 10})

    # Get track mapping from DB
    session = WorkerSession()
    try:
        mapping = session.query(TrackMapping).filter(
            TrackMapping.internal_id == internal_id
        ).first()

        if not mapping:
            raise ValueError("Track mapping not found")

        self.update_state(state="PROGRESS", meta={"progress": 20})

        # Download and process
        # source_video_id is used ONLY internally — never exposed
        output_path = download_track(
            source_video_id=mapping.source_video_id,
            internal_id=mapping.internal_id,
            title=mapping.title,
            artist=mapping.artist,
            album=mapping.album,
            quality=quality,
            source_thumbnail_url=mapping.source_thumbnail_url,
        )

        self.update_state(state="PROGRESS", meta={"progress": 90})

        # Verify file exists
        if not os.path.exists(output_path):
            raise FileNotFoundError("Output file not created")

        self.update_state(state="PROGRESS", meta={"progress": 100})

        return {
            "internal_id": internal_id,
            "status": "done",
            "progress": 100,
        }

    except Exception as e:
        # Log internally but never expose details
        print(f"[wave worker] Download failed for {internal_id}: {str(e)}")
        raise
    finally:
        session.close()
