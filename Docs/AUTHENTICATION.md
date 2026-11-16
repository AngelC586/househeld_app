# Authentication Documentation

This document explains the authentication flow in our Flutter app and what's going on behind the scenes when a user creates an account or signs in.

The HouseHeld app uses Firebase Authentication to manage user sign-in state and Cloud Firestore to store app-specific user profile data.

The authentication flow currently supports:
* Creating a new account with a username, display name, email, and password
* Email verification
* Signing in with email and password
* "Forgot Password" flow and password reset
* Persistent signed-in sessions between app launches
* Signing out
* Handling authentication errors, such as invalid credentials
* Creating a new user profile in Cloud Firestore database after registration
* Changing account details from an in-app settings screen
* Deleting an account from an in-app settings screen

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

So, if the user is not already signed in, Flutter takes them to `login_screen.dart`, which contains the logic for the login screen UI and user sign in.
The login screen also has a button to register for an account, which takes users to `registration_screen.dart`, which itself contains the logic for
the registration screen UI and user registration.

When a user successfully signs in through the login screen, the Auth Gate will detect those changes and then check whether or not the user currently belongs
to a "household". If not, the user will be routed to the `household_onboarding_screen`, where they can either create or join a household. If they do
belong to a household already, they will be taken to the home screen for that household.

When a user successfully registers a new account through the registration screen, the Auth Gate will detect those changes and immediately route the user
to the `email_verification_screen`. After successful verification, the user will always be taken to the `household_onboarding_screen`, since all new users
should not, by default, belong to a household already. 

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

The `registration_screen.dart` file also contains exception handling code that catches and handles exceptions thrown by Firebase Auth.
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

## Email Verification

When a new user successfully registers their account, they are required to verify their email. To ensure this, new users are taken directly
to the `email_verification_screen` upon registering a new account. The `email_verification_screen.dart` file contains the UI to help the user 
complete email verification and the logic to check whether or not a user has completed it yet. Verification emails are sent with the following
piece of code:

```dart
await refreshedUser.sendEmailVerification();
```

Where `sendEmailVerification()` is a built-in method provided by Firebase Auth. The Email verification screen UI contains a button for users
to resend the verification email (limited to a 60 second cooldown) and a button for users to confirm that they have verified their email.
Pressing this button checks whether or not the user's email has, in fact, been verified. If not, it will prompt the user to try again.
If it has been verified successfully, the user will be taken to the `household_onboarding_screen` so they can begin to use the app.

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

Like registration, `login_screen.dart` has exception handling for signing in which throws FirebaseAuth errors for things such as
a wrong password, invalid email/password combination, a disabled account, or other authentication failture related errors.

Additionally, Firebase Auth automatically persists a user's authenticated sessions on supported mobile devices, meaning that after a successful
sign-in, a user can expect to exit the app, still be signed in when returning, and be shown the home screen immediately upon reopening the app.

Should a user decide to sign-out, Firebase clears their current authentication session. Internally, the User object becomes `null`,
then `authStateChanges()` emits `null`, then `AuthGate()` rebuilds itself and the login screen appears once again.

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
* Password reset and forgot password flow
* Email verification
* Account settings and changing account details
* Deleting account

All tests here confirm that the simple authentication system is functioning correctly.

## Future Authentication Work

The current implementation is complete for the scope of this project.

A potential future additions could include the ability to sign in with username. This work would, most improtantly, require all usernames to be
unique, which is currently not supported. 