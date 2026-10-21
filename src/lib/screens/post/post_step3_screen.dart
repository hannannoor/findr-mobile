import 'package:flutter/material.dart';
import 'package:findr_application/models/post_data.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:findr_application/screens/post/post_step4_screen.dart';
import 'package:findr_application/widgets/app_page.dart';
import 'package:findr_application/widgets/location_picker.dart';
import 'package:findr_application/theme/app_theme.dart';

// third step of creating a report.
// this screen collects location, date, time and reward if it is a lost item.
class PostStep3Screen extends StatefulWidget {
  final PostData data;

  const PostStep3Screen({super.key, required this.data});

  @override
  State<PostStep3Screen> createState() => _PostStep3ScreenState();
}

class _PostStep3ScreenState extends State<PostStep3Screen> {
  FindrColors get themeColors => FindrColors.of(context);

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

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

  // checks the location, date, time and reward before going to step 4.
  // also saves the selected date and time into the post data object.
  void next() {
    if (widget.data.location.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a location')));
      return;
    }

    // the pin is required, so the report can be placed on the campus map.
    if (!widget.data.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please drop a pin for where this happened'),
        ),
      );
      return;
    }

    // date is required so the report has a proper timeframe.
    if (selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    // time is required to make the report more accurate.
    if (selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a time')));
      return;
    }

    // checks reward amount only if the user typed something.
    final rewardText = widget.data.rewardAmount.trim();

    if (rewardText.isNotEmpty) {
      final parsed = double.tryParse(rewardText);

      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward must be a number greater than zero'),
          ),
        );
        return;
      }

      // reward can only have up to 2 decimal places.
      if (widget.data.rewardAmount.contains('.') &&
          widget.data.rewardAmount.split('.')[1].length > 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward can have maximum 2 decimal places'),
          ),
        );
        return;
      }
    }

    // combine the picked date and time into one DateTime so it can be saved
    // to firestore as a real timestamp instead of as text.
    final dateLostFound = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (dateLostFound.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The lost or found time cannot be in the future'),
        ),
      );
      return;
    }

    widget.data.date =
        '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';
    widget.data.time = selectedTime!.format(context);
    widget.data.dateLostFound = dateLostFound;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostStep4Screen(data: widget.data)),
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

            // main step 3 content goes above the background image.
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
                          const PostStepper(currentStep: 2),
                          const SizedBox(height: 18),
                          buildLocationCard(),

                          // reward card only shows for lost reports.
                          if (widget.data.reportType == 'Lost') ...[
                            const SizedBox(height: 14),
                            buildRewardCard(),
                          ],
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
  // repeated here to keep the page style same as the other post steps.
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

  // builds the location section.
  // user enters location and chooses the date and time.
  Widget buildLocationCard() {
    return PostSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location Details',
      children: [
        Text(
          'Where and when did it happen?',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),

        const SizedBox(height: 16),

        // location text field.
        postFieldLabel(context, 'Location', Icons.location_on_outlined),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey(widget.data.location),
          initialValue: widget.data.location,
          decoration: postFieldDecoration(context, 'Where did you lose it?')
              .copyWith(
                suffixIcon: Icon(
                  Icons.my_location,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
          onChanged: (v) {
            widget.data.location = v;
          },
        ),

        const SizedBox(height: 16),

        // the pin. required, so the report can appear on the campus map.
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
          initial: widget.data.hasLocation
              ? LatLng(widget.data.latitude!, widget.data.longitude!)
              : null,
          onChanged: (point) {
            widget.data.latitude = point.latitude;
            widget.data.longitude = point.longitude;
          },
          // picking a preset fills the text field in too, so the two stay
          // consistent without the user typing it twice.
          onPlaceNamed: (name) {
            if (widget.data.location.trim().isEmpty) {
              setState(() => widget.data.location = name);
            }
          },
        ),

        const SizedBox(height: 16),

        // date and time picker buttons side by side.
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
                  postFieldLabel(context, 'Time', Icons.access_time),
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
      ],
    );
  }

  // builds the optional reward section.
  // this only appears for lost items because found reports dont need reward.
  Widget buildRewardCard() {
    return PostSectionCard(
      icon: Icons.card_giftcard,
      title: 'Reward',
      titleSuffix: '(Optional)',
      children: [
        Text(
          'Offer a reward to increase chances of return.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),

        const SizedBox(height: 14),

        postFieldLabel(context, 'Reward Amount', Icons.attach_money),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: widget.data.rewardAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: postFieldDecoration(context, 'e.g., 20').copyWith(
            prefixText: '\$ ',
            prefixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: themeColors.textPrimary,
            ),
          ),
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              final parsed = double.tryParse(v);

              if (parsed == null || !parsed.isFinite || parsed <= 0) {
                return 'Please enter a number greater than zero';
              }

              // reward can only have up to 2 decimal places.
              if (v.contains('.') && v.split('.')[1].length > 2) {
                return 'Maximum 2 decimal places';
              }
            }

            return null;
          },
          onChanged: (v) {
            widget.data.rewardAmount = v;
          },
        ),

        const SizedBox(height: 6),

        Text(
          'Leave blank if no reward is offered.',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
            Icon(icon, size: 15, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isPlaceholder
                      ? Colors.grey[400]
                      : themeColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
