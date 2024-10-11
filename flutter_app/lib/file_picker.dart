import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

Future<XFile?> pickFile(String title) async {
  final imagePicker = ImagePicker();
  final result = await imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1000,
    maxHeight: 1000,
  );
  return result;
}

Future<(Uint8List? bytes, Size size)> getFirstFrameAndSize(
    Uint8List image) async {
  final decodedImage = await decodeImageFromList(image);
  print(
      'SIZE is ${decodedImage.width.toDouble()}, ${decodedImage.height.toDouble()}');
  final byteData =
      await decodedImage.toByteData(format: ui.ImageByteFormat.png);
  // Disposing decodedImage here throws "This image has been disposed" on web
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
    targetHeight = size;
    targetWidth = (targetHeight * aspect).toInt();
  } else {
    targetWidth = size;
    targetHeight = (targetWidth / aspect).toInt();
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
