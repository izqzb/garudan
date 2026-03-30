import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

// ──────────────────────────────────────────────
// App Theme
// ──────────────────────────────────────────────

class GarudanTheme {
  GarudanTheme._();

  static const Color _primary = Color(0xFF7C83FD);
  static const Color _secondary = Color(0xFF64FFDA);
  static const Color _error = Color(0xFFFF5370);
  static const Color _warning = Color(0xFFFFCB6B);

  // AMOLED Black
  static const Color _surfaceAmoled = Color(0xFF000000);
  static const Color _surface1 = Color(0xFF0D0D0D);
  static const Color _surface2 = Color(0xFF141414);
  static const Color _surface3 = Color(0xFF1C1C1C);
  static const Color _surface4 = Color(0xFF242424);
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
          titleTextStyle: GoogleFonts.inter(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: _onSurfaceMuted),
          hintStyle: const TextStyle(color: _onSurfaceMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          iconColor: _onSurfaceMuted,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A2A),
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(color: _onSurface, size: 22),
        chipTheme: ChipThemeData(
          backgroundColor: _surface3,
          labelStyle: TextStyle(color: _onSurface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          headlineMedium: GoogleFonts.inter(
            color: _onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
          titleLarge: GoogleFonts.inter(
            color: _onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          titleMedium: GoogleFonts.inter(
            color: _onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.inter(
            color: _onSurface,
            fontSize: 14,
          ),
          bodySmall: GoogleFonts.inter(
            color: _onSurfaceMuted,
            fontSize: 12,
          ),
          labelSmall: GoogleFonts.inter(
            color: _onSurfaceMuted,
            fontSize: 11,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surfaceAmoled,
          selectedItemColor: _primary,
          unselectedItemColor: _onSurfaceMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _surface1,
          indicatorColor: _primary.withOpacity(0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primary);
            }
            return const IconThemeData(color: _onSurfaceMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.inter(color: _primary, fontSize: 11, fontWeight: FontWeight.w600);
            }
            return GoogleFonts.inter(color: _onSurfaceMuted, fontSize: 11);
          }),
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
          titleTextStyle: GoogleFonts.inter(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        extensions: const [GarudanColors()],
      );
}

// ──────────────────────────────────────────────
// Custom Theme Extension
// ──────────────────────────────────────────────

class GarudanColors extends ThemeExtension<GarudanColors> {
  const GarudanColors({
    this.success = const Color(0xFF64FFDA),
    this.warning = const Color(0xFFFFCB6B),
    this.running = const Color(0xFF64FFDA),
    this.stopped = const Color(0xFFFF5370),
    this.paused = const Color(0xFFFFCB6B),
    this.surface1 = const Color(0xFF0D0D0D),
    this.surface2 = const Color(0xFF141414),
    this.surface3 = const Color(0xFF1C1C1C),
    this.surface4 = const Color(0xFF242424),
    this.muted = const Color(0xFF888888),
    this.primary = const Color(0xFF7C83FD),
  });

  final Color success;
  final Color warning;
  final Color running;
  final Color stopped;
  final Color paused;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color surface4;
  final Color muted;
  final Color primary;

  @override
  GarudanColors copyWith({
    Color? success,
    Color? warning,
    Color? running,
    Color? stopped,
    Color? paused,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? surface4,
    Color? muted,
    Color? primary,
  }) {
    return GarudanColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      running: running ?? this.running,
      stopped: stopped ?? this.stopped,
      paused: paused ?? this.paused,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      surface4: surface4 ?? this.surface4,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
    );
  }

  @override
  GarudanColors lerp(GarudanColors? other, double t) {
    if (other == null) return this;
    return GarudanColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      running: Color.lerp(running, other.running, t)!,
      stopped: Color.lerp(stopped, other.stopped, t)!,
      paused: Color.lerp(paused, other.paused, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      surface4: Color.lerp(surface4, other.surface4, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}

// ──────────────────────────────────────────────
// Terminal Color Themes
// ──────────────────────────────────────────────

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

class TerminalThemes {
  TerminalThemes._();

  static TerminalColors fromName(TerminalThemeName name) {
    return switch (name) {
      TerminalThemeName.amoled => amoled,
      TerminalThemeName.dracula => dracula,
      TerminalThemeName.nord => nord,
      TerminalThemeName.monokai => monokai,
      TerminalThemeName.solarizedDark => solarizedDark,
      TerminalThemeName.oneDark => oneDark,
      TerminalThemeName.gruvbox => gruvbox,
    };
  }

  static final amoled = TerminalColors(
    background: const Color(0xFF000000),
    foreground: const Color(0xFFE0E0E0),
    cursor: const Color(0xFF7C83FD),
    cursorAccent: const Color(0xFF000000),
    selection: const Color(0xFF7C83FD).withOpacity(0.3),
    black: const Color(0xFF1C1C1C),
    white: const Color(0xFFE0E0E0),
    red: const Color(0xFFFF5370),
    green: const Color(0xFF64FFDA),
    yellow: const Color(0xFFFFCB6B),
    blue: const Color(0xFF7C83FD),
    magenta: const Color(0xFFC792EA),
    cyan: const Color(0xFF89DDFF),
    brightBlack: const Color(0xFF4A4A4A),
    brightWhite: const Color(0xFFFFFFFF),
    brightRed: const Color(0xFFFF7986),
    brightGreen: const Color(0xFFA3FFE9),
    brightYellow: const Color(0xFFFFE39A),
    brightBlue: const Color(0xFFA8AEFF),
    brightMagenta: const Color(0xFFD9B3FF),
    brightCyan: const Color(0xFFB2EBFF),
  );

  static final dracula = TerminalColors(
    background: const Color(0xFF282A36),
    foreground: const Color(0xFFF8F8F2),
    cursor: const Color(0xFFFF79C6),
    cursorAccent: const Color(0xFF282A36),
    selection: const Color(0xFF44475A),
    black: const Color(0xFF21222C),
    white: const Color(0xFFF8F8F2),
    red: const Color(0xFFFF5555),
    green: const Color(0xFF50FA7B),
    yellow: const Color(0xFFF1FA8C),
    blue: const Color(0xFF6272A4),
    magenta: const Color(0xFFFF79C6),
    cyan: const Color(0xFF8BE9FD),
    brightBlack: const Color(0xFF6272A4),
    brightWhite: const Color(0xFFFFFFFF),
    brightRed: const Color(0xFFFF6E6E),
    brightGreen: const Color(0xFF69FF94),
    brightYellow: const Color(0xFFFFFFA5),
    brightBlue: const Color(0xFFD6ACFF),
    brightMagenta: const Color(0xFFFF92DF),
    brightCyan: const Color(0xFFA4FFFF),
  );

  static final nord = TerminalColors(
    background: const Color(0xFF2E3440),
    foreground: const Color(0xFFD8DEE9),
    cursor: const Color(0xFF88C0D0),
    cursorAccent: const Color(0xFF2E3440),
    selection: const Color(0xFF434C5E),
    black: const Color(0xFF3B4252),
    white: const Color(0xFFE5E9F0),
    red: const Color(0xFFBF616A),
    green: const Color(0xFFA3BE8C),
    yellow: const Color(0xFFEBCB8B),
    blue: const Color(0xFF81A1C1),
    magenta: const Color(0xFFB48EAD),
    cyan: const Color(0xFF88C0D0),
    brightBlack: const Color(0xFF4C566A),
    brightWhite: const Color(0xFFECEFF4),
    brightRed: const Color(0xFFBF616A),
    brightGreen: const Color(0xFFA3BE8C),
    brightYellow: const Color(0xFFEBCB8B),
    brightBlue: const Color(0xFF81A1C1),
    brightMagenta: const Color(0xFFB48EAD),
    brightCyan: const Color(0xFF8FBCBB),
  );

  static final monokai = TerminalColors(
    background: const Color(0xFF272822),
    foreground: const Color(0xFFF8F8F2),
    cursor: const Color(0xFFF8F8F0),
    cursorAccent: const Color(0xFF272822),
    selection: const Color(0xFF49483E),
    black: const Color(0xFF272822),
    white: const Color(0xFFF8F8F2),
    red: const Color(0xFFF92672),
    green: const Color(0xFFA6E22E),
    yellow: const Color(0xFFF4BF75),
    blue: const Color(0xFF66D9E8),
    magenta: const Color(0xFFAE81FF),
    cyan: const Color(0xFFA1EFE4),
    brightBlack: const Color(0xFF75715E),
    brightWhite: const Color(0xFFF9F8F5),
    brightRed: const Color(0xFFF92672),
    brightGreen: const Color(0xFFA6E22E),
    brightYellow: const Color(0xFFF4BF75),
    brightBlue: const Color(0xFF66D9E8),
    brightMagenta: const Color(0xFFAE81FF),
    brightCyan: const Color(0xFFA1EFE4),
  );

  static final solarizedDark = TerminalColors(
    background: const Color(0xFF002B36),
    foreground: const Color(0xFF839496),
    cursor: const Color(0xFF268BD2),
    cursorAccent: const Color(0xFF002B36),
    selection: const Color(0xFF073642),
    black: const Color(0xFF073642),
    white: const Color(0xFFEEE8D5),
    red: const Color(0xFFDC322F),
    green: const Color(0xFF859900),
    yellow: const Color(0xFFB58900),
    blue: const Color(0xFF268BD2),
    magenta: const Color(0xFFD33682),
    cyan: const Color(0xFF2AA198),
    brightBlack: const Color(0xFF586E75),
    brightWhite: const Color(0xFFFDF6E3),
    brightRed: const Color(0xFFCB4B16),
    brightGreen: const Color(0xFF859900),
    brightYellow: const Color(0xFFB58900),
    brightBlue: const Color(0xFF268BD2),
    brightMagenta: const Color(0xFFD33682),
    brightCyan: const Color(0xFF2AA198),
  );

  static final oneDark = TerminalColors(
    background: const Color(0xFF282C34),
    foreground: const Color(0xFFABB2BF),
    cursor: const Color(0xFF528BFF),
    cursorAccent: const Color(0xFF282C34),
    selection: const Color(0xFF3E4451),
    black: const Color(0xFF282C34),
    white: const Color(0xFFABB2BF),
    red: const Color(0xFFE06C75),
    green: const Color(0xFF98C379),
    yellow: const Color(0xFFE5C07B),
    blue: const Color(0xFF61AFEF),
    magenta: const Color(0xFFC678DD),
    cyan: const Color(0xFF56B6C2),
    brightBlack: const Color(0xFF5C6370),
    brightWhite: const Color(0xFFFFFFFF),
    brightRed: const Color(0xFFBE5046),
    brightGreen: const Color(0xFF98C379),
    brightYellow: const Color(0xFFD19A66),
    brightBlue: const Color(0xFF61AFEF),
    brightMagenta: const Color(0xFFC678DD),
    brightCyan: const Color(0xFF56B6C2),
  );

  static final gruvbox = TerminalColors(
    background: const Color(0xFF282828),
    foreground: const Color(0xFFEBDBB2),
    cursor: const Color(0xFFFE8019),
    cursorAccent: const Color(0xFF282828),
    selection: const Color(0xFF3C3836),
    black: const Color(0xFF282828),
    white: const Color(0xFFA89984),
    red: const Color(0xFFCC241D),
    green: const Color(0xFF98971A),
    yellow: const Color(0xFFD79921),
    blue: const Color(0xFF458588),
    magenta: const Color(0xFFB16286),
    cyan: const Color(0xFF689D6A),
    brightBlack: const Color(0xFF928374),
    brightWhite: const Color(0xFFEBDBB2),
    brightRed: const Color(0xFFFB4934),
    brightGreen: const Color(0xFFB8BB26),
    brightYellow: const Color(0xFFFABD2F),
    brightBlue: const Color(0xFF83A598),
    brightMagenta: const Color(0xFFD3869B),
    brightCyan: const Color(0xFF8EC07C),
  );
}
