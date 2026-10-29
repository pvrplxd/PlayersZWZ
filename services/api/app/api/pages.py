from flask import Blueprint, render_template, request

pages_bp = Blueprint("pages", __name__)


def wants_html():
    return (request.args.get("format") != "json"
            and request.accept_mimetypes["text/html"] > request.accept_mimetypes["application/json"])


@pages_bp.get("/")
def home():
    return render_template("service.html", page="home")


def error_page():
    return render_template("service.html", page="missing"), 404
