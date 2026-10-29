import json
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore
from flask import current_app


def get_firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    project_id = current_app.config.get("FIREBASE_PROJECT_ID")
    credential_setting = current_app.config.get("GOOGLE_APPLICATION_CREDENTIALS")

    if not project_id:
        raise RuntimeError("FIREBASE_PROJECT_ID is missing from backend configuration.")

    credential_json = current_app.config.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if credential_json:
        try:
            account = json.loads(credential_json)
            if not isinstance(account, dict) or account.get("project_id") != project_id:
                raise ValueError("Project mismatch")
            credential = credentials.Certificate(account)
        except (ValueError, TypeError, KeyError):
            # Never include the credential contents in errors or logs.
            raise RuntimeError("Invalid Firebase service-account configuration.") from None
    else:
        if not credential_setting:
            raise RuntimeError("Firebase service-account configuration is missing.")
        credential_path = Path(credential_setting)
        if not credential_path.is_absolute():
            credential_path = Path(current_app.root_path).parent / credential_path
        if not credential_path.is_file():
            raise RuntimeError("Firebase service-account file not found.")
        credential = credentials.Certificate(str(credential_path))
    return firebase_admin.initialize_app(
        credential,
        {"projectId": project_id},
    )


def verify_firebase_id_token(id_token: str) -> dict:
    return auth.verify_id_token(id_token, app=get_firebase_app())


def get_firestore_client():
    return firestore.client(app=get_firebase_app())