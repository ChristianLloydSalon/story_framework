import 'dart:io';

import 'package:flutter/widgets.dart';

/// A provider for the image file at [path].
ImageProvider? fileImage(String path) => FileImage(File(path));
