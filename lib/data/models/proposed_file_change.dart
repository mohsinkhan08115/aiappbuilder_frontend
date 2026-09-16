class ProposedFileChange {
  final String path;
  final String action; // create, modify, delete
  final String? originalContent;
  final String? proposedContent;

  ProposedFileChange({
    required this.path,
    required this.action,
    this.originalContent,
    this.proposedContent,
  });

  factory ProposedFileChange.fromJson(Map<String, dynamic> json) {
    return ProposedFileChange(
      path: json['path'] as String,
      action: json['action'] as String,
      originalContent: json['original_content'] as String?,
      proposedContent: json['proposed_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'action': action,
      'original_content': originalContent,
      'proposed_content': proposedContent,
    };
  }
}
