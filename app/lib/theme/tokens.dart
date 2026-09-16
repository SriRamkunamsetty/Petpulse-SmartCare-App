import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the "Organic" design system
/// (`project/_ds/organic-.../styles.css`) used by the PetPulse prototype.
class PpColors {
  PpColors._();

  static const bg = Color(0xFFF5EAD8);
  static const surface = Color(0xFFEBDDC5);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFFC67139);
  static const accent2 = Color(0xFF7A8A5E);
  static const divider = Color(0x29201E1D); // ~16% of text

  static const neutral100 = Color(0xFFF9F4ED);
  static const neutral200 = Color(0xFFEEE7DB);
  static const neutral300 = Color(0xFFDCD3C4);
  static const neutral400 = Color(0xFFC0B6A5);
  static const neutral500 = Color(0xFFA19786);
  static const neutral600 = Color(0xFF82796A);
  static const neutral700 = Color(0xFF645C50);
  static const neutral800 = Color(0xFF474238);
  static const neutral900 = Color(0xFF2E2B25);

  static const accent100 = Color(0xFFFFF2EB);
  static const accent200 = Color(0xFFFFE1D0);
  static const accent300 = Color(0xFFFFC6A5);
  static const accent400 = Color(0xFFF6A06B);
  static const accent500 = Color(0xFFD67F48);
  static const accent600 = Color(0xFFB2622D);
  static const accent700 = Color(0xFF8C491A);
  static const accent800 = Color(0xFF643312);
  static const accent900 = Color(0xFF402310);

  static const accent2_100 = Color(0xFFF0FAE1);
  static const accent2_200 = Color(0xFFE1EECC);
  static const accent2_300 = Color(0xFFCCDBB2);
  static const accent2_400 = Color(0xFFAEBF92);
  static const accent2_500 = Color(0xFF8FA073);
  static const accent2_600 = Color(0xFF728157);
  static const accent2_700 = Color(0xFF56633F);
  static const accent2_800 = Color(0xFF3D472B);
  static const accent2_900 = Color(0xFF272E1B);

  static const liveRed = Color(0xFFFF5B4A);
}

class PpSpace {
  PpSpace._();
  static const s1 = 4.4;
  static const s2 = 8.8;
  static const s3 = 13.2;
  static const s4 = 17.6;
  static const s6 = 26.4;
  static const s8 = 35.2;
}

class PpRadius {
  PpRadius._();
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 28.0;
  // Cards/dialogs in the prototype use radius-lg * 1.15.
  static const card = lg * 1.15;
}

class PpShadow {
  PpShadow._();
  static const sm = [
    BoxShadow(color: Color(0x242E2B25), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x292E2B25), blurRadius: 10, offset: Offset(0, 3)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x382E2B25), blurRadius: 32, offset: Offset(0, 12)),
  ];
}
