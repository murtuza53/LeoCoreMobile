// Attach Docs models (LeoCore 1.6.x). Look up a document by number, then
// attach files to it. Tolerant parsing — missing fields degrade gracefully.

int _i(dynamic v) => v is num ? v.toInt() : (v == null ? 0 : int.tryParse(v.toString()) ?? 0);
String _s(dynamic v) => v?.toString() ?? '';
bool _b(dynamic v) => v == true;

/// Result of `GET /documents/lookup?number=`.
class DocLookup {
  final bool found;
  final String docType;
  final int docId;
  final String docNumber;
  final String docTypeLabel;
  final String queried; // the number searched (for the not-found message)
  const DocLookup({
    this.found = false,
    this.docType = '',
    this.docId = 0,
    this.docNumber = '',
    this.docTypeLabel = '',
    this.queried = '',
  });

  factory DocLookup.fromJson(Map j) => DocLookup(
        found: _b(j['found']),
        docType: _s(j['docType']),
        docId: _i(j['docId']),
        docNumber: _s(j['docNumber']),
        docTypeLabel: _s(j['docTypeLabel']),
        queried: _s(j['number']),
      );
}

/// Result of `POST /documents/attach`.
class AttachResult {
  final bool success;
  final int attached;
  final String docType;
  final int docId;
  final String docNumber;
  final List<({String originalName, String fileName, int size})> files;
  final List<({String originalName, String message})> errors;
  const AttachResult({
    this.success = false,
    this.attached = 0,
    this.docType = '',
    this.docId = 0,
    this.docNumber = '',
    this.files = const [],
    this.errors = const [],
  });

  factory AttachResult.fromJson(Map j) => AttachResult(
        success: _b(j['success']),
        attached: _i(j['attached']),
        docType: _s(j['docType']),
        docId: _i(j['docId']),
        docNumber: _s(j['docNumber']),
        files: (j['files'] is List ? j['files'] as List : const [])
            .whereType<Map>()
            .map((m) => (originalName: _s(m['originalName']), fileName: _s(m['fileName']), size: _i(m['size'])))
            .toList(),
        errors: (j['errors'] is List ? j['errors'] as List : const [])
            .whereType<Map>()
            .map((m) => (originalName: _s(m['originalName']), message: _s(m['message'])))
            .toList(),
      );
}

/// One existing attachment on a document.
class DocAttachment {
  final int id;
  final String fileName;
  final int size;
  final String contentType;
  final String uploadedAt;
  final String uploadedBy;
  final String url;
  const DocAttachment({
    required this.id,
    required this.fileName,
    this.size = 0,
    this.contentType = '',
    this.uploadedAt = '',
    this.uploadedBy = '',
    this.url = '',
  });

  factory DocAttachment.fromJson(Map j) => DocAttachment(
        id: _i(j['id']),
        fileName: _s(j['fileName']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
        uploadedAt: _s(j['uploadedAt']),
        uploadedBy: _s(j['uploadedBy']),
        url: _s(j['url']),
      );

  bool get isImage => contentType.startsWith('image/') || RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(fileName);
  bool get isPdf => contentType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
}
