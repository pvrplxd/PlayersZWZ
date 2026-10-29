import re

SPORTS = {"Basketball", "Badminton", "Football", "Skating", "Cricket", "Tennis"}


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
