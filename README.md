<div align="center">

<img src="https://img.shields.io/badge/⚡-PLAYERSZWZ-0A0A0F?style=for-the-badge&labelColor=DFFF27&color=0A0A0F" height="50"/>

### AI-Powered Sports Matchmaking & Arena Booking App

*Find players. Fill teams. Book arenas. No more WhatsApp chaos.*
<br/>

<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white&labelColor=02569B" height="28"/>
<img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black&labelColor=FFCA28" height="28"/>
<img src="https://img.shields.io/badge/Flask-000000?style=for-the-badge&logo=flask&logoColor=white&labelColor=000000" height="28"/>
<img src="https://img.shields.io/badge/scikit--learn-F7931E?style=for-the-badge&logo=scikitlearn&logoColor=white&labelColor=F7931E" height="28"/>
<img src="https://img.shields.io/badge/Google%20Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white&labelColor=4285F4" height="28"/>

<br/><br/>

<img src="https://img.shields.io/badge/status-in%20development-DFFF27?style=flat-square&labelColor=1a1a1a"/>
<img src="https://img.shields.io/badge/UCP-Final%20Year%20Project-1a1a1a?style=flat-square&labelColor=0A0A0F"/>
<img src="https://img.shields.io/badge/Group-S26CS024-1a1a1a?style=flat-square&labelColor=6c2bd9&color=ffffff"/>

</div>

<br/>

---

## 📌 The Problem

Organizing a casual cricket/futsal/badminton match today means **spamming WhatsApp groups**, **calling around for players**, and **guessing if a ground is even free**. Half the games fall apart because someone bails last-minute and there's no way to tell who's reliable.

**PLAYERSZWZ** fixes this with one mobile workflow: discover nearby players → create or join a game → book an arena → get notified → rate after the match.

---

## ✨ Core Features

<table>
<tr>
<td width="50%" valign="top">

### 🔐 Accounts & Profiles
Secure signup/login, sport preferences, availability mode, and adjustable search radius — all synced to a single trust-aware profile.

</td>
<td width="50%" valign="top">

### 📍 Nearby Discovery
Geohash-powered radius search surfaces compatible players and open games around you, with map and list views.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🎮 Game Management
Create games, send or approve join requests, and track live participant counts and capacity in real time.

</td>
<td width="50%" valign="top">

### 🏟️ Arena Booking
Browse nearby arenas, check open slots, and submit booking requests with live Pending → Approved status.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🧠 AI Recommendations
Ranks games and players using preference, proximity, history, and reliability — rule-based first, ML-enhanced later.

</td>
<td width="50%" valign="top">

### ⭐ Trust & Reliability
Post-game ratings, no-show tracking, and a dispute-aware reliability score that's fair by design.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🔔 Notifications
Push + in-app alerts for join requests, approvals, booking updates, and game reminders.

</td>
<td width="50%" valign="top">

### 🛠️ Admin Moderation
Report review workflow with warnings, suspensions, and a fully logged audit trail.

</td>
</tr>
</table>

---

## 🏗️ Architecture

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "background": "transparent",
    "primaryColor": "#1a1a2e",
    "primaryTextColor": "#f5f5f7",
    "primaryBorderColor": "#DFFF27",
    "lineColor": "#9d8cff",
    "secondaryColor": "#2d2d44",
    "tertiaryColor": "#1a1a2e",
    "fontFamily": "Inter, sans-serif",
    "fontSize": "15px"
  },
  "flowchart": { "curve": "basis", "rounded": true, "htmlLabels": true }
}}%%
flowchart TD
    A(["📱 Flutter Mobile App"]) -->|HTTPS / REST| B(["⚙️ Flask REST API"])
    B --> C(["🔑 Auth & Session"])
    B --> D(["🧩 Backend Services"])
    D --> D1(["🔍 Discovery"])
    D --> D2(["🎮 Game Management"])
    D --> D3(["🏟️ Arena & Booking"])
    D --> D4(["🧠 AI Recommendation Engine"])
    D --> D5(["⭐ Rating & Moderation"])
    D --> D6(["🔔 Notifications"])
    D --> E(["☁️ Cloud Firestore"])
    A --> F(["🔥 Firebase Auth"])
    D --> G(["🗺️ Google Maps API"])
    D6 --> H(["📲 Firebase Cloud Messaging"])

    classDef default fill:#1a1a2e,stroke:#DFFF27,stroke-width:1.5px,color:#f5f5f7,rx:12,ry:12
    classDef ai fill:#2d1b4e,stroke:#c77dff,stroke-width:2px,color:#f5f5f7,rx:12,ry:12
    class D4 ai
```

**Pattern:** Layered client-server — UI, API, domain services, and data are fully decoupled, so the rule-based recommendation engine can be swapped for a smarter ML model later without touching the app.

---

## 🧰 Tech Stack

<div align="center">

| Layer | Stack |
|:---|:---|
| **Frontend** | <img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white"/> |
| **Backend** | <img src="https://img.shields.io/badge/Flask-000000?style=flat-square&logo=flask&logoColor=white"/> |
| **Database** | <img src="https://img.shields.io/badge/Cloud%20Firestore-FFCA28?style=flat-square&logo=firebase&logoColor=black"/> |
| **Auth** | <img src="https://img.shields.io/badge/Firebase%20Auth-FFCA28?style=flat-square&logo=firebase&logoColor=black"/> |
| **Maps** | <img src="https://img.shields.io/badge/Google%20Maps%20%2F%20Places-4285F4?style=flat-square&logo=googlemaps&logoColor=white"/> |
| **Notifications** | <img src="https://img.shields.io/badge/Firebase%20Cloud%20Messaging-FFCA28?style=flat-square&logo=firebase&logoColor=black"/> |
| **AI Engine** | <img src="https://img.shields.io/badge/scikit--learn-F7931E?style=flat-square&logo=scikitlearn&logoColor=white"/> |

</div>

---

## 📊 Project Roadmap

```mermaid
%%{init: {
  "theme": "base",
  "themeVariables": {
    "background": "transparent",
    "primaryColor": "#2d1b4e",
    "primaryTextColor": "#f5f5f7",
    "primaryBorderColor": "#DFFF27",
    "secondaryColor": "#1a1a2e",
    "tertiaryColor": "transparent",
    "fontFamily": "Inter, sans-serif",
    "fontSize": "14px",
    "taskTextColor": "#f5f5f7",
    "taskTextOutsideColor": "#f5f5f7",
    "activeTaskBkgColor": "#DFFF27",
    "activeTaskBorderColor": "#0A0A0F",
    "doneTaskBkgColor": "#5e548e",
    "doneTaskBorderColor": "#c77dff",
    "critBkgColor": "#ff6b9d",
    "sectionBkgColor": "rgba(157,140,255,0.08)",
    "sectionBkgColor2": "rgba(223,255,39,0.06)",
    "gridColor": "rgba(255,255,255,0.12)"
  }
}}%%
gantt
    title PLAYERSZWZ Development Phases
    dateFormat  YYYY-MM-DD
    axisFormat  %b

    section Phase 1 · Requirements
    SRS, Backlog, Epics, Risk Analysis     :done, p1, 2026-04-10, 25d

    section Phase 2 · Design
    Architecture, ERD, API, UI/UX          :done, p2, 2026-05-08, 26d

    section Phase 3 · AI & Matchmaking
    Rule-based + ML ranking system         :active, p3, 2026-06-10, 20d

    section Phase 4 · Testing & Submission
    QA, polish, docs, final viva           :p4, after p3, 15d
```

---

## 👥 Team — Group S26CS024

<table>
<tr>
<td align="center" width="33%">

**🧑‍💻 Waleed Abid**
<br/>
<img src="https://img.shields.io/badge/Mobile%20Architecture-0A0A0F?style=flat-square&color=0A0A0F&labelColor=DFFF27"/>
<br/><br/>
Backend integration · Project coordination

</td>
<td align="center" width="33%">

**🎯 Afaq Ul Islam**
<br/>
<img src="https://img.shields.io/badge/Scrum%20Master-ffffff?style=flat-square&color=6c2bd9"/>
<br/><br/>
Frontend · Maps & UI flows

</td>
<td align="center" width="33%">

**🧠 Hassan Ahmed**
<br/>
<img src="https://img.shields.io/badge/AI%20%26%20QA-0A0A0F?style=flat-square&color=DFFF27"/>
<br/><br/>
Recommendation module · Testing & docs

</td>
</tr>
</table>

<div align="center">

**Product Owner:** Mr. Asif Farooq &nbsp;·&nbsp; **Institution:** University of Central Punjab — Faculty of IT & CS

</div>

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
