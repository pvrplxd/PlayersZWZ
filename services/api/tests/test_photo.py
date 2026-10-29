import base64
from io import BytesIO
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

from PIL import Image
from app import create_app
from app.profile.photo import normalize_photo, photo_record, MAX_PHOTO_BYTES


def image_body():
    output = BytesIO()
    image = Image.new("RGB", (640, 480), (30, 90, 120))
    exif = Image.Exif()
    exif[270] = "Private camera metadata"
    image.save(output, "JPEG", exif=exif)
    return {"image": base64.b64encode(output.getvalue()).decode()}


class PhotoValidationTests(unittest.TestCase):
    def test_resize_square_strip_metadata_and_bound_size(self):
        data = normalize_photo(image_body())
        self.assertLessEqual(len(data), MAX_PHOTO_BYTES)
        with Image.open(BytesIO(data)) as image:
            self.assertEqual(image.size, (512, 512))
            self.assertEqual(image.format, "JPEG")
            self.assertEqual(len(image.getexif()), 0)

    def test_reject_invalid_formats_fields_and_oversized_inputs(self):
        for body in (None, {}, {"image": 3}, {"image": "not-base64"},
                     {"image": base64.b64encode(b"<svg></svg>").decode()},
                     {**image_body(), "user_id": "someone-else"},
                     {"image": "A" * 2_800_000}):
            with self.assertRaises(ValueError):
                normalize_photo(body)

    def test_reject_high_pixel_count_before_decoding(self):
        output = BytesIO()
        Image.new("1", (4000, 4000)).save(output, "PNG")
        with self.assertRaises(ValueError):
            normalize_photo({"image": base64.b64encode(output.getvalue()).decode()})


class PhotoRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.db = self.enterContext(patch("app.profile.photo.get_firestore_client")).return_value
        self.enterContext(patch("app.profile.photo.firestore.transactional", side_effect=lambda f: f))
        self.refs = {key: MagicMock() for key in ("users", "profiles")}
        self.ids = []
        def collection(name):
            def document(uid):
                self.ids.append(uid)
                return self.refs[name]
            return SimpleNamespace(document=document)
        self.db.collection.side_effect = collection
        self.refs["users"].get.return_value.to_dict.return_value = {"status": "active"}
        self.refs["profiles"].get.return_value.to_dict.return_value = {"setup_complete": False}
        self.photo = self.refs["profiles"].collection.return_value.document.return_value
        self.photo.get.return_value.to_dict.return_value = {"jpeg": b"saved"}
        self.transaction = self.db.transaction.return_value

    def test_owned_photo_round_trip_and_delete(self):
        self.assertEqual(photo_record("me"), (b"saved", None))
        self.assertEqual(self.ids, ["me", "me"])
        self.refs["profiles"].collection.assert_called_with("media")
        self.refs["profiles"].collection.return_value.document.assert_called_with("avatar")
        self.assertEqual(photo_record("me", operation="write", data=b"new"), (b"new", None))
        self.transaction.set.assert_called_once()
        self.assertEqual(photo_record("me", operation="delete"), (None, None))
        self.transaction.delete.assert_called_once_with(self.photo)

    def test_suspended_or_missing_account_cannot_read_or_write(self):
        for user in (None, {"status": "suspended"}):
            self.refs["users"].get.return_value.to_dict.return_value = user
            for operation in ("read", "write", "delete"):
                self.assertIsNotNone(photo_record("me", operation=operation, data=b"new")[1])
        self.transaction.set.assert_not_called()
        self.transaction.delete.assert_not_called()
        self.photo.get.assert_not_called()


class PhotoRouteTests(unittest.TestCase):
    def setUp(self):
        self.client = create_app().test_client()
        self.enterContext(patch("app.auth.middleware.verify_firebase_id_token", return_value={"uid": "me"}))
        db = self.enterContext(patch("app.auth.middleware.get_firestore_client"))
        db.return_value.collection.return_value.document.return_value.get.return_value.to_dict.return_value = {"status": "active"}
        self.headers = {"Authorization": "Bearer test-token"}

    def test_every_operation_requires_authentication(self):
        for method in ("get", "put", "delete"):
            self.assertEqual(getattr(self.client, method)("/api/v1/me/profile/photo").status_code, 401)

    def test_save_uses_token_owner_and_returns_normalized_photo(self):
        with patch("app.profile.routes.photo_record", side_effect=lambda uid, operation, data: (data, None)) as save:
            response = self.client.put("/api/v1/me/profile/photo", json=image_body(), headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(save.call_args.args, ("me",))
        self.assertEqual(save.call_args.kwargs["operation"], "write")
        self.assertEqual(response.json["photo"]["content_type"], "image/jpeg")
        self.assertEqual(response.headers["Cache-Control"], "private, no-store")

    def test_invalid_body_and_large_request_do_not_write(self):
        with patch("app.profile.routes.photo_record") as save:
            self.assertEqual(self.client.put("/api/v1/me/profile/photo", json={"image": "invalid", "user_id": "other"}, headers=self.headers).status_code, 400)
            self.assertEqual(self.client.put("/api/v1/me/profile/photo", data="{" , content_type="application/json", headers=self.headers).status_code, 400)
            self.assertEqual(self.client.put("/api/v1/me/profile/photo", data=b"A" * 2_800_001, content_type="application/json", headers=self.headers).status_code, 413)
            save.assert_not_called()

    def test_read_delete_and_failure_responses(self):
        with patch("app.profile.routes.photo_record", return_value=(None, None)):
            self.assertIsNone(self.client.get("/api/v1/me/profile/photo", headers=self.headers).json["photo"])
            self.assertIsNone(self.client.delete("/api/v1/me/profile/photo", headers=self.headers).json["photo"])
        with patch("app.profile.routes.photo_record", side_effect=RuntimeError("private failure")):
            response = self.client.get("/api/v1/me/profile/photo", headers=self.headers)
            self.assertEqual(response.status_code, 503)
            self.assertNotIn("private failure", response.get_data(as_text=True))
