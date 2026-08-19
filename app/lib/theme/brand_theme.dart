import 'package:flutter/material.dart';

abstract final class FolooBrand {
  static const ink = Color(0xFF1F1F1F);
  static const lime = Color(0xFFC9FA00);
  static const gray = Color(0xFF888888);
  static const fieldFill = Color(0xFFF8F8F8);
  static const danger = Color(0xFFC62828);

  static const logoWithTagline = 'assets/branding/foloo_logo_light_v1.png';
  static const logo = 'assets/branding/foloo_logo_light_v2.png';
  static const logoWithTaglineOnDark = 'assets/branding/foloo_logo_dark_v1.png';
  static const logoOnDark = 'assets/branding/foloo_logo_dark_v2.png';

  static String logoFor(Brightness brightness, {bool tagline = false}) {
    if (brightness == Brightness.dark) {
      return tagline ? logoWithTaglineOnDark : logoOnDark;
    }
    return tagline ? logoWithTagline : logo;
  }
}
