from flask import Blueprint, current_app, jsonify


mobile_config_bp = Blueprint("mobile_config", __name__, url_prefix="/api/v1")


@mobile_config_bp.get("/mobile-config")
def mobile_config():
    """Return non-sensitive runtime configuration required by the native app."""
    key = current_app.config["GEOAPIFY_API_KEY"].strip()
    if not key:
        return (
            jsonify(
                error={
                    "code": "CONFIGURATION_ERROR",
                    "message": "Map configuration is unavailable.",
                }
            ),
            503,
            {"Cache-Control": "no-store"},
        )
    return jsonify({"geoapify_api_key": key}), 200, {"Cache-Control": "no-store"}
