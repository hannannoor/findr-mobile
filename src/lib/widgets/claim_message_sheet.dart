import 'package:flutter/material.dart';
import 'package:findr_application/theme/app_theme.dart';

// bottom sheet used to submit a claim message.
// it keeps its own text controller until the sheet is closed.
class ClaimMessageSheet extends StatefulWidget {
  // report type changes the wording shown to the user.
  final String reportType;

  const ClaimMessageSheet({
    super.key,
    required this.reportType,
  });

  @override
  State<ClaimMessageSheet> createState() =>
      _ClaimMessageSheetState();
}

class _ClaimMessageSheetState
    extends State<ClaimMessageSheet> {
  final TextEditingController controller =
      TextEditingController();

  final GlobalKey<FormState> formKey =
      GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // checks if the user is claiming a found report.
  bool get isFoundReport =>
      widget.reportType == 'Found';

  // validates the message and sends it back to the previous screen.
  void submit() {
    if (formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        controller.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return Padding(
      // moves the sheet above the keyboard while typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            18,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // small handle shown at the top of the sheet.
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  isFoundReport
                      ? 'Claim this item'
                      : 'I found this item',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  isFoundReport
                      ? 'Describe something about the item that only the real '
                          'owner would know. This helps the finder confirm '
                          'your claim.'
                      : 'Let the owner know where you found it and how you '
                          'can hand it over.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 300,
                  autofocus: true,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: isFoundReport
                        ? 'e.g. There is a blue sticker inside the lid and my '
                            'name is written on the base.'
                        : 'e.g. I picked it up near LT25 this morning, I can '
                            'pass it to you at the library.',
                    hintStyle:
                        const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: colors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().length < 10) {
                      return 'Please write at least 10 characters.';
                    }

                    return null;
                  },
                ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          colors.primary,
                      foregroundColor:
                          Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                    ),
                    child:
                        const Text('Submit claim'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}