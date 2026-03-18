"""
wave. — FastAPI application entry point
All routes serve internal wave schema only. No source references ever reach the client.
"""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from database import init_db

DATA_DIR = os.environ.get("DATA_DIR", "./data")
CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "*")

# Ensure data directories exist
os.makedirs(os.path.join(DATA_DIR, "audio"), exist_ok=True)
os.makedirs(os.path.join(DATA_DIR, "art"), exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup."""
    init_db()
    yield


app = FastAPI(
    title="wave. API",
    description="Music download and streaming API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS.split(",") if CORS_ORIGINS != "*" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import and include routers
from routes.search import router as search_router
from routes.download import router as download_router
from routes.stream import router as stream_router
from routes.artwork import router as artwork_router

app.include_router(search_router, tags=["Search"])
app.include_router(download_router, tags=["Download"])
app.include_router(stream_router, tags=["Stream"])
app.include_router(artwork_router, tags=["Artwork"])


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "wave."}


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "wave.",
        "version": "1.0.0",
        "status": "running",
    }
