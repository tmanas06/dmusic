"""
wave. — Proxy service
Proxies thumbnails through our domain. Client never sees external image URLs.
"""

import os
import httpx
from typing import Optional

DATA_DIR = os.environ.get("DATA_DIR", "./data")
ART_DIR = os.path.join(DATA_DIR, "art")
os.makedirs(ART_DIR, exist_ok=True)


async def proxy_artwork(source_url: str, internal_id: str) -> Optional[str]:
    """
    Download artwork from source URL and save locally.
    Returns local filename or None on failure.
    """
    filename = f"{internal_id}.jpg"
    filepath = os.path.join(ART_DIR, filename)

    # Return cached version if exists
    if os.path.exists(filepath):
        return filename

    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            resp = await client.get(source_url)
            if resp.status_code == 200 and len(resp.content) > 0:
                with open(filepath, "wb") as f:
                    f.write(resp.content)
                return filename
    except Exception:
        pass  # Silently fail — artwork is non-critical

    return None


def get_artwork_path(internal_id: str) -> Optional[str]:
    """Get the local filesystem path for cached artwork."""
    filepath = os.path.join(ART_DIR, f"{internal_id}.jpg")
    if os.path.exists(filepath):
        return filepath
    return None
