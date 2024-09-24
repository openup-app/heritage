import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

Future<XFile?> pickFile(String title) async {
  final result = await fp.FilePicker.platform.pickFiles(
    dialogTitle: title,
    allowMultiple: false,
  );
  final path = result?.files.first.path;
  if (path == null) {
    return null;
  }
  return XFile(path);
}

/// Capture a photo or pick from gallery, or fallback to a file picker.
Future<XFile?> pickPhoto(BuildContext context) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return pickFile('Pick a photo');
  }

  final source = await showDialog<ImageSource>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Pick a photo'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take new photo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            icon: const Icon(Icons.photo),
            label: const Text('Pick from Gallery'),
          ),
        ],
      );
    },
  );
  if (source == null) {
    return null;
  }

  final picker = ImagePicker();
  XFile? result;
  try {
    if (source == ImageSource.camera) {
      await Permission.camera.request();
    }
    result = await picker.pickImage(source: source);
  } on PlatformException catch (e) {
    if (e.code == 'camera_access_denied') {
      result = null;
    } else {
      rethrow;
    }
  }
  if (result == null) {
    return null;
  }

  return XFile(result.path);
}

Future<(Uint8List? bytes, Size size)> getFirstFrameAndSize(
    Uint8List image) async {
  final decodedImage = await decodeImageFromList(image);
  final byteData =
      await decodedImage.toByteData(format: ui.ImageByteFormat.png);
  decodedImage.dispose();
  return (
    byteData?.buffer.asUint8List(),
    Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
  );
}

Future<Uint8List?> downscaleImage(Uint8List image, {required int size}) async {
  final uiImage = await decodeImageFromList(image);
  final resized = await _downscaleImage(uiImage, size);
  return _encodeJpg(resized);
}

Future<ui.Image> _downscaleImage(ui.Image image, int size) async {
  if (max(image.width, image.height) < size) {
    return image;
  }

  final aspect = image.width / image.height;
  final int targetWidth;
  final int targetHeight;
  if (aspect < 1) {
    targetWidth = size;
    targetHeight = targetWidth ~/ aspect;
  } else {
    targetHeight = size;
    targetWidth = (targetHeight * aspect).toInt();
  }

  final pictureRecorder = ui.PictureRecorder();
  final canvas = ui.Canvas(pictureRecorder);
  canvas.drawImageRect(
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    Offset.zero & Size(targetWidth.toDouble(), targetHeight.toDouble()),
    Paint(),
  );

  final picture = pictureRecorder.endRecording();
  return picture.toImage(targetWidth, targetHeight);
}

Future<Uint8List?> _encodeJpg(ui.Image image, {int quality = 80}) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))
      ?.buffer
      .asUint8List();
  if (bytes == null) {
    return null;
  }

  final jpg = img.encodeJpg(
    img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    ),
    quality: quality,
  );
  return Uint8List.fromList(jpg);
}
