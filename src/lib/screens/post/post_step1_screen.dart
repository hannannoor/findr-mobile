import 'package:flutter/material.dart';
import 'package:findr_application/models/post_data.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:findr_application/screens/post/post_step2_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// first step of creating a report.
// user chooses whether they are reporting a lost item or a found item.
class PostStep1Screen extends StatefulWidget {
  const PostStep1Screen({super.key});

  @override
  State<PostStep1Screen> createState() => _PostStep1ScreenState();
}

class _PostStep1ScreenState extends State<PostStep1Screen> {
  FindrColors get themeColors => FindrColors.of(context);

  // stores the report details as the user moves through the post steps.
  // it starts empty here because this is the first screen.
  final PostData data = PostData();

  // checks if user selected lost/found before going to step 2.
  // if nothing is selected, it shows a snackbar instead of continuing.
  void next() {
    if (data.reportType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Lost or Found')),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostStep2Screen(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      bottomNavigationBar: AppBottomNav(currentIndex: 2),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppPageBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHeading(),
                          const SizedBox(height: 16),
                          const PostStepper(currentStep: 0),
                          const SizedBox(height: 18),
                          buildContent(),
                        ],
                      ),
                    ),
                  ),
                  PostBottomButtons(
                    showBack: false,
                    onBack: () {},
                    onNext: next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // builds the top logo and subtitle for the post screen.
  // kept similar to the other screens so the app style stays consistent.
  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 115),
        ),
        Text(
          'Create a lost or found report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // builds the main card content for step 1.
  // this is where the user picks lost or found.
  Widget buildContent() {
    return PostSectionCard(
      icon: Icons.assignment_outlined,
      title: 'Choose Report Type',
      children: [
        Text(
          'What are you reporting?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: themeColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select whether your item is lost or found.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),

        // buttons for choosing lost or found report type.
        Row(
          children: [
            Expanded(
              child: buildTypeButton('Lost', Icons.work_outline_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: buildTypeButton('Found', Icons.inventory_2_outlined),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // small note to explain reward behaviour to the user.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeColors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reward is optional',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: themeColors.textPrimary,
                      ),
                    ),
                    Text(
                      'You can offer a reward for lost items only.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // reusable button for the lost/found selection.
  // it changes colour when selected so the user can see their choice clearly.
  Widget buildTypeButton(String type, IconData icon) {
    bool isSelected = data.reportType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          data.reportType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: isSelected ? themeColors.primary : themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? themeColors.primary : themeColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.white : Colors.grey[500],
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
