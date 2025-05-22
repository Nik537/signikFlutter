enum SignikDocumentStatus {
  unsigned,
  signed,
  error,
}

class SignikDocument {
  final String name;
  final String path;
  final SignikDocumentStatus status;

  SignikDocument({required this.name, required this.path, required this.status});
} 