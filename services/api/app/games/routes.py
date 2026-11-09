from datetime import datetime

from flask import Blueprint, current_app, g, jsonify, request
from werkzeug.exceptions import BadRequest

from ..auth.middleware import require_firebase_user
from ..firebase import get_firestore_client
from .repository import (
    cancel_join,
    create_game,
    update_game,
    cancel_game,
    get_game,
    join_game,
    is_approved_player,
    list_join_requests,
    list_my_games,
    list_open_games,
    list_player_previews,
    review_join_request,
)
from .service import GameError, parse_point, radius_value, serialize_game, validate_create


games_bp = Blueprint("games", __name__, url_prefix="/api/v1")


def _error(code, message, status):
    return jsonify(error={"code": code, "message": message}), status


def _repository_error(code):
    details = {
        "PROFILE_REQUIRED": ("PROFILE_REQUIRED", "Complete your profile before using games.", 403),
        "ACCOUNT_SUSPENDED": ("ACCOUNT_SUSPENDED", "This account is not active.", 403),
        "NOT_FOUND": ("NOT_FOUND", "This game or request could not be found.", 404),
        "FORBIDDEN": ("FORBIDDEN", "You do not have permission to do that.", 403),
        "GAME_FULL": ("GAME_FULL", "This game has no open player spots.", 409),
        "GAME_CLOSED": ("GAME_CLOSED", "This game has already started or closed.", 409),
        "JOIN_REQUEST_EXISTS": ("JOIN_REQUEST_EXISTS", "You already have an active request for this game.", 409),
        "ORGANIZER_CANNOT_JOIN": ("ORGANIZER_CANNOT_JOIN", "You are already the host of this game.", 409),
        "ORGANIZER_CANNOT_CANCEL": ("ORGANIZER_CANNOT_CANCEL", "The host cannot leave their own game.", 409),
        "REQUEST_ALREADY_REVIEWED": ("REQUEST_ALREADY_REVIEWED", "This request has already been reviewed.", 409),
        "JOIN_NOT_ACTIVE": ("JOIN_NOT_ACTIVE", "This game request is no longer active.", 409),
        "CAPACITY_TOO_SMALL": ("CAPACITY_TOO_SMALL", "Player limit cannot be lower than the number already approved.", 409),
    }
    return _error(*details.get(code, ("REQUEST_FAILED", "Could not complete that request.", 400)))


def _run(operation):
    try:
        return operation()
    except GameError as exc:
        return _error(exc.code, str(exc), exc.status)
    except Exception:
        current_app.logger.exception("Game API operation failed.")
        return _error("DATABASE_UNAVAILABLE", "Games are unavailable right now. Please retry.", 503)


@games_bp.post("/games")
@require_firebase_user
def create():
    try:
        details = validate_create(request.get_json(silent=True))
    except (GameError, BadRequest) as exc:
        if isinstance(exc, GameError):
            return _error(exc.code, str(exc), exc.status)
        return _error("VALIDATION_ERROR", "Complete the game details.", 400)

    def operation():
        result, error = create_game(g.firebase_uid, g.current_user or {}, details)
        if error:
            return _repository_error(error)
        game_id, game = result
        return jsonify(game=serialize_game(game_id, game, participation="approved")), 201

    return _run(operation)


@games_bp.patch("/games/<game_id>")
@require_firebase_user
def edit_game(game_id):
    try:
        details = validate_create(request.get_json(silent=True))
    except (GameError, BadRequest) as exc:
        if isinstance(exc, GameError):
            return _error(exc.code, str(exc), exc.status)
        return _error("VALIDATION_ERROR", "Complete the game details.", 400)

    def operation():
        game, error = update_game(game_id, g.firebase_uid, details)
        if error:
            return _repository_error(error)
        return jsonify(game=serialize_game(game_id, game, participation="approved"))

    return _run(operation)


@games_bp.delete("/games/<game_id>")
@require_firebase_user
def delete_game(game_id):
    def operation():
        game, error = cancel_game(game_id, g.firebase_uid)
        if error:
            return _repository_error(error)
        return jsonify(game=serialize_game(game_id, game, participation="approved"))

    return _run(operation)


@games_bp.get("/games/open")
@require_firebase_user
def open_games():
    def operation():
        query = request.args
        lat, lon = query.get("latitude"), query.get("longitude")
        profile = get_firestore_client().collection("profiles").document(g.firebase_uid).get().to_dict() or {}
        if profile.get("setup_complete") is not True:
            raise GameError("PROFILE_REQUIRED", "Complete your profile before finding games.", 403)
        if (lat is None) != (lon is None):
            raise GameError("VALIDATION_ERROR", "Send both latitude and longitude.")
        if lat is None:
            location = profile.get("location")
            if location is None:
                raise GameError("PROFILE_REQUIRED", "Save a playing area before finding games.", 403)
            latitude = getattr(location, "latitude", None)
            longitude = getattr(location, "longitude", None)
            if latitude is None or longitude is None:
                raise GameError("PROFILE_REQUIRED", "Save a playing area before finding games.", 403)
        else:
            try:
                latitude, longitude = parse_point({"latitude": float(lat), "longitude": float(lon)})
            except ValueError as exc:
                raise GameError("VALIDATION_ERROR", "Choose a valid map center.") from exc
        radius = radius_value(query.get("radius_km"), profile.get("radius_km", 10))
        sport = query.get("sport")
        if sport in {None, "", "All"}:
            sport = None
        else:
            from ..profile.service import SPORTS
            if sport not in SPORTS:
                raise GameError("VALIDATION_ERROR", "Choose a supported sport.")
        time_window = query.get("time_window")
        if time_window not in {None, "", "24h", "7d"}:
            raise GameError("VALIDATION_ERROR", "Choose a valid time filter.")
        try:
            limit = int(query.get("limit", "20"))
            cursor = int(query.get("cursor", "0"))
        except ValueError as exc:
            raise GameError("VALIDATION_ERROR", "Choose a valid result page.") from exc
        if not 1 <= limit <= 50 or not 0 <= cursor <= 100000:
            raise GameError("VALIDATION_ERROR", "Choose a valid result page.")
        page, next_cursor = list_open_games(
            latitude, longitude, radius, sport=sport,
            time_window=time_window, limit=limit, cursor=cursor,
        )
        games = []
        for distance, _start, game_id, game in page:
            participant = get_firestore_client().collection("game_participants").document(
                f"{game_id}_{g.firebase_uid}"
            ).get()
            participation = (participant.to_dict() or {}).get("request_status") if participant.exists else None
            item = serialize_game(
                game_id, game, participation=participation, distance_km=distance
            )
            item["players"] = list_player_previews(game_id)
            games.append(item)
        return jsonify(games=games, next_cursor=next_cursor, radius_km=radius)

    return _run(operation)


@games_bp.get("/games/<game_id>/players/<user_id>/photo")
@require_firebase_user
def player_photo(game_id, user_id):
    """Avatar of an approved player, shown on that game's map bubble."""
    def operation():
        if not is_approved_player(game_id, user_id):
            raise GameError("NOT_FOUND", "This player could not be found.", 404)
        from ..profile.photo import photo_record, photo_response
        data, error = photo_record(user_id)
        if error:
            return jsonify(photo=None)
        response = jsonify(photo_response(data))
        response.headers["Cache-Control"] = "private, max-age=300"
        return response

    return _run(operation)


@games_bp.get("/games/<game_id>")
@require_firebase_user
def game_details(game_id):
    def operation():
        game, participation = get_game(game_id, g.firebase_uid)
        return jsonify(game=serialize_game(game_id, game, participation=participation))

    return _run(operation)


@games_bp.post("/games/<game_id>/join")
@require_firebase_user
def request_to_join(game_id):
    def operation():
        result, error = join_game(game_id, g.firebase_uid)
        if error:
            return _repository_error(error)
        return jsonify(request=result), 201

    return _run(operation)


@games_bp.delete("/games/<game_id>/join")
@require_firebase_user
def leave_game(game_id):
    def operation():
        result, error = cancel_join(game_id, g.firebase_uid)
        if error:
            return _repository_error(error)
        return jsonify(request=result)

    return _run(operation)


@games_bp.get("/games/<game_id>/requests")
@require_firebase_user
def game_requests(game_id):
    def operation():
        requests = list_join_requests(game_id, g.firebase_uid)
        for item in requests:
            joined_at = item.get("joined_at")
            item["joined_at"] = joined_at.isoformat() if isinstance(joined_at, datetime) else None
        return jsonify(requests=requests)

    return _run(operation)


@games_bp.patch("/join-requests/<request_id>")
@require_firebase_user
def update_join_request(request_id):
    body = request.get_json(silent=True)
    if not isinstance(body, dict) or set(body) != {"action"}:
        return _error("VALIDATION_ERROR", "Choose approve or reject.", 400)
    if not isinstance(body["action"], str):
        return _error("VALIDATION_ERROR", "Choose approve or reject.", 400)
    action = {"approve": "approved", "reject": "rejected"}.get(body["action"])
    if action is None:
        return _error("VALIDATION_ERROR", "Choose approve or reject.", 400)

    def operation():
        result, error = review_join_request(request_id, g.firebase_uid, action)
        if error:
            return _repository_error(error)
        return jsonify(request={"id": request_id, "request_status": result["request_status"]})

    return _run(operation)


@games_bp.get("/me/games")
@require_firebase_user
def my_games():
    def operation():
        records = list_my_games(g.firebase_uid)
        return jsonify({
            key: [serialize_game(item["id"], item, participation=item.get("participation")) for item in values]
            for key, values in records.items()
        })

    return _run(operation)
