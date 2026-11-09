import 'package:meta/meta.dart';

import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';

/// The kind of media an asset holds.
enum StoryAssetType {
  /// A still or animated image.
  image,

  /// A video.
  video,

  /// An audio clip.
  audio,

  /// Anything else, such as a Lottie file or font.
  other,
}

/// A piece of media declared once in a document and referenced by id.
///
/// Elements point at assets with a [ReferenceStorySource]. This keeps a single
/// place to update media locations, for example after uploading a local file.
@immutable
final class StoryAsset {
  /// Creates an asset.
  ///
  /// [source] must be a concrete location: a [ReferenceStorySource] cannot
  /// point at another asset.
  StoryAsset({
    required this.id,
    required this.type,
    required this.source,
    this.mimeType,
    JsonMap metadata = const {},
  })  : assert(source is! ReferenceStorySource,
            'An asset cannot reference another asset'),
        metadata = freezeJsonMap(metadata, name: 'metadata');

  /// Unique id within the document.
  final String id;

  /// What kind of media this is.
  final StoryAssetType type;

  /// Where the media is loaded from.
  final StorySource source;

  /// MIME type such as `image/jpeg`, if known.
  final String? mimeType;

  /// Application-defined JSON-compatible data.
  final JsonMap metadata;

  /// Returns a copy with the given fields replaced.
  StoryAsset copyWith({
    String? id,
    StoryAssetType? type,
    StorySource? source,
    String? mimeType,
    JsonMap? metadata,
  }) {
    return StoryAsset(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      mimeType: mimeType ?? this.mimeType,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryAsset &&
      other.id == id &&
      other.type == type &&
      other.source == source &&
      other.mimeType == mimeType &&
      deepEquals(other.metadata, metadata);

  @override
  int get hashCode =>
      Object.hash(id, type, source, mimeType, deepHash(metadata));

  @override
  String toString() => 'StoryAsset($id, ${type.name}, $source)';
}
