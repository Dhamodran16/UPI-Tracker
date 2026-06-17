# UPI Tracker — Flutter App

Auto-tracks UPI payments from notifications and syncs to the backend API.

## Quick Start

### 1. Prerequisites
- Flutter SDK >= 3.0 installed and on PATH
- Android Studio / emulator OR a physical Android device (API 26+)
- Backend server running (see `../server_app/README.md`)

### 2. Run on emulator (default — talks to `http://10.0.2.2:3000`)
```bash
flutter pub get
flutter run
```

### 3. Run pointing to a real / cloud server
```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

### 4. Build a release APK
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-api.example.com
```

## First-run steps on device
1. Open the app → Register or Login.
2. Go to **Add** tab → tap **Enable** on the notification banner.
3. Grant *Notification listener access* to UPI Tracker.
4. Make a UPI payment — it will be tracked automatically.

## Architecture
```
lib/
├── main.dart                # App entry, routing, shell
├── models/expense.dart      # Expense, MonthlySummary, SavingsGoal
├── providers/               # ExpenseProvider (state + persistence)
├── screens/                 # HomeScreen, TransactionsScreen, …
├── services/
│   ├── api_service.dart     # Dio HTTP client (JWT auth, configurable base URL)
│   └── notification_service.dart  # MethodChannel bridge to Kotlin
├── utils/app_theme.dart     # Colors, typography, constants
└── widgets/common_widgets.dart
android/
└── app/src/main/kotlin/…/
    ├── MainActivity.kt              # MethodChannel setup
    └── UpiNotificationService.kt    # Notification listener + auto-categorizer
```

## Environment Variables
| Variable | Default | Description |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:3000` | Backend API base URL |

Pass via `--dart-define=API_BASE_URL=<value>` at build/run time.
