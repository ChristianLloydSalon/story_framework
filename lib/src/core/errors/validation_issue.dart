import 'package:meta/meta.dart';

/// How serious a validation issue is.
enum StoryValidationSeverity {
  /// The document cannot be played, rendered, or exported reliably.
  error,

  /// The document works but is probably not what the author intended.
  warning,
}

/// A single problem found while validating a story document.
@immutable
final class StoryValidationIssue {
  /// Creates an issue.
  const StoryValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    required this.path,
  });

  /// Creates an error-level issue.
  const StoryValidationIssue.error(this.code, this.message,
      {required this.path})
      : severity = StoryValidationSeverity.error;

  /// Creates a warning-level issue.
  const StoryValidationIssue.warning(
    this.code,
    this.message, {
    required this.path,
  }) : severity = StoryValidationSeverity.warning;

  /// How serious the issue is.
  final StoryValidationSeverity severity;

  /// A stable, machine-readable identifier such as `duplicate_id`.
  final String code;

  /// A human-readable explanation.
  final String message;

  /// Location in the document, such as `groups[0].items[2].elements[1]`.
  final String path;

  /// Whether this issue is an error.
  bool get isError => severity == StoryValidationSeverity.error;

  @override
  bool operator ==(Object other) =>
      other is StoryValidationIssue &&
      other.severity == severity &&
      other.code == code &&
      other.message == message &&
      other.path == path;

  @override
  int get hashCode => Object.hash(severity, code, message, path);

  @override
  String toString() => '[${severity.name}] $code at $path: $message';
}
