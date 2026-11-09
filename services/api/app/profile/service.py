import re

SPORTS = {"Basketball", "Badminton", "Football", "Skating", "Cricket", "Tennis"}
SPORT_ROLES = {
    "Football": {"Goalkeeper", "Defender", "Midfielder", "Forward"},
    "Cricket": {"Batter", "Bowler", "All-rounder", "Wicket-keeper"},
    "Basketball": {"Guard", "Forward", "Center"},
    "Badminton": {"Singles", "Doubles"},
    "Tennis": {"Singles", "Doubles"},
    "Skating": {"Street", "Park", "Speed"},
}
SKILL_LEVELS = {"Beginner", "Intermediate", "Advanced"}
LOCATION_MODES = {"live", "home"}
AVAILABILITY_DAYS = {
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
}


def username(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9][a-z0-9_.]{2,19}", value.strip().lower()):
        raise ValueError("Use 3–20 letters, numbers, underscores or dots; start with a letter or number.")
    return value.strip().lower()


def validate(body):
    if not isinstance(body, dict) or set(body) != {"username", "sports"}:
        raise ValueError("Supply username and sports only.")
    name = username(body["username"])
    sports = body["sports"]
    if not isinstance(sports, list) or not 1 <= len(sports) <= 6 or any(not isinstance(s, str) or s not in SPORTS for s in sports) or len(set(sports)) != len(sports):
        raise ValueError("Choose at least one supported sport, without duplicates.")
    return {"username": name, "sports": sports, "setup_complete": True}


def validate_location(body):
    import math
    if not isinstance(body, dict) or set(body) != {"latitude", "longitude", "label", "source"}:
        raise ValueError("Supply coordinates, label and source.")
    for key, limit in (("latitude", 90), ("longitude", 180)):
        value = body[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not -limit <= value <= limit or not math.isfinite(value):
            raise ValueError("Invalid coordinates.")
    if body["source"] not in ("gps", "manual"):
        raise ValueError("Invalid location source.")
    label = body["label"]
    if not isinstance(label, str) or not 1 <= len(label.strip()) <= 300:
        raise ValueError("Choose a valid location label.")
    return {**body, "label": label.strip()}


def validate_preferences(body):
    """Validate the fields a completed player may change from their profile."""
    required = {"sports", "availability", "radius_km", "bio"}
    optional = {"roles", "levels", "location_mode"}
    if not isinstance(body, dict) or not required <= set(body) or not set(body) <= required | optional:
        raise ValueError("Supply sports, availability, radius and bio, plus optional roles, levels and location mode.")

    sports = body["sports"]
    if (
        not isinstance(sports, list)
        or not 1 <= len(sports) <= len(SPORTS)
        or any(not isinstance(sport, str) or sport not in SPORTS for sport in sports)
        or len(set(sports)) != len(sports)
    ):
        raise ValueError("Choose at least one supported sport, without duplicates.")

    availability = body["availability"]
    if (
        not isinstance(availability, list)
        or any(not isinstance(day, str) or day not in AVAILABILITY_DAYS for day in availability)
        or len(set(availability)) != len(availability)
    ):
        raise ValueError("Choose valid availability days, without duplicates.")

    radius = body["radius_km"]
    if isinstance(radius, bool) or not isinstance(radius, int) or not 1 <= radius <= 50:
        raise ValueError("Choose a radius from 1 to 50 km.")

    bio = body["bio"]
    if not isinstance(bio, str) or len(bio.strip()) > 280:
        raise ValueError("Bio must be 280 characters or fewer.")

    details = {
        "sports": sports,
        "availability": availability,
        "radius_km": radius,
        "bio": bio.strip(),
    }

    if "roles" in body:
        roles = body["roles"]
        if not isinstance(roles, dict) or any(sport not in sports for sport in roles):
            raise ValueError("Roles must belong to your chosen sports.")
        for sport, values in roles.items():
            if (
                not isinstance(values, list)
                or len(values) > len(SPORT_ROLES[sport])
                or len(set(values)) != len(values)
                or any(value not in SPORT_ROLES[sport] for value in values)
            ):
                raise ValueError("Choose valid roles for each sport.")
        details["roles"] = {sport: values for sport, values in roles.items() if values}

    if "levels" in body:
        levels = body["levels"]
        if (
            not isinstance(levels, dict)
            or any(sport not in sports for sport in levels)
            or any(level not in SKILL_LEVELS for level in levels.values())
        ):
            raise ValueError("Choose a valid level for each sport.")
        details["levels"] = levels

    if "location_mode" in body:
        if body["location_mode"] not in LOCATION_MODES:
            raise ValueError("Choose live or home location.")
        details["location_mode"] = body["location_mode"]

    return details


def validate_home_location(body):
    """Validate a player's saved home location (used when searching from home)."""
    import math
    if not isinstance(body, dict) or set(body) != {"latitude", "longitude", "label"}:
        raise ValueError("Supply coordinates and a label.")
    for key, limit in (("latitude", 90), ("longitude", 180)):
        value = body[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not -limit <= value <= limit or not math.isfinite(value):
            raise ValueError("Invalid coordinates.")
    label = body["label"]
    if not isinstance(label, str) or not 1 <= len(label.strip()) <= 300:
        raise ValueError("Choose a valid location label.")
    return {"latitude": float(body["latitude"]), "longitude": float(body["longitude"]), "label": label.strip()}
