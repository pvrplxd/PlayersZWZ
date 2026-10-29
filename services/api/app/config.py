import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    PORT = int(os.getenv("PORT", "5000"))
    DEBUG = not os.getenv("VERCEL") and os.getenv("FLASK_ENV", "development") == "development"
    FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "")
    FIREBASE_SERVICE_ACCOUNT_JSON = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    # This key is delivered to the native client for Geoapify tile requests.
    # Restrict it in Geoapify; it cannot be kept secret once a map is rendered.
    GEOAPIFY_API_KEY = os.getenv("GEOAPIFY_API_KEY", "")
    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "").split(",")
        if origin.strip()
    ]
    DEFAULT_RADIUS_KM = int(os.getenv("DEFAULT_RADIUS_KM", "10"))
    MAX_RADIUS_KM = int(os.getenv("MAX_RADIUS_KM", "50"))

