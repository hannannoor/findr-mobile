import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/firebase_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/location_picker.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:findr_application/widgets/report_photo_picker.dart';
import 'package:findr_application/theme/app_theme.dart';

// lets the report owner update the main fields of an existing report.
// ownership, creation time and workflow status are preserved automatically.
class EditReportScreen extends ConsumerStatefulWidget {
  final ItemReport report;

  const EditReportScreen({super.key, required this.report});

  @override
  ConsumerState<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends ConsumerState<EditReportScreen> {
  FindrColors get themeColors => FindrColors.of(context);

  final formKey = GlobalKey<FormState>();

  late final TextEditingController itemNameController;
  late final TextEditingController brandController;
  late final TextEditingController descriptionController;
  late final TextEditingController locationController;
  late final TextEditingController rewardController;

  late String reportType;
  late String category;
  late String colour;
  late String condition;
  late String base64Image;
  late String imagePath;
  late DateTime selectedDateTime;

  // The pin, so editing a report does not silently drop it off the map.
  double? latitude;
  double? longitude;

  bool isSaving = false;
  bool isPickingImage = false;

  final List<String> categoryOptions = [
    'Electronics',
    'Bags',
    'Bottles',
    'Accessories',
    'Stationery',
    'Other',
  ];

  final List<String> colourOptions = [
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

  final List<String> conditionOptions = [
    'New',
    'Like New',
    'Used',
    'Damaged',
    'Not Sure',
  ];

  @override
  void initState() {
    super.initState();

    final report = widget.report;

    itemNameController = TextEditingController(text: report.name);
    brandController = TextEditingController(text: report.brand);
    descriptionController = TextEditingController(text: report.description);
    locationController = TextEditingController(text: report.location);
    latitude = report.latitude;
    longitude = report.longitude;
    rewardController = TextEditingController(
      text: report.reward == null ? '' : report.reward!.toStringAsFixed(2),
    );

    reportType = report.reportType;
    category = report.category;
    colour = report.colour;
    condition = report.condition;
    base64Image = report.base64Image;
    imagePath = report.imagePath;
    selectedDateTime = report.dateLostFound;
  }

  @override
  void dispose() {
    itemNameController.dispose();
    brandController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    rewardController.dispose();
    super.dispose();
  }

  // keeps older/custom values usable even if they are not in the default list.
  List<String> optionsWithCurrent(List<String> options, String current) {
    final values = List<String>.from(options);

    if (current.isNotEmpty && !values.contains(current)) {
      values.insert(0, current);
    }

    return values;
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final earliestDate = DateTime(2020);
    final initialDate = selectedDateTime.isBefore(earliestDate)
        ? earliestDate
        : selectedDateTime.isAfter(now)
        ? now
        : selectedDateTime;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliestDate,
      lastDate: now,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDateTime.hour,
        selectedDateTime.minute,
      );
    });
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedDateTime = DateTime(
        selectedDateTime.year,
        selectedDateTime.month,
        selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> saveReport() async {
    if (isSaving || isPickingImage || !formKey.currentState!.validate()) {
      return;
    }

    if (selectedDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The lost or found time cannot be in the future.'),
        ),
      );
      return;
    }

    double? reward;
    if (reportType == 'Lost' && rewardController.text.trim().isNotEmpty) {
      reward = double.tryParse(rewardController.text.trim());
    }

    // the map only works if every report has a pin, so editing cannot
    // remove one.
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please drop a pin for where this happened'),
        ),
      );
      return;
    }

    final original = widget.report;
    final updatedReport = ItemReport(
      id: original.id,
      userId: original.userId,
      userEmail: original.userEmail,
      name: itemNameController.text.trim(),
      category: category,
      colour: colour,
      brand: brandController.text.trim(),
      condition: condition,
      description: descriptionController.text.trim(),
      location: locationController.text.trim(),
      latitude: latitude,
      longitude: longitude,
      reportType: reportType,
      reportStatus: original.reportStatus,
      dateLostFound: selectedDateTime,
      createdAt: original.createdAt,
      base64Image: base64Image,
      imagePath: imagePath,
      reward: reportType == 'Lost' ? reward : null,
    );

    setState(() {
      isSaving = true;
    });

    try {
      final FirebaseService firebaseService = ref.read(firebaseServiceProvider);

      await firebaseService.updateReport(updatedReport);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update the report. Please try again.'),
        ),
      );
    }
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
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeading(),
                            const SizedBox(height: 18),
                            buildTypeCard(),
                            const SizedBox(height: 14),
                            ReportPhotoPicker(
                              base64Image: base64Image,
                              imagePath: imagePath,
                              enabled: !isSaving,
                              onImageChanged: (value) {
                                setState(() {
                                  base64Image = value;
                                  imagePath = '';
                                });
                              },
                              onBusyChanged: (value) {
                                if (mounted && isPickingImage != value) {
                                  setState(() {
                                    isPickingImage = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            buildItemDetailsCard(),
                            const SizedBox(height: 14),
                            buildLocationCard(),
                            if (reportType == 'Lost') ...[
                              const SizedBox(height: 14),
                              buildRewardCard(),
                            ],
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  buildBottomButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            buildBackButton(),
            const SizedBox(width: 8),
            Expanded(
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: const FindrLogo(height: 105),
              ),
            ),
          ],
        ),
        Text(
          'Update your report details.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget buildBackButton() {
    return AppBackButton(
      onTap: isSaving || isPickingImage
          ? () {}
          : () => Navigator.of(context).pop(),
    );
  }

  Widget buildTypeCard() {
    return PostSectionCard(
      icon: Icons.assignment_outlined,
      title: 'Report Type',
      children: [
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
      ],
    );
  }

  Widget buildTypeButton(String type, IconData icon) {
    final selected = reportType == type;

    return GestureDetector(
      onTap: isSaving
          ? null
          : () {
              setState(() {
                reportType = type;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? themeColors.primary : themeColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? themeColors.primary : themeColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 25,
              color: selected ? Colors.white : Colors.grey[500],
            ),
            const SizedBox(height: 7),
            Text(
              type,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildItemDetailsCard() {
    final categories = optionsWithCurrent(categoryOptions, category);
    final colours = optionsWithCurrent(colourOptions, colour);
    final conditions = optionsWithCurrent(conditionOptions, condition);

    return PostSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Item Details',
      children: [
        postFieldLabel(context, 'Item Name', Icons.label_outline),
        const SizedBox(height: 6),
        TextFormField(
          controller: itemNameController,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(context, 'e.g., Blue Water Bottle'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter the item name'
              : null,
        ),
        const SizedBox(height: 14),
        postFieldLabel(context, 'Category', Icons.grid_view_rounded),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: category.isEmpty ? null : category,
          decoration: postFieldDecoration(context, ''),
          hint: const Text('Select category'),
          items: categories
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          validator: (value) => value == null || value.isEmpty
              ? 'Please select a category'
              : null,
          onChanged: isSaving
              ? null
              : (value) {
                  setState(() {
                    category = value ?? '';
                  });
                },
        ),
        const SizedBox(height: 14),
        postFieldLabel(context, 'Colour', Icons.palette_outlined),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: colour.isEmpty ? null : colour,
          decoration: postFieldDecoration(context, ''),
          hint: const Text('Select colour'),
          items: colours
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          validator: (value) =>
              value == null || value.isEmpty ? 'Please select a colour' : null,
          onChanged: isSaving
              ? null
              : (value) {
                  setState(() {
                    colour = value ?? '';
                  });
                },
        ),
        const SizedBox(height: 14),
        postFieldLabel(context, 'Brand (Optional)', Icons.business_outlined),
        const SizedBox(height: 6),
        TextFormField(
          controller: brandController,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(context, 'e.g., Apple, Casio'),
        ),
        const SizedBox(height: 14),
        postFieldLabel(
          context,
          'Condition (Optional)',
          Icons.fact_check_outlined,
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: condition.isEmpty ? null : condition,
          decoration: postFieldDecoration(context, ''),
          hint: const Text('Select condition'),
          items: conditions
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: isSaving
              ? null
              : (value) {
                  setState(() {
                    condition = value ?? '';
                  });
                },
        ),
        const SizedBox(height: 14),
        postFieldLabel(context, 'Description', Icons.description_outlined),
        const SizedBox(height: 6),
        TextFormField(
          controller: descriptionController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 4,
          maxLength: 250,
          decoration: postFieldDecoration(
            context,
            'Describe the item in detail...',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter a description'
              : null,
        ),
      ],
    );
  }

  Widget buildLocationCard() {
    return PostSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location & Date',
      children: [
        postFieldLabel(context, 'Location', Icons.location_on_outlined),
        const SizedBox(height: 6),
        TextFormField(
          controller: locationController,
          textCapitalization: TextCapitalization.words,
          decoration: postFieldDecoration(
            context,
            'Where was the item lost or found?',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter a location'
              : null,
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            postFieldLabel(context, 'Pin on Map', Icons.place_outlined),
            const SizedBox(width: 6),
            const Text(
              'required',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD94084),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        LocationPicker(
          initial: (latitude != null && longitude != null)
              ? LatLng(latitude!, longitude!)
              : null,
          onChanged: (point) {
            latitude = point.latitude;
            longitude = point.longitude;
          },
          onPlaceNamed: (name) {
            if (locationController.text.trim().isEmpty) {
              locationController.text = name;
            }
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  postFieldLabel(context, 'Date', Icons.calendar_today),
                  const SizedBox(height: 6),
                  buildPickerButton(
                    icon: Icons.calendar_today,
                    text: formatDate(selectedDateTime),
                    onTap: pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  postFieldLabel(context, 'Time', Icons.access_time),
                  const SizedBox(height: 6),
                  buildPickerButton(
                    icon: Icons.access_time,
                    text: formatTime(selectedDateTime),
                    onTap: pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildRewardCard() {
    return PostSectionCard(
      icon: Icons.card_giftcard,
      title: 'Reward',
      titleSuffix: '(Optional)',
      children: [
        postFieldLabel(context, 'Reward Amount', Icons.attach_money),
        const SizedBox(height: 6),
        TextFormField(
          controller: rewardController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: postFieldDecoration(
            context,
            'e.g., 20',
          ).copyWith(prefixText: '\$ '),
          validator: (value) {
            final text = value?.trim() ?? '';

            if (text.isEmpty) {
              return null;
            }

            final parsed = double.tryParse(text);
            if (parsed == null || !parsed.isFinite || parsed <= 0) {
              return 'Please enter a valid reward amount';
            }

            if (text.contains('.') && text.split('.').last.length > 2) {
              return 'Maximum 2 decimal places';
            }

            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Rewards only appear on lost reports.',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget buildPickerButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: themeColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: themeColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: themeColors.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: themeColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving || isPickingImage
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: themeColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving || isPickingImage ? null : saveReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9CC9FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: Text(
                isSaving
                    ? 'Saving...'
                    : isPickingImage
                    ? 'Processing...'
                    : 'Save Changes',
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

  String formatDate(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }

  String formatTime(DateTime value) {
    return TimeOfDay.fromDateTime(value).format(context);
  }
}
