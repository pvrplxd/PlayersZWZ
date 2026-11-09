from datetime import datetime, timezone

from google.cloud import firestore

from ..firebase import get_firestore_client
from .service import GameError, encode_geohash, geohash_search_prefixes, haversine_km


def create_game(uid, user, details):
    db = get_firestore_client()
    user_ref = db.collection("users").document(uid)
    profile_ref = db.collection("profiles").document(uid)
    game_ref = db.collection("games").document()
    participant_ref = db.collection("game_participants").document(f"{game_ref.id}_{uid}")

    @firestore.transactional
    def create(transaction):
        account = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        if not account or not profile or profile.get("setup_complete") is not True:
            return None, "PROFILE_REQUIRED"
        if account.get("status") != "active":
            return None, "ACCOUNT_SUSPENDED"
        game = {
            "organizer_id": uid,
            "organizer_name": (account.get("name") or user.get("name") or "Player").strip(),
            "sport": details["sport"],
            "start_time": details["start_time"],
            "location": firestore.GeoPoint(details["latitude"], details["longitude"]),
            "geohash": encode_geohash(details["latitude"], details["longitude"]),
            "location_label": details["location_label"],
            "required_players": details["required_players"],
            "fee_amount": details["fee_amount"],
            "approved_count": 1,
            "status": "open",
            "notes": details["notes"],
            "created_at": firestore.SERVER_TIMESTAMP,
        }
        transaction.create(game_ref, game)
        transaction.create(participant_ref, {
            "game_id": game_ref.id,
            "user_id": uid,
            "request_status": "approved",
            "is_organizer": True,
            "joined_at": firestore.SERVER_TIMESTAMP,
        })
        return {**game, "created_at": datetime.now(timezone.utc)}, None

    game, error = create(db.transaction())
    return (game_ref.id, game), error


def update_game(game_id, uid, details):
    db = get_firestore_client()
    game_ref = db.collection("games").document(game_id)

    @firestore.transactional
    def update(transaction):
        snapshot = game_ref.get(transaction=transaction)
        if not snapshot.exists:
            return None, "NOT_FOUND"
        game = snapshot.to_dict() or {}
        if game.get("organizer_id") != uid:
            return None, "FORBIDDEN"
        start_time = game.get("start_time")
        if game.get("status") not in {"open", "full"} or not isinstance(start_time, datetime) or start_time <= datetime.now(timezone.utc):
            return None, "GAME_CLOSED"
        if details["required_players"] < game.get("approved_count", 1):
            return None, "CAPACITY_TOO_SMALL"
        updated = {
            "sport": details["sport"],
            "start_time": details["start_time"],
            "location": firestore.GeoPoint(details["latitude"], details["longitude"]),
            "geohash": encode_geohash(details["latitude"], details["longitude"]),
            "location_label": details["location_label"],
            "required_players": details["required_players"],
            "fee_amount": details["fee_amount"],
            "notes": details["notes"],
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        updated["status"] = "full" if details["required_players"] == game.get("approved_count", 1) else "open"
        transaction.update(game_ref, updated)
        return {**game, **updated, "updated_at": datetime.now(timezone.utc)}, None

    return update(db.transaction())


def cancel_game(game_id, uid):
    db = get_firestore_client()
    game_ref = db.collection("games").document(game_id)

    @firestore.transactional
    def cancel(transaction):
        snapshot = game_ref.get(transaction=transaction)
        if not snapshot.exists:
            return None, "NOT_FOUND"
        game = snapshot.to_dict() or {}
        if game.get("organizer_id") != uid:
            return None, "FORBIDDEN"
        if game.get("status") == "cancelled":
            return game, None
        start_time = game.get("start_time")
        if game.get("status") not in {"open", "full"} or not isinstance(start_time, datetime) or start_time <= datetime.now(timezone.utc):
            return None, "GAME_CLOSED"
        transaction.update(game_ref, {
            "status": "cancelled",
            "cancelled_at": firestore.SERVER_TIMESTAMP,
        })
        return {**game, "status": "cancelled", "cancelled_at": datetime.now(timezone.utc)}, None

    result, error = cancel(db.transaction())
    if error or result is None:
        return result, error
    batch = db.batch()
    for participant in db.collection("game_participants").where("game_id", "==", game_id).stream():
        record = participant.to_dict() or {}
        if record.get("request_status") in {"pending", "approved"}:
            batch.update(participant.reference, {
                "request_status": "cancelled",
                "cancelled_at": firestore.SERVER_TIMESTAMP,
            })
    batch.commit()
    return result, None


def list_open_games(latitude, longitude, radius_km, *, sport=None, time_window=None, limit=20, cursor=0):
    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    if time_window == "24h":
        cutoff = now.timestamp() + 24 * 60 * 60
    elif time_window == "7d":
        cutoff = now.timestamp() + 7 * 24 * 60 * 60
    else:
        cutoff = None

    results = []
    games_ref = db.collection("games")
    candidates = {}
    for prefix in geohash_search_prefixes(latitude, longitude, radius_km):
        query = (games_ref
                 .where("status", "==", "open")
                 .where("geohash", ">=", prefix)
                 .where("geohash", "<=", prefix + "~"))
        for snapshot in query.stream():
            candidates[snapshot.id] = snapshot

    for snapshot in candidates.values():
        game = snapshot.to_dict() or {}
        start_time = game.get("start_time")
        if not isinstance(start_time, datetime) or start_time <= now:
            continue
        if cutoff is not None and start_time.timestamp() > cutoff:
            continue
        if sport and game.get("sport") != sport:
            continue
        location = game.get("location")
        game_lat = getattr(location, "latitude", None)
        game_lon = getattr(location, "longitude", None)
        if game_lat is None or game_lon is None:
            continue
        distance = haversine_km(latitude, longitude, game_lat, game_lon)
        if distance <= radius_km:
            results.append((distance, start_time, snapshot.id, game))

    results.sort(key=lambda item: (item[0], item[1], item[2]))
    page = results[cursor:cursor + limit]
    next_cursor = cursor + limit if cursor + limit < len(results) else None
    return page, next_cursor


def get_game(game_id, uid):
    db = get_firestore_client()
    snapshot = db.collection("games").document(game_id).get()
    if not snapshot.exists:
        raise GameError("NOT_FOUND", "This game could not be found.", 404)
    game = snapshot.to_dict() or {}
    participant = db.collection("game_participants").document(f"{game_id}_{uid}").get()
    participation = None
    if participant.exists:
        participation = (participant.to_dict() or {}).get("request_status")
    return game, participation


def join_game(game_id, uid):
    db = get_firestore_client()
    game_ref = db.collection("games").document(game_id)
    user_ref = db.collection("users").document(uid)
    profile_ref = db.collection("profiles").document(uid)
    participant_ref = db.collection("game_participants").document(f"{game_id}_{uid}")

    @firestore.transactional
    def join(transaction):
        account = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        game = game_ref.get(transaction=transaction).to_dict()
        existing = participant_ref.get(transaction=transaction).to_dict()
        if not account or account.get("status") != "active":
            return None, "ACCOUNT_SUSPENDED"
        if not profile or profile.get("setup_complete") is not True:
            return None, "PROFILE_REQUIRED"
        if not game:
            return None, "NOT_FOUND"
        start_time = game.get("start_time")
        if not isinstance(start_time, datetime) or start_time <= datetime.now(timezone.utc):
            return None, "GAME_CLOSED"
        if game.get("organizer_id") == uid:
            return None, "ORGANIZER_CANNOT_JOIN"
        if game.get("status") != "open" or game.get("approved_count", 0) >= game.get("required_players", 0):
            return None, "GAME_FULL"
        if existing and existing.get("request_status") in {"pending", "approved"}:
            return None, "JOIN_REQUEST_EXISTS"
        transaction.set(participant_ref, {
            "game_id": game_id,
            "user_id": uid,
            "request_status": "pending",
            "is_organizer": False,
            "joined_at": firestore.SERVER_TIMESTAMP,
        })
        return {"request_id": participant_ref.id, "request_status": "pending"}, None

    return join(db.transaction())


def review_join_request(request_id, organizer_uid, action):
    if action not in {"approved", "rejected"}:
        raise GameError("VALIDATION_ERROR", "Choose approve or reject.")
    db = get_firestore_client()
    request_ref = db.collection("game_participants").document(request_id)

    @firestore.transactional
    def review(transaction):
        request = request_ref.get(transaction=transaction).to_dict()
        if not request:
            return None, "NOT_FOUND"
        game_ref = db.collection("games").document(request["game_id"])
        game = game_ref.get(transaction=transaction).to_dict()
        if not game:
            return None, "NOT_FOUND"
        if game.get("organizer_id") != organizer_uid:
            return None, "FORBIDDEN"
        if request.get("request_status") != "pending":
            return None, "REQUEST_ALREADY_REVIEWED"
        if action == "approved":
            player = db.collection("users").document(request["user_id"]).get(
                transaction=transaction
            ).to_dict()
            if not player or player.get("status") != "active":
                return None, "ACCOUNT_SUSPENDED"
            start_time = game.get("start_time")
            if not isinstance(start_time, datetime) or start_time <= datetime.now(timezone.utc):
                return None, "GAME_CLOSED"
            approved = game.get("approved_count", 0)
            capacity = game.get("required_players", 0)
            if game.get("status") != "open" or approved >= capacity:
                return None, "GAME_FULL"
            approved += 1
            transaction.update(game_ref, {
                "approved_count": approved,
                "status": "full" if approved >= capacity else "open",
            })
        transaction.update(request_ref, {
            "request_status": action,
            "reviewed_at": firestore.SERVER_TIMESTAMP,
        })
        return {**request, "request_status": action}, None

    result, error = review(db.transaction())
    return result, error


def cancel_join(game_id, uid):
    db = get_firestore_client()
    game_ref = db.collection("games").document(game_id)
    participant_ref = db.collection("game_participants").document(f"{game_id}_{uid}")

    @firestore.transactional
    def cancel(transaction):
        participant = participant_ref.get(transaction=transaction).to_dict()
        game = game_ref.get(transaction=transaction).to_dict()
        if not game or not participant:
            return None, "NOT_FOUND"
        start_time = game.get("start_time")
        if not isinstance(start_time, datetime) or start_time <= datetime.now(timezone.utc):
            return None, "GAME_CLOSED"
        if participant.get("is_organizer"):
            return None, "ORGANIZER_CANNOT_CANCEL"
        if participant.get("request_status") not in {"pending", "approved"}:
            return None, "JOIN_NOT_ACTIVE"
        if participant.get("request_status") == "approved":
            approved = max(1, game.get("approved_count", 1) - 1)
            transaction.update(game_ref, {
                "approved_count": approved,
                "status": "open" if game.get("status") == "full" else game.get("status", "open"),
            })
        transaction.update(participant_ref, {
            "request_status": "cancelled",
            "cancelled_at": firestore.SERVER_TIMESTAMP,
        })
        return {"request_status": "cancelled"}, None

    return cancel(db.transaction())


def list_join_requests(game_id, organizer_uid):
    db = get_firestore_client()
    game = db.collection("games").document(game_id).get()
    if not game.exists:
        raise GameError("NOT_FOUND", "This game could not be found.", 404)
    if (game.to_dict() or {}).get("organizer_id") != organizer_uid:
        raise GameError("FORBIDDEN", "Only the host can review requests.", 403)
    requests = []
    for snapshot in db.collection("game_participants").where("game_id", "==", game_id).stream():
        request = snapshot.to_dict() or {}
        if request.get("request_status") != "pending":
            continue
        user_id = request.get("user_id")
        user = db.collection("users").document(user_id).get().to_dict() or {}
        profile = db.collection("profiles").document(user_id).get().to_dict() or {}
        requests.append({
            "id": snapshot.id,
            "user_id": user_id,
            "name": user.get("name") or "Player",
            "sports": profile.get("sports", []),
            "roles": profile.get("roles", {}),
            "levels": profile.get("levels", {}),
            "joined_at": request.get("joined_at"),
            "request_status": "pending",
        })
    requests.sort(key=lambda item: item["joined_at"] or datetime.min.replace(tzinfo=timezone.utc))
    return requests


def list_my_games(uid):
    db = get_firestore_client()
    hosted = []
    joined = []
    history = []
    now = datetime.now(timezone.utc)
    for snapshot in db.collection("games").where("organizer_id", "==", uid).stream():
        game = snapshot.to_dict() or {}
        item = {"id": snapshot.id, **game, "participation": "hosted"}
        (history if game.get("status") == "cancelled" or game.get("start_time") and game["start_time"] <= now else hosted).append(item)
    for snapshot in db.collection("game_participants").where("user_id", "==", uid).stream():
        participant = snapshot.to_dict() or {}
        if participant.get("is_organizer"):
            continue
        game_snapshot = db.collection("games").document(participant.get("game_id", "")).get()
        if not game_snapshot.exists:
            continue
        game = game_snapshot.to_dict() or {}
        item = {"id": game_snapshot.id, **game, "participation": participant.get("request_status")}
        if game.get("status") == "cancelled" or game.get("start_time") and game["start_time"] <= now:
            history.append(item)
        elif participant.get("request_status") in {"pending", "approved"}:
            joined.append(item)
    order = lambda item: item.get("start_time") or datetime.max.replace(tzinfo=timezone.utc)
    hosted.sort(key=order)
    joined.sort(key=order)
    history.sort(key=order, reverse=True)
    return {"hosted": hosted, "joined": joined, "history": history}


def list_player_previews(game_id, limit=3):
    """Approved players for map bubbles: host first, then by join time."""
    db = get_firestore_client()
    players = []
    for snapshot in db.collection("game_participants").where("game_id", "==", game_id).stream():
        item = snapshot.to_dict() or {}
        if item.get("request_status") == "approved" and item.get("user_id"):
            players.append(item)
    players.sort(key=lambda item: (
        not item.get("is_organizer", False),
        item.get("joined_at") or datetime.min.replace(tzinfo=timezone.utc),
    ))
    previews = []
    for item in players[:limit]:
        user_id = item["user_id"]
        user = db.collection("users").document(user_id).get().to_dict() or {}
        photo = db.collection("profiles").document(user_id).collection("media").document("avatar").get()
        previews.append({
            "user_id": user_id,
            "name": (user.get("name") or "Player").strip() or "Player",
            "has_photo": photo.exists,
        })
    return previews


def is_approved_player(game_id, user_id):
    snapshot = get_firestore_client().collection("game_participants").document(f"{game_id}_{user_id}").get()
    return snapshot.exists and (snapshot.to_dict() or {}).get("request_status") == "approved"
