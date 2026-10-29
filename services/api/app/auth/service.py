"""Account setup rules; identity and privileges come from trusted sources."""

from flask import current_app


class AccountSuspended(Exception):
    pass


class AccountSetupRequired(Exception):
    pass


def validate_session_body(body):
    if not isinstance(body, dict):
        raise ValueError("The request body must be a JSON object.")
    if body.keys() - {"name", "city", "favorite_sport"}:
        raise ValueError("Only name, city, and favorite_sport may be supplied.")
    result = {}
    for field, limit in (("name", 100), ("city", 100), ("favorite_sport", 50)):
        if field not in body:
            continue
        value = body[field]
        if not isinstance(value, str) or not value.strip() or len(value.strip()) > limit:
            raise ValueError(f"{field} must contain 1–{limit} characters.")
        result[field] = value.strip()
    return result


def initial_records(uid, claims, details):
    user = {
        "user_id": uid,
        "name": details.get("name", claims.get("name", "")),
        "email": claims.get("email"),
        "role": "player",
        "city": details.get("city", ""),
        "status": "active",
    }
    profile = {
        "profile_id": uid,
        "user_id": uid,
        "sports": [details["favorite_sport"]] if "favorite_sport" in details else [],
        "availability": [],
        "radius_km": current_app.config["DEFAULT_RADIUS_KM"],
        "bio": "",
        "location": None,
        "reliability_score": None,
    }
    return user, profile


def account_response(uid, user, profile):
    if user is not None and user.get("status") == "suspended":
        raise AccountSuspended()
    if user is None or profile is None:
        raise AccountSetupRequired()
    return {
        "user": {**user, "user_id": uid},
        "profile": {**serialize_profile(profile), "profile_id": uid, "user_id": uid},
        "role": user.get("role"),
    }

def serialize_profile(profile):
    from google.cloud.firestore import GeoPoint
    result = dict(profile)
    location = result.get("location")
    if isinstance(location, GeoPoint):
        result["location"] = {"latitude": location.latitude, "longitude": location.longitude}
    return result
