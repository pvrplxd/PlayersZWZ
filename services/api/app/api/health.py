from flask import Blueprint, jsonify, render_template

health_bp = Blueprint("health", __name__)


@health_bp.get("/health")
def health():
    from .pages import wants_html
    if wants_html():
        response = render_template("service.html", page="health")
        return response, 200, {"Cache-Control": "no-store", "Vary": "Accept"}
    return jsonify({"status": "ok", "service": "playerszwz-api"}), 200, {"Cache-Control": "no-store", "Vary": "Accept"}

