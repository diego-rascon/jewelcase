import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The app is dark-only and neutral: white and soft, untinted grays in the
/// spirit of Apple's dark mode. Content sits on a mid-dark gray; chrome (the
/// sidebar, the phone tab bar) is one step lighter. White is the accent
/// (selection, active controls, filled buttons). Only Now Playing and the
/// album and playlist page headers take colors from the art.
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
    // The icons Material widgets add themselves (an AppBar's back button).
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(LucideIcons.chevronLeft),
      closeButtonIconBuilder: (_) => const Icon(LucideIcons.x),
      drawerButtonIconBuilder: (_) => const Icon(LucideIcons.menu),
      endDrawerButtonIconBuilder: (_) => const Icon(LucideIcons.menu),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    // The phone tab bar's background is the `Frosted` it sits in (`AppShell`).
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
      // Material's chip icon size, named, so chips match the menus.
      iconTheme: IconThemeData(size: IconSizes.small, color: scheme.primary),
    ),
    // Rows of the popup menus (`showPopupMenu`): inset and rounded instead of
    // edge-to-edge 48px ones.
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(168, 40)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: const ProgressIndicatorThemeData(strokeCap: StrokeCap.round),
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

/// Width of the desktop queue sidebar.
const queueSidebarWidth = 340.0;

/// From this window width the queue opens as a sidebar beside the content,
/// leaving the content and the player bar enough room. Narrower windows show
/// the queue in Now Playing instead.
const queueSidebarLayoutWidth = 1140.0;

bool fitsQueueSidebar(BuildContext context) => MediaQuery.sizeOf(context).width >= queueSidebarLayoutWidth;

/// The app's icon sizes. Give an icon one of these rather than a number, so
/// icons in the same role match everywhere. Material's default, 24, is the
/// large size: an icon or [IconButton] with no size set gets it.
abstract final class IconSizes {
  /// Beside a line of text: sidebar items, desktop menu rows, inline labels.
  static const small = 18.0;

  /// Rows of buttons ([smallIconButtons]) and song-row indicators. Also the
  /// slot a [small] icon sits centered in, so labels line up.
  static const medium = 20.0;

  /// Standalone buttons and touch lists (the phone menu sheet), and every
  /// button in Now Playing besides its playback controls.
  static const large = 24.0;

  /// Now Playing's previous, play/pause and next, the one place controls run
  /// bigger.
  static const xlarge = 32.0;
}

/// The standard size for a row of icon buttons (the player bars, the album
/// and playlist page actions): [IconSizes.medium] icons in 40px buttons, side
/// by side, so the icons line up and sit evenly apart. Wrap the row in an
/// [IconButtonTheme] with this, and leave the buttons' own `iconSize` unset.
final smallIconButtons = IconButtonThemeData(
  style: IconButton.styleFrom(iconSize: IconSizes.medium, fixedSize: const Size.square(40), padding: EdgeInsets.zero),
);
