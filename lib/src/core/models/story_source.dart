import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../utilities/json.dart';

/// Where a piece of media comes from.
///
/// Sources are descriptions, not live resources: they never hold open
/// connections, decoders, or controllers. Media integrations resolve them.
///
/// Authentication is intentionally not part of a source. Request headers and
/// credentials belong to the host application's media configuration so they
/// are never written into serialized documents or logs.
@immutable
sealed class StorySource {
  const StorySource();

  /// Whether this source can be written into a serialized document.
  bool get isSerializable => true;
}

/// Media loaded over HTTP(S).
final class NetworkStorySource extends StorySource {
  /// Creates a source for [url].
  const NetworkStorySource(this.url);

  /// The media URL.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is NetworkStorySource && other.url == url;

  @override
  int get hashCode => url.hashCode;

  /// Omits the query and fragment so signed URLs are not leaked into logs.
  @override
  String toString() =>
      'NetworkStorySource(${url.scheme}://${url.authority}${url.path})';
}

/// Media stored in a file on the device.
final class FileStorySource extends StorySource {
  /// Creates a source for the file at [path].
  const FileStorySource(this.path);

  /// Absolute or app-relative file path.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is FileStorySource && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'FileStorySource($path)';
}

/// Media bundled as a Flutter asset.
final class AssetStorySource extends StorySource {
  /// Creates a source for the asset [name], optionally from [package].
  const AssetStorySource(this.name, {this.package});

  /// Asset key, such as `assets/intro.png`.
  final String name;

  /// The package that bundles the asset, if not the application.
  final String? package;

  @override
  bool operator ==(Object other) =>
      other is AssetStorySource &&
      other.name == name &&
      other.package == package;

  @override
  int get hashCode => Object.hash(name, package);

  @override
  String toString() =>
      'AssetStorySource($name${package == null ? '' : ', package: $package'})';
}

/// Media held in memory.
///
/// Serialized as base64. Prefer a file or network source for large media.
final class MemoryStorySource extends StorySource {
  /// Creates a source over [bytes].
  MemoryStorySource(Uint8List bytes, {this.mimeType})
      : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  /// The encoded media bytes (read-only).
  final Uint8List bytes;

  /// MIME type such as `image/png`, if known.
  final String? mimeType;

  @override
  bool operator ==(Object other) =>
      other is MemoryStorySource &&
      other.mimeType == mimeType &&
      deepEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(mimeType, bytes.length);

  @override
  String toString() =>
      'MemoryStorySource(${bytes.length} bytes${mimeType == null ? '' : ', $mimeType'})';
}

/// Media produced by a byte stream at runtime.
///
/// Stream sources are runtime-only and cannot be serialized; persist the media
/// to a file or upload it, then reference that instead.
final class StreamStorySource extends StorySource {
  /// Creates a source; [open] is called each time the media is (re)loaded.
  const StreamStorySource(this.open, {this.mimeType});

  /// Opens a fresh stream of the media bytes.
  final Stream<List<int>> Function() open;

  /// MIME type such as `video/mp4`, if known.
  final String? mimeType;

  @override
  bool get isSerializable => false;

  @override
  String toString() => 'StreamStorySource(${mimeType ?? 'unknown type'})';
}

/// An application-defined source resolved by a custom media provider.
final class CustomStorySource extends StorySource {
  /// Creates a custom source of [type] with JSON-compatible [data].
  CustomStorySource(this.type, {JsonMap data = const {}})
      : data = freezeJsonMap(data, name: 'data');

  /// Identifier the media provider uses to recognize this source.
  final String type;

  /// Provider-specific JSON-compatible data.
  final JsonMap data;

  @override
  bool operator ==(Object other) =>
      other is CustomStorySource &&
      other.type == type &&
      deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(type, deepHash(data));

  @override
  String toString() => 'CustomStorySource($type)';
}

/// A reference to an asset declared in the document's asset table.
///
/// Lets many elements share one piece of media and lets applications swap the
/// underlying location (for example after an upload) in a single place.
final class ReferenceStorySource extends StorySource {
  /// Creates a reference to the asset with [assetId].
  const ReferenceStorySource(this.assetId);

  /// The id of the referenced document asset.
  final String assetId;

  @override
  bool operator ==(Object other) =>
      other is ReferenceStorySource && other.assetId == assetId;

  @override
  int get hashCode => assetId.hashCode;

  @override
  String toString() => 'ReferenceStorySource($assetId)';
}
