import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

// ── App Theme ─────────────────────────────────────────────────────────────────

class GarudanTheme {
  GarudanTheme._();

  static const Color primary    = Color(0xFF7C83FD);
  static const Color secondary  = Color(0xFF64FFDA);
  static const Color error      = Color(0xFFFF5370);
  static const Color warning    = Color(0xFFFFCB6B);

  // Dark surfaces
  static const Color darkBg     = Color(0xFF000000);
  static const Color darkS1     = Color(0xFF0D0D0D);
  static const Color darkS2     = Color(0xFF141414);
  static const Color darkS3     = Color(0xFF1C1C1C);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkText   = Color(0xFFE0E0E0);
  static const Color darkMuted  = Color(0xFF888888);

  // Light surfaces
  static const Color lightBg    = Color(0xFFF5F5F5);
  static const Color lightS1    = Color(0xFFFFFFFF);
  static const Color lightS2    = Color(0xFFF0F0F0);
  static const Color lightS3    = Color(0xFFE8E8E8);
  static const Color lightBorder= Color(0xFFDDDDDD);
  static const Color lightText  = Color(0xFF1A1A1A);
  static const Color lightMuted = Color(0xFF888888);

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg      = isDark ? darkBg     : lightBg;
    final s1      = isDark ? darkS1     : lightS1;
    final s2      = isDark ? darkS2     : lightS2;
    final s3      = isDark ? darkS3     : lightS3;
    final border  = isDark ? darkBorder : lightBorder;
    final text    = isDark ? darkText   : lightText;
    final muted   = isDark ? darkMuted  : lightMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: s1,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: text,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : lightS1,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: GoogleFonts.inter(color: text, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: s2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 1.5)),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: text, size: 22),
      textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s3,
        contentTextStyle: GoogleFonts.inter(color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      extensions: [GarudanColors(isDark: isDark)],
    );
  }
}

class GarudanColors extends ThemeExtension<GarudanColors> {
  const GarudanColors({required this.isDark});
  final bool isDark;

  Color get success  => const Color(0xFF64FFDA);
  Color get warning  => const Color(0xFFFFCB6B);
  Color get error    => const Color(0xFFFF5370);
  Color get primary  => const Color(0xFF7C83FD);
  Color get surface1 => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
  Color get surface2 => isDark ? const Color(0xFF141414) : const Color(0xFFF0F0F0);
  Color get surface3 => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);
  Color get border   => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD);
  Color get muted    => const Color(0xFF888888);
  Color get text     => isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
  Color get bg       => isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);

  @override
  GarudanColors copyWith({bool? isDark}) => GarudanColors(isDark: isDark ?? this.isDark);
  @override
  GarudanColors lerp(GarudanColors? other, double t) => this;
}

// ── Terminal Themes (xterm 4.x) ───────────────────────────────────────────────

enum TerminalThemeName {
  amoled('AMOLED Black'),
  dracula('Dracula'),
  nord('Nord'),
  monokai('Monokai'),
  solarizedDark('Solarized Dark'),
  oneDark('One Dark'),
  gruvbox('Gruvbox');
  const TerminalThemeName(this.label);
  final String label;
}

class GarudanTerminalThemes {
  GarudanTerminalThemes._();

  static TerminalTheme fromName(TerminalThemeName name) => switch (name) {
    TerminalThemeName.amoled       => amoled,
    TerminalThemeName.dracula      => dracula,
    TerminalThemeName.nord         => nord,
    TerminalThemeName.monokai      => monokai,
    TerminalThemeName.solarizedDark => solarizedDark,
    TerminalThemeName.oneDark      => oneDark,
    TerminalThemeName.gruvbox      => gruvbox,
  };

  static const amoled = TerminalTheme(
    cursor: Color(0xFF7C83FD), selection: Color(0x447C83FD),
    foreground: Color(0xFFE0E0E0), background: Color(0xFF000000),
    black: Color(0xFF1C1C1C), white: Color(0xFFE0E0E0),
    red: Color(0xFFFF5370), green: Color(0xFF64FFDA),
    yellow: Color(0xFFFFCB6B), blue: Color(0xFF7C83FD),
    magenta: Color(0xFFC792EA), cyan: Color(0xFF89DDFF),
    brightBlack: Color(0xFF4A4A4A), brightRed: Color(0xFFFF7986),
    brightGreen: Color(0xFFA3FFE9), brightYellow: Color(0xFFFFE39A),
    brightBlue: Color(0xFFA8AEFF), brightMagenta: Color(0xFFD9B3FF),
    brightCyan: Color(0xFFB2EBFF), brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0x447C83FD),
    searchHitBackgroundCurrent: Color(0xFF7C83FD),
    searchHitForeground: Color(0xFFFFFFFF),
  );

  static const dracula = TerminalTheme(
    cursor: Color(0xFFFF79C6), selection: Color(0x6644475A),
    foreground: Color(0xFFF8F8F2), background: Color(0xFF282A36),
    black: Color(0xFF21222C), white: Color(0xFFF8F8F2),
    red: Color(0xFFFF5555), green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C), blue: Color(0xFF6272A4),
    magenta: Color(0xFFFF79C6), cyan: Color(0xFF8BE9FD),
    brightBlack: Color(0xFF6272A4), brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94), brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF), brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF), brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0x44FF79C6),
    searchHitBackgroundCurrent: Color(0xFFFF79C6),
    searchHitForeground: Color(0xFF282A36),
  );

  static const nord = TerminalTheme(
    cursor: Color(0xFF88C0D0), selection: Color(0x66434C5E),
    foreground: Color(0xFFD8DEE9), background: Color(0xFF2E3440),
    black: Color(0xFF3B4252), white: Color(0xFFE5E9F0),
    red: Color(0xFFBF616A), green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B), blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD), cyan: Color(0xFF88C0D0),
    brightBlack: Color(0xFF4C566A), brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C), brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1), brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB), brightWhite: Color(0xFFECEFF4),
    searchHitBackground: Color(0x4488C0D0),
    searchHitBackgroundCurrent: Color(0xFF88C0D0),
    searchHitForeground: Color(0xFF2E3440),
  );

  static const monokai = TerminalTheme(
    cursor: Color(0xFFF8F8F0), selection: Color(0x6649483E),
    foreground: Color(0xFFF8F8F2), background: Color(0xFF272822),
    black: Color(0xFF272822), white: Color(0xFFF8F8F2),
    red: Color(0xFFF92672), green: Color(0xFFA6E22E),
    yellow: Color(0xFFF4BF75), blue: Color(0xFF66D9E8),
    magenta: Color(0xFFAE81FF), cyan: Color(0xFFA1EFE4),
    brightBlack: Color(0xFF75715E), brightRed: Color(0xFFF92672),
    brightGreen: Color(0xFFA6E22E), brightYellow: Color(0xFFF4BF75),
    brightBlue: Color(0xFF66D9E8), brightMagenta: Color(0xFFAE81FF),
    brightCyan: Color(0xFFA1EFE4), brightWhite: Color(0xFFF9F8F5),
    searchHitBackground: Color(0x44AE81FF),
    searchHitBackgroundCurrent: Color(0xFFAE81FF),
    searchHitForeground: Color(0xFF272822),
  );

  static const solarizedDark = TerminalTheme(
    cursor: Color(0xFF268BD2), selection: Color(0x66073642),
    foreground: Color(0xFF839496), background: Color(0xFF002B36),
    black: Color(0xFF073642), white: Color(0xFFEEE8D5),
    red: Color(0xFFDC322F), green: Color(0xFF859900),
    yellow: Color(0xFFB58900), blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682), cyan: Color(0xFF2AA198),
    brightBlack: Color(0xFF586E75), brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF859900), brightYellow: Color(0xFFB58900),
    brightBlue: Color(0xFF268BD2), brightMagenta: Color(0xFFD33682),
    brightCyan: Color(0xFF2AA198), brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0x44268BD2),
    searchHitBackgroundCurrent: Color(0xFF268BD2),
    searchHitForeground: Color(0xFF002B36),
  );

  static const oneDark = TerminalTheme(
    cursor: Color(0xFF528BFF), selection: Color(0x663E4451),
    foreground: Color(0xFFABB2BF), background: Color(0xFF282C34),
    black: Color(0xFF282C34), white: Color(0xFFABB2BF),
    red: Color(0xFFE06C75), green: Color(0xFF98C379),
    yellow: Color(0xFFE5C07B), blue: Color(0xFF61AFEF),
    magenta: Color(0xFFC678DD), cyan: Color(0xFF56B6C2),
    brightBlack: Color(0xFF5C6370), brightRed: Color(0xFFBE5046),
    brightGreen: Color(0xFF98C379), brightYellow: Color(0xFFD19A66),
    brightBlue: Color(0xFF61AFEF), brightMagenta: Color(0xFFC678DD),
    brightCyan: Color(0xFF56B6C2), brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0x44528BFF),
    searchHitBackgroundCurrent: Color(0xFF528BFF),
    searchHitForeground: Color(0xFF282C34),
  );

  static const gruvbox = TerminalTheme(
    cursor: Color(0xFFFE8019), selection: Color(0x663C3836),
    foreground: Color(0xFFEBDBB2), background: Color(0xFF282828),
    black: Color(0xFF282828), white: Color(0xFFA89984),
    red: Color(0xFFCC241D), green: Color(0xFF98971A),
    yellow: Color(0xFFD79921), blue: Color(0xFF458588),
    magenta: Color(0xFFB16286), cyan: Color(0xFF689D6A),
    brightBlack: Color(0xFF928374), brightRed: Color(0xFFFB4934),
    brightGreen: Color(0xFFB8BB26), brightYellow: Color(0xFFFABD2F),
    brightBlue: Color(0xFF83A598), brightMagenta: Color(0xFFD3869B),
    brightCyan: Color(0xFF8EC07C), brightWhite: Color(0xFFEBDBB2),
    searchHitBackground: Color(0x44FE8019),
    searchHitBackgroundCurrent: Color(0xFFFE8019),
    searchHitForeground: Color(0xFF282828),
  );
}
