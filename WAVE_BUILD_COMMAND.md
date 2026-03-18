# ⚡ WAVE — ANTIGRAVITY BUILD COMMAND
> Paste this entire document into Claude Code, Cursor Agent, or any AI coding agent.
> It contains every spec, screen, and decision made. Zero ambiguity.

---

## MISSION

Build **wave.** — a full-stack mobile music download & player app.
- Frontend: Flutter (iOS + Android)
- Backend: Python + FastAPI
- Downloader: yt-dlp + ffmpeg (server-side only, never exposed to client)
- Audio: just_audio + equalizer_flutter + audio_service
- Local DB: Hive
- Job queue: Celery + Redis
- Deployment target: Docker on a VPS (DigitalOcean / Hetzner)

The user never sees any reference to YouTube, yt-dlp, or any scraping tool.
All YouTube metadata is abstracted behind your own internal API schema.

---

## PART 1 — BACKEND (FastAPI + Python)

### File structure
```
backend/
├── main.py
├── routes/
│   ├── search.py
│   ├── download.py
│   ├── stream.py
│   └── artwork.py
├── services/
│   ├── searcher.py       # wraps ytmusicapi
│   ├── downloader.py     # wraps yt-dlp + ffmpeg
│   ├── metadata.py       # strips and rewrites ID3 tags
│   └── proxy.py          # proxies thumbnails through your domain
├── models.py
├── database.py           # SQLite via SQLAlchemy (stores internal_id → yt_id mapping)
├── worker.py             # Celery tasks
├── requirements.txt
└── Dockerfile
```

### requirements.txt
```
fastapi
uvicorn[standard]
yt-dlp
ytmusicapi
ffmpeg-python
mutagen
celery[redis]
redis
sqlalchemy
aiofiles
httpx
python-multipart
```

### Core API contract (all responses use your schema — NO YouTube fields ever sent to client)

#### GET /search?q={query}
Returns:
```json
[
  {
    "id": "wv_abc123",
    "title": "Vampire",
    "artist": "Olivia Rodrigo",
    "album": "GUTS",
    "duration_seconds": 219,
    "artwork_url": "https://yourserver.com/art/wv_abc123",
    "quality_available": ["128kbps", "256kbps", "320kbps"]
  }
]
```
Implementation in `services/searcher.py`:
- Call `ytmusicapi.search(query, filter='songs')`
- Map each result to your internal schema
- Store `yt_video_id` → `internal_id` in SQLite
- Proxy artwork: download thumbnail → save to `/static/art/{internal_id}.jpg` → return your URL
- NEVER include videoId, browseId, or any YouTube field in the response

#### POST /download
Body: `{ "id": "wv_abc123", "quality": "320kbps" }`
Returns: `{ "job_id": "job_xyz789", "status": "queued" }`
Implementation:
- Enqueue a Celery task `tasks.download_track(internal_id, quality)`
- Task: look up yt_video_id from DB, run yt-dlp, run ffmpeg, strip+rewrite ID3 tags, save file

#### GET /download-status/{job_id}
Returns: `{ "status": "pending|processing|done|failed", "progress": 0-100 }`

#### GET /file/{id}
Streams the audio file to Flutter for saving to phone storage.
Sets `Content-Disposition: attachment; filename="{title} - {artist}.mp3"`

#### GET /art/{id}
Serves the proxied artwork image. Cache headers: max-age=604800.

### services/downloader.py
```python
import yt_dlp
import ffmpeg
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB, APIC
import httpx

QUALITY_MAP = {"128kbps": "128", "256kbps": "256", "320kbps": "320"}

def download_track(yt_video_id: str, internal_id: str, title: str, artist: str, album: str, artwork_path: str, quality: str, output_dir: str) -> str:
    bitrate = QUALITY_MAP.get(quality, "320")
    output_path = f"{output_dir}/{internal_id}.mp3"
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": f"{output_dir}/{internal_id}.%(ext)s",
        "quiet": True,
        "no_warnings": True,
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": bitrate,
        }],
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([f"https://www.youtube.com/watch?v={yt_video_id}"])

    # Strip ALL original metadata, write only clean tags
    audio = MP3(output_path, ID3=ID3)
    audio.tags.clear()
    audio.tags.add(TIT2(encoding=3, text=title))
    audio.tags.add(TPE1(encoding=3, text=artist))
    audio.tags.add(TALB(encoding=3, text=album))
    if artwork_path:
        with open(artwork_path, 'rb') as img:
            audio.tags.add(APIC(encoding=3, mime='image/jpeg', type=3, desc='Cover', data=img.read()))
    audio.save()
    return output_path
```

### Error handling rule
ALL errors caught in routes must return generic messages:
```python
# WRONG:
raise HTTPException(500, detail="yt-dlp: ERROR: Sign in to confirm you're not a bot")
# RIGHT:
raise HTTPException(500, detail="Download failed. Please try again.")
```

### Celery worker (worker.py)
```python
from celery import Celery
app = Celery('wave', broker='redis://localhost:6379/0', backend='redis://localhost:6379/0')

@app.task(bind=True)
def download_track_task(self, internal_id: str, quality: str):
    self.update_state(state='PROGRESS', meta={'progress': 10})
    # ... fetch from DB, call downloader, update progress
    self.update_state(state='SUCCESS', meta={'progress': 100})
```

### Dockerfile (backend)
```dockerfile
FROM python:3.11-slim
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### docker-compose.yml
```yaml
version: '3.9'
services:
  api:
    build: ./backend
    ports: ["8000:8000"]
    volumes: ["./data:/app/data"]
    depends_on: [redis]
    environment:
      - REDIS_URL=redis://redis:6379/0
  worker:
    build: ./backend
    command: celery -A worker worker --loglevel=info
    volumes: ["./data:/app/data"]
    depends_on: [redis]
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
```

---

## PART 2 — FLUTTER APP

### pubspec.yaml dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Audio
  just_audio: ^0.9.36
  audio_service: ^0.18.12
  equalizer_flutter: ^1.0.0
  # Networking
  dio: ^5.4.0
  # Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.2
  # UI
  cached_network_image: ^3.3.1
  google_fonts: ^6.1.0
  # Utils
  permission_handler: ^11.3.0
  uuid: ^4.3.3
```

### App structure
```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── models/
│   ├── track.dart
│   └── download_job.dart
├── services/
│   ├── api_service.dart
│   └── audio_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── search_screen.dart
│   ├── library_screen.dart
│   ├── player_screen.dart       # full-screen player (bottom sheet)
│   └── equalizer_screen.dart
├── widgets/
│   ├── track_card.dart
│   ├── mood_card.dart
│   ├── mini_player.dart
│   ├── waveform_bars.dart
│   ├── eq_slider.dart
│   └── frequency_curve_painter.dart
└── providers/
    ├── player_provider.dart
    └── library_provider.dart
```

### theme/app_theme.dart — EXACT design system
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF1C1C28);
  static const accent = Color(0xFFC8FF57);       // acid lime — primary action color
  static const accent2 = Color(0xFFFF5C87);      // pink-red — artwork gradients only
  static const accent3 = Color(0xFF5CE0FF);      // cyan — artwork gradients only
  static const textPrimary = Color(0xFFF0F0F5);
  static const textMuted = Color(0xFF6B6B85);
  static const border = Color(0x12FFFFFF);       // 7% white

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: surface,
      background: bg,
      onPrimary: Colors.black,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.syneTextTheme().copyWith(
      // Syne for display/headings
      displayLarge: GoogleFonts.syne(fontWeight: FontWeight.w800, color: textPrimary),
      headlineMedium: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary),
      // DM Sans for body
      bodyLarge: GoogleFonts.dmSans(color: textPrimary),
      bodyMedium: GoogleFonts.dmSans(color: textMuted),
      bodySmall: GoogleFonts.dmSans(color: textMuted, fontSize: 11),
    ),
  );
}
```

### models/track.dart
```dart
import 'package:hive/hive.dart';
part 'track.g.dart';

@HiveType(typeId: 0)
class Track extends HiveObject {
  @HiveField(0) final String id;           // internal wave ID e.g. "wv_abc123"
  @HiveField(1) final String title;
  @HiveField(2) final String artist;
  @HiveField(3) final String album;
  @HiveField(4) final int durationSeconds;
  @HiveField(5) final String artworkUrl;   // always your proxied server URL
  @HiveField(6) String? localFilePath;     // set after download completes
  @HiveField(7) final DateTime addedAt;
  @HiveField(8) String quality;            // "128kbps" | "256kbps" | "320kbps"

  bool get isDownloaded => localFilePath != null;
}
```

### services/api_service.dart
```dart
class ApiService {
  static const _base = 'https://yourserver.com/api'; // never expose YouTube URLs
  final _dio = Dio(BaseOptions(baseUrl: _base));

  Future<List<Track>> search(String query) async {
    final res = await _dio.get('/search', queryParameters: {'q': query});
    return (res.data as List).map((j) => Track.fromJson(j)).toList();
  }

  Future<String> requestDownload(String trackId, String quality) async {
    final res = await _dio.post('/download', data: {'id': trackId, 'quality': quality});
    return res.data['job_id'];
  }

  Stream<int> watchProgress(String jobId) async* {
    // Poll every 800ms until done
    while (true) {
      await Future.delayed(const Duration(milliseconds: 800));
      final res = await _dio.get('/download-status/$jobId');
      final progress = res.data['progress'] as int;
      yield progress;
      if (res.data['status'] == 'done' || res.data['status'] == 'failed') break;
    }
  }

  Future<void> downloadFileToPhone(String trackId, String savePath) async {
    await _dio.download('/file/$trackId', savePath);
  }
}
```

### screens/home_screen.dart — key structure
```dart
// Scaffold with:
// 1. Stack: background blob animations (AnimatedContainer or Lottie) behind everything
// 2. CustomScrollView with SliverList:
//    - Header: logo "wave." + avatar circle
//    - Greeting: time-based ("good morning ☀️" / "good evening ✦")
//      headline uses RichText mixing Syne bold + DM Sans italic for "vibe"
//    - SearchBar widget → navigates to SearchScreen on tap
//    - Section "moods" → horizontal ListView of MoodCard widgets
//    - MiniPlayer widget (always visible at bottom when track loaded)
//    - Section "trending now" with live pulse dot
//    - List of TrackCard widgets
// 3. Bottom: BottomNavigationBar (transparent, blur backdrop)

// Background blob animation:
Widget _buildBlob(Color color, double size, Alignment alignment) {
  return Align(
    alignment: alignment,
    child: AnimatedContainer(
      duration: const Duration(seconds: 8),
      curve: Curves.easeInOut,
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.15), Colors.transparent]),
      ),
    ),
  );
}

// Greeting logic:
String _getGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'good morning ☀️';
  if (h < 18) return 'good afternoon 〰';
  return 'good evening ✦';
}
```

### widgets/mood_card.dart
```dart
// 130×155 ClipRRect(borderRadius: 18)
// Gradient background (4 presets: purple-dark, navy, burnt-orange, forest)
// Foreground: Column(emoji 26px, title Syne bold 14px, count DM Sans 11px muted)
// Overlay: gradient from transparent (top) to black 70% (bottom)
// OnTap: scale animation via GestureDetector + AnimationController (scale 0.96 on press)
```

### widgets/mini_player.dart
```dart
// Fixed at bottom above BottomNav (use Stack in main scaffold)
// Height: 72px, background: surface with blur (BackdropFilter)
// Left accent bar: 3px wide, gradient accent→accent2
// Content: Row(artwork 48px rounded-12, track info, controls)
// Controls: prev, play/pause (filled accent circle), next
// Tap anywhere → opens PlayerScreen as bottom sheet
// Animated waveform bars (5 bars, staggered animation) next to "now playing" label
```

### screens/player_screen.dart — full player (DraggableScrollableSheet)
```dart
// Opens as modal bottom sheet, slides up
// minChildSize: 0.12 (mini player peek), maxChildSize: 1.0
// Full screen layout:
//   - Drag handle pill at top
//   - Large album artwork: 280×280, rounded-24, CachedNetworkImage
//     When playing: subtle rotation animation (full 360° in 20s, pauses when stopped)
//   - Track title (Syne 24px bold) + artist (DM Sans 16px muted)
//   - Seek bar: custom SliderTheme with accent color, time labels
//   - Main controls: Row(shuffle, prev, play/pause BIG 64px circle, next, repeat)
//   - Secondary row: download button, like, share, EQ shortcut
//   - Download button states: idle → loading(CircularProgressIndicator) → done(checkmark)
```

### screens/equalizer_screen.dart — FULL IMPLEMENTATION
```dart
// State: List<double> bands = [0,0,0,0,0,0,0,0,0,0] (range -15.0 to +15.0 dB)
// Presets map:
const Map<String, List<double>> EQ_PRESETS = {
  'Flat':      [0,0,0,0,0,0,0,0,0,0],
  'Bass':      [6,5,4,2,0,0,0,0,0,0],
  'Rock':      [4,3,2,0,-1,1,3,4,4,3],
  'Pop':       [-1,1,2,3,2,0,-1,-1,-1,-1],
  'Hip-Hop':   [5,4,2,3,-1,-1,2,2,3,4],
  'Classical': [4,3,3,2,-1,-1,0,2,3,4],
  'Custom':    null,
};

const List<String> FREQ_LABELS = ['31','63','125','250','500','1k','2k','4k','8k','16k'];

// Layout:
// 1. Preset pills row (horizontal scroll, tapping animates all sliders)
// 2. FrequencyCurvePainter (CustomPainter, 120px height)
//    - draws grid lines at -15,-10,-5,0,5,10,15 dB
//    - cubic spline through 10 control points
//    - filled area below/above 0dB line with accent color at 20% opacity
//    - repaints whenever bands change
// 3. Row of 10 vertical sliders
//    Each band widget: Column(dB label, RotatedBox(VerticalSlider), freq label)
// 4. On slider change: call equalizer_flutter to set band gain + update CustomPainter

// FrequencyCurvePainter — key snippet:
class FrequencyCurvePainter extends CustomPainter {
  final List<double> bands;
  FrequencyCurvePainter(this.bands);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = List.generate(10, (i) {
      final x = (i / 9) * size.width;
      final y = size.height / 2 - (bands[i] / 15) * (size.height / 2 - 8);
      return Offset(x, y);
    });
    // Draw grid, then cubic spline path, then fill, then stroke
    // Use accent color (0xFFC8FF57) with varying opacity
  }

  @override bool shouldRepaint(FrequencyCurvePainter old) => old.bands != bands;
}

// Connect to audio engine:
void _setBand(int index, double value) {
  setState(() => bands[index] = value);
  EqualizerFlutter.setBandLevel(index, value.toInt());
}
```

### Navigation structure
```dart
// main.dart uses GoRouter:
// /             → HomeScreen
// /search       → SearchScreen
// /library      → LibraryScreen
// /player       → PlayerScreen (modal, not a route — opened via showModalBottomSheet)
// /equalizer    → EqualizerScreen

// Bottom nav tabs: Home, Search, Library, EQ
// MiniPlayer sits in a persistent Stack above BottomNav
```

---

## PART 3 — UX CONCEALMENT RULES (enforce everywhere)

1. **Internal ID system**: every track gets a UUID prefixed with `wv_`. The yt video ID is stored ONLY in the backend DB, never returned to Flutter.

2. **Image proxying**: ALL artwork served from `yourserver.com/art/{id}`. Flutter CachedNetworkImage only ever calls your domain.

3. **Metadata sanitization**: before the mp3 file is sent to the phone, ID3 tags are cleared and rewritten with only: title, artist, album, track artwork. No URL, no source, no YouTube fields.

4. **Error messages**: Flutter catches all DioException and shows user-friendly strings only. No stack traces, no backend error details.

5. **Network requests visible to user**: only `yourserver.com/*`. Never `youtube.com`, `ytimg.com`, `googlevideo.com`.

6. **App branding**: app name is "wave.", icon is a sine wave mark, splash screen is the logo on `#0A0A0F` background. Zero mention of YouTube anywhere in UI, settings, or about screen.

---

## PART 4 — DESIGN SYSTEM (implement exactly)

### Colors
```dart
bg       = #0A0A0F   // near-black base
surface  = #13131A   // card / bottom sheet background  
surface2 = #1C1C28   // elevated surface, hover states
accent   = #C8FF57   // ACID LIME — primary CTA, active states, icons
accent2  = #FF5C87   // used ONLY in artwork gradients
accent3  = #5CE0FF   // used ONLY in artwork gradients
text     = #F0F0F5   // primary text
muted    = #6B6B85   // secondary text, timestamps, labels
border   = #FFFFFF12 // 7% white — card borders
```

### Typography
- Display / headings: **Syne** (weight 700–800)
- Body / UI labels: **DM Sans** (weight 300–500)
- Greeting headline uses mixed style: Syne 800 for "what's the" + DM Sans 300 italic for "vibe"

### Motion rules
- Page transitions: fade + slide up 16px, 280ms, easeOutCubic
- Staggered list entrance: each item delays by 40ms × index
- Mood cards: scale 0.96 on press, spring back 200ms
- Download button: idle → spinner → checkmark with scale bounce
- Album art: continuous 20s rotation when playing, pauses smoothly
- EQ sliders: preset tap animates all sliders simultaneously with 300ms tween
- Waveform bars: 5 bars, staggered height animation, pauses when audio paused
- Ambient blobs: slow float 8–10s, subtle scale 1.0→1.05

### Component specs

**Track card:**
- Height: 70px row
- Art: 46×46, borderRadius 12, gradient background
- Title: Syne 500 15px, single line ellipsis
- Artist: DM Sans 12px muted
- Duration: DM Sans 12px muted, right-aligned
- Download button: 28×28, borderRadius 8, border accent/7, accent icon
  - States: idle(↓), loading(spinner), done(✓ with accent bg)

**Bottom nav:**
- Background: `#0A0A0F` at 85% opacity + `BackdropFilter(blur: 20)`
- Border top: 0.5px `#FFFFFF12`
- Active item: full opacity + 4px accent dot below icon
- Inactive: 50% opacity

**Search bar:**
- Background: surface, borderRadius 16
- Border: 1px `#FFFFFF12`, focus: `rgba(C8FF57, 0.3)` + outer glow `rgba(C8FF57, 0.06)`
- Icon: magnifier, 40% opacity
- Placeholder: "search any song, artist..."

---

## PART 5 — COMPLETE SCREEN LIST

| Screen | Key interactions |
|---|---|
| Home | Mood cards scroll, track list, mini player |
| Search | Debounced search (300ms), results with download buttons |
| Library | Downloaded tracks grid, filter pills, long-press options |
| Full player | Rotating art, seek bar, download, like, EQ shortcut |
| Equalizer | 10-band sliders, curve painter, presets, live audio effect |
| Settings | Audio quality (128/256/320), storage path, clear cache |

---

## PART 6 — BUILD ORDER

Run these steps in sequence:

```
1. scaffold Flutter project: flutter create wave_app
2. add all pubspec.yaml dependencies, run flutter pub get
3. implement AppTheme (colors, fonts, motion constants)
4. implement Track model + Hive adapter
5. implement ApiService (search, download, file endpoints)
6. implement PlayerProvider (just_audio + audio_service)
7. build HomeScreen (static, no data yet)
8. build SearchScreen (wire to ApiService.search)
9. build LibraryScreen (wire to Hive box)
10. build MiniPlayer widget
11. build FullPlayerScreen (bottom sheet)
12. build EqualizerScreen (sliders + curve painter + presets)
13. wire download flow end-to-end (request → poll → save file → update Hive)
14. --- BACKEND ---
15. scaffold FastAPI project
16. implement /search (ytmusicapi + internal ID mapping)
17. implement /download + Celery task (yt-dlp + ffmpeg + metadata strip)
18. implement /download-status (Celery result polling)
19. implement /file/{id} (stream audio file)
20. implement /art/{id} (serve proxied artwork)
21. test full flow locally
22. write Dockerfile + docker-compose.yml
23. deploy to VPS, configure nginx reverse proxy + SSL
```

---

## PART 7 — QUICK REFERENCE

**Start the backend locally:**
```bash
cd backend
docker-compose up --build
# API at http://localhost:8000
# Celery worker auto-starts
```

**Run Flutter:**
```bash
cd wave_app
flutter run
# Set API base URL to http://10.0.2.2:8000 for Android emulator
# Set to http://localhost:8000 for iOS simulator
```

**Key environment variables (backend):**
```
REDIS_URL=redis://redis:6379/0
DATA_DIR=/app/data
MAX_DOWNLOAD_QUALITY=320
CORS_ORIGINS=*
```

---

*Built to spec from the wave. design session. Every decision in this document was deliberate.*
*Do not deviate from the UX concealment rules. Do not expose YouTube references anywhere in the Flutter app.*
