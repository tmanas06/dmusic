"""
wave. — Download routes
POST /download — enqueue download job
GET /download-status/{job_id} — check job progress
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import DownloadRequest, DownloadResponse, JobStatusResponse, TrackMapping

router = APIRouter()


@router.post("/download", response_model=DownloadResponse)
async def request_download(
    body: DownloadRequest,
    db: Session = Depends(get_db),
):
    """
    Enqueue a download job for a track.
    The client only provides the internal wave ID + desired quality.
    """
    # Look up the track mapping
    mapping = db.query(TrackMapping).filter(
        TrackMapping.internal_id == body.id
    ).first()

    if not mapping:
        raise HTTPException(status_code=404, detail="Track not found.")

    # Validate quality
    available = mapping.quality_available.split(",")
    quality = body.quality if body.quality in available else "320kbps"

    try:
        # Import here to avoid circular imports with Celery
        from worker import download_track_task

        task = download_track_task.delay(
            internal_id=mapping.internal_id,
            quality=quality,
        )

        return DownloadResponse(
            job_id=task.id,
            status="queued",
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Download failed. Please try again.",
        )


@router.get("/download-status/{job_id}", response_model=JobStatusResponse)
async def download_status(job_id: str):
    """
    Check the status of a download job.
    Returns generic status — no internal details exposed.
    """
    try:
        from worker import celery_app

        result = celery_app.AsyncResult(job_id)

        if result.state == "PENDING":
            return JobStatusResponse(status="pending", progress=0)
        elif result.state == "PROGRESS":
            info = result.info or {}
            return JobStatusResponse(
                status="processing",
                progress=info.get("progress", 0),
            )
        elif result.state == "SUCCESS":
            return JobStatusResponse(status="done", progress=100)
        elif result.state == "FAILURE":
            return JobStatusResponse(status="failed", progress=0)
        else:
            return JobStatusResponse(status="processing", progress=0)

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Status check failed. Please try again.",
        )
