# Authentication Documentation

This document explains the authentication flow in our Flutter app and what's going on behind the scenes when a user creates an account or signs in.

The HouseHeld app uses Firebase Authentication to manage user sign-in state and Cloud Firestore to store app-specific user profile data.

The authentication flow currently supports:
* Creating a new account with a username, display name, email, and password
* Signing in with email and password
* Persistent signed-in sessions between app launches
* Signing out
* Handling authentication errors, such as invalid credentials
* Creating a new user profile in Cloud Firestore database after registration
* Temporarily bypassing the login screen for debugging/testing purposes

For a more in-depth breakdown of how Firebase Authentication works, see the official Firebase documentation here:
https://firebase.google.com/docs/auth/flutter/start?_gl=1*tlgk2*_up*MQ..&gclid=EAIaIQobChMIsbOBguWjlwMVWYnCCB05Gwz8EAAYASAAEgI9UPD_BwE&gbraid=0AAAAADpUDOhcNu0rJil-tSmt9x0jU83PR

## Startup

Firebase is initialized before the Flutter app starts, allowing it's services to be available throughout the entire app.
The application initializes Firebase in the `main()` function of the `main.dart` file.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
    );

  runApp(const HouseHeld());
}
```
## AuthGate

Once Firebase services are initialized, the Flutter app will startup. By default, the app instantiates the `AuthGate()` class,
which is contained in the `auth_gate.dart` file. This class determines whether the user launching the app should be greeted with the home screen 
if they are signed in, or the login screen if they are not.

`auth_gate.dart` has a listening stream that is listening to this function:

```dart
FirebaseAuth.instance.authStateChanges()
``` 

If Firebase returns a User object, the app considers the user to be authenticated, but if Firebase returns `null`, then the app
considers the user to not be authenticated and displays the login screen.

This means that the app does not manually navigate to the home screen after a successful login. Instead, Firebase changes the authentication
state and the `AuthGate()` class detects those changes, prompting Flutter to rebuild the appropriate UI.

So, if the user is not already signed in, Flutter takes them to `login_screen.dart`, which contains the logic for the login screen UI,
user registration, and user sign in.

## Registration

When a new user registers, the application currently collects the following information:
* Username
* Display Name
* Email
* Password

When registering, two operations occur: the creation of a Firebase Auth account and the creation of a Cloud Firestore user profile.

Firstly, a new user will be registered in Firebase Auth. This is done through the following function:

```dart
FirebaseAuth.instance.createUserWithEmailAndPassword(...)
```

When this function is called, Firebase Auth receives the entered email and password, validates the account information, creates an 
authentication account with the user's credentials, generates a unique ID for that user, and automatically signs that user in. Passwords
are never stored in the Cloud Firestore database, nor are they visible in the Firebase Console. They are handled by Firebase Auth behind the scenes.

The creation of a Firebase Auth account, however, only creates an authentication identity. HouseHeld also requires application-specific information,
such as a user's username, display name, and email. So, when a user registers, the app also creates a Cloud Firestore user profile for that user.
This is the information that is stored directly in the Cloud Firestore database and used for general app functionality.

User profiles are created through the following function:

```dart
FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'username': ...,
    'email': ...,
    'displayName': ...,
  });
```

This function creates a new entry in the Cloud Firestore database for the newly registered user using their submitted credentials. 
For more information about the database and it's document hierarchy, see [DATABASE.md](DATABASE.md).

The `login_screen.dart` file also contains exception handling code that catches and handles exceptions thrown by Firebase Auth.
In most cases, these exceptions consist of errors that may occur when attempting to register, such as when attempting to register 
with an email that is already registered or entering an email with an invalid format.

## Relationship Between Firebase Auth & Cloud Firestore

The current database design stores user profiles at `users/{uid}`, where the document ID must be the same UID assigned by Firebase Auth.
The Firebase Auth account and the Cloud Firestore user profile represent the same person, but they serve different purposes.

Firebase Auth stores a user's UID, email, password credentials (behind the scenes), and authentication state.
Cloud Firestore stored a user's username, display name, and application-specific user data.

The Firestore rules dictated in `firestore.rules` allow the authenticated user to create their own user profile. The important relationship here
is that `Authenticated Firebase UID == Firestore users/{document ID}`. This is what prevents one authenticated user from creating or 
modifying another user's profile.

So while Firebase Auth determines handles the users that are currently signed in, Cloud Firestore handles the data that belongs to those users.

## Signing In

Existing users can sign in to the app using only the email and password fields. Currently, signing in with username is not supported.

When signing in, the following function is called:

```dart
FirebaseAuth.instance.signInWithEmailAndPassword(...)
```

This function prompts Flutter to send the entered credentials to Firebase Auth, then Firebase validates the credentials, authentication
succeeds, Firebase returns a User object, the `authStateChanges()` listener emits that a user was detected, and `AuthGate()` displays 
the home screen.

The application itself does not need to manually load or compare user credentials, as Firebase Auth performs credential verification automatically.

Like registration, `login_screen.dart` has additional exception handling for signing in which throws FirebaseAuth errors for things such as
a wrong password, invalid email/password combination, a disabled account, or other authentication failture related errors.

Additionally, Firebase Auth automatically persists a user's authenticated sessions on supported mobile devices, meaning that after a successful
sign-in, a user can expect to exit the app, still be signed in when returning, and be shown the home screen immediately upon reopening the app.

Currently, however, Cloud Firestore user profiles do NOT get loaded back in when closing and reopening the app. This means that a signed-in user
who closes and reopens the app right now will not have their Firebase Auth and Cloud Firestore data matched, meaning they will be blocked
from accessing their own app data until they log out and log back in, as per the Firestore Rules.

Should a user decide to sign-out, Firebase clears their current authentication session. Internally, the User object becomes `null`,
then `authStateChanges()` emits `null`, then `AuthGate()` rebuilds itself and the login screen appears once again.

## Bypassing

For development purposes, the current implementation includes temporary authentication bypassing functionality. It's main purpose is to
allow developers working on UI/navigation to enter the main application without having to repeatedly sign-in in case persistence fails.

**Important:** For developers, when bypassing the login screen, you are acting as an unauthorized user, meaning that you will be unable 
to test features that require user IDs, such as adding/manipulating entries in core features. Developer accounts for the app will be 
created later to test the household membership system and core feature functionality.

## Completed Testing

The current implementation has been successfully tested for:
* New account registration
* Firebase Auth account creation
* Firestore user-profile creation
* Matching Firebase Auth UID and Firestore document ID
* Successful email/password sign-in
* Incorrect credential handling
* Logging out
* Re-logging in
* Authentication persistence after closing and reopening the app

All tests here confirm that the simple authentication system is functioning correctly.

## Future Authentication Work

The current implementation is intentionally minimal and was made merely a proof-of-concept for authentication services.
Potential future improvements, changes, and additions include:
* Separating Sign-In and Registration Screens
* Signing in with username
* Better/simpler error messages
* Password confirmation
* Show password
* Password reset and forgot password flow
* Email verification
* Account settings and changing account details
* Deleting account
* Loading Firestore user profile after login