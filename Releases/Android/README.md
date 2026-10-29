# Android test releases

This folder is the local staging area for installable Android test builds.

Use a versioned filename:

```text
playerszwz-v0.1.0-test.1.apk
```

APK files are intentionally ignored by Git. Publish each tested APK as a GitHub Release asset with the matching tag, release notes, and a SHA-256 checksum. This keeps the source repository fast while making each test build easy to download and identify.

Only Android APK artifacts belong here. iOS archives and signing materials must never be stored in this repository.
