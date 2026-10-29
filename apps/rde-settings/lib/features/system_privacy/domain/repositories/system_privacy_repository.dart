import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/system_privacy/domain/entities/system_privacy_settings.dart';

abstract interface class SystemPrivacyRepository {
  Either<Failure, SystemPrivacySettings> getSettings();
  Future<Either<Failure, void>> saveSettings(SystemPrivacySettings settings);
}
