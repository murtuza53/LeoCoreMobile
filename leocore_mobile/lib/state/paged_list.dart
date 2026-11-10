import 'dart:async';

import '../api/api_client.dart';

/// One page from the server.
class PageResult<T> {
  final List<T> items;
  final bool hasMore;
  const PageResult(this.items, this.hasMore);
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(int page, int pageSize, String search);

/// A server-paged, server-searched list: infinite scroll on `hasMore`, search
/// sent to the server (debounced, back to page 1). Replies that arrive after a
/// newer search or refresh are ignored, so fast typing never shows stale rows.
class PagedList<T> {
  PagedList(this._fetch, {required this.onChanged, this.pageSize = 50, this.idOf});

  final PageFetcher<T> _fetch;
  final void Function() onChanged;
  final int pageSize;

  /// Drops rows already on screen when a later page repeats them (the data
  /// changed between pages).
  final Object Function(T)? idOf;

  List<T> items = const [];
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;
  bool loaded = false;
  String search = '';
  String? error;

  int _page = 0;
  int _gen = 0;
  Timer? _debounce;

  /// Loads page 1 (current search). Safe to call from build: it starts on the
  /// next event-loop turn.
  void ensureLoaded() {
    if (loaded || loading) return;
    loading = true; // block repeat calls from the same frame
    Timer.run(refresh);
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final gen = ++_gen;
    loading = true;
    loadingMore = false;
    error = null;
    onChanged();
    try {
      final r = await _fetch(1, pageSize, search.trim());
      if (gen != _gen) return;
      items = r.items;
      hasMore = r.hasMore;
      _page = 1;
      loaded = true;
    } on ApiException catch (e) {
      if (gen != _gen) return;
      error = e.message;
    } catch (_) {
      if (gen != _gen) return;
      error = 'Could not load the list. Pull down to try again.';
    }
    loading = false;
    onChanged();
  }

  Future<void> loadMore() async {
    if (!hasMore || loading || loadingMore) return;
    final gen = _gen;
    loadingMore = true;
    onChanged();
    try {
      final r = await _fetch(_page + 1, pageSize, search.trim());
      if (gen != _gen) return;
      final id = idOf;
      if (id == null) {
        items = [...items, ...r.items];
      } else {
        final seen = {for (final x in items) id(x)};
        items = [...items, ...r.items.where((x) => seen.add(id(x)))];
      }
      hasMore = r.hasMore;
      _page++;
    } catch (_) {
      if (gen != _gen) return;
      // Keep hasMore: scrolling to the end again retries.
    }
    loadingMore = false;
    onChanged();
  }

  /// What the user typed. The server search starts 300 ms after the last key.
  void setSearch(String v) {
    if (v == search) return;
    search = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
    onChanged();
  }

  /// Forget everything (sign-out, or switching filters that need a fresh list).
  void reset() {
    _gen++;
    _debounce?.cancel();
    items = const [];
    hasMore = false;
    loading = false;
    loadingMore = false;
    loaded = false;
    search = '';
    error = null;
    _page = 0;
  }
}
