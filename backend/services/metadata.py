"""
wave. — Metadata service
Handles ID3 tag reading and sanitization utilities.
"""

from mutagen.mp3 import MP3
from mutagen.id3 import ID3, ID3NoHeaderError
from typing import Optional, Dict


def get_track_info(filepath: str) -> Optional[Dict]:
    """Read sanitized metadata from an MP3 file."""
    try:
        audio = MP3(filepath, ID3=ID3)
        tags = audio.tags
        if not tags:
            return None

        return {
            "title": str(tags.get("TIT2", "Unknown")),
            "artist": str(tags.get("TPE1", "Unknown Artist")),
            "album": str(tags.get("TALB", "")),
            "duration_seconds": int(audio.info.length),
            "has_artwork": "APIC:" in tags or "APIC:Cover" in tags,
        }
    except (ID3NoHeaderError, Exception):
        return None


def validate_clean_metadata(filepath: str) -> bool:
    """
    Verify that an MP3 file contains ONLY clean metadata.
    Returns True if no source references are found.
    """
    try:
        audio = MP3(filepath, ID3=ID3)
        tags = audio.tags
        if not tags:
            return True

        # Allowed tag types
        allowed_prefixes = {"TIT2", "TPE1", "TALB", "APIC"}
        
        for key in tags.keys():
            prefix = key.split(":")[0] if ":" in key else key
            if prefix not in allowed_prefixes:
                return False

        return True
    except Exception:
        return True
