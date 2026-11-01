import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ProfilePhotoService {
  static Future<String?> choosePhoto() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const FormatException(
        'Could not read that photo. Please choose another.',
      );
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 5 MB.');
    }

    return compute(_makeThumbnail, bytes);
  }
}

String _makeThumbnail(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);

  if (info == null || decoder == null) {
    throw const FormatException('Choose a valid JPG or PNG photo.');
  }

  if (info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 25000000) {
    throw const FormatException(
      'Choose a photo with a resolution below 25 megapixels.',
    );
  }

  final decoded = decoder.decodeFrame(0);
  if (decoded == null) {
    throw const FormatException('Could not open that photo.');
  }

  final upright = img.bakeOrientation(decoded);
  final thumbnail = img.copyResizeCropSquare(
    upright,
    size: 256,
    interpolation: img.Interpolation.average,
  );

  final encoded = base64Encode(img.encodeJpg(thumbnail, quality: 75));

  if (encoded.length > 100000) {
    throw const FormatException(
      'That photo is too detailed. Please choose another.',
    );
  }

  return encoded;
}
