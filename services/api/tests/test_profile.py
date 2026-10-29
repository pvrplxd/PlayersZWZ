import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from app.profile.routes import username, validate, save_profile

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
