import 'package:flutter/material.dart';
import 'package:findr_application/models/post_data.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:findr_application/screens/post/post_step3_screen.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_page.dart';

// second step of creating a report.
// this screen collects the item details like name, category, colour and description.
class PostStep2Screen extends StatefulWidget {
  final PostData data;

  const PostStep2Screen({super.key, required this.data});

  @override
  State<PostStep2Screen> createState() => _PostStep2ScreenState();
}

class _PostStep2ScreenState extends State<PostStep2Screen> {
  FindrColors get themeColors => FindrColors.of(context);

  final formKey = GlobalKey<FormState>();
  late String description;

  // dropdown options for category.
  // kept in a list so it is easier to reuse in the dropdown.
  final List<String> categories = [
    'Electronics',
    'Bags',
    'Bottles',
    'Accessories',
    'Stationery',
    'Other',
  ];

  // dropdown options for colour.
  // user can still choose other if the colour is not listed.
  final List<String> colours = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Pink',
    'Green',
    'Navy',
    'Grey',
    'Other',
  ];

  // condition is optional because a user may not know it exactly.
  final List<String> conditions = [
    'New',
    'Like New',
    'Used',
    'Damaged',
    'Not Sure',
  ];

  // sets the starting description from the saved post data.
  // this helps keep the text if the user goes back and returns to this page.
  @override
  void initState() {
    super.initState();
    description = widget.data.description;
  }

  // validates and saves the form before moving to step 3.
  // if required fields are missing, it stays on this screen.
  void next() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    formKey.currentState!.save();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostStep3Screen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
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
                          const PostStepper(currentStep: 1),
                          const SizedBox(height: 18),
                          buildContent(),
                        ],
                      ),
                    ),
                  ),
                  PostBottomButtons(
                    onBack: () {
                      Navigator.of(context).pop();
                    },
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

  // builds the top logo and subtitle for the post screens.
  // this keeps the create report pages matching the rest of the app.
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

  // builds the main form card for item details.
  // this is where the user enters the main info about the item.
  Widget buildContent() {
    return PostSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Item Details',
      children: [
        Text(
          'Tell us more about the item.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),

        const SizedBox(height: 18),

        Form(
          key: formKey,
          child: Column(
            children: [
              // item name field.
              postFieldLabel(context, 'Item Name', Icons.label_outline),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: widget.data.itemName,
                decoration: postFieldDecoration(
                  context,
                  'e.g., Blue Water Bottle',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the item name'
                    : null,
                onSaved: (v) {
                  widget.data.itemName = v!.trim();
                },
              ),

              const SizedBox(height: 14),

              // category dropdown.
              // this is required because it helps organise the report later.
              postFieldLabel(context, 'Category', Icons.grid_view_rounded),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: widget.data.category.isEmpty
                    ? null
                    : widget.data.category,
                hint: Text(
                  'Select category',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                decoration: postFieldDecoration(context, ''),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select a category' : null,
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  widget.data.category = v!;
                },
              ),

              const SizedBox(height: 14),

              // colour dropdown.
              // this is required so the item can be matched more easily later.
              postFieldLabel(context, 'Colour', Icons.palette_outlined),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: widget.data.colour.isEmpty ? null : widget.data.colour,
                hint: Text(
                  'Select colour',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                decoration: postFieldDecoration(context, ''),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select a colour' : null,
                items: colours
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  widget.data.colour = v!;
                },
              ),

              const SizedBox(height: 14),

              // optional brand helps users and the matching feature identify
              // similar items more accurately.
              postFieldLabel(
                context,
                'Brand (Optional)',
                Icons.business_outlined,
              ),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: widget.data.brand,
                textCapitalization: TextCapitalization.words,
                decoration: postFieldDecoration(context, 'e.g., Apple, Casio'),
                onSaved: (v) {
                  widget.data.brand = v?.trim() ?? '';
                },
              ),

              const SizedBox(height: 14),

              // optional condition is stored with the report and can later be
              // used by the AI matching score.
              postFieldLabel(
                context,
                'Condition (Optional)',
                Icons.fact_check_outlined,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: widget.data.condition.isEmpty
                    ? null
                    : widget.data.condition,
                hint: Text(
                  'Select condition',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                decoration: postFieldDecoration(context, ''),
                items: conditions
                    .map(
                      (condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(
                          condition,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    widget.data.condition = v ?? '';
                  });
                },
              ),

              const SizedBox(height: 14),

              // description field.
              // setState is used so the character counter updates while typing.
              postFieldLabel(
                context,
                'Description',
                Icons.description_outlined,
              ),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: description,
                maxLines: 3,
                maxLength: 250,
                decoration:
                    postFieldDecoration(
                      context,
                      'Describe your item in detail...',
                    ).copyWith(
                      counterText: '${description.length}/250',
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a description'
                    : null,
                onChanged: (v) {
                  setState(() {
                    description = v;
                  });
                },
                onSaved: (v) {
                  widget.data.description = v?.trim() ?? '';
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
