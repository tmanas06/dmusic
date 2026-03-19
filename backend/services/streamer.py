import time
import yt_dlp
from typing import Optional, Dict, Tuple

# Simple in-memory cache for stream URLs: {source_video_id: (url, expiry_timestamp)}
_stream_cache: Dict[str, Tuple[str, float]] = {}
CACHE_EXPIRY = 3600  # 1 hour

def get_direct_stream_url(source_video_id: str) -> Optional[str]:
    """
    Get a direct audio-only stream URL from YouTube using yt-dlp with caching.
    """
    now = time.time()
    
    # Check cache
    if source_video_id in _stream_cache:
        url, expiry = _stream_cache[source_video_id]
        if now < expiry:
            return url

    ydl_opts = {
        "format": "bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "nocheckcertificate": True,
        "skip_download": True,
        "extract_flat": False,
        "family": "ipv4", # Often faster than ipv6 for specific regions
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"https://www.youtube.com/watch?v={source_video_id}", download=False)
            url = info.get("url")
            if url:
                # Cache for almost 1 hour
                _stream_cache[source_video_id] = (url, now + CACHE_EXPIRY - 300)
                return url
    except Exception:
        pass
        
    return None
