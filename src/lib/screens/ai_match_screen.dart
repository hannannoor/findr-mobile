import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/match_result.dart';
import 'package:findr_application/providers/applied_ai_provider.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/services/match_service.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/screens/ai_match_results_screen.dart';

enum _AiPhotoSource { camera, gallery }

// this screen collects the details of an item and scores them against the
// live reports in firestore using the matching algorithm in MatchService.
class AiMatchScreen extends ConsumerStatefulWidget {
  const AiMatchScreen({super.key});

  @override
  ConsumerState<AiMatchScreen> createState() => _AiMatchScreenState();
}

class _AiMatchScreenState extends ConsumerState<AiMatchScreen> {
  FindrColors get themeColors => FindrColors.of(context);
  // whether the user lost this item or found it.
  // it decides which side of the collection gets searched: a lost item is
  // matched against found reports and the other way round.
  String searchingFor = 'Lost';
  // form key is used to check if the required fields are filled in.
  var form = GlobalKey<FormState>();

  // stores the values from the form.
  // these values are only used for the ui flow for now.
  String category = '';
  String itemName = '';
  String brand = '';
  String model = '';
  String description = '';
  String location = '';
  String colour = '';
  String condition = '';
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final ImagePicker photoPicker = ImagePicker();
  final List<Uint8List> selectedPhotos = <Uint8List>[];
  bool isPickingPhotos = false;

  // category options for the dropdown.
  final List<String> categories = [
    'Earphones',
    'Electronics',
    'Bags',
    'Bottles',
    'Accessories',
    'Other',
  ];

  // colour options for the dropdown.
  final List<String> colours = [
    'White',
    'Black',
    'Red',
    'Blue',
    'Pink',
    'Green',
    'Other',
  ];

  // condition options for the dropdown.
  final List<String> conditions = ['New', 'Like New', 'Used', 'Damaged'];

  // opens the date picker so the user can choose when the item was lost/found.
  // the date cannot be in the future.
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // opens the time picker so the user can choose the rough time.
  // if the user cancels, nothing changes.
  Future<void> pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  // true while the language model is being consulted.
  bool isSearching = false;

  // Validates the form, scores every open report locally, then asks the
  // language model to re-rank whatever survived before showing the results.
  Future<void> search() async {
    if (isSearching) return;
    if (!form.currentState!.validate()) return;

    form.currentState!.save();

    // the stream is subscribed to in build(), so by the time the user has
    // filled the form the reports are already loaded and can be read here.
    final List<ItemReport> reports =
        ref.read(openReportsProvider).value ?? <ItemReport>[];

    DateTime? searchDate;
    if (selectedDate != null) {
      searchDate = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime?.hour ?? 12,
        selectedTime?.minute ?? 0,
      );
    }

    // Step one: the local weighted algorithm. This always runs, is instant,
    // and produces the explainable per-field score.
    final List<MatchResult> matches = MatchService().findMatches(
      reports: reports,
      searchingFor: searchingFor,
      itemName: itemName,
      category: category,
      colour: colour,
      brand: brand,
      condition: condition,
      description: description,
      location: location,
      date: searchDate,
    );

    // Step two: the language model looks at the shortlist and re-ranks it by
    // meaning. If no key is configured or the call fails, the local results
    // are shown unchanged, so the feature never depends on the network.
    final aiService = ref.read(appliedAIServiceProvider);
    bool usedAi = false;

    if (aiService.isConfigured && matches.isNotEmpty) {
      setState(() => isSearching = true);

      // Only the reports that survived local scoring are sent, which keeps
      // the prompt small and the response fast.
      final shortlist = reports
          .where((r) => matches.any((m) => m.reportId == r.id))
          .toList();

      final verdicts = await aiService.rankReports(
        searchingFor: searchingFor,
        itemName: itemName,
        category: category,
        colour: colour,
        brand: brand,
        description: description,
        location: location,
        candidates: shortlist,
      );

      if (!mounted) return;
      setState(() => isSearching = false);

      if (verdicts.isNotEmpty) {
        usedAi = true;

        for (final match in matches) {
          final verdict = verdicts[match.reportId];
          if (verdict == null) continue;

          match.aiConfidence = verdict.confidence;
          match.aiReason = verdict.reason;
        }

        // Reports the model rejected outright are dropped, and the rest are
        // ordered by the model's confidence first.
        matches.removeWhere(
          (m) => m.aiConfidence != null && m.aiConfidence! < 30,
        );

        matches.sort((a, b) {
          final int aScore = a.aiConfidence ?? a.matchPercent;
          final int bScore = b.aiConfidence ?? b.matchPercent;
          return bScore.compareTo(aScore);
        });

        // The best match badge is recalculated against the new order.
        for (final m in matches) {
          m.isBestMatch = false;
        }
        if (matches.isNotEmpty) {
          final int top =
              matches.first.aiConfidence ?? matches.first.matchPercent;
          if (top >= 70) matches.first.isBestMatch = true;
        }
      }
    }

    if (!mounted) return;

    // shown at the top of the results so the user can see what was searched.
    final List<List<String>> criteria = [
      if (itemName.isNotEmpty) ['Item Name', itemName],
      if (category.isNotEmpty) ['Category', category],
      if (colour.isNotEmpty) ['Colour', colour],
      if (brand.isNotEmpty) ['Brand', brand],
      if (condition.isNotEmpty) ['Condition', condition],
      if (location.isNotEmpty) ['Location', location],
      if (selectedPhotos.isNotEmpty)
        ['Reference Photos', '${selectedPhotos.length} attached'],
    ];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AiMatchResultsScreen(
          matches: matches,
          criteria: criteria,
          searchingFor: searchingFor,
          usedAi: usedAi,
          searchedCount: reports
              .where((r) => r.reportType != searchingFor)
              .length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watching here is what starts the stream. reading a stream provider
    // that nothing has subscribed to yet returns no value at all, which is
    // why searching used to report that there was nothing to compare with.
    final reportsAsync = ref.watch(openReportsProvider);
    final bool reportsReady = reportsAsync.hasValue;

    return Scaffold(
      backgroundColor: themeColors.backgroundAlt,
      bottomNavigationBar: const AppBottomNav(currentIndex: -1),
      body: Stack(
        children: [
          const AppPageBackground(),

          // main ai match form goes above the background image.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeading(),
                    const SizedBox(height: 18),
                    buildSearchTypeCard(),
                    const SizedBox(height: 14),
                    buildItemDetailsCard(),
                    const SizedBox(height: 14),
                    buildWhenWhereCard(),
                    const SizedBox(height: 14),
                    buildAdditionalDetailsCard(),
                    const SizedBox(height: 20),
                    buildSearchButton(reportsReady && !isSearching),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // lets the user say whether they lost or found the item, which flips
  // which half of the reports gets searched.
  Widget buildSearchTypeCard() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: themeColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          buildTypeOption('Lost', 'Lost Item', Icons.work_outline_rounded),
          buildTypeOption('Found', 'Found Item', Icons.inventory_2_outlined),
        ],
      ),
    );
  }

  Widget buildTypeOption(String value, String label, IconData icon) {
    final bool selected = searchingFor == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => searchingFor = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? themeColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: themeColors.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : themeColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : themeColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // builds the top logo and subtitle for the ai match page.
  // repeated here so the page matches the other findr screens.
  Widget buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: const FindrLogo(height: 125),
        ),
        Text(
          'AI powered item search.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: themeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // builds the item details section.
  // this collects the main item information for matching.
  Widget buildItemDetailsCard() {
    return buildSectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Item Details',
      children: [
        buildLabel('Category'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: category.isEmpty ? null : category,
          hint: Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'Select category',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
          decoration: buildInputDecoration(''),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }

            return null;
          },
          items: categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(cat, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              category = value!;
            });
          },
        ),

        const SizedBox(height: 16),

        buildLabel('Item Name'),
        const SizedBox(height: 6),
        TextFormField(
          decoration: buildInputDecoration('Enter item name'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the item name';
            }

            return null;
          },
          onSaved: (value) {
            itemName = value!.trim();
          },
        ),

        const SizedBox(height: 16),

        // brand and model are optional but can make the match more accurate.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabelWithOptional('Brand'),
                  const SizedBox(height: 6),
                  TextFormField(
                    decoration: buildInputDecoration('Enter brand'),
                    onSaved: (value) {
                      brand = value?.trim() ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabelWithOptional('Model'),
                  const SizedBox(height: 6),
                  TextFormField(
                    decoration: buildInputDecoration('Enter model'),
                    onSaved: (value) {
                      model = value?.trim() ?? '';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        buildLabel('Description'),
        const SizedBox(height: 6),
        buildDescriptionField(),
      ],
    );
  }

  // builds the description field.
  // the counter updates when the user types.
  Widget buildDescriptionField() {
    return TextFormField(
      maxLines: 3,
      maxLength: 200,
      decoration: buildInputDecoration('Describe your item in detail...')
          .copyWith(
            counterText: '${description.length}/200',
            counterStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a description';
        }

        return null;
      },
      onChanged: (value) {
        setState(() {
          description = value;
        });
      },
      onSaved: (value) {
        description = value?.trim() ?? '';
      },
    );
  }

  // builds the date, time and location section.
  // this helps match reports from similar places and timings.
  Widget buildWhenWhereCard() {
    return buildSectionCard(
      icon: Icons.location_on_outlined,
      title: 'When & Where',
      children: [
        // date and time picker buttons are side by side.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Date'),
                  const SizedBox(height: 6),
                  buildPickerButton(
                    icon: Icons.calendar_today,
                    text: selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Select date',
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
                  buildLabelWithOptional('Time'),
                  const SizedBox(height: 6),
                  buildPickerButton(
                    icon: Icons.access_time,
                    text: selectedTime != null
                        ? selectedTime!.format(context)
                        : 'Select time',
                    onTap: pickTime,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        buildLabel('Last Known Location'),
        const SizedBox(height: 6),
        TextFormField(
          decoration: buildInputDecoration('').copyWith(
            hintText:
                'Enter last known location (e.g., Central Library, Level 2)',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Colors.grey[400],
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the last known location';
            }

            return null;
          },
          onSaved: (value) {
            location = value?.trim() ?? '';
          },
        ),
      ],
    );
  }

  // builds the extra details section.
  // these fields are optional but can improve the match results.
  Widget buildAdditionalDetailsCard() {
    return buildSectionCard(
      icon: Icons.settings_outlined,
      title: 'Additional Details',
      children: [
        // colour and condition dropdowns are side by side to save space.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabelWithOptional('Colour'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: colour.isEmpty ? null : colour,
                    hint: Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Select colour',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                    decoration: buildInputDecoration(''),
                    items: colours.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        colour = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabelWithOptional('Condition'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: condition.isEmpty ? null : condition,
                    hint: Row(
                      children: [
                        Icon(Icons.adjust, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Select condition',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                    decoration: buildInputDecoration(''),
                    items: conditions.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        condition = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        buildLabelWithOptional('Add Photos'),
        const SizedBox(height: 6),
        buildPhotoUploadArea(),
      ],
    );
  }

  Future<void> showPhotoSourcePicker() async {
    if (isPickingPhotos || selectedPhotos.length >= 5) return;

    final colors = themeColors;
    final source = await showModalBottomSheet<_AiPhotoSource>(
      context: context,
      backgroundColor: colors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add reference photos',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose clear photos that help describe the item.',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoSourceButton(
                      context: sheetContext,
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      value: _AiPhotoSource.gallery,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPhotoSourceButton(
                      context: sheetContext,
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      value: _AiPhotoSource.camera,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    setState(() => isPickingPhotos = true);

    try {
      final List<XFile> pickedFiles;
      if (source == _AiPhotoSource.gallery) {
        pickedFiles = await photoPicker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 82,
        );
      } else {
        final image = await photoPicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 82,
        );
        pickedFiles = image == null ? <XFile>[] : <XFile>[image];
      }

      final remaining = 5 - selectedPhotos.length;
      final filesToAdd = pickedFiles.take(remaining);
      final bytes = await Future.wait(
        filesToAdd.map((file) => file.readAsBytes()),
      );

      if (!mounted) return;
      setState(() => selectedPhotos.addAll(bytes));

      if (pickedFiles.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 5 photos.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open photos. Check the app permission and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPickingPhotos = false);
    }
  }

  Widget _buildPhotoSourceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required _AiPhotoSource value,
  }) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pop(value),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: themeColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: themeColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget buildPhotoUploadArea() {
    if (selectedPhotos.isEmpty) {
      return InkWell(
        onTap: showPhotoSourcePicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: themeColors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColors.border, width: 1.5),
          ),
          child: Column(
            children: [
              if (isPickingPhotos)
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: themeColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 28,
                  color: themeColors.primary,
                ),
              const SizedBox(height: 6),
              Text(
                isPickingPhotos ? 'Adding photos...' : 'Tap to add photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: themeColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Camera or gallery · up to 5 photos',
                style: TextStyle(
                  fontSize: 11,
                  color: themeColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                selectedPhotos.length + (selectedPhotos.length < 5 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == selectedPhotos.length) {
                return InkWell(
                  onTap: showPhotoSourcePicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 78,
                    decoration: BoxDecoration(
                      color: themeColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColors.border),
                    ),
                    child: Icon(Icons.add_rounded, color: themeColors.primary),
                  ),
                );
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      selectedPhotos[index],
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.68),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            setState(() => selectedPhotos.removeAt(index)),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${selectedPhotos.length}/5 reference photos attached',
          style: TextStyle(
            color: themeColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // builds the ai search button at the bottom of the form.
  Widget buildSearchButton(bool ready) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        // disabled until the reports have arrived, so a search can never run
        // against an empty list and wrongly report no matches.
        onPressed: ready ? search : null,
        icon: ready
            ? const Icon(Icons.auto_awesome, size: 18)
            : const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
        label: Text(
          isSearching
              ? 'Asking the AI...'
              : ready
              ? 'AI Search'
              : 'Loading Reports...',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: themeColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // builds the white rounded section card.
  // this keeps all three form sections looking consistent.
  Widget buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: themeColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: themeColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: themeColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  // builds a small label above required fields.
  Widget buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  // builds a label with optional beside it.
  // this makes it clearer which fields the user can skip.
  Widget buildLabelWithOptional(String text) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(Optional)',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  // reusable picker button for date and time.
  // it looks like a text field but opens a picker when tapped.
  Widget buildPickerButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    bool isPlaceholder = text.startsWith('Select');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: themeColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isPlaceholder
                      ? Colors.grey[400]
                      : themeColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // keeps the text field style in one place.
  // this makes the fields look the same across the form.
  InputDecoration buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
      filled: true,
      fillColor: themeColors.surfaceSoft,
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
        borderSide: BorderSide(color: themeColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}
