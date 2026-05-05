import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  const AppGradients._();

  static const LinearGradient heroTeal = LinearGradient(
    colors: [AppColors.tealDeep, AppColors.teal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient incomeCard = LinearGradient(
    colors: [Color(0xFF4FBE7D), Color(0xFF85D97A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseCard = LinearGradient(
    colors: [Color(0xFFF15F68), Color(0xFFF38F82)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softTeal = LinearGradient(
    colors: [Color(0xFFD8F4F1), Color(0xFFBEE8E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
