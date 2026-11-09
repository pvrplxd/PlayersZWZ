import unittest
from unittest.mock import MagicMock, patch

from app import create_app


class PlayerPhotoRouteTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch("app.auth.middleware.verify_firebase_id_token", return_value={"uid": "me"}))
        db = self.enterContext(patch("app.auth.middleware.get_firestore_client")).return_value
        user = MagicMock(exists=True)
        user.to_dict.return_value = {"status": "active"}
        db.collection.return_value.document.return_value.get.return_value = user
        self.client = create_app().test_client()
        self.headers = {"Authorization": "Bearer token"}

    def test_only_approved_players_photos_are_served(self):
        with patch("app.games.routes.is_approved_player", return_value=False):
            response = self.client.get("/api/v1/games/g1/players/u2/photo", headers=self.headers)
        self.assertEqual(response.status_code, 404)

    def test_approved_player_photo_is_returned(self):
        with patch("app.games.routes.is_approved_player", return_value=True), \
                patch("app.profile.photo.photo_record", return_value=(b"jpeg", None)):
            response = self.client.get("/api/v1/games/g1/players/u2/photo", headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["photo"]["content_type"], "image/jpeg")

    def test_requires_sign_in(self):
        response = self.client.get("/api/v1/games/g1/players/u2/photo")
        self.assertEqual(response.status_code, 401)
