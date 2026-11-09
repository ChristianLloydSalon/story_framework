import 'validation_issue.dart';

/// Base class for every error thrown by Story Framework.
///
/// Catch [StoryException] to handle any framework failure, or a subtype for a
/// specific one.
abstract class StoryException implements Exception {
  /// Creates an exception with a human-readable [message].
  const StoryException(this.message, {this.cause});

  /// A human-readable explanation.
  final String message;

  /// The underlying error, if this exception wraps another one.
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$suffix';
  }
}

/// A group, item, element, or asset with the requested id does not exist.
class StoryNotFoundException extends StoryException {
  /// Creates the exception for the missing [id].
  const StoryNotFoundException(this.id, String message, {super.cause})
      : super(message);

  /// The id that could not be found.
  final String id;
}

/// A story or source type is not supported by the current configuration.
class UnsupportedStoryTypeException extends StoryException {
  /// Creates the exception.
  const UnsupportedStoryTypeException(super.message, {super.cause});
}

/// An element type is not supported by the component handling it.
class UnsupportedElementException extends StoryException {
  /// Creates the exception for [elementType].
  const UnsupportedElementException(this.elementType, String message,
      {super.cause})
      : super(message);

  /// The serialization type of the unsupported element.
  final String elementType;
}

/// No renderer is registered for an element type.
class RendererNotRegisteredException extends StoryException {
  /// Creates the exception for [elementType].
  const RendererNotRegisteredException(this.elementType, String message,
      {super.cause})
      : super(message);

  /// The serialization type of the element that has no renderer.
  final String elementType;
}

/// A media resource failed to initialize.
class MediaInitializationException extends StoryException {
  /// Creates the exception.
  const MediaInitializationException(super.message, {super.cause});
}

/// Playback failed.
class PlaybackException extends StoryException {
  /// Creates the exception.
  const PlaybackException(super.message, {super.cause});
}

/// An editor operation could not be applied.
class EditorOperationException extends StoryException {
  /// Creates the exception.
  const EditorOperationException(super.message, {super.cause});
}

/// A document failed validation.
class InvalidCompositionException extends StoryException {
  /// Creates the exception with the validation [issues] that caused it.
  InvalidCompositionException(List<StoryValidationIssue> issues, {super.cause})
      : issues = List.unmodifiable(issues),
        super(_describe(issues));

  /// The issues that made the document invalid.
  final List<StoryValidationIssue> issues;

  static String _describe(List<StoryValidationIssue> issues) {
    final errors = issues.where((issue) => issue.isError).toList();
    if (errors.isEmpty) return 'Invalid composition';
    final first = errors.first;
    final more = errors.length > 1 ? ' and ${errors.length - 1} more' : '';
    return 'Invalid composition: ${first.message} at ${first.path}$more';
  }
}

/// A document could not be encoded or decoded.
class SerializationException extends StoryException {
  /// Creates the exception; [path] locates the failing value, if known.
  const SerializationException(super.message, {this.path, super.cause});

  /// Location of the failing value, such as `groups[0].items[1].duration`.
  final String? path;

  @override
  String toString() {
    final location = path == null ? '' : ' at $path';
    final suffix = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$location$suffix';
  }
}

/// Export failed.
class ExportException extends StoryException {
  /// Creates the exception.
  const ExportException(super.message, {super.cause});
}

/// A cache operation failed.
class CacheException extends StoryException {
  /// Creates the exception.
  const CacheException(super.message, {super.cause});
}

/// A configuration value is invalid.
class ConfigurationException extends StoryException {
  /// Creates the exception.
  const ConfigurationException(super.message, {super.cause});
}

/// A controller was used after it was disposed.
class ControllerDisposedException extends StoryException {
  /// Creates the exception for the controller named [controllerName].
  const ControllerDisposedException(this.controllerName)
      : super('$controllerName was used after being disposed');

  /// The type or name of the disposed controller.
  final String controllerName;
}
