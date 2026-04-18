import 'package:flutter/material.dart';

class IconChoice {
  final String key;
  final IconData icon;

  const IconChoice({required this.key, required this.icon});
}

const List<IconChoice> kCategoryIconChoices = [
  IconChoice(key: 'label', icon: Icons.label_outline),
  IconChoice(key: 'shopping_bag', icon: Icons.shopping_bag_outlined),
  IconChoice(key: 'restaurant', icon: Icons.restaurant_outlined),
  IconChoice(key: 'local_cafe', icon: Icons.local_cafe_outlined),
  IconChoice(key: 'home', icon: Icons.home_outlined),
  IconChoice(key: 'directions_car', icon: Icons.directions_car_outlined),
  IconChoice(key: 'flight', icon: Icons.flight_outlined),
  IconChoice(key: 'school', icon: Icons.school_outlined),
  IconChoice(key: 'health', icon: Icons.health_and_safety_outlined),
  IconChoice(key: 'gift', icon: Icons.card_giftcard_outlined),
  IconChoice(key: 'savings', icon: Icons.savings_outlined),
  IconChoice(key: 'payments', icon: Icons.payments_outlined),
  IconChoice(key: 'account_balance', icon: Icons.account_balance_outlined),
  IconChoice(key: 'work', icon: Icons.work_outline),
  IconChoice(key: 'wallet', icon: Icons.account_balance_wallet_outlined),
  IconChoice(key: 'request_quote', icon: Icons.request_quote_outlined),
  IconChoice(key: 'money_off', icon: Icons.money_off_csred_outlined),
];

const List<Color> kCategoryColorChoices = [
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF6B7280),
];

IconData iconFromKey(String key) {
  for (final choice in kCategoryIconChoices) {
    if (choice.key == key) {
      return choice.icon;
    }
  }
  return Icons.label_outline;
}

Color colorFromHex(String input, {Color fallback = const Color(0xFF6366F1)}) {
  final normalized = input.trim().toUpperCase();
  if (!RegExp(r'^#?[0-9A-F]{6}$').hasMatch(normalized)) {
    return fallback;
  }
  final hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
  return Color(int.parse('FF$hex', radix: 16));
}

String colorToHex(Color color) {
  final value = color.value & 0x00FFFFFF;
  return '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
