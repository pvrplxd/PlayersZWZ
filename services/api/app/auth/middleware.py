from functools import wraps

from firebase_admin import auth
from flask import current_app, g, jsonify, request

from ..firebase import get_firestore_client, verify_firebase_id_token


def _error(code: str, message: str, status: int):
    return jsonify({"error": {"code": code, "message": message}}), status


def require_firebase_user(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        scheme, separator, token = authorization.partition(" ")

        if not separator or scheme.lower() != "bearer" or not token.strip():
            return _error(
                "UNAUTHORIZED",
                "A Firebase ID token is required.",
                401,
            )

        try:
            claims = verify_firebase_id_token(token.strip())
        except (auth.InvalidIdTokenError, ValueError):
            return _error(
                "INVALID_TOKEN",
                "The Firebase ID token is invalid or expired.",
                401,
            )
        except Exception:
            current_app.logger.exception("Firebase ID token verification failed.")
            return _error(
                "AUTH_SERVICE_UNAVAILABLE",
                "Could not verify the sign-in token right now.",
                503,
            )

        uid = claims.get("uid")
        if not uid:
            return _error("INVALID_TOKEN", "The token has no user ID.", 401)

        try:
            snapshot = (
                get_firestore_client()
                .collection("users")
                .document(uid)
                .get()
            )
            user_data = snapshot.to_dict() if snapshot.exists else None
        except Exception:
            current_app.logger.exception("Could not load the user record.")
            return _error(
                "DATABASE_UNAVAILABLE",
                "Could not load your account right now.",
                503,
            )

        g.firebase_claims = claims
        g.firebase_uid = uid
        g.current_user = (
            {**user_data, "user_id": uid} if user_data is not None else None
        )

        if g.current_user and g.current_user.get("status") == "suspended":
            return _error(
                "ACCOUNT_SUSPENDED",
                "This account is suspended.",
                403,
            )

        return view(*args, **kwargs)

    return wrapped


def require_role(*allowed_roles: str):
    if not allowed_roles:
        raise ValueError("require_role needs at least one allowed role.")

    def decorator(view):
        @wraps(view)
        @require_firebase_user
        def wrapped(*args, **kwargs):
            user = g.current_user

            if user is None:
                return _error(
                    "PROFILE_REQUIRED",
                    "Complete account setup before using this feature.",
                    403,
                )

            if user.get("role") not in allowed_roles:
                return _error(
                    "FORBIDDEN",
                    "You do not have permission to perform this action.",
                    403,
                )

            return view(*args, **kwargs)

        return wrapped

    return decorator