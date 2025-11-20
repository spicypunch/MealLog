// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Meal Log';

  @override
  String get enterFoodNameTitle => '음식 이름을 입력해주세요';

  @override
  String get defaultFoodName => '음식';

  @override
  String get skip => '건너뛰기';

  @override
  String get confirm => '확인';

  @override
  String get cameraPermissionRequired => '카메라 권한이 필요합니다.';

  @override
  String get photoSaved => '사진이 저장되었습니다!';

  @override
  String errorOccurred(Object error) {
    return '오류가 발생했습니다: $error';
  }

  @override
  String get permissionRequiredTitle => '권한 필요';

  @override
  String get permissionRequiredContent =>
      '사진을 저장하려면 저장소/사진 권한이 필요합니다. 앱 설정에서 권한을 허용해주세요.';

  @override
  String get cancel => '취소';

  @override
  String get openSettings => '설정 열기';

  @override
  String get noPhotosMessage =>
      '아직 저장된 사진이 없습니다.\n아래 카메라 버튼을 눌러 첫 번째 식사를 기록해보세요!';

  @override
  String get processingPhoto => '사진 처리 중...';

  @override
  String get dateFormat => 'yy년 M월 d일 h:mm a';
}
