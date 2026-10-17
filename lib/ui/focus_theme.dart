import 'package:flutter/material.dart';

@immutable
class FocusColors extends ThemeExtension<FocusColors> {
  const FocusColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.soft,
    required this.warning,
    required this.warningSurface,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color soft;
  final Color warning;
  final Color warningSurface;

  static const light = FocusColors(
    background: Color(0xFFF9FAF7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF20251F),
    muted: Color(0xFF626A5F),
    line: Color(0xFFE5E8DF),
    accent: Color(0xFFC8F476),
    accentInk: Color(0xFF243016),
    soft: Color(0xFFEDF2E7),
    warning: Color(0xFF8D3E24),
    warningSurface: Color(0xFFFAECE5),
  );

  static const dark = FocusColors(
    background: Color(0xFF171A17),
    surface: Color(0xFF242924),
    ink: Color(0xFFF2F4ED),
    muted: Color(0xFFA9B2A6),
    line: Color(0xFF343C32),
    accent: Color(0xFFB7E768),
    accentInk: Color(0xFF213013),
    soft: Color(0xFF293324),
    warning: Color(0xFFFFB68E),
    warningSurface: Color(0xFF3E2923),
  );

  static FocusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<FocusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  FocusColors copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? accentInk,
    Color? soft,
    Color? warning,
    Color? warningSurface,
  }) {
    return FocusColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      soft: soft ?? this.soft,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
    );
  }

  @override
  FocusColors lerp(covariant FocusColors? other, double t) {
    if (other == null) return this;
    return FocusColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
    );
  }
}

ThemeData focusTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? FocusColors.dark
      : FocusColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    brightness: brightness,
    primary: colors.ink,
    onPrimary: colors.background,
    primaryContainer: colors.accent,
    onPrimaryContainer: colors.accentInk,
    secondary: colors.accent,
    onSecondary: colors.accentInk,
    secondaryContainer: colors.soft,
    onSecondaryContainer: colors.ink,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.muted,
    outline: colors.muted,
    outlineVariant: colors.line,
    error: colors.warning,
    onError: colors.background,
    errorContainer: colors.warningSurface,
    onErrorContainer: colors.warning,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
  final text = base.textTheme.apply(
    bodyColor: colors.ink,
    displayColor: colors.ink,
  );
  final textTheme = text.copyWith(
    displayLarge: text.displayLarge?.copyWith(
      fontSize: 64,
      fontWeight: FontWeight.w700,
      height: 1.08,
      letterSpacing: -2,
    ),
    displayMedium: text.displayMedium?.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -1,
    ),
    displaySmall: text.displaySmall?.copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      height: 1.18,
      letterSpacing: -0.7,
    ),
    headlineLarge: text.headlineLarge?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.5,
    ),
    headlineMedium: text.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.32,
      letterSpacing: -0.4,
    ),
    headlineSmall: text.headlineSmall?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.32,
      letterSpacing: -0.4,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.32,
      letterSpacing: -0.4,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: 0,
    ),
    titleSmall: text.titleSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: 0,
    ),
    bodyLarge: text.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.55,
      letterSpacing: 0,
    ),
    bodyMedium: text.bodyMedium?.copyWith(
      fontSize: 16,
      height: 1.55,
      letterSpacing: 0,
    ),
    bodySmall: text.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.45,
      letterSpacing: 0,
      color: colors.muted,
    ),
    labelLarge: text.labelLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: 0,
    ),
    labelMedium: text.labelMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0,
    ),
    labelSmall: text.labelSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 0,
    ),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: colors.line),
  );

  return base.copyWith(
    extensions: [colors],
    textTheme: textTheme,
    dividerColor: colors.line,
    iconTheme: IconThemeData(color: colors.ink, size: 22),
    appBarTheme: AppBarThemeData(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 24,
      titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 20),
      iconTheme: IconThemeData(color: colors.ink, size: 22),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.ink,
        foregroundColor: colors.background,
        disabledBackgroundColor: colors.soft,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: BorderSide(color: colors.line),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: buttonShape,
        textStyle: textTheme.labelMedium,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.ink,
        minimumSize: const Size(48, 48),
        iconSize: 22,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 56),
      hintStyle: textTheme.bodyLarge?.copyWith(color: colors.muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.muted),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: colors.warning),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.ink, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.warning),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.warning, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 76,
      indicatorColor: colors.accent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? colors.ink : colors.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.accentInk : colors.muted,
          size: 22,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.ink,
      linearTrackColor: colors.line,
      linearMinHeight: 4,
      borderRadius: BorderRadius.circular(4),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.ink,
      selectionColor: colors.accent.withValues(alpha: 0.45),
      selectionHandleColor: colors.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.background,
      ),
      actionTextColor: colors.background,
      behavior: SnackBarBehavior.floating,
      shape: buttonShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: colors.muted,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
