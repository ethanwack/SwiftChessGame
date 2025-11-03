# SwiftChessGame

A full-featured chess game built with SwiftUI that supports local play against AI, local multiplayer, and online multiplayer using Firebase.

## Features

- Play against AI with adjustable difficulty
- Local 2-player mode
- Online multiplayer with real-time game synchronization
- User authentication (email/password or guest mode)
- Game lobby system for finding online opponents
- Time controls for each player
- Full chess rule implementation including:
  - All piece movements
  - Check and checkmate detection
  - Castling
  - En passant
  - Pawn promotion

## Prerequisites

- Xcode 14.0 or later
- iOS 15.0 or later
- macOS 12.0 or later (for macOS version)
- A Firebase account

## Installation

1. Clone the repository:
```bash
git clone https://github.com/ethanwack/SwiftChessGame.git
cd SwiftChessGame
```

2. Set up Firebase:
   - Go to the [Firebase Console](https://console.firebase.google.com)
   - Create a new project
   - Add an iOS app to your Firebase project
     - Use "Chess" as the Bundle ID
   - Download the `GoogleService-Info.plist` file
   - Replace the existing `GoogleService-Info.plist` in the project with your downloaded file

3. Install dependencies:
   - This project uses Swift Package Manager for dependencies
   - The required packages will be automatically installed when you open the project in Xcode

4. Open the project:
```bash
open ChessGame.xcodeproj
```

5. Build and run the project in Xcode

## Firebase Configuration

The app requires the following Firebase services:
- Authentication (for user management)
- Cloud Firestore (for game state and multiplayer)

To set up Firebase:

1. Enable Authentication in Firebase Console:
   - Go to Authentication > Sign-in method
   - Enable Email/Password
   - Enable Anonymous authentication

2. Set up Cloud Firestore:
   - Go to Firestore Database
   - Create a database in test mode
   - Set up the following security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /games/{gameId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        resource.data.whitePlayerID == request.auth.uid ||
        resource.data.blackPlayerID == request.auth.uid
      );
    }
  }
}
```

## Usage

1. Launch the app
2. Sign in with your email or play as guest
3. Choose your game mode:
   - vs Computer: Play against AI
   - Local 2-Player: Play on the same device
   - Online Multiplayer: Play against other players online

For online multiplayer:
1. Create a new game or join an existing one from the lobby
2. White player moves first
3. The game automatically synchronizes moves between players
4. Time control is optional and can be set when creating a game

## License

This project is licensed under the MIT License - see the LICENSE file for details