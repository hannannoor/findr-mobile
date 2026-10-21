import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:findr_application/widgets/post_widgets.dart';
import 'package:findr_application/theme/app_theme.dart';

// shared photo picker used by both create report and edit report.
// keeping it in one widget makes the photo behaviour and styling consistent.
class ReportPhotoPicker extends StatefulWidget {
  final String base64Image;
  final String imagePath;
  final ValueChanged<String> onImageChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled;

  const ReportPhotoPicker({
    super.key,
    required this.base64Image,
    required this.onImageChanged,
    this.imagePath = '',
    this.onBusyChanged,
    this.enabled = true,
  });

  @override
  State<ReportPhotoPicker> createState() => _ReportPhotoPickerState();
}

class _ReportPhotoPickerState extends State<ReportPhotoPicker> {
  FindrColors get themeColors => FindrColors.of(context);

  // base64 makes an image around one third larger. this limit leaves room for
  // the other report fields inside firestore's one-document size limit.
  static const int maxBase64Length = 700000;

  final ImagePicker imagePicker = ImagePicker();

  Uint8List? imageBytes;
  bool isPicking = false;

  @override
  void initState() {
    super.initState();
    imageBytes = decodeCurrentImage(widget.base64Image);

    // android can close the activity while the native camera/gallery is open.
    // image_picker keeps that result so it can be recovered when flutter returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recoverLostImage();
    });
  }

  @override
  void didUpdateWidget(covariant ReportPhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.base64Image != widget.base64Image) {
      imageBytes = decodeCurrentImage(widget.base64Image);
    }
  }

  Uint8List? decodeCurrentImage(String value) {
    if (value.isEmpty) {
      return null;
    }

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> recoverLostImage() async {
    if (!widget.enabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    setPicking(true);

    try {
      final response = await imagePicker.retrieveLostData();

      if (!mounted || response.isEmpty) {
        return;
      }

      final files = response.files;
      if (files != null && files.isNotEmpty) {
        await usePickedImage(files.first);
      } else if (response.exception != null) {
        showMessage('Could not recover the selected photo. Please try again.');
      }
    } on PlatformException {
      showMessage('Could not recover the selected photo. Please try again.');
    } finally {
      setPicking(false);
    }
  }

  Future<void> showImageSourceSheet() async {
    if (!widget.enabled || isPicking) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: themeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Photo Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: buildSourceIcon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  subtitle: const Text('Recommended for the Android emulator'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: buildSourceIcon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  subtitle: const Text('Best when presenting on a real phone'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || source == null) {
      return;
    }

    await pickImage(source);
  }

  Widget buildSourceIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: themeColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: themeColors.primary),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    if (isPicking) {
      return;
    }

    setPicking(true);

    try {
      final file = await imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 65,
        requestFullMetadata: false,
      );

      // cancelling the native picker is normal and should not show an error.
      if (file == null) {
        return;
      }

      await usePickedImage(file);
    } on PlatformException {
      showMessage(
        'Could not access the photo. Check the app permission and try again.',
      );
    } catch (_) {
      showMessage('Could not process that photo. Please choose another one.');
    } finally {
      setPicking(false);
    }
  }

  Future<void> usePickedImage(XFile file) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('The selected image is empty.');
    }

    final encoded = base64Encode(bytes);
    if (encoded.length > maxBase64Length) {
      showMessage(
        'That photo is still too large after compression. '
        'Please choose a smaller photo.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      imageBytes = bytes;
    });
    widget.onImageChanged(encoded);
  }

  void removeImage() {
    if (!widget.enabled || isPicking) {
      return;
    }

    setState(() {
      imageBytes = null;
    });
    widget.onImageChanged('');
  }

  void setPicking(bool value) {
    if (!mounted || isPicking == value) {
      return;
    }

    setState(() {
      isPicking = value;
    });
    widget.onBusyChanged?.call(value);
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageBytes != null || widget.imagePath.isNotEmpty;

    return PostSectionCard(
      icon: Icons.image_outlined,
      title: 'Item Photo',
      titleSuffix: '(Optional)',
      children: [
        Text(
          'Add one clear photo to help others identify the item.',
          style: TextStyle(fontSize: 13, color: themeColors.textSecondary),
        ),
        const SizedBox(height: 14),
        if (hasPhoto) buildPhotoPreview() else buildEmptyPicker(),
        if (isPicking) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 3,
            color: themeColors.primary,
            backgroundColor: themeColors.surfaceSoft,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'The photo is resized and compressed automatically for Firestore.',
          style: TextStyle(fontSize: 10, color: themeColors.muted),
        ),
      ],
    );
  }

  Widget buildEmptyPicker() {
    return GestureDetector(
      onTap: widget.enabled && !isPicking ? showImageSourceSheet : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: themeColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: themeColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            if (isPicking)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 34,
                color: widget.enabled ? themeColors.primary : themeColors.muted,
              ),
            const SizedBox(height: 7),
            Text(
              isPicking ? 'Processing Photo...' : 'Add Photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: themeColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Choose from Gallery or Camera',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: themeColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPhotoPreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 210,
            child: imageBytes != null
                ? Image.memory(
                    imageBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        buildPhotoPlaceholder(),
                  )
                : Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        buildPhotoPlaceholder(),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.enabled && !isPicking
                    ? showImageSourceSheet
                    : null,
                icon: const Icon(Icons.sync, size: 17),
                label: const Text('Replace'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: themeColors.primary,
                  side: BorderSide(color: themeColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton.icon(
                onPressed: widget.enabled && !isPicking ? removeImage : null,
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE0415F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildPhotoPlaceholder() {
    return Container(
      color: themeColors.surfaceSoft,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: 44,
        color: themeColors.muted,
      ),
    );
  }
}
