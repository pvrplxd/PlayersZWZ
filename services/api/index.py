"""Vercel WSGI entry point; local development continues to use run.py."""
from app import create_app

app = create_app()
