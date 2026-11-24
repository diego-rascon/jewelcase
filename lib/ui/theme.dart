import 'package:material_ui/material_ui.dart';

/// The app is dark-only and neutral: white and soft, untinted grays in the
/// spirit of Apple's dark mode. Content sits on a mid-dark gray; chrome (the
/// sidebar, the phone tab bar) is one step lighter. White is the accent
/// (selection, active controls, filled buttons). Only Now Playing takes
/// colors from the art.
ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Colors.grey,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: Colors.white,
        onPrimary: Colors.black,
        primaryContainer: const Color(0xFF363636),
        onPrimaryContainer: Colors.white,
        inversePrimary: Colors.black,
        secondary: const Color(0xFFAEAEAE),
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF2B2B2B),
        onSecondaryContainer: Colors.white,
        error: const Color(0xFFFF453A), // systemRed
        onError: Colors.white,
        errorContainer: const Color(0xFF5E1F1B),
        onErrorContainer: const Color(0xFFFFD9D5),
        surfaceTint: Colors.transparent,
        // Darkest to lightest. `surface` is the content background;
        // `surfaceContainerLow` is the chrome around it.
        surfaceContainerLowest: const Color(0xFF0D0D0D),
        surface: const Color(0xFF161616),
        surfaceContainerLow: const Color(0xFF1D1D1D),
        surfaceContainer: const Color(0xFF222222),
        surfaceContainerHigh: const Color(0xFF2A2A2A),
        surfaceContainerHighest: const Color(0xFF343434),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF9B9B9B),
        outline: const Color(0xFF666666),
        outlineVariant: const Color(0xFF2C2C2C), // hairline borders and separators
        inverseSurface: const Color(0xFFE6E6E6),
        onInverseSurface: const Color(0xFF161616),
      );

  final base = ThemeData(colorScheme: scheme, brightness: Brightness.dark, useMaterial3: true);
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      activeTrackColor: scheme.onSurface,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.16),
      thumbColor: scheme.onSurface,
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      checkmarkColor: scheme.onPrimary,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // MenuAnchor menus (e.g. the Albums sort): inset, rounded rows instead of
    // edge-to-edge 48px ones.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(168, 40)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Breakpoint between the phone layout (bottom tabs) and the desktop layout
/// (sidebar + player bar).
const wideLayoutWidth = 840.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideLayoutWidth;
