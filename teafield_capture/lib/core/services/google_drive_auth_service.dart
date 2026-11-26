import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import '../constants/app_constants.dart';
import 'settings_service.dart';

/// Holds in-memory OAuth credentials for an active Drive session.
///
/// Access tokens are NEVER written to SQLite, SharedPreferences, logs, or ZIPs.
class DriveAuthCredentials {
  final String email;
  final String accessToken;

  const DriveAuthCredentials({
    required this.email,
    required this.accessToken,
  });
}

/// Manages Google account sign-in and narrow `drive.file` scope authorization
/// using the `google_sign_in` 7.x singleton API.
class GoogleDriveAuthService {
  GoogleDriveAuthService._();

  static final GoogleDriveAuthService instance = GoogleDriveAuthService._();

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  bool _initialized = false;
  GoogleSignInAccount? _currentUser;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventSubscription;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get connectedEmail => _currentUser?.email;
  bool get isSignedIn => _currentUser != null;

  /// Initializes the Google Sign-In singleton once.
  ///
  /// Does NOT trigger any UI or network prompt during photo capture.
  Future<void> initialize({String? clientId, String? serverClientId}) async {
    if (_initialized) return;

    final savedServerClientId =
        serverClientId ?? await SettingsService.instance.getGoogleServerClientId();

    await _signIn.initialize(
      clientId: clientId,
      serverClientId: savedServerClientId,
    );

    _eventSubscription = _signIn.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _currentUser = event.user;
            SettingsService.instance.setDriveAccountEmail(event.user.email);
          case GoogleSignInAuthenticationEventSignOut():
            _currentUser = null;
        }
      },
      onError: (_) {
        // Errors are surfaced during explicit user actions.
      },
    );

    _initialized = true;
  }

  /// Attempts lightweight restoration of an existing session only when the
  /// user opens the Backup / Drive management screens.
  Future<String?> tryRestorePreviousAccount() async {
    await initialize();
    try {
      await _signIn.attemptLightweightAuthentication();
      return _currentUser?.email ??
          await SettingsService.instance.getDriveAccountEmail();
    } catch (_) {
      return await SettingsService.instance.getDriveAccountEmail();
    }
  }

  /// Authenticates interactively and obtains a fresh `drive.file` access token
  /// in memory. Only invoke from an explicit user action (Connect / Upload / Delete).
  Future<DriveAuthCredentials> authorizeForDrive({
    bool forceInteractive = false,
  }) async {
    await initialize();

    var account = _currentUser;
    if (account == null || forceInteractive) {
      if (!_signIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Interactive Google Sign-In is not supported on this platform.',
        );
      }
      account = await _signIn.authenticate();
      _currentUser = account;
      await SettingsService.instance.setDriveAccountEmail(account.email);
    }

    GoogleSignInClientAuthorization? authorization;
    if (!forceInteractive) {
      authorization = await account.authorizationClient
          .authorizationForScopes(AppConstants.driveScopes);
    }

    authorization ??= await account.authorizationClient
        .authorizeScopes(AppConstants.driveScopes);

    return DriveAuthCredentials(
      email: account.email,
      accessToken: authorization.accessToken,
    );
  }

  /// Signs out from Google and clears the locally remembered email.
  Future<void> signOut() async {
    await initialize();
    await _signIn.signOut();
    _currentUser = null;
    await SettingsService.instance.setDriveAccountEmail(null);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
