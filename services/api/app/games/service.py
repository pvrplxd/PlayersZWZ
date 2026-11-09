from datetime import datetime, timezone
import math

from ..profile.service import SPORTS

_GEOHASH_ALPHABET = "0123456789bcdefghjkmnpqrstuvwxyz"


class GameError(Exception):
    def __init__(self, code, message, status=400):
        super().__init__(message)
        self.code = code
        self.status = status


def _number(value, name, minimum, maximum):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise GameError("VALIDATION_ERROR", f"Choose a valid {name}.")
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise GameError("VALIDATION_ERROR", f"Choose a valid {name}.")
    return float(value)


def parse_point(body):
    latitude = _number(body.get("latitude"), "latitude", -90, 90)
    longitude = _number(body.get("longitude"), "longitude", -180, 180)
    return latitude, longitude


def validate_create(body):
    required = {
        "sport", "start_time", "latitude", "longitude", "location_label",
        "required_players", "notes",
    }
    if not isinstance(body, dict) or not required.issubset(body) or set(body) - (required | {"fee_amount"}):
        raise GameError("VALIDATION_ERROR", "Complete the game details.")

    sport = body["sport"]
    if not isinstance(sport, str) or sport not in SPORTS:
        raise GameError("VALIDATION_ERROR", "Choose a supported sport.")

    raw_time = body["start_time"]
    if not isinstance(raw_time, str):
        raise GameError("VALIDATION_ERROR", "Choose a future date and time.")
    try:
        start_time = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
    except ValueError as exc:
        raise GameError("VALIDATION_ERROR", "Choose a valid date and time.") from exc
    if start_time.tzinfo is None or start_time <= datetime.now(timezone.utc):
        raise GameError("VALIDATION_ERROR", "Choose a future date and time.")
    start_time = start_time.astimezone(timezone.utc)

    latitude, longitude = parse_point(body)
    location_label = body["location_label"]
    if not isinstance(location_label, str) or not 1 <= len(location_label.strip()) <= 300:
        raise GameError("VALIDATION_ERROR", "Choose a game location.")

    players = body["required_players"]
    # The host counts as the first player; a game must have room for at least one guest.
    if isinstance(players, bool) or not isinstance(players, int) or not 2 <= players <= 40:
        raise GameError("VALIDATION_ERROR", "Choose between 2 and 40 total players.")

    notes = body["notes"]
    if not isinstance(notes, str) or len(notes.strip()) > 280:
        raise GameError("VALIDATION_ERROR", "Notes must be 280 characters or fewer.")

    fee_amount = body.get("fee_amount", 0)
    if (isinstance(fee_amount, bool) or not isinstance(fee_amount, int)
            or not 0 <= fee_amount <= 100000):
        raise GameError("VALIDATION_ERROR", "Enter a fee between Rs. 0 and Rs. 100,000.")

    return {
        "sport": sport,
        "start_time": start_time,
        "latitude": latitude,
        "longitude": longitude,
        "location_label": location_label.strip(),
        "required_players": players,
        "fee_amount": fee_amount,
        "notes": notes.strip(),
    }


def haversine_km(latitude_a, longitude_a, latitude_b, longitude_b):
    earth_radius_km = 6371.0088
    lat_a, lat_b = math.radians(latitude_a), math.radians(latitude_b)
    delta_lat = lat_b - lat_a
    delta_lon = math.radians(longitude_b - longitude_a)
    arc = math.sin(delta_lat / 2) ** 2 + math.cos(lat_a) * math.cos(lat_b) * math.sin(delta_lon / 2) ** 2
    arc = min(1.0, max(0.0, arc))
    return earth_radius_km * 2 * math.atan2(math.sqrt(arc), math.sqrt(1 - arc))


def encode_geohash(latitude, longitude, precision=10):
    lat_range = [-90.0, 90.0]
    lon_range = [-180.0, 180.0]
    bits = []
    even = True
    while len(bits) < precision * 5:
        bounds = lon_range if even else lat_range
        value = longitude if even else latitude
        midpoint = (bounds[0] + bounds[1]) / 2
        if value >= midpoint:
            bits.append(1)
            bounds[0] = midpoint
        else:
            bits.append(0)
            bounds[1] = midpoint
        even = not even
    chars = []
    for offset in range(0, len(bits), 5):
        value = 0
        for bit in bits[offset:offset + 5]:
            value = (value << 1) | bit
        chars.append(_GEOHASH_ALPHABET[value])
    return "".join(chars)


def geohash_search_prefixes(latitude, longitude, radius_km):
    # Choose cells at least twice the radius in both dimensions, then search
    # the center cell and its eight neighbors before exact Haversine filtering.
    precision = 1
    for candidate in range(10, 0, -1):
        bits = candidate * 5
        lon_bits = (bits + 1) // 2
        lat_bits = bits // 2
        cell_height_km = 180 / (2 ** lat_bits) * 111.32
        cell_width_km = 360 / (2 ** lon_bits) * 111.32 * max(0.0, math.cos(math.radians(latitude)))
        if min(cell_height_km, cell_width_km) >= radius_km * 2:
            precision = candidate
            break
    bits = precision * 5
    lon_bits = (bits + 1) // 2
    lat_bits = bits // 2
    lat_step = 180 / (2 ** lat_bits)
    lon_step = 360 / (2 ** lon_bits)
    prefixes = set()
    for lat_delta in (-lat_step, 0.0, lat_step):
        lat = min(89.999999, max(-89.999999, latitude + lat_delta))
        for lon_delta in (-lon_step, 0.0, lon_step):
            lon = ((longitude + lon_delta + 180) % 360) - 180
            prefixes.add(encode_geohash(lat, lon, precision))
    return prefixes


def timestamp(value):
    if not isinstance(value, datetime):
        return value
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def serialize_game(game_id, game, *, participation=None, distance_km=None):
    location = game.get("location")
    latitude = getattr(location, "latitude", None)
    longitude = getattr(location, "longitude", None)
    if isinstance(location, dict):
        latitude = location.get("latitude", latitude)
        longitude = location.get("longitude", longitude)
    capacity = game.get("required_players", 0)
    approved = game.get("approved_count", 0)
    result = {
        "id": game_id,
        "sport": game.get("sport"),
        "start_time": timestamp(game.get("start_time")),
        "latitude": latitude,
        "longitude": longitude,
        "location_label": game.get("location_label", "Game location"),
        "required_players": capacity,
        "fee_amount": game.get("fee_amount", 0),
        "approved_count": approved,
        "open_spots": max(0, capacity - approved),
        "status": game.get("status"),
        "organizer_id": game.get("organizer_id"),
        "organizer_name": game.get("organizer_name", "Player"),
        "notes": game.get("notes", ""),
        "created_at": timestamp(game.get("created_at")),
        "participation": participation,
    }
    if distance_km is not None:
        result["distance_km"] = round(distance_km, 1)
    return result


def radius_value(value, fallback=10):
    if value is None:
        return fallback
    if isinstance(value, bool):
        raise GameError("VALIDATION_ERROR", "Radius must be between 1 and 50 km.")
    try:
        radius = float(value)
    except (TypeError, ValueError) as exc:
        raise GameError("VALIDATION_ERROR", "Radius must be between 1 and 50 km.") from exc
    if not math.isfinite(radius) or not 1 <= radius <= 50:
        raise GameError("VALIDATION_ERROR", "Radius must be between 1 and 50 km.")
    return radius
