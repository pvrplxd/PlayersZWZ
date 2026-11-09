import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from app.profile.routes import username, validate, save_profile
from app.profile.service import validate_preferences
from app.profile.repository import save_preferences

class ProfileTests(unittest.TestCase):
    def test_validation(self):
        self.assertEqual(username(" Afaq_1 "), "afaq_1")
        for value in ["ab", "../name", "name space", "", "x" * 21, None]:
            with self.assertRaises(ValueError):
                username(value)
        for sports in [[], ["Golf"], ["Cricket", "Cricket"], [None]]:
            with self.assertRaises(ValueError):
                validate({"username": "afaq", "sports": sports})
        with self.assertRaises(ValueError):
            validate({"username": "afaq", "sports": ["Cricket"], "role": "admin"})

    def test_transaction(self):
        with patch("app.profile.repository.get_firestore_client") as get_db, patch("app.profile.repository.firestore.transactional", side_effect=lambda f: f):
            db = get_db.return_value
            refs = {name: MagicMock() for name in ["users", "profiles", "usernames"]}
            db.collection.side_effect = lambda name: SimpleNamespace(document=lambda key: refs[name])
            refs["users"].get.return_value.to_dict.return_value = {"status": "active"}
            refs["profiles"].get.return_value.to_dict.return_value = {"bio": "preserve"}
            refs["usernames"].get.return_value.to_dict.return_value = {"user_id": "other"}
            details = validate({"username": "afaq", "sports": ["Cricket"]})
            self.assertEqual(save_profile("me", details)[1], "USERNAME_TAKEN")
            db.transaction.return_value.update.assert_not_called()
            refs["usernames"].get.return_value.to_dict.return_value = {"user_id": "me"}
            profile, error = save_profile("me", details)
            self.assertIsNone(error)
            self.assertEqual(profile["bio"], "preserve")
            self.assertTrue(profile["setup_complete"])
            refs["users"].get.return_value.to_dict.return_value = {"status": "suspended"}
            db.transaction.return_value.reset_mock()
            self.assertEqual(save_profile("me", details)[1], "ACCOUNT_SUSPENDED")
            db.transaction.return_value.update.assert_not_called()

    def test_preferences_validation_and_transaction(self):
        valid = {
            "sports": ["Cricket", "Football"],
            "availability": ["Friday", "Sunday"],
            "radius_km": 15,
            "bio": " Weekend player ",
        }
        self.assertEqual(validate_preferences(valid)["bio"], "Weekend player")
        for field, value in [
            ("sports", []),
            ("availability", ["Friday", "Friday"]),
            ("radius_km", 51),
            ("radius_km", True),
            ("bio", "x" * 281),
        ]:
            with self.assertRaises(ValueError):
                validate_preferences({**valid, field: value})

        with patch("app.profile.repository.get_firestore_client") as get_db, patch("app.profile.repository.firestore.transactional", side_effect=lambda f: f):
            db = get_db.return_value
            refs = {name: MagicMock() for name in ["users", "profiles"]}
            db.collection.side_effect = lambda name: SimpleNamespace(document=lambda key: refs[name])
            refs["users"].get.return_value.to_dict.return_value = {"status": "active"}
            refs["profiles"].get.return_value.to_dict.return_value = {"setup_complete": True, "username": "afaq"}
            profile, error = save_preferences("me", validate_preferences(valid))
            self.assertIsNone(error)
            self.assertEqual(profile["radius_km"], 15)
            db.transaction.return_value.update.assert_called_once()
            refs["profiles"].get.return_value.to_dict.return_value = {"setup_complete": False}
            self.assertEqual(save_preferences("me", validate_preferences(valid))[1], "PROFILE_REQUIRED")


class ProfileExtrasTests(unittest.TestCase):
    base = {"sports": ["Cricket", "Football"], "availability": [], "radius_km": 10, "bio": ""}

    def test_roles_levels_and_mode(self):
        details = validate_preferences({**self.base, "roles": {"Cricket": ["Batter"], "Football": []},
                                        "levels": {"Cricket": "Advanced"}, "location_mode": "home"})
        self.assertEqual(details["roles"], {"Cricket": ["Batter"]})
        self.assertEqual(details["levels"], {"Cricket": "Advanced"})
        self.assertEqual(details["location_mode"], "home")
        self.assertNotIn("roles", validate_preferences(dict(self.base)))
        for extra in [{"roles": {"Tennis": ["Singles"]}}, {"roles": {"Cricket": ["Goalkeeper"]}},
                      {"roles": {"Cricket": ["Batter", "Batter"]}}, {"levels": {"Cricket": "Pro"}},
                      {"location_mode": "office"}, {"role": "admin"}]:
            with self.assertRaises(ValueError):
                validate_preferences({**self.base, **extra})

    def test_home_location(self):
        from app.profile.service import validate_home_location
        self.assertEqual(validate_home_location({"latitude": 31.5, "longitude": 74.3, "label": " Home "})["label"], "Home")
        for body in [{"latitude": 91, "longitude": 0, "label": "x"}, {"latitude": 1, "longitude": 1, "label": ""},
                     {"latitude": 1, "longitude": 1, "label": "x", "source": "gps"}, {"latitude": True, "longitude": 1, "label": "x"}]:
            with self.assertRaises(ValueError):
                validate_home_location(body)
