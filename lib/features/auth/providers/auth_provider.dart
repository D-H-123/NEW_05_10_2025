// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication status
enum AuthStatus { signedOut, signedIn, guest, loading, error }

/// Lightweight auth state model
class AuthState {
  final AuthStatus status;
  final String? uid;
  final String? errorMessage;
  const AuthState({
    required this.status,
    this.uid,
    this.errorMessage,
  });
  
  /// Getter for backward compatibility and better naming
  String? get userId => uid;
  
  const AuthState.signedOut() : this(status: AuthStatus.signedOut);
  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.guest(String guestId)
      : this(status: AuthStatus.guest, uid: guestId);
  const AuthState.signedIn(String uid)
      : this(status: AuthStatus.signedIn, uid: uid);
  const AuthState.error(String msg) : this(status: AuthStatus.error, errorMessage: msg);
}

/// Controller that exposes auth methods to the UI
class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState.signedOut()) {
    // Keep state in sync with Firebase Auth changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        state = const AuthState.signedOut();
      } else {
        state = AuthState.signedIn(user.uid);
      }
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;

  /// Email/password sign-up
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      state = const AuthState.loading();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState.signedIn(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(e.message ?? 'Sign up failed');
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Email/password sign-in
  Future<void> signInWithEmail(String email, String password) async {
    try {
      state = const AuthState.loading();
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState.signedIn(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(e.message ?? 'Sign in failed');
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Google Sign-In using google_sign_in v7+ API.
  Future<void> signInWithGoogle() async {
    try {
      state = const AuthState.loading();

      // Optional: initialize with clientId/serverClientId if required on your platform:
      await _google.initialize(clientId: '<IOS_CLIENT_ID>', serverClientId: '950146446484-lsr7ut9ufeu2u2e93lb0qgeapk8juvu7.apps.googleusercontent.com');

      // Prefer authenticate() on platforms that support it (v7+)
      GoogleSignInAccount? account;
      if (_google.supportsAuthenticate()) {
        // interactive sign-in that returns a GoogleSignInAccount
        account = await _google.authenticate();
      } else {
        // best-effort lightweight sign-in (may return null)
        account = await _google.attemptLightweightAuthentication();
        if (account == null) {
          // If you reach here on web, follow google_sign_in_web docs (renderButton) or configure
          throw FirebaseAuthException(
            code: 'UNSUPPORTED_PLATFORM',
            message:
                'Interactive Google sign-in is not available on this platform. See google_sign_in docs.',
          );
        }
      }

      // Get tokens for the account. In v7+, GoogleSignInAuthentication currently exposes idToken.
      final googleAuth = account.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'NO_ID_TOKEN',
          message: 'Google returned no idToken. Check your client IDs / configuration.',
        );
      }

      // Create Firebase credential using idToken only (access token removed in v7).
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await _auth.signInWithCredential(credential);
      state = AuthState.signedIn(userCredential.user!.uid);
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(e.message ?? 'Google sign-in failed');
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Guest sign-in (local only). Replace this with anonymous Firebase auth if desired.
  Future<void> signInAsGuest() async {
    // You might want to persist a guest id and the guest scan count using Hive / secure storage
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    state = AuthState.guest(guestId);
  }

  /// Sign out from Firebase and attempt to sign out from Google as well
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      try {
        // ignore errors if Google sign-out fails
        await _google.signOut();
      } catch (_) {}
      state = const AuthState.signedOut();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}

/// Riverpod provider (same name used in skeleton)
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());
