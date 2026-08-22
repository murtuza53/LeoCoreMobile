import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/documents.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Attach Docs (LeoCore 1.6.x) — two modes:
///  • Single: look up one document by number, attach photos / scans / files.
///  • By filename: pick many files whose names are document numbers
///    (e.g. CSI-2026-0053.pdf); matched files upload immediately, unmatched
///    ones let the user enter the number.
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
    final batch = app.docBatchMode;

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: context.tr('Attach documents'),
              subtitle: context.tr('Find a document, then attach files'),
              onBack: () => app.nav(Screen.more),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Segmented(
                options: [context.tr('One document'), context.tr('Match by name')],
                selected: batch ? 1 : 0,
                onSelect: (i) => app.setBatchMode(i == 1),
              ),
            ),
            Expanded(child: batch ? _buildBatch(context, app) : _buildSingle(context, app)),
          ],
        ),
        _buildStickyBar(context, app),
      ],
    );
  }

  // ── Single-document mode ────────────────────────────────────────────────
  Widget _buildSingle(BuildContext context, AppState app) {
    final lc = context.lc;
    final look = app.docLookup;
    final found = look?.found == true;

    if (!_numFocus.hasFocus && _num.text != app.docNumber) {
      _num.value = TextEditingValue(text: app.docNumber, selection: TextSelection.collapsed(offset: app.docNumber.length));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, found ? 120 : 24),
      children: [
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
            SizedBox(width: 110, child: PrimaryButton(context.tr('Look up'), height: 48, onTap: app.lookupDocument, busy: app.docLookupBusy)),
          ],
        ),
        const SizedBox(height: 12),
        if (look != null && !app.docLookupBusy) _resultBanner(context, look),
        if (found) ...[
          const SizedBox(height: 16),
          SectionLabel(context.tr('Add files')),
          const SizedBox(height: 10),
          Row(children: [
            _Source(Icons.document_scanner_outlined, context.tr('Scan'), () => _scan(context, app)),
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
          if (app.attachFiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('${context.tr('To upload')} (${app.attachFiles.length})'),
                if (app.attachHasImages)
                  GestureDetector(
                    onTap: app.attachCombineToPdf,
                    child: Text(context.tr('Combine to PDF'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: lc.tprim)),
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
          if (app.attachResult != null && app.attachResult!.errors.isNotEmpty)
            for (final e in app.attachResult!.errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${e.originalName}: ${e.message}', style: TextStyle(fontSize: 11.5, color: lc.bad)),
              ),
        ],
      ],
    );
  }

  Widget _resultBanner(BuildContext context, DocLookup look) {
    final lc = context.lc;
    final found = look.found;
    return Container(
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
    );
  }

  // ── Batch (match-by-filename) mode ──────────────────────────────────────
  Widget _buildBatch(BuildContext context, AppState app) {
    final lc = context.lc;
    final docs = app.batchDocs;
    final foundList = docs.where((d) => d.status != 'notfound').toList();
    final notFound = docs.where((d) => d.status == 'notfound').toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, docs.isEmpty ? 24 : 120),
      children: [
        Row(children: [
          _Source(Icons.folder_open_outlined, context.tr('Pick files'), app.pickBatchFiles),
          const SizedBox(width: 8),
          _Source(Icons.photo_library_outlined, context.tr('Gallery'), app.pickBatchFromGallery),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(context.tr('File names are matched to document numbers (e.g. CSI-2026-0053.pdf).'),
              style: TextStyle(fontSize: 11, color: lc.mut)),
        ),
        if (docs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(context.tr('Pick files to match by name.'), style: TextStyle(fontSize: 13.5, color: lc.mut))),
          ),
        if (foundList.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionLabel('${context.tr('Matched')} (${foundList.length})'),
          const SizedBox(height: 8),
          for (final d in foundList) _batchRow(context, app, d),
        ],
        if (notFound.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionLabel('${context.tr('Not matched')} (${notFound.length})'),
          const SizedBox(height: 8),
          for (final d in notFound) _batchNotFoundRow(context, app, d),
        ],
      ],
    );
  }

  Widget _batchRow(BuildContext context, AppState app, BatchDoc d) {
    final lc = context.lc;
    Widget trailing;
    switch (d.status) {
      case 'uploaded':
        trailing = Icon(Icons.cloud_done_outlined, size: 20, color: lc.ok);
        break;
      case 'uploading':
        trailing = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2));
        break;
      case 'checking':
        trailing = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: lc.mut));
        break;
      case 'error':
        trailing = GestureDetector(onTap: () => app.uploadBatchItem(d), child: Icon(Icons.refresh, size: 20, color: lc.bad));
        break;
      default: // found
        trailing = GestureDetector(
          onTap: () => app.uploadBatchItem(d),
          child: Icon(Icons.cloud_upload_outlined, size: 22, color: lc.tprim),
        );
    }
    return LcCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Icon(_iconFor(d.fileName), size: 20, color: lc.icon),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text(
                d.status == 'error' ? (d.message ?? context.tr('Upload failed')) : (d.lookup?.docTypeLabel ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: d.status == 'error' ? lc.bad : lc.ok),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
        GestureDetector(
          onTap: () => app.removeBatch(d),
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(Icons.close, size: 18, color: lc.mut)),
        ),
      ]),
    );
  }

  Widget _batchNotFoundRow(BuildContext context, AppState app, BatchDoc d) {
    final lc = context.lc;
    return LcCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_iconFor(d.fileName), size: 18, color: lc.icon),
            const SizedBox(width: 9),
            Expanded(child: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: lc.mut))),
            GestureDetector(
              onTap: () => app.removeBatch(d),
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close, size: 18, color: lc.mut),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: lc.bg, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(9)),
                child: Center(
                  child: TextFormField(
                    key: ValueKey('num_${d.path}'),
                    initialValue: d.number,
                    onChanged: (v) => app.setBatchNumber(d, v),
                    onFieldSubmitted: (_) => app.recheckBatch(d),
                    decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: context.tr('Enter document number')),
                    style: TextStyle(fontSize: 13.5, color: lc.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlineButton2(context.tr('Check'), height: 40, onTap: () => app.recheckBatch(d)),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Sticky action bar ───────────────────────────────────────────────────
  Widget _buildStickyBar(BuildContext context, AppState app) {
    final lc = context.lc;
    final show = app.docBatchMode ? app.batchFoundCount > 0 : (app.docLookup?.found == true);
    if (!show) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: lc.card, border: Border(top: BorderSide(color: lc.line))),
        child: app.docBatchMode
            ? PrimaryButton(
                '${context.tr('Upload matched')} (${app.batchFoundCount})',
                icon: Icons.cloud_upload_outlined,
                onTap: app.uploadAllFound,
                busy: app.batchBusy,
              )
            : PrimaryButton(
                app.attachFiles.isEmpty ? context.tr('Attach files') : '${context.tr('Attach')} ${app.attachFiles.length}',
                icon: Icons.cloud_upload_outlined,
                onTap: app.submitAttachments,
                busy: app.attachBusy,
              ),
      ),
    );
  }

  // ── Scan with proper camera-permission handling ─────────────────────────
  Future<void> _scan(BuildContext context, AppState app) async {
    final status = await app.ensureCameraPermission();
    if (status == 'granted') {
      await app.attachScanDocument();
      return;
    }
    if (!context.mounted) return;
    if (status == 'settings') {
      final lc = context.lc;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: lc.card,
          title: Text(context.tr('Camera access needed'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(context.tr('Turn on Camera for LeoCore ERP in Settings to scan documents.'),
              style: TextStyle(fontSize: 13.5, height: 1.5, color: lc.mut)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'), style: TextStyle(color: lc.mut))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Open Settings'), style: TextStyle(color: lc.tprim, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (go == true) await app.openAppPermissionSettings();
    } else {
      app.showToast(context.tr('Camera permission is required to scan'));
    }
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
          decoration: BoxDecoration(color: lc.card, border: Border.all(color: lc.line), borderRadius: BorderRadius.circular(12)),
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
