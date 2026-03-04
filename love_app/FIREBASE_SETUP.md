# Setup Instructions for Love Messages App with Firebase Sync

## ✨ New Features
Your messaging app now supports **real-time synchronization** between two phones! Messages and photos are instantly synced across both devices using Firebase.

## 🔧 Setup Steps

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a new project"
3. Name it something like `love-messages-app`
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Add Android App
1. In Firebase Console, click the Android icon
2. Enter package name: `com.example.love_app` (or your preferred name)
3. Download the `google-services.json` file
4. Place it in: `android/app/google-services.json`

### 3. Add iOS App (if using iPhone)
1. In Firebase Console, click the iOS icon
2. Enter bundle ID: `com.example.loveapp`
3. Download `GoogleService-Info.plist`
4. In Xcode, right-click and select "Add Files"
5. Select the downloaded plist file
6. Make sure it's added to the Runner target

### 4. Update Firebase Configuration
1. In Firebase Console, go to **Project Settings**
2. Copy your project details (Project ID, API Key, etc.)
3. Update the file: `lib/firebase_options.dart`
4. Replace the placeholder values with your actual Firebase credentials:
   ```dart
   static const FirebaseOptions android = FirebaseOptions(
     apiKey: 'YOUR_ACTUAL_API_KEY',
     appId: 'YOUR_ACTUAL_APP_ID',
     messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
     projectId: 'your-project-id',
     databaseURL: 'https://your-project-id.firebaseio.com',
     storageBucket: 'your-project-id.appspot.com',
   );
   ```

### 5. Setup Firestore Database
1. In Firebase Console, go to **Firestore Database**
2. Click **Create Database**
3. Choose **Start in test mode** (for development)
4. Select a region close to you

### 6. Setup Storage (for photo sharing)
1. In Firebase Console, go to **Storage**
2. Click **Get Started**
3. Start in test mode
4. Select a region

### 7. Run the App
```bash
cd /home/ajamtroye/delivery/perso/kowshikaandswann/love_app
flutter pub get
flutter run
```

## 📱 How to Use

1. **Install on both phones** - Run `flutter run` on both devices
2. **Enter your names** - Use different names on each phone (e.g., him/her)
3. **Send messages** - Type and send instantly
4. **Share photos** - Click the 📷 icon to send pictures
5. **Instant sync** - Messages appear in real-time on both phones!

## 🔒 Security Rules (Optional but Recommended)

In Firestore, update your security rules to protect conversations:

Go to **Firestore Database → Rules** and set:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /conversations/{conversationId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

For production, you can make it more restrictive, but for a private app between you two, this works well.

## 📸 Photo Storage Rules

Go to **Storage → Rules** and set:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /conversations/{conversationId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 🐛 Troubleshooting

**Error: "Unknown host exception"**
- Check your internet connection
- Verify Firebase project is created
- Check API key in firebase_options.dart

**App crashes on startup**
- Ensure google-services.json is in android/app/
- Run `flutter clean` then `flutter pub get`
- Restart the app

**Messages not syncing**
- Check Firebase Firestore permissions (test mode should work)
- Verify both phones have internet
- Check that conversation ID is the same (sorted names)

## 🎉 Your First Sync!

1. Install on both phones with different names
2. One person sends a message
3. It should appear instantly on the other phone!

Enjoy your private messaging app! 💕
