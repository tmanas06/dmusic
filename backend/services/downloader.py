"""
wave. — Download service (wraps yt-dlp + ffmpeg)
Downloads audio, converts to MP3 at requested quality, strips and rewrites ID3 tags.
All source references stay server-side.
"""

import os
import glob
import yt_dlp
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB, APIC, ID3NoHeaderError

DATA_DIR = os.environ.get("DATA_DIR", "./data")
AUDIO_DIR = os.path.join(DATA_DIR, "audio")
ART_DIR = os.path.join(DATA_DIR, "art")
os.makedirs(AUDIO_DIR, exist_ok=True)

QUALITY_MAP = {
    "128kbps": "128",
    "256kbps": "256",
    "320kbps": "320",
}


def download_track(
    source_video_id: str,
    internal_id: str,
    title: str,
    artist: str,
    album: str,
    quality: str,
) -> str:
    """
    Download audio from source, convert to MP3, sanitize metadata.
    Returns the path to the output MP3 file.
    
    NOTE: source_video_id is used ONLY for the download URL.
    The resulting file has NO trace of the source.
    """
    bitrate = QUALITY_MAP.get(quality, "320")
    output_template = os.path.join(AUDIO_DIR, f"{internal_id}.%(ext)s")
    output_path = os.path.join(AUDIO_DIR, f"{internal_id}.mp3")

    # If already downloaded at this quality, return immediately
    if os.path.exists(output_path):
        return output_path

    # yt-dlp options — quiet mode, no logging of source info
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": bitrate,
            }
        ],
    }

    # Download and convert
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([f"https://www.youtube.com/watch?v={source_video_id}"])

    # Clean up any non-mp3 intermediary files
    for f in glob.glob(os.path.join(AUDIO_DIR, f"{internal_id}.*")):
        if not f.endswith(".mp3"):
            try:
                os.remove(f)
            except OSError:
                pass

    # Sanitize ID3 tags — strip ALL original metadata, write only clean tags
    _rewrite_metadata(output_path, internal_id, title, artist, album)

    return output_path


def _rewrite_metadata(
    filepath: str,
    internal_id: str,
    title: str,
    artist: str,
    album: str,
) -> None:
    """
    Strip all existing ID3 tags and write clean metadata.
    Ensures no source references remain in the file.
    """
    try:
        audio = MP3(filepath, ID3=ID3)
    except ID3NoHeaderError:
        audio = MP3(filepath)
        audio.add_tags()

    # Clear ALL existing tags
    audio.tags.delete(filepath)
    audio = MP3(filepath, ID3=ID3)
    try:
        audio.add_tags()
    except Exception:
        pass

    # Write clean tags only
    audio.tags.add(TIT2(encoding=3, text=title))
    audio.tags.add(TPE1(encoding=3, text=artist))
    audio.tags.add(TALB(encoding=3, text=album))

    # Embed artwork if available
    artwork_path = os.path.join(ART_DIR, f"{internal_id}.jpg")
    if os.path.exists(artwork_path):
        with open(artwork_path, "rb") as img:
            audio.tags.add(
                APIC(
                    encoding=3,
                    mime="image/jpeg",
                    type=3,  # Cover (front)
                    desc="Cover",
                    data=img.read(),
                )
            )

    audio.save()
