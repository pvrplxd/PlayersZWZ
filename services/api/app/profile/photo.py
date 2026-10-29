"""Bounded avatar thumbnails, never originals or embedded location metadata.

The API owns one small media document per profile. Keeping the thumbnail out of
the profile document avoids inflating session reads and needs no new storage
account. Full-size media belongs in object storage when that feature is added.
"""
import base64
import binascii
from io import BytesIO
import warnings

from PIL import Image, ImageOps, UnidentifiedImageError
from google.cloud import firestore

from ..firebase import get_firestore_client

MAX_UPLOAD_BYTES = 2 * 1024 * 1024
MAX_REQUEST_BYTES = 2_800_000
MAX_PHOTO_BYTES = 128 * 1024


def normalize_photo(body):
    if not isinstance(body, dict) or set(body) != {"image"} or not isinstance(body["image"], str):
        raise ValueError("Choose a photo to upload.")
    if len(body["image"]) > (MAX_UPLOAD_BYTES + 2) // 3 * 4:
        raise ValueError("Choose a photo smaller than 2 MB.")
    try:
        raw = base64.b64decode(body["image"], validate=True)
        if not raw or len(raw) > MAX_UPLOAD_BYTES:
            raise ValueError("Choose a photo smaller than 2 MB.")
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(raw)) as source:
                if source.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValueError("Choose a JPEG, PNG or WebP photo.")
                if source.width * source.height > 12_000_000 or max(source.size) > 6000:
                    raise ValueError("Choose a smaller photo.")
                source.load()
                oriented = ImageOps.exif_transpose(source)
                square = ImageOps.fit(oriented.convert("RGBA"), (512, 512), method=Image.Resampling.LANCZOS)
                # Flatten transparency and copy only pixels, dropping EXIF/GPS.
                clean = Image.new("RGB", square.size, (29, 29, 29))
                clean.paste(square, mask=square.getchannel("A"))
                for quality in (85, 70, 55):
                    output = BytesIO()
                    clean.save(output, format="JPEG", quality=quality, optimize=True)
                    if len(output.getvalue()) <= MAX_PHOTO_BYTES:
                        return output.getvalue()
    except (binascii.Error, UnidentifiedImageError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise ValueError("That photo could not be read. Choose another image.") from exc
    raise ValueError("Choose a less detailed photo.")


def photo_record(uid, *, operation="read", data=None):
    db = get_firestore_client()
    user_ref = db.collection("users").document(uid)
    profile_ref = db.collection("profiles").document(uid)
    photo_ref = profile_ref.collection("media").document("avatar")

    @firestore.transactional
    def access(transaction):
        user = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        if not user or profile is None:
            return None, "PROFILE_REQUIRED"
        if user.get("status") != "active":
            return None, "ACCOUNT_SUSPENDED"
        if operation == "read":
            record = photo_ref.get(transaction=transaction).to_dict()
            return record.get("jpeg") if record else None, None
        if operation == "delete":
            transaction.delete(photo_ref)
            return None, None
        if operation != "write" or not isinstance(data, bytes) or len(data) > MAX_PHOTO_BYTES:
            raise ValueError("Invalid photo operation")
        transaction.set(photo_ref, {"jpeg": data, "updated_at": firestore.SERVER_TIMESTAMP})
        return data, None

    return access(db.transaction())


def photo_response(data):
    return {"photo": None if data is None else {"image": base64.b64encode(data).decode("ascii"), "content_type": "image/jpeg"}}
