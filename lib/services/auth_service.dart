import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    print("AuthService: Attempting Email/Password Sign-Up for $email...");
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print("AuthService: Email/Password Sign-Up successful: ${userCredential.user?.uid}");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("AuthService: Firebase Auth Exception during Email/Password Sign-Up: ${e.message}, Code: ${e.code}");
      throw e;
    } catch (e, s) {
      print("AuthService: Generic Exception during Email/Password Sign-Up: $e");
      print("AuthService: StackTrace: $s");
      throw e;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    print("AuthService: Attempting Email/Password Sign-In for $email...");
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print("AuthService: Email/Password Sign-In successful: ${userCredential.user?.uid}");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("AuthService: Firebase Auth Exception during Email/Password Sign-In: ${e.message}, Code: ${e.code}");
      throw e;
    } catch (e, s) {
      print("AuthService: Generic Exception during Email/Password Sign-In: $e");
      print("AuthService: StackTrace: $s");
      throw e;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    print("AuthService: Attempting Google Sign-In...");
    try {
      print("AuthService: Calling GoogleSignIn().signIn()...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print(
        "AuthService: GoogleSignIn().signIn() completed. User: ${googleUser?.displayName}",
      );

      if (googleUser == null) {
        print("AuthService: Google sign-in cancelled by user.");
        return null;
      }

      print("AuthService: Getting Google authentication...");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print(
        "AuthService: Google authentication obtained. AccessToken: ${googleAuth.accessToken != null}, IDToken: ${googleAuth.idToken != null}",
      );

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print("AuthService: Firebase AuthCredential created.");

      print("AuthService: Signing in with Firebase credential...");
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      print(
        "AuthService: Firebase Sign-In successful: ${userCredential.user?.displayName}",
      );
      return userCredential;
    } on FirebaseAuthException catch (e, s) {
      print(
        "AuthService: Firebase Auth Exception during Google Sign-In: ${e.message}, Code: ${e.code}",
      );
      print("AuthService: StackTrace: $s");
      throw e;
    } catch (e, s) {
      print("AuthService: Generic Exception during Google Sign-In: $e");
      print("AuthService: StackTrace: $s");
      throw e;
    }
  }

  Future<UserCredential?> signInWithFacebook() async {
    print("AuthService: Attempting Facebook Sign-In...");
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        print("AuthService: Facebook AccessToken obtained.");

        final AuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);
        print("AuthService: Firebase AuthCredential created from Facebook token.");

        UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
        print("AuthService: Firebase Sign-In with Facebook successful: ${userCredential.user?.displayName}");
        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        print("AuthService: Facebook sign-in cancelled by user.");
        return null;
      } else {
        print("AuthService: Facebook sign-in failed: ${result.message}");
        throw FirebaseAuthException(code: 'facebook-sign-in-failed', message: result.message);
      }
    } on FirebaseAuthException catch (e) {
      print("AuthService: Firebase Auth Exception during Facebook Sign-In: ${e.code} - ${e.message}");
      throw e;
    } catch (e, s) {
      print("AuthService: Generic Exception during Facebook Sign-In: $e");
      print("AuthService: StackTrace: $s");
      throw e;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    print("AuthService: Attempting Apple Sign-In...");
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      print(
          "AuthService: Apple ID Credential obtained. UserIdentifier: ${appleCredential.userIdentifier}");

      final String? idToken = appleCredential.identityToken;
      if (idToken == null) {
        print("AuthService: Apple identityToken is null.");
        throw FirebaseAuthException(
            code: 'apple-id-token-null',
            message: 'Failed to retrieve Apple ID token.');
      }

      final AuthCredential appleAuthCredential =
          AppleAuthProvider.credential(idToken);

      print("AuthService: Firebase AuthCredential created from Apple token.");
      UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(appleAuthCredential);
      print(
          "AuthService: Firebase Sign-In with Apple successful: ${userCredential.user?.displayName}");

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        String? displayName;
        if (appleCredential.givenName != null &&
            appleCredential.familyName != null) {
          displayName =
              '${appleCredential.givenName} ${appleCredential.familyName}';
        } else if (appleCredential.givenName != null) {
          displayName = appleCredential.givenName;
        }
        if (displayName != null && displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
          print(
              "AuthService: Updated Firebase user displayName from Apple: $displayName");
        }
      }
      return userCredential;
    } on SignInWithAppleException catch (e) {
      print("AuthService: SignInWithAppleException: ${e.toString()}");
      if (e.toString().toLowerCase().contains("canceled")) {
        print("AuthService: Apple sign-in cancelled by user.");
        return null;
      }
      throw FirebaseAuthException(
          code: 'apple-sign-in-failed',
          message: e.toString());
    } on FirebaseAuthException catch (e) {
      print(
          "AuthService: Firebase Auth Exception during Apple Sign-In: ${e.code} - ${e.message}");
      throw e;
    } catch (e, s) {
      print("AuthService: Generic Exception during Apple Sign-In: $e");
      print("AuthService: StackTrace: $s");
      throw e;
    }
  }

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print("Google signed out");
      }
      await FacebookAuth.instance.logOut();
      print("Facebook logged out (if was signed in)");
    } catch (e) {
      print("Error during social sign outs: $e");
    } finally {
      await _firebaseAuth.signOut();
      print("Firebase signed out. 已登出");
    }
  }
}