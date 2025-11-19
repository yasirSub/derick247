import 'package:flutter/material.dart';

/// Centralized responsive helpers so every screen can react the same way to
/// very small, regular, and large devices.
class Responsive {
  const Responsive._();

  /// Breakpoints tuned for typical phones/tablets.
  static const double compactWidth = 360;
  static const double regularWidth = 480;
  static const double tabletWidth = 768;
  static const double desktopWidth = 1024;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= compactWidth;

  static bool isRegular(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width > compactWidth && width <= regularWidth;
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width > regularWidth &&
      MediaQuery.sizeOf(context).width < desktopWidth;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopWidth;

  /// Dynamic horizontal padding that shrinks on small devices to keep content
  /// visible without overflow.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= compactWidth) return 12;
    if (width <= regularWidth) return 16;
    if (width <= tabletWidth) return 20;
    return 24;
  }

  /// Additional vertical spacing between major sections.
  static double sectionSpacing(BuildContext context) {
    if (isCompact(context)) return 16;
    if (isRegular(context)) return 20;
    return 24;
  }

  /// Default max width for centered content (like auth forms).
  static double maxContentWidth(BuildContext context, {double? maxWidth}) {
    final width = MediaQuery.sizeOf(context).width;
    final resolved = maxWidth ?? 600;
    return width < resolved ? width : resolved;
  }

  /// Clamps a text scale factor so huge system settings do not break layouts.
  static double clampTextScale(BuildContext context, {double maxScale = 1.2}) {
    final media = MediaQuery.of(context);
    return media.textScaleFactor.clamp(0.85, maxScale);
  }
}

/// Wrapper that provides consistent padding, alignment, and max width.
class ResponsiveScaffoldBody extends StatelessWidget {
  final Widget child;
  final double? maxContentWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const ResponsiveScaffoldBody({
    super.key,
    required this.child,
    this.maxContentWidth,
    this.scrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth ?? Responsive.maxContentWidth(context),
        ),
        child: child,
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
            vertical: Responsive.sectionSpacing(context),
          ),
      child: content,
    );
  }
}

/// A helper widget that automatically switches between Row and Column for two
/// inputs so they render nicely on tiny phones.
class ResponsivePair extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double breakpoint;
  final double gap;
  final int firstFlex;
  final int secondFlex;

  const ResponsivePair({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = Responsive.regularWidth,
    this.gap = 12,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isStacked = width <= breakpoint;

    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          SizedBox(height: gap),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: firstFlex, child: first),
        SizedBox(width: gap),
        Expanded(flex: secondFlex, child: second),
      ],
    );
  }
}
