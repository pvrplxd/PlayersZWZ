from flask import Flask, jsonify, request
from flask_cors import CORS

from .config import Config


def create_app(config_object: type[Config] = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_object)
    CORS(app, origins=app.config["CORS_ORIGINS"])

    from .api.health import health_bp
    from .api.mobile_config import mobile_config_bp
    from .auth.routes import auth_bp

    from .api.pages import pages_bp, wants_html, error_page
    app.register_blueprint(pages_bp)
    app.register_blueprint(health_bp)
    app.register_blueprint(mobile_config_bp)
    app.register_blueprint(auth_bp)
    from .profile.routes import profile_bp
    app.register_blueprint(profile_bp)

    @app.errorhandler(404)
    def not_found(_error):
        if not request.path.startswith("/api/") and wants_html():
            return error_page()
        return jsonify({"error": {"code": "NOT_FOUND", "message": "Route not found."}}), 404

    @app.errorhandler(500)
    def internal_error(_error):
        return jsonify({"error": {"code": "INTERNAL_ERROR", "message": "An unexpected server error occurred."}}), 500

    return app

