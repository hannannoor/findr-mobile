import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';

// shared page layout used across the app.
class AppPage extends StatelessWidget {
  final String subtitle;
  final Widget child;

  // shows a back button for pages opened from another screen.
  final bool showBack;

  // optional title used on pushed pages.
  final String title;

  // optional button shown at the top right.
  final Widget? action;

  final Widget? bottomNavigationBar;

  // controls whether the page handles scrolling automatically.
  final bool scrollable;

  const AppPage({
    super.key,
    required this.subtitle,
    required this.child,
    this.title = '',
    this.showBack = false,
    this.action,
    this.bottomNavigationBar,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPageHeading(
          subtitle: subtitle,
          title: title,
          showBack: showBack,
          action: action,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: bottomNavigationBar,
      body: SizedBox.expand(
        child: Stack(
          children: [
            const AppPageBackground(),
            SafeArea(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        28,
                      ),
                      child: content,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        14,
                        20,
                        0,
                      ),
                      child: content,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// shows the themed background used behind each page.
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    final bool dark =
        Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colors.background,
          ),

          // uses a separate image for dark mode.
          if (dark)
            Image.asset(
              'assets/images/background_dark.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) {
                return ColoredBox(
                  color: colors.background,
                );
              },
            )
          else
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                colors.illustrationTint,
                BlendMode.hue,
              ),
              child: Image.asset(
                'assets/images/background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) {
                  return ColoredBox(
                    color: colors.background,
                  );
                },
              ),
            ),

          // adds the palette overlay in light mode.
          if (!dark)
            ColoredBox(
              color: colors.illustrationOverlay,
            ),
        ],
      ),
    );
  }
}

// shows the findr logo using the colours from the current theme.
class FindrLogo extends StatelessWidget {
  final double height;
  final double? width;
  final AlignmentGeometry alignment;

  const FindrLogo({
    super.key,
    required this.height,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    final double logoWidth =
        width ?? height * (1196 / 477);

    // creates one coloured layer of the logo.
    Widget layer(Color colour) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          colour,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          'assets/images/logo.png',
          width: logoWidth,
          height: height,
          fit: BoxFit.fill,
          errorBuilder: (_, _, _) {
            return SizedBox(
              width: logoWidth,
              height: height,
            );
          },
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: logoWidth,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            layer(colors.logoLetters),

            // colours the location pin separately from the logo text.
            ClipRect(
              clipper: const _FindrPinClipper(),
              child: layer(colors.logoPin),
            ),
          ],
        ),
      ),
    );
  }
}

// keeps only the location pin area of the logo.
class _FindrPinClipper extends CustomClipper<Rect> {
  const _FindrPinClipper();

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      size.width * 0.24,
      size.height * 0.08,
      size.width * 0.34,
      size.height * 0.39,
    );
  }

  @override
  bool shouldReclip(
    covariant _FindrPinClipper oldClipper,
  ) {
    return false;
  }
}

// builds the heading shown at the top of each page.
class AppPageHeading extends StatelessWidget {
  final String subtitle;
  final String title;
  final bool showBack;
  final Widget? action;

  const AppPageHeading({
    super.key,
    required this.subtitle,
    this.title = '',
    this.showBack = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    // pushed pages use a smaller heading with a back button.
    if (showBack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const AppBackButton(),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (title.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -0.6,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              subtitle,
              style: TextStyle(
                // makes the subtitle larger when there is no title.
                fontSize: title.isEmpty ? 27 : 14,
                fontWeight: title.isEmpty
                    ? FontWeight.w800
                    : FontWeight.w500,
                height: title.isEmpty ? 1.1 : 1.3,
                letterSpacing:
                    title.isEmpty ? -0.5 : 0,
                color: title.isEmpty
                    ? colors.textPrimary
                    : colors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    // main pages use the large findr logo instead.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Transform.translate(
                offset: const Offset(-25, 0),
                child: const FindrLogo(
                  height: 125,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// back button used on pushed pages.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AppBackButton({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Tooltip(
      message: 'Back',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primaryStrong.withValues(
                alpha: 0.12,
              ),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ??
                () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 23,
                color: colors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// back button with text for pages where the destination should be clear.
class AppBackAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AppBackAction({
    super.key,
    this.label = 'Back',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.arrow_back_rounded,
        size: 19,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        backgroundColor: colors.surfaceSoft,
        disabledForegroundColor: colors.muted,
        disabledBackgroundColor: colors.backgroundAlt,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: colors.border,
          ),
        ),
      ),
    );
  }
}

// reusable circular icon button used around the app.
class AppCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface.withValues(
            alpha: 0.94,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.06,
              ),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 20,
              color: colors.textSecondary,
            ),

            // optional red dot used for unread items.
            if (showDot)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0415F),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.surface,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// shared card used for grouped content.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),

        // uses a border instead of a heavy shadow.
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: child,
    );
  }
}

// small label used above groups of content.
class AppSectionLabel extends StatelessWidget {
  final String text;

  const AppSectionLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 10,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// shared empty state used when a screen has no data to show.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final double height;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface.withValues(
                alpha: 0.82,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 38,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}