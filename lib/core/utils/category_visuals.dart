import 'package:flutter/material.dart';

class IconChoice {
  final String key;
  final IconData icon;

  const IconChoice({required this.key, required this.icon});
}

const List<IconChoice> kCategoryIconChoices = [
  // Mặc định
  IconChoice(key: 'label', icon: Icons.label_outline),
  // Ăn uống
  IconChoice(key: 'restaurant', icon: Icons.restaurant_outlined),
  IconChoice(key: 'local_cafe', icon: Icons.local_cafe_outlined),
  IconChoice(key: 'fastfood', icon: Icons.fastfood_outlined),
  IconChoice(key: 'local_bar', icon: Icons.local_bar_outlined),
  // Mua sắm
  IconChoice(key: 'shopping_bag', icon: Icons.shopping_bag_outlined),
  IconChoice(key: 'checkroom', icon: Icons.checkroom_outlined),
  IconChoice(key: 'devices', icon: Icons.devices_outlined),
  // Nhà cửa
  IconChoice(key: 'home', icon: Icons.home_outlined),
  IconChoice(
    key: 'electrical_services',
    icon: Icons.electrical_services_outlined,
  ),
  IconChoice(key: 'wifi', icon: Icons.wifi_outlined),
  // Di chuyển
  IconChoice(key: 'directions_car', icon: Icons.directions_car_outlined),
  IconChoice(key: 'motorcycle', icon: Icons.motorcycle_outlined),
  IconChoice(key: 'flight', icon: Icons.flight_outlined),
  IconChoice(key: 'local_gas_station', icon: Icons.local_gas_station_outlined),
  // Sức khoẻ & làm đẹp
  IconChoice(key: 'health', icon: Icons.health_and_safety_outlined),
  IconChoice(key: 'fitness_center', icon: Icons.fitness_center_outlined),
  IconChoice(key: 'spa', icon: Icons.spa_outlined),
  // Giáo dục
  IconChoice(key: 'school', icon: Icons.school_outlined),
  IconChoice(key: 'menu_book', icon: Icons.menu_book_outlined),
  // Giải trí
  IconChoice(key: 'movie', icon: Icons.movie_outlined),
  IconChoice(key: 'sports_esports', icon: Icons.sports_esports_outlined),
  IconChoice(key: 'sports_soccer', icon: Icons.sports_soccer_outlined),
  IconChoice(key: 'music_note', icon: Icons.music_note_outlined),
  // Tài chính
  IconChoice(key: 'savings', icon: Icons.savings_outlined),
  IconChoice(key: 'payments', icon: Icons.payments_outlined),
  IconChoice(key: 'credit_card', icon: Icons.credit_card_outlined),
  IconChoice(key: 'trending_up', icon: Icons.trending_up_outlined),
  // Công việc
  IconChoice(key: 'work', icon: Icons.work_outline),
  IconChoice(key: 'computer', icon: Icons.computer_outlined),
  // Gia đình & xã hội
  IconChoice(key: 'gift', icon: Icons.card_giftcard_outlined),
  IconChoice(key: 'favorite', icon: Icons.favorite_outline),
  IconChoice(key: 'people', icon: Icons.people_outline),
  IconChoice(key: 'pets', icon: Icons.pets_outlined),
  // Khác
  IconChoice(key: 'more_horiz', icon: Icons.more_horiz_outlined),
];

const List<IconChoice> kIncomeIconChoices = [
  // Lương & thu nhập cố định
  IconChoice(key: 'payments', icon: Icons.payments_outlined),
  IconChoice(key: 'work', icon: Icons.work_outline),
  IconChoice(key: 'badge', icon: Icons.badge_outlined),
  IconChoice(key: 'schedule', icon: Icons.schedule_outlined),
  // Thưởng & phúc lợi
  IconChoice(key: 'stars', icon: Icons.stars_outlined),
  IconChoice(key: 'card_giftcard', icon: Icons.card_giftcard_outlined),
  IconChoice(key: 'emoji_events', icon: Icons.emoji_events_outlined),
  // Kinh doanh & freelance
  IconChoice(key: 'storefront', icon: Icons.storefront_outlined),
  IconChoice(key: 'handshake', icon: Icons.handshake_outlined),
  IconChoice(key: 'sell', icon: Icons.sell_outlined),
  IconChoice(key: 'computer', icon: Icons.computer_outlined),
  // Đầu tư & tài chính
  IconChoice(key: 'trending_up', icon: Icons.trending_up_outlined),
  IconChoice(key: 'savings', icon: Icons.savings_outlined),
  IconChoice(key: 'account_balance', icon: Icons.account_balance_outlined),
  IconChoice(key: 'currency_exchange', icon: Icons.currency_exchange_outlined),
  IconChoice(key: 'bar_chart', icon: Icons.bar_chart_outlined),
  // Cho thuê & tài sản
  IconChoice(key: 'home', icon: Icons.home_outlined),
  IconChoice(key: 'apartment', icon: Icons.apartment_outlined),
  IconChoice(key: 'directions_car', icon: Icons.directions_car_outlined),
  // Trợ cấp & hỗ trợ
  IconChoice(
    key: 'volunteer_activism',
    icon: Icons.volunteer_activism_outlined,
  ),
  IconChoice(key: 'people', icon: Icons.people_outline),
  IconChoice(key: 'favorite', icon: Icons.favorite_outline),
  // Khác
  IconChoice(key: 'label', icon: Icons.label_outline),
  IconChoice(key: 'more_horiz', icon: Icons.more_horiz_outlined),
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
  if (key == 'event_note') {
    return Icons.event_note_outlined;
  }
  for (final choice in [...kCategoryIconChoices, ...kIncomeIconChoices]) {
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
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
