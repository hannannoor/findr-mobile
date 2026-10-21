import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// step indicator shown at the top of every post screen.
// currentStep starts from 0, so 0 means step 1.
class PostStepper extends StatelessWidget {
  final int currentStep;

  const PostStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    // labels for the four steps in the create report flow.
    List<String> labels = [
      'Choose type',
      'Item Details',
      'Location & Date',
      'Review & Submit',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // each step gets its own equal space.
          // this helps the label stay centered under the circle.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(labels.length, (i) {
              bool isCompleted = i < currentStep;
              bool isCurrent = i == currentStep;

              return Expanded(
                child: Column(
                  children: [
                    // builds the left line, circle and right line.
                    Row(
                      children: [
                        // left line is hidden for the first step.
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : (isCompleted || isCurrent
                                      ? colors.primary
                                      : colors.border),
                          ),
                        ),

                        // step circle shows either a number or check icon.
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCompleted || isCurrent
                                ? colors.primary
                                : colors.border,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                          ),
                        ),

                        // right line is hidden for the last step.
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == labels.length - 1
                                ? Colors.transparent
                                : (isCompleted
                                      ? colors.primary
                                      : colors.border),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // label sits under each step circle.
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? colors.textPrimary : colors.muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// white section card used in the post screens.
// it keeps each step looking consistent.
class PostSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? titleSuffix;
  final List<Widget> children;

  const PostSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.titleSuffix,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // card header with icon and title.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),

              // optional text beside the title, like "(Optional)".
              if (titleSuffix != null) ...[
                const SizedBox(width: 5),
                Text(
                  titleSuffix!,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// bottom buttons used on each post step.
// it shows back and next, or only next if showBack is false.
class PostBottomButtons extends StatelessWidget {
  final bool showBack;
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const PostBottomButtons({
    super.key,
    this.showBack = true,
    this.nextLabel = 'Next',
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // back button is hidden on the first step.
          if (showBack) Expanded(child: AppBackAction(onTap: onBack)),

          if (showBack) const SizedBox(width: 12),

          Expanded(
            flex: showBack ? 1 : 2,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: Text(
                nextLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// small icon and label used above post form fields.
// this keeps the form labels looking the same.
Widget postFieldLabel(BuildContext context, String text, IconData icon) {
  final FindrColors colors = FindrColors.of(context);

  return Row(
    children: [
      Icon(icon, size: 14, color: colors.primary),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    ],
  );
}

// keeps the post form field style in one place.
// used by the text fields across the create report steps.
InputDecoration postFieldDecoration(BuildContext context, String hint) {
  final FindrColors colors = FindrColors.of(context);

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 14, color: colors.muted),
    filled: true,
    fillColor: colors.surfaceSoft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1),
    ),
  );
}
