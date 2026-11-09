import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Opens the full-screen viewer for a product's photos, starting at
/// [initialIndex]. Used by the product list thumbnail and the detail strip.
void openProductPhotos(BuildContext context, Product product, {int initialIndex = 0}) {
  final app = context.read<AppState>();
  final urls = product.images.map((im) => app.imageUrl(im.url)).toList();
  if (urls.isEmpty) return;
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, __, ___) => PhotoViewer(
      urls: urls,
      initialIndex: initialIndex.clamp(0, urls.length - 1),
      code: product.code,
      title: product.name,
    ),
  ));
}

/// Full-screen, swipeable, pinch-to-zoom viewer with Share and Download.
class PhotoViewer extends StatefulWidget {
  /// Absolute URLs of the full-size pictures.
  final List<String> urls;
  final int initialIndex;
  /// Product code — names the saved file ("<code>_1.jpg").
  final String code;
  /// Product name — shown on top and sent as the share text.
  final String title;
  const PhotoViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    this.code = '',
    this.title = '',
  });
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _busy = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _act({required bool share}) async {
    if (_busy) return;
    final app = context.read<AppState>();
    final url = widget.urls[_index];
    setState(() => _busy = true);
    try {
      final bytes = await AuthedNetworkImage.bytesFor(app, url);
      if (bytes == null) {
        app.showToast(app.t('Could not load the picture'));
        return;
      }
      final name = AppState.pictureFileName(widget.code, url, _index);
      if (share) {
        await app.sharePicture(bytes, name,
            text: [widget.title, widget.code].where((s) => s.isNotEmpty).join(' · '));
      } else {
        await app.savePicture(bytes, name);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _roundButton(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white.withValues(alpha: onTap == null ? 0.4 : 1), size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: AuthedNetworkImage(url: widget.urls[i], fit: BoxFit.contain),
              ),
            ),
          ),
          // Top bar: title, then share / download / close.
          Positioned(
            top: top,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: widget.title.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    ),
                  )
                else ...[
                  _roundButton(Icons.share_outlined, () => _act(share: true), tooltip: context.tr('Share')),
                  const SizedBox(width: 10),
                  _roundButton(Icons.download_outlined, () => _act(share: false), tooltip: context.tr('Download')),
                ],
                const SizedBox(width: 10),
                _roundButton(Icons.close, () => Navigator.of(context).pop(), tooltip: context.tr('Close')),
              ],
            ),
          ),
          // Page indicator.
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
                  child: Text('${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
