from flask import Blueprint, current_app, g, jsonify, request
from werkzeug.exceptions import BadRequest

from .middleware import require_firebase_user
from .repository import ensure_account, load_account
from .service import (
    AccountSetupRequired,
    AccountSuspended,
    account_response,
    initial_records,
    validate_session_body,
)

auth_bp = Blueprint("auth", __name__, url_prefix="/api/v1")


def _account_result(operation):
    try:
        user, profile = operation()
        return jsonify(account_response(g.firebase_uid, user, profile)), 200
    except AccountSuspended:
        return jsonify(error={"code": "ACCOUNT_SUSPENDED", "message": "This account is suspended."}), 403
    except AccountSetupRequired:
        return jsonify(error={"code": "PROFILE_REQUIRED", "message": "Complete account setup using /api/v1/auth/session."}), 403
    except Exception:
        current_app.logger.error("Account database operation failed.")
        return jsonify(error={"code": "DATABASE_UNAVAILABLE", "message": "Could not load your account right now. Please retry."}), 503


@auth_bp.post("/auth/session")
@require_firebase_user
def session():
    try:
        if not request.is_json:
            raise ValueError("Send a JSON object with Content-Type application/json.")
        details = validate_session_body(request.get_json())
    except (ValueError, BadRequest) as error:
        message = str(error) if isinstance(error, ValueError) else "The request contains invalid JSON."
        return jsonify(error={"code": "VALIDATION_ERROR", "message": message}), 400
    user, profile = initial_records(g.firebase_uid, g.firebase_claims, details)
    return _account_result(lambda: ensure_account(g.firebase_uid, user, profile))


@auth_bp.get("/me")
@require_firebase_user
def me():
    return _account_result(lambda: load_account(g.firebase_uid))
