String friendlyError(Object error) {
  if (error is FormatException) return error.message;
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  final text = error.toString();
  return text.replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
}
