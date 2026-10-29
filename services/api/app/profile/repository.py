from google.cloud import firestore
from ..firebase import get_firestore_client

def save_profile(uid, details):
    db = get_firestore_client()
    user_ref = db.collection("users").document(uid)
    profile_ref = db.collection("profiles").document(uid)
    claim_ref = db.collection("usernames").document(details["username"])

    @firestore.transactional
    def save(transaction):
        user = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        claim = claim_ref.get(transaction=transaction).to_dict()
        if not user or profile is None:
            return None, "PROFILE_REQUIRED"
        if user.get("status") == "suspended":
            return None, "ACCOUNT_SUSPENDED"
        if claim and claim.get("user_id") != uid:
            return None, "USERNAME_TAKEN"
        old_name = profile.get("username")
        old_ref = None
        old_claim = None
        if old_name and old_name != details["username"]:
            old_ref = db.collection("usernames").document(old_name)
            old_claim = old_ref.get(transaction=transaction).to_dict()
        transaction.set(claim_ref, {"user_id": uid})
        transaction.update(profile_ref, details)
        if old_claim and old_claim.get("user_id") == uid:
            transaction.delete(old_ref)
        return {**profile, **details}, None
    return save(db.transaction())



def save_location(uid, details):
    db = get_firestore_client()
    user_ref = db.collection("users").document(uid)
    profile_ref = db.collection("profiles").document(uid)

    @firestore.transactional
    def save(transaction):
        user = user_ref.get(transaction=transaction).to_dict()
        profile = profile_ref.get(transaction=transaction).to_dict()
        if not user or not profile or profile.get("setup_complete") is not True:
            return None, "PROFILE_REQUIRED"
        if user.get("status") == "suspended":
            return None, "ACCOUNT_SUSPENDED"
        updates = {
            "location": firestore.GeoPoint(details["latitude"], details["longitude"]),
            "location_source": details["source"],
            "location_label": details["label"],
            "manual_area": details["label"] if details["source"] == "manual" else "",
        }
        transaction.update(profile_ref, updates)
        return {**profile, **updates}, None
    return save(db.transaction())
