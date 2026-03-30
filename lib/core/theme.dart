import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

class GarudanTheme {
  GarudanTheme._();
  static const Color _primary = Color(0xFF7C83FD);
  static const Color _secondary = Color(0xFF64FFDA);
  static const Color _error = Color(0xFFFF5370);
  static const Color _surfaceAmoled = Color(0xFF000000);
  static const Color _surface1 = Color(0xFF0D0D0D);
  static const Color _surface2 = Color(0xFF141414);
  static const Color _surface3 = Color(0xFF1C1C1C);
  static const Color _onSurface = Color(0xFFE0E0E0);
  static const Color _onSurfaceMuted = Color(0xFF888888);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      error: _error,
      surface: _surface1,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: _onSurface,
    ),
    scaffoldBackgroundColor: _surfaceAmoled,
    appBarTheme: AppBarTheme(
      backgroundColor: _surfaceAmoled,
      foregroundColor: _onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _surfaceAmoled,
      ),
      titleTextStyle: GoogleFonts.inter(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      color: _surface2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary, width: 1.5)),
      labelStyle: const TextStyle(color: _onSurfaceMuted),
      hintStyle: const TextStyle(color: _onSurfaceMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2A2A), thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: _onSurface, size: 22),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface1,
      indicatorColor: _primary.withOpacity(0.2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surface3,
      contentTextStyle: GoogleFonts.inter(color: _onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: const [GarudanColors()],
  );
}

class GarudanColors extends ThemeExtension<GarudanColors> {
  const GarudanColors({
    this.success = const Color(0xFF64FFDA),
    this.warning = const Color(0xFFFFCB6B),
    this.surface1 = const Color(0xFF0D0D0D),
    this.surface2 = const Color(0xFF141414),
    this.surface3 = const Color(0xFF1C1C1C),
    this.muted = const Color(0xFF888888),
    this.primary = const Color(0xFF7C83FD),
  });
  final Color success;
  final Color warning;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color muted;
  final Color primary;

  @override
  GarudanColors copyWith({Color? success, Color? warning, Color? surface1, Color? surface2, Color? surface3, Color? muted, Color? primary}) {
    return GarudanColors(success: success ?? this.success, warning: warning ?? this.warning, surface1: surface1 ?? this.surface1, surface2: surface2 ?? this.surface2, surface3: surface3 ?? this.surface3, muted: muted ?? this.muted, primary: primary ?? this.primary);
  }

  @override
  GarudanColors lerp(GarudanColors? other, double t) {
    if (other == null) return this;
    return GarudanColors(success: Color.lerp(success, other.success, t)!, warning: Color.lerp(warning, other.warning, t)!, surface1: Color.lerp(surface1, other.surface1, t)!, surface2: Color.lerp(surface2, other.surface2, t)!, surface3: Color.lerp(surface3, other.surface3, t)!, muted: Color.lerp(muted, other.muted, t)!, primary: Color.lerp(primary, other.primary, t)!);
  }
}

// ── Terminal Themes (xterm 3.x TerminalTheme — no cursorAccent) ──────────────

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

  static TerminalTheme fromName(TerminalThemeName name) {
    return switch (name) {
      TerminalThemeName.amoled       => amoled,
      TerminalThemeName.dracula      => dracula,
      TerminalThemeName.nord         => nord,
      TerminalThemeName.monokai      => monokai,
      TerminalThemeName.solarizedDark => solarizedDark,
      TerminalThemeName.oneDark      => oneDark,
      TerminalThemeName.gruvbox      => gruvbox,
    };
  }

  static const amoled = TerminalTheme(
    cursor: Color(0xFF7C83FD),
    selection: Color(0x447C83FD),
    foreground: Color(0xFFE0E0E0),
    background: Color(0xFF000000),
    black: Color(0xFF1C1C1C),
    white: Color(0xFFE0E0E0),
    red: Color(0xFFFF5370),
    green: Color(0xFF64FFDA),
    yellow: Color(0xFFFFCB6B),
    blue: Color(0xFF7C83FD),
    magenta: Color(0xFFC792EA),
    cyan: Color(0xFF89DDFF),
    brightBlack: Color(0xFF4A4A4A),
    brightWhite: Color(0xFFFFFFFF),
    brightRed: Color(0xFFFF7986),
    brightGreen: Color(0xFFA3FFE9),
    brightYellow: Color(0xFFFFE39A),
    brightBlue: Color(0xFFA8AEFF),
    brightMagenta: Color(0xFFD9B3FF),
    brightCyan: Color(0xFFB2EBFF),
  );

  static const dracula = TerminalTheme(
    cursor: Color(0xFFFF79C6),
    selection: Color(0x6644475A),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    black: Color(0xFF21222C),
    white: Color(0xFFF8F8F2),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFF6272A4),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    brightBlack: Color(0xFF6272A4),
    brightWhite: Color(0xFFFFFFFF),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
  );

  static const nord = TerminalTheme(
    cursor: Color(0xFF88C0D0),
    selection: Color(0x66434C5E),
    foreground: Color(0xFFD8DEE9),
    background: Color(0xFF2E3440),
    black: Color(0xFF3B4252),
    white: Color(0xFFE5E9F0),
    red: Color(0xFFBF616A),
    green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD),
    cyan: Color(0xFF88C0D0),
    brightBlack: Color(0xFF4C566A),
    brightWhite: Color(0xFFECEFF4),
    brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C),
    brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1),
    brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB),
  );

  static const monokai = TerminalTheme(
    cursor: Color(0xFFF8F8F0),
    selection: Color(0x6649483E),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF272822),
    black: Color(0xFF272822),
    white: Color(0xFFF8F8F2),
    red: Color(0xFFF92672),
    green: Color(0xFFA6E22E),
    yellow: Color(0xFFF4BF75),
    blue: Color(0xFF66D9E8),
    magenta: Color(0xFFAE81FF),
    cyan: Color(0xFFA1EFE4),
    brightBlack: Color(0xFF75715E),
    brightWhite: Color(0xFFF9F8F5),
    brightRed: Color(0xFFF92672),
    brightGreen: Color(0xFFA6E22E),
    brightYellow: Color(0xFFF4BF75),
    brightBlue: Color(0xFF66D9E8),
    brightMagenta: Color(0xFFAE81FF),
    brightCyan: Color(0xFFA1EFE4),
  );

  static const solarizedDark = TerminalTheme(
    cursor: Color(0xFF268BD2),
    selection: Color(0x66073642),
    foreground: Color(0xFF839496),
    background: Color(0xFF002B36),
    black: Color(0xFF073642),
    white: Color(0xFFEEE8D5),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    brightBlack: Color(0xFF586E75),
    brightWhite: Color(0xFFFDF6E3),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF859900),
    brightYellow: Color(0xFFB58900),
    brightBlue: Color(0xFF268BD2),
    brightMagenta: Color(0xFFD33682),
    brightCyan: Color(0xFF2AA198),
  );

  static const oneDark = TerminalTheme(
    cursor: Color(0xFF528BFF),
    selection: Color(0x663E4451),
    foreground: Color(0xFFABB2BF),
    background: Color(0xFF282C34),
    black: Color(0xFF282C34),
    white: Color(0xFFABB2BF),
    red: Color(0xFFE06C75),
    green: Color(0xFF98C379),
    yellow: Color(0xFFE5C07B),
    blue: Color(0xFF61AFEF),
    magenta: Color(0xFFC678DD),
    cyan: Color(0xFF56B6C2),
    brightBlack: Color(0xFF5C6370),
    brightWhite: Color(0xFFFFFFFF),
    brightRed: Color(0xFFBE5046),
    brightGreen: Color(0xFF98C379),
    brightYellow: Color(0xFFD19A66),
    brightBlue: Color(0xFF61AFEF),
    brightMagenta: Color(0xFFC678DD),
    brightCyan: Color(0xFF56B6C2),
  );

  static const gruvbox = TerminalTheme(
    cursor: Color(0xFFFE8019),
    selection: Color(0x663C3836),
    foreground: Color(0xFFEBDBB2),
    background: Color(0xFF282828),
    black: Color(0xFF282828),
    white: Color(0xFFA89984),
    red: Color(0xFFCC241D),
    green: Color(0xFF98971A),
    yellow: Color(0xFFD79921),
    blue: Color(0xFF458588),
    magenta: Color(0xFFB16286),
    cyan: Color(0xFF689D6A),
    brightBlack: Color(0xFF928374),
    brightWhite: Color(0xFFEBDBB2),
    brightRed: Color(0xFFFB4934),
    brightGreen: Color(0xFFB8BB26),
    brightYellow: Color(0xFFFABD2F),
    brightBlue: Color(0xFF83A598),
    brightMagenta: Color(0xFFD3869B),
    brightCyan: Color(0xFF8EC07C),
  );
}
