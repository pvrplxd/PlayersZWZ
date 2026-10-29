"""Firestore access for the current authenticated account."""

from datetime import datetime, timezone

from google.cloud import firestore

from ..firebase import get_firestore_client
from .service import AccountSuspended


def load_account(uid):
    client = get_firestore_client()
    user, profile = client.get_all([
        client.collection("users").document(uid),
        client.collection("profiles").document(uid),
    ])
    # get_all does not guarantee response order.
    records = {snapshot.reference.parent.id: snapshot.to_dict() for snapshot in (user, profile)}
    return records["users"], records["profiles"]


def ensure_account(uid, initial_user, initial_profile):
    client = get_firestore_client()
    user_ref = client.collection("users").document(uid)
    profile_ref = client.collection("profiles").document(uid)

    @firestore.transactional
    def create_missing(transaction):
        # Read both records before writing so simultaneous first sessions retry safely.
        user = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        if user is not None and user.get("status") == "suspended":
            raise AccountSuspended()
        if user is None:
            user = {**initial_user, "created_at": datetime.now(timezone.utc)}
            transaction.create(user_ref, user)
        if profile is None:
            profile = initial_profile
            transaction.create(profile_ref, profile)
        return user, profile

    return create_missing(client.transaction())
