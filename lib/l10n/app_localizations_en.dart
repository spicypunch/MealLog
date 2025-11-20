// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Meal Log';

  @override
  String get enterFoodNameTitle => 'Please enter the food name';

  @override
  String get defaultFoodName => 'Food';

  @override
  String get skip => 'Skip';

  @override
  String get confirm => 'Confirm';

  @override
  String get cameraPermissionRequired => 'Camera permission is required.';

  @override
  String get photoSaved => 'Photo saved!';

  @override
  String errorOccurred(Object error) {
    return 'Error occurred: $error';
  }

  @override
  String get permissionRequiredTitle => 'Permission Required';

  @override
  String get permissionRequiredContent =>
      'Storage/Photo permission is required to save photos. Please enable it in app settings.';

  @override
  String get cancel => 'Cancel';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get noPhotosMessage =>
      'No photos yet.\nTap the camera button below to log your first meal!';

  @override
  String get processingPhoto => 'Processing photo...';

  @override
  String get dateFormat => 'MMM d, yy h:mm a';
}
