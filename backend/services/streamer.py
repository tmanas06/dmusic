import yt_dlp
from typing import Optional

def get_direct_stream_url(source_video_id: str) -> Optional[str]:
    """
    Get a direct audio-only stream URL from YouTube using yt-dlp.
    Returns the URL which can be used by the Flutter app for streaming.
    
    NOTE: This URL is direct from Google servers, but we are keeping our 
    internal track IDs and schema in the client.
    """
    ydl_opts = {
        "format": "bestaudio/best",
        "quiet": True,
        "no_warnings": True,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"https://www.youtube.com/watch?v={source_video_id}", download=False)
            return info.get("url")
    except Exception:
        return None
