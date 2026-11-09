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
  final bool canAttach;
  final bool canDelete;

  /// Files already on the document, newest first. Null on servers before
  /// 1.6.52, which don't return the list (hide view/delete then).
  final List<DocAttachment>? attachments;
  const DocLookup({
    this.found = false,
    this.docType = '',
    this.docId = 0,
    this.docNumber = '',
    this.docTypeLabel = '',
    this.queried = '',
    this.canAttach = true,
    this.canDelete = false,
    this.attachments,
  });

  factory DocLookup.fromJson(Map j) => DocLookup(
        found: _b(j['found']),
        docType: _s(j['docType']),
        docId: _i(j['docId']),
        docNumber: _s(j['docNumber']),
        docTypeLabel: _s(j['docTypeLabel']),
        queried: _s(j['number']),
        // Older servers don't send the flags: attaching was always allowed.
        canAttach: j.containsKey('canAttach') ? _b(j['canAttach']) : true,
        canDelete: _b(j['canDelete']),
        attachments: parseAttachments(j['attachments']),
      );
}

/// Parses an `attachments` array; null when the key is missing.
List<DocAttachment>? parseAttachments(dynamic v) =>
    v is List ? v.whereType<Map>().map(DocAttachment.fromJson).toList() : null;

/// Result of `POST /documents/attach`.
class AttachResult {
  final bool success;
  final int attached;
  final String docType;
  final int docId;
  final String docNumber;
  final List<({String originalName, String fileName, int size})> files;
  final List<({String originalName, String message})> errors;

  /// The document's full attachment list after the upload (1.6.52+).
  final List<DocAttachment>? attachments;
  const AttachResult({
    this.success = false,
    this.attached = 0,
    this.docType = '',
    this.docId = 0,
    this.docNumber = '',
    this.files = const [],
    this.errors = const [],
    this.attachments,
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
        attachments: parseAttachments(j['attachments']),
      );
}

/// A file being matched to a document by its filename in the bulk-attach flow.
/// Mutable: its lookup/status update as the number is checked and uploaded.
class BatchDoc {
  final String path;
  final String fileName;
  String number; // derived from the filename, editable when not found
  DocLookup? lookup;
  String status; // checking | found | notfound | uploading | uploaded | error
  String? message;
  BatchDoc(this.path, this.fileName, this.number, {this.status = 'checking'});

  bool get found => lookup?.found == true;
}

/// One existing attachment on a document (1.6.52 shape). `url` /
/// `downloadUrl` are root-relative and need the Bearer header.
class DocAttachment {
  final int id;
  final String fileName;
  final int size;
  final String contentType;
  final DateTime? uploadedAt; // local time
  final String uploadedBy;
  final String url;
  final String downloadUrl;
  final bool _isImage;
  final bool _isPdf;
  const DocAttachment({
    required this.id,
    required this.fileName,
    this.size = 0,
    this.contentType = '',
    this.uploadedAt,
    this.uploadedBy = '',
    this.url = '',
    this.downloadUrl = '',
    bool isImage = false,
    bool isPdf = false,
  })  : _isImage = isImage,
        _isPdf = isPdf;

  factory DocAttachment.fromJson(Map j) => DocAttachment(
        id: _i(j['id']),
        fileName: _s(j['fileName']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
        // Server sends UTC ("…Z"); show it in the phone's time zone.
        uploadedAt: DateTime.tryParse(_s(j['uploadedAt']))?.toLocal(),
        uploadedBy: _s(j['uploadedBy']),
        url: _s(j['url']),
        downloadUrl: _s(j['downloadUrl']),
        isImage: _b(j['isImage']),
        isPdf: _b(j['isPdf']),
      );

  bool get isImage =>
      _isImage || contentType.startsWith('image/') || RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(fileName);
  bool get isPdf => _isPdf || contentType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');

  /// MIME type for opening / sharing the file.
  String get mime => contentType.isNotEmpty ? contentType : (isPdf ? 'application/pdf' : 'application/octet-stream');
}
