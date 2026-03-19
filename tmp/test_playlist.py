from ytmusicapi import YTMusic
import json

yt = YTMusic()
pid = "PLdSz2Ai3c165U5ZHPwAnGJcshkO9XFWVI"
try:
    playlist = yt.get_playlist(pid, limit=10)
    print(f"Playlist Name: {playlist.get('title')}")
    print(f"Track Count: {len(playlist.get('tracks', []))}")
    if playlist.get('tracks'):
        print("First Track Sample:")
        print(json.dumps(playlist['tracks'][0], indent=2))
except Exception as e:
    print(f"Error: {e}")
