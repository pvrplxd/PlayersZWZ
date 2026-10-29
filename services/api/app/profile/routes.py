from flask import Blueprint, g, jsonify, request
from werkzeug.exceptions import BadRequest
from ..firebase import get_firestore_client
from ..auth.middleware import require_firebase_user
from .service import username, validate
from ..auth.service import serialize_profile
from .repository import save_profile
from .photo import normalize_photo, photo_record, photo_response, MAX_REQUEST_BYTES
import json

profile_bp = Blueprint("profile", __name__, url_prefix="/api/v1")
def error(code, message, status):
    return jsonify(error={"code": code, "message": message}), status


@profile_bp.get("/usernames/availability")
@require_firebase_user
def availability():
    try:
        name = username(request.args.get("username"))
    except ValueError as exc:
        return error("VALIDATION_ERROR", str(exc), 400)
    try:
        record = get_firestore_client().collection("usernames").document(name).get().to_dict()
        return jsonify(username=name, available=record is None or record.get("user_id") == g.firebase_uid)
    except Exception:
        return error("DATABASE_UNAVAILABLE", "Could not check username. Please retry.", 503)


@profile_bp.put("/me/profile")
@require_firebase_user
def update_profile():
    try:
        details = validate(request.get_json(silent=True))
    except (ValueError, BadRequest):
        return error("VALIDATION_ERROR", "Enter a valid username and choose at least one sport.", 400)
    try:
        profile, code = save_profile(g.firebase_uid, details)
        if code:
            return error(code, "That username is already taken." if code == "USERNAME_TAKEN" else "Account setup is unavailable.", 409 if code == "USERNAME_TAKEN" else 403)
        return jsonify(profile=serialize_profile(profile))
    except Exception:
        return error("DATABASE_UNAVAILABLE", "Could not save profile. Please retry.", 503)

@profile_bp.put("/me/profile/location")
@require_firebase_user
def update_location():
    from .service import validate_location
    from .repository import save_location
    try:
        details = validate_location(request.get_json(silent=True))
    except ValueError:
        return error("VALIDATION_ERROR", "Choose a valid location.", 400)
    try:
        profile, code = save_location(g.firebase_uid, details)
        if code:
            return error(code, "Complete profile setup or sign in again.", 403)
        return jsonify(profile=serialize_profile(profile))
    except Exception:
        return error("DATABASE_UNAVAILABLE", "Could not save location. Please retry.", 503)


@profile_bp.route("/me/profile/photo", methods=["GET", "PUT", "DELETE"])
@require_firebase_user
def profile_photo():
    if not g.current_user or g.current_user.get("status") != "active":
        return error("PROFILE_REQUIRED", "Complete account setup before choosing a photo.", 403)
    data = None
    if request.method == "PUT":
        if request.mimetype != "application/json":
            return error("VALIDATION_ERROR", "Supply a photo as JSON.", 400)
        if request.content_length and request.content_length > MAX_REQUEST_BYTES:
            return error("PHOTO_TOO_LARGE", "Choose a photo smaller than 2 MB.", 413)
        try:
            # Bound chunked requests too, before parsing or decoding any image.
            raw = request.stream.read(MAX_REQUEST_BYTES + 1)
            if len(raw) > MAX_REQUEST_BYTES:
                return error("PHOTO_TOO_LARGE", "Choose a photo smaller than 2 MB.", 413)
            data = normalize_photo(json.loads(raw))
        except (ValueError, BadRequest) as exc:
            message = str(exc) if isinstance(exc, ValueError) and not isinstance(exc, json.JSONDecodeError) else "Choose a valid photo."
            return error("INVALID_PHOTO", message, 400)
    operation = {"GET": "read", "PUT": "write", "DELETE": "delete"}[request.method]
    try:
        saved, code = photo_record(g.firebase_uid, operation=operation, data=data)
        if code:
            return error(code, "Sign in again to update your photo.", 403)
        response = jsonify(photo_response(saved))
        response.headers["Cache-Control"] = "private, no-store"
        return response
    except Exception:
        return error("DATABASE_UNAVAILABLE", "Could not update your photo. Please retry.", 503)
