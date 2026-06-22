<div align="center">

# 🏆 PLAYERSZWZ

### AI-Powered Sports Matchmaking & Arena Booking App

*Find players. Fill teams. Book arenas. No more WhatsApp chaos.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Flask](https://img.shields.io/badge/Flask-REST%20API-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![scikit-learn](https://img.shields.io/badge/scikit--learn-AI%20Engine-F7931E?style=for-the-badge&logo=scikit-learn&logoColor=white)](https://scikit-learn.org)

![Status](https://img.shields.io/badge/Status-In%20Development-DFFF27?style=flat-square)
![FYP](https://img.shields.io/badge/UCP-Final%20Year%20Project-0A0A0F?style=flat-square)
![Group](https://img.shields.io/badge/Group%20ID-S26CS024-blueviolet?style=flat-square)

</div>

---

## 📌 The Problem

Organizing a casual cricket/futsal/badminton match today means **spamming WhatsApp groups**, **calling around for players**, and **guessing if a ground is even free**. Half the games fall apart because someone bails last-minute and there's no way to tell who's reliable.

**PLAYERSZWZ** fixes this with one mobile workflow: discover nearby players → create or join a game → book an arena → get notified → rate after the match.

---

## ✨ Core Features

| Module | What it does |
|---|---|
| 🔐 **Accounts & Profiles** | Secure signup/login, sport preferences, availability mode, search radius |
| 📍 **Nearby Discovery** | Geohash-based radius search for players & open games near you |
| 🎮 **Game Management** | Create games, send/approve join requests, live participant tracking |
| 🏟️ **Arena Booking** | Browse arenas, check slots, submit booking requests with live status |
| 🧠 **AI Recommendations** | Ranks games/players by preference, distance, history & reliability |
| ⭐ **Trust & Reliability** | Post-game ratings, no-show tracking, dispute-aware scoring |
| 🔔 **Notifications** | Push + in-app alerts for requests, approvals, reminders, bookings |
| 🛠️ **Admin Moderation** | Report review, warnings/suspensions, full audit log |

---

## 🏗️ Architecture

```mermaid
flowchart TD
    A["📱 Flutter Mobile App"] -->|HTTPS / REST| B["⚙️ Flask REST API"]
    B --> C["🔑 Auth & Session Middleware"]
    B --> D["🧩 Backend Services"]
    D --> D1["Discovery"]
    D --> D2["Game Management"]
    D --> D3["Arena & Booking"]
    D --> D4["🧠 AI Recommendation Engine"]
    D --> D5["Rating & Moderation"]
    D --> D6["Notifications"]
    D --> E["☁️ Cloud Firestore"]
    A --> F["🔥 Firebase Auth"]
    D --> G["🗺️ Google Maps API"]
    D6 --> H["📲 Firebase Cloud Messaging"]
```

**Pattern:** Layered client-server — UI, API, domain services, and data are fully decoupled, so the rule-based recommendation engine can be swapped for a smarter ML model later without touching the app.

---

## 🧰 Tech Stack

<div align="center">

| Layer | Technology |
|:---:|:---:|
| **Frontend** | Flutter (Dart) |
| **Backend** | Flask (Python REST API) |
| **Database** | Cloud Firestore (NoSQL) |
| **Auth** | Firebase Authentication |
| **Maps** | Google Maps / Places API |
| **Notifications** | Firebase Cloud Messaging |
| **AI Engine** | scikit-learn (rule-based → ML ranking) |

</div>

---

## 📊 Project Roadmap

```mermaid
gantt
    title PLAYERSZWZ Development Phases
    dateFormat  YYYY-MM-DD
    axisFormat  %b

    section Phase 1: Requirements
    SRS, Backlog, Epics, Risk Analysis     :done, p1, 2026-04-10, 25d

    section Phase 2: Design
    Architecture, ERD, API, UI/UX          :done, p2, 2026-05-08, 26d

    section Phase 3: AI & Matchmaking
    Rule-based + ML ranking system         :active, p3, 2026-06-10, 20d

    section Phase 4: Testing & Submission
    QA, polish, docs, final viva           :p4, after p3, 15d
```

---

## 👥 Team — Group S26CS024

| Member | Role |
|---|---|
| **Waleed Abid** | Mobile architecture, backend integration, project coordination |
| **Afaq Ul Islam** | Scrum Master, frontend implementation, maps & UI flows |
| **Hassan Ahmed** | AI recommendation module, testing, documentation & QA |

**Product Owner:** Mr. Asif Farooq · **Institution:** University of Central Punjab — Faculty of IT & CS

---

## 📂 Repository Structure

```
playerszwz/
├── mobile/              # Flutter application
├── backend/             # Flask REST API + services
├── ai-engine/           # Recommendation logic (rule-based + ML)
├── docs/                # SRS, SDS, diagrams, IV&V reports
└── README.md
```

---

## 🚀 Getting Started

```bash
# Clone the repo
git clone https://github.com/<org>/playerszwz.git

# Backend setup
cd backend && pip install -r requirements.txt && flask run

# Mobile app setup
cd mobile && flutter pub get && flutter run
```

> Configure your own `.env` / `firebase_options.dart` with Firebase & Google Maps API keys — never commit credentials.

---

<div align="center">

**Built as a Final Year Project at the University of Central Punjab** 🎓

⭐ Star this repo if you'd rather book a ground than send 40 WhatsApp messages.

</div>
