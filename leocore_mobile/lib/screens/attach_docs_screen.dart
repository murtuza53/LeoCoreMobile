import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Attach Docs (LeoCore 1.6.x) — look up a document by number, then attach
/// photos / scans / files from the phone, storage or cloud.
class AttachDocsScreen extends StatefulWidget {
  const AttachDocsScreen({super.key});
  @override
  State<AttachDocsScreen> createState() => _AttachDocsScreenState();
}

class _AttachDocsScreenState extends State<AttachDocsScreen> {
  late final TextEditingController _num;
  final _numFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _num = TextEditingController(text: context.read<AppState>().docNumber);
  }

  @override
  void dispose() {
    _num.dispose();
    _numFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lc = context.lc;
    final look = app.docLookup;
    final found = look?.found == true;

    if (!_numFocus.hasFocus && _num.text != app.docNumber) {
      _num.value = TextEditingValue(text: app.docNumber, selection: TextSelection.collapsed(offset: app.docNumber.length));
    }

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Attach documents'),
              subtitle: context.tr('Find a document, then attach files'),
              onBack: () => app.nav(Screen.more),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, found ? 120 : 24),
                children: [
                  // Document number + look up
                  Text(context.tr('Document number'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: lc.mut)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: lc.bg, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Icon(Icons.tag, size: 18, color: lc.icon),
                            const SizedBox(width: 9),
                            Expanded(
                              child: TextField(
                                controller: _num,
                                focusNode: _numFocus,
                                onChanged: app.setDocNumber,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => app.lookupDocument(),
                                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'INV-2026-0001'),
                                style: TextStyle(fontSize: 15, color: lc.ink),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: PrimaryButton(context.tr('Look up'), height: 48, onTap: app.lookupDocument, busy: app.docLookupBusy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lookup result
                  if (look != null && !app.docLookupBusy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: found ? lc.okbg : lc.badbg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: found ? lc.ok.withValues(alpha: 0.4) : lc.bad.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Icon(found ? Icons.check_circle_outline : Icons.error_outline, size: 20, color: found ? lc.ok : lc.bad),
                        const SizedBox(width: 10),
                        Expanded(
                          child: found
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(look.docTypeLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: lc.ok)),
                                    Text(look.docNumber, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                                  ],
                                )
                              : Text('${context.tr('Document not found')}${look.queried.isNotEmpty ? ' · ${look.queried}' : ''}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lc.bad)),
                        ),
                      ]),
                    ),

                  // Add-files sources (only once a document is confirmed)
                  if (found) ...[
                    const SizedBox(height: 16),
                    SectionLabel(context.tr('Add files')),
                    const SizedBox(height: 10),
                    Row(children: [
                      _Source(Icons.document_scanner_outlined, context.tr('Scan'), app.attachScanDocument),
                      const SizedBox(width: 8),
                      _Source(Icons.photo_camera_outlined, context.tr('Photo'), app.attachTakePhoto),
                      const SizedBox(width: 8),
                      _Source(Icons.photo_library_outlined, context.tr('Gallery'), app.attachFromGallery),
                      const SizedBox(width: 8),
                      _Source(Icons.folder_open_outlined, context.tr('Files'), app.attachPickFiles),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(context.tr('Scan applies auto edge, skew and colour correction, and makes a multi-page PDF.'),
                          style: TextStyle(fontSize: 11, color: lc.mut)),
                    ),

                    // Staged files
                    if (app.attachFiles.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionLabel('${context.tr('To upload')} (${app.attachFiles.length})'),
                          if (app.attachHasImages)
                            GestureDetector(
                              onTap: app.attachCombineToPdf,
                              child: Text(context.tr('Combine to PDF'),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: lc.tprim)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final f in app.attachFiles)
                        LcCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Icon(_iconFor(f.name), size: 20, color: lc.icon),
                            const SizedBox(width: 11),
                            Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            GestureDetector(
                              onTap: () => app.removeAttachFile(f.path),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 18, color: lc.mut)),
                            ),
                          ]),
                        ),
                    ],

                    // Result / errors from the last upload
                    if (app.attachResult != null && app.attachResult!.errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final e in app.attachResult!.errors)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('${e.originalName}: ${e.message}', style: TextStyle(fontSize: 11.5, color: lc.bad)),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
        if (found)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(color: lc.card, border: Border(top: BorderSide(color: lc.line))),
              child: PrimaryButton(
                app.attachFiles.isEmpty ? context.tr('Attach files') : '${context.tr('Attach')} ${app.attachFiles.length}',
                icon: Icons.cloud_upload_outlined,
                onTap: app.submitAttachments,
                busy: app.attachBusy,
              ),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (RegExp(r'\.(jpe?g|png|gif|webp|heic)$').hasMatch(n)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _Source extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Source(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    final lc = context.lc;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: lc.card,
            border: Border.all(color: lc.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: lc.icon),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lc.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
