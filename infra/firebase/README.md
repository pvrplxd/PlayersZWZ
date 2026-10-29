# Firebase infrastructure

Firestore rules must deny direct mobile-client access to product data. The Flask API is the only product-data access path and enforces authorization and business rules. Add rules and indexes after the Firebase project and collection schema are confirmed; never deploy rules from this scaffold without reviewing them against the live project.

