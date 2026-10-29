import unittest
from unittest.mock import MagicMock, patch
from types import SimpleNamespace
from google.cloud.firestore import GeoPoint
from app.profile.service import validate_location
from app.profile.repository import save_location
from app.auth.service import serialize_profile
from app import create_app

class LocationTests(unittest.TestCase):
    def test_coordinates_and_fields(self):
        valid = {"latitude": 31.52, "longitude": 74.35, "source": "manual", "label": " Lahore "}
        self.assertEqual(validate_location(valid)["label"], "Lahore")
        for field, value in [("latitude", True), ("latitude", float("nan")), ("longitude", 181), ("latitude", 91), ("label", ""), ("source", "other")]:
            with self.assertRaises(ValueError):
                validate_location({**valid, field: value})
        with self.assertRaises(ValueError):
            validate_location({**valid, "user_id": "other"})
        self.assertEqual(serialize_profile({"location": GeoPoint(31, 74)})["location"], {"latitude": 31, "longitude": 74})

    def test_save_ownership_and_suspension(self):
        with patch("app.profile.repository.get_firestore_client") as get_db, patch("app.profile.repository.firestore.transactional", side_effect=lambda f: f):
            db = get_db.return_value
            refs = {name: MagicMock() for name in ["users", "profiles"]}
            ids = []
            def collection(name):
                def document(uid):
                    ids.append(uid)
                    return refs[name]
                return SimpleNamespace(document=document)
            db.collection.side_effect = collection
            refs["users"].get.return_value.to_dict.return_value = {"status": "active"}
            refs["profiles"].get.return_value.to_dict.return_value = {"setup_complete": True, "sports": ["Cricket"]}
            profile, code = save_location("me", {"latitude": 31, "longitude": 74, "source": "manual", "label": "Lahore"})
            self.assertIsNone(code)
            self.assertEqual(ids, ["me", "me"])
            self.assertEqual(profile["sports"], ["Cricket"])
            refs["users"].get.return_value.to_dict.return_value = {"status": "suspended"}
            db.transaction.return_value.reset_mock()
            self.assertEqual(save_location("me", {})[1], "ACCOUNT_SUSPENDED")
            db.transaction.return_value.update.assert_not_called()

    def test_route_requires_auth(self):
        client = create_app().test_client()
        self.assertEqual(client.put("/api/v1/me/profile/location", json={}).status_code, 401)
