import 'package:equatable/equatable.dart';

class SettingsModel extends Equatable {
  final String coupleId;
  final String currency;
  final String language;
  final bool notificationsEnabled;
  final bool biometricEnabled;

  const SettingsModel({
    required this.coupleId,
    required this.currency,
    required this.language,
    required this.notificationsEnabled,
    required this.biometricEnabled,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      coupleId: json['couple_id'] as String,
      currency: json['currency'] as String,
      language: json['language'] as String,
      notificationsEnabled: json['notifications_enabled'] as bool,
      biometricEnabled: json['biometric_enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'couple_id': coupleId,
      'currency': currency,
      'language': language,
      'notifications_enabled': notificationsEnabled,
      'biometric_enabled': biometricEnabled,
    };
  }

  @override
  List<Object?> get props => [
    coupleId,
    currency,
    language,
    notificationsEnabled,
    biometricEnabled,
  ];
}
