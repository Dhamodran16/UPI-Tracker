# Checklist

- [x] Backend Server (SendGrid integration & routes cleanup)
  - [x] Update `package.json` (remove nodemailer, twilio; add @sendgrid/mail)
  - [x] Update `server_app/.env.example`
  - [x] Implement SendGrid OTP delivery in `authController.js`
  - [x] Implement `verifyFirebaseToken` endpoint in `authController.js` and `routes/auth.js`
- [x] Flutter Frontend (Firebase Phone Auth setup & screens)
  - [x] Update `pubspec.yaml` with `firebase_core` and `firebase_auth`
  - [x] Update `main.dart` with Firebase core initialization & safety flag
  - [x] Update `api_service.dart` with `verifyFirebaseToken` call
  - [x] Update `login_screen.dart` with Firebase Phone Auth and mock fallback
- [x] Firebase Options Setup (Step 5 & 6)
  - [x] Create `firebase_options.dart` using parameters from google-services.json
  - [x] Configure Firebase initialization with platform options in `main.dart`
- [x] Verification
  - [x] Run backend tests (`npm test`)
  - [x] Run frontend tests (`flutter test`)
- [x] Form Styling Alignment
  - [x] Ensure form labels are 14 (floating/labelStyle in app_theme.dart)
  - [x] Ensure values are 16 on forms (explicit text styles on TextFields/TextFormFields)

