import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/settings.dart';
import '../theme/tokens.dart';

/// The runner's photo, or their initial on the sunset gradient.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 96, this.shadow = true});
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final path = settings.photoPath;
    final name = settings.name.isEmpty ? 'ع' : settings.name;
    final hasPhoto = path != null && File(path).existsSync();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: Grad.sunset,
        shape: BoxShape.circle,
        image: hasPhoto ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover) : null,
        border: hasPhoto ? Border.all(color: Colors.white, width: size / 28) : null,
        boxShadow: shadow ? const [BoxShadow(color: Color(0x40F25C2C), blurRadius: 20, offset: Offset(0, 8))] : null,
      ),
      child: hasPhoto
          ? null
          : Text(name.characters.first, style: TextStyle(fontSize: size * .42, color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

/// Bottom sheet: camera / gallery / remove. The photo is copied into the app's folder.
Future<void> pickProfilePhoto(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('التقط صورة'), onTap: () => Navigator.pop(c, 'cam')),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('اختر من الصور'), onTap: () => Navigator.pop(c, 'gal')),
        if (settings.photoPath != null)
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('احذف الصورة'), onTap: () => Navigator.pop(c, 'del')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == null) return;
  if (choice == 'del') {
    await settings.setPhoto(null);
    return;
  }
  final x = await ImagePicker().pickImage(
    source: choice == 'cam' ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 600,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.front,
  );
  if (x == null) return;
  final dir = await getApplicationDocumentsDirectory();
  // New name each time so the image cache doesn't show the old photo.
  final dest = '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(x.path).copy(dest);
  final old = settings.photoPath;
  await settings.setPhoto(dest);
  if (old != null && old != dest) {
    try {
      await File(old).delete();
    } catch (_) {}
  }
}
