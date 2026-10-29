import unittest
from unittest.mock import patch

from app import create_app
from app.config import Config
from app.firebase import get_firebase_app


class CloudConfigTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app(Config)
        self.app.config.update(FIREBASE_PROJECT_ID="test-project", GOOGLE_APPLICATION_CREDENTIALS="secrets/local.json")
        context = self.app.app_context()
        context.push()
        self.addCleanup(context.pop)
        self.enterContext(patch("app.firebase.firebase_admin.get_app", side_effect=ValueError))
        self.cert = self.enterContext(patch("app.firebase.credentials.Certificate"))
        self.initialize = self.enterContext(patch("app.firebase.firebase_admin.initialize_app"))

    def test_cloud_credentials_override_local_path(self):
        self.app.config["FIREBASE_SERVICE_ACCOUNT_JSON"] = '{"project_id":"test-project","private_key":"test-only"}'
        get_firebase_app()
        self.cert.assert_called_once_with({"project_id": "test-project", "private_key": "test-only"})
        self.initialize.assert_called_once_with(self.cert.return_value, {"projectId": "test-project"})

    def test_invalid_cloud_credentials_fail_without_leaking_or_falling_back(self):
        for raw in ('secret-value', '[]', '{"project_id":"other-project","private_key":"secret-value"}'):
            self.app.config["FIREBASE_SERVICE_ACCOUNT_JSON"] = raw
            with self.assertRaises(RuntimeError) as caught:
                get_firebase_app()
            self.assertNotIn("secret-value", str(caught.exception))
        self.cert.assert_not_called()
        self.initialize.assert_not_called()

    def test_local_file_credentials_remain_supported(self):
        self.app.config["FIREBASE_SERVICE_ACCOUNT_JSON"] = ""
        with patch("app.firebase.Path.is_file", return_value=True):
            get_firebase_app()
        self.assertTrue(self.cert.call_args.args[0].endswith("secrets/local.json"))

    def test_vercel_entry_point_health_and_auth(self):
        from index import app
        client = app.test_client()
        self.assertEqual(client.get("/health").status_code, 200)
        self.assertEqual(client.get("/api/v1/me").status_code, 401)

    def test_mobile_config_returns_only_the_public_map_key(self):
        self.app.config["GEOAPIFY_API_KEY"] = "test-map-key"
        response = self.app.test_client().get("/api/v1/mobile-config")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"geoapify_api_key": "test-map-key"})
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_mobile_config_requires_server_configuration(self):
        self.app.config["GEOAPIFY_API_KEY"] = ""
        response = self.app.test_client().get("/api/v1/mobile-config")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.get_json()["error"]["code"], "CONFIGURATION_ERROR")
