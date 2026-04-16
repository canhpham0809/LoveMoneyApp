import 'package:equatable/equatable.dart';

class SettingsEntity extends Equatable {
  final String coupleId;
  final String currency;
  final String language;
  final bool notificationsEnabled;
  final bool biometricEnabled;

  const SettingsEntity({
    required this.coupleId,
    required this.currency,
    required this.language,
    required this.notificationsEnabled,
    required this.biometricEnabled,
  });

  @override
  List<Object?> get props => [
    coupleId,
    currency,
    language,
    notificationsEnabled,
    biometricEnabled,
  ];
}
