import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from firebase_admin import auth

from app import create_app
from app.auth import repository
from app.config import Config


class TestConfig(Config):
    TESTING = True


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app(TestConfig)
        self.client = self.app.test_client()
        self.claims = {"uid": "player-1", "email": "player@example.com", "name": "Player"}
        self.user = {"user_id": "player-1", "role": "player", "status": "active"}
        self.profile = {"user_id": "player-1", "sports": []}
        self.headers = {"Authorization": "Bearer test-token"}
        self.verify = self.enterContext(patch("app.auth.middleware.verify_firebase_id_token", return_value=self.claims))
        self.db = self.enterContext(patch("app.auth.middleware.get_firestore_client"))
        self.snapshot = self.db.return_value.collection.return_value.document.return_value.get.return_value
        self.snapshot.exists = False

    def test_missing_or_invalid_token(self):
        self.assertEqual(self.client.get("/api/v1/me").status_code, 401)
        self.verify.assert_not_called()
        self.verify.side_effect = auth.InvalidIdTokenError("Invalid")
        self.assertEqual(self.client.get("/api/v1/me", headers=self.headers).status_code, 401)

    def test_session_uses_trusted_identity_and_defaults(self):
        with patch("app.auth.routes.ensure_account", return_value=(self.user, self.profile)) as ensure:
            response = self.client.post("/api/v1/auth/session", json={"name": " Afaq ", "favorite_sport": "Football"}, headers=self.headers)
        self.assertEqual(response.status_code, 200)
        uid, user, profile = ensure.call_args.args
        self.assertEqual(uid, "player-1")
        self.assertEqual(user["name"], "Afaq")
        self.assertEqual(user["email"], self.claims["email"])
        self.assertEqual(user["role"], "player")
        self.assertEqual(profile["sports"], ["Football"])
        self.assertIsNone(profile["reliability_score"])

    def test_invalid_bodies_and_privilege_injection(self):
        with patch("app.auth.routes.ensure_account") as ensure:
            for body in ([], None, {"role": "admin"}, {"user_id": "other"}, {"name": " "}, {"city": 7}, {"favorite_sport": "x" * 51}):
                response = self.client.post("/api/v1/auth/session", json=body, headers=self.headers)
                self.assertEqual(response.status_code, 400, body)
            response = self.client.post("/api/v1/auth/session", data="{", content_type="application/json", headers=self.headers)
            self.assertEqual(response.status_code, 400)
            ensure.assert_not_called()

    def test_me_requires_setup_without_writing(self):
        with patch("app.auth.routes.load_account", return_value=(None, None)), patch("app.auth.routes.ensure_account") as ensure:
            response = self.client.get("/api/v1/me", headers=self.headers)
            self.assertEqual(response.status_code, 403)
            self.assertEqual(response.json["error"]["code"], "PROFILE_REQUIRED")
            ensure.assert_not_called()

    def test_me_returns_current_account(self):
        with patch("app.auth.routes.load_account", return_value=(self.user, self.profile)) as load:
            response = self.client.get("/api/v1/me", headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["role"], "player")
        load.assert_called_once_with("player-1")

    def test_suspended_account_cannot_start_session(self):
        self.snapshot.exists = True
        self.snapshot.to_dict.return_value = {**self.user, "status": "suspended"}
        with patch("app.auth.routes.ensure_account") as ensure:
            response = self.client.post("/api/v1/auth/session", json={}, headers=self.headers)
            self.assertEqual(response.status_code, 403)
            ensure.assert_not_called()

    def test_database_and_verification_failures(self):
        with patch("app.auth.routes.ensure_account", side_effect=RuntimeError("private database detail")):
            response = self.client.post("/api/v1/auth/session", json={}, headers=self.headers)
            self.assertEqual(response.status_code, 503)
            self.assertNotIn("private", response.get_data(as_text=True))
        self.verify.side_effect = RuntimeError("Unavailable")
        self.assertEqual(self.client.get("/api/v1/me", headers=self.headers).status_code, 503)


class AccountRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.db = self.enterContext(patch("app.auth.repository.get_firestore_client")).return_value
        # Execute the transaction body locally; real Firestore commit/retry remains an integration check.
        self.enterContext(patch("app.auth.repository.firestore.transactional", side_effect=lambda function: function))
        self.refs = {name: MagicMock() for name in ("users", "profiles")}
        self.db.collection.side_effect = lambda name: SimpleNamespace(document=lambda uid: self.refs[name])
        self.transaction = self.db.transaction.return_value

    def test_first_session_then_retry_preserves_existing_data(self):
        for ref in self.refs.values():
            ref.get.return_value.to_dict.return_value = None
        user, profile = repository.ensure_account("player-1", {"role": "player"}, {"sports": []})
        self.assertEqual(self.transaction.create.call_count, 2)
        self.assertIn("created_at", user)
        existing_user = {"role": "admin", "status": "warned"}
        existing_profile = {"sports": ["Cricket"], "bio": "Keep me"}
        self.refs["users"].get.return_value.to_dict.return_value = existing_user
        self.refs["profiles"].get.return_value.to_dict.return_value = existing_profile
        self.transaction.reset_mock()
        self.assertEqual(repository.ensure_account("player-1", user, profile), (existing_user, existing_profile))
        self.transaction.create.assert_not_called()

    def test_missing_profile_repaired_without_overwriting_user(self):
        self.refs["users"].get.return_value.to_dict.return_value = {"role": "admin"}
        self.refs["profiles"].get.return_value.to_dict.return_value = None
        repository.ensure_account("player-1", {"role": "player"}, {"sports": []})
        self.transaction.create.assert_called_once_with(self.refs["profiles"], {"sports": []})

    def test_suspension_rechecked_inside_transaction(self):
        self.refs["users"].get.return_value.to_dict.return_value = {"status": "suspended"}
        self.refs["profiles"].get.return_value.to_dict.return_value = None
        with self.assertRaises(repository.AccountSuspended):
            repository.ensure_account("player-1", {}, {})
        self.transaction.create.assert_not_called()


if __name__ == "__main__":
    unittest.main()
