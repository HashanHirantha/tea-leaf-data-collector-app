/// Application-wide constants for TeaField Capture.
class AppConstants {
  AppConstants._();

  static const String appName = 'TeaField Capture';
  static const String projectCodeDefault = 'SL_TEA_RESEARCH';
  static const String sampleCodePrefix = 'TEA';
  static const String qrAppIdentifier = 'teafield';
  static const int qrSchemaVersion = 1;
  static const int gpsTimeoutSeconds = 12;
  static const int maxPhotoRetakes = 10;
  static const String databaseName = 'teafield_capture.db';
  static const int databaseVersion = 1;

  // File storage
  static const String appRootFolder = 'teafield';
  static const String photosFolder = 'photos';
  static const String exportsFolder = 'exports';
  static const String importsFolder = 'imports';

  // Google Drive
  static const String driveFolderName = 'TeaField Capture';
  static const String driveBackupsSubfolder = 'backups';
  static const List<String> driveScopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  // Resumable upload threshold (5 MB)
  static const int resumableUploadThreshold = 5 * 1024 * 1024;
}
