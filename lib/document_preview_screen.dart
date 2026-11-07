import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    super.key,
    this.title = 'Dart study notes',
    this.courseCode = 'CSCI 3101U',
    this.resourceType = 'Notes',
    this.uploader = 'Sample student',
    this.assetPath = 'assets/sample_notes.pdf',
    this.fileSizeLabel,
    this.likeCount,
    this.downloadCount,
    this.onLike,
    this.onDownload,
    this.onSetReminder,
  });

  final String title;
  final String courseCode;
  final String resourceType;
  final String uploader;
  final String assetPath;
  final String? fileSizeLabel;
  final int? likeCount;
  final int? downloadCount;
  final VoidCallback? onLike;
  final VoidCallback? onDownload;
  final VoidCallback? onSetReminder;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  final _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    setState(() {
      _pageCount = document.pages.length;
      _page = controller.pageNumber ?? 1;
    });
  }

  void _onPageChanged(int? page) {
    if (!mounted || page == null || page == _page) return;
    setState(() => _page = page);
  }

  void _goToPage(int page) {
    if (_controller.isReady) {
      _controller.goToPage(pageNumber: page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    const purple = Color(0xFF5B4CF5);
    const muted = Color(0xFF59667C);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: _expanded
          ? null
          : AppBar(
              title: const Text('Document preview'),
              backgroundColor: purple,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
      bottomNavigationBar: _expanded ? null : const _PreviewTabs(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight < 490 && !_expanded
                  ? 490
                  : constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_expanded) ...[
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.courseCode} | ${widget.resourceType}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'By ${widget.uploader}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      key: const ValueKey('pdf-preview'),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: colors.outlineVariant),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(
                              child: PdfViewer.asset(
                                widget.assetPath,
                                controller: _controller,
                                params: PdfViewerParams(
                                  backgroundColor: const Color(0xFFE8EDF4),
                                  onViewerReady: _onViewerReady,
                                  onPageChanged: _onPageChanged,
                                  errorBannerBuilder:
                                      (context, error, stack, ref) =>
                                          const Center(
                                            child: Text(
                                              'Unable to open this PDF.',
                                            ),
                                          ),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Previous page',
                                  onPressed: _pageCount > 0 && _page > 1
                                      ? () => _goToPage(_page - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Expanded(
                                  child: Text(
                                    _pageCount == 0
                                        ? 'PDF'
                                        : 'Page $_page of $_pageCount',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Next page',
                                  onPressed: _page < _pageCount
                                      ? () => _goToPage(_page + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                                IconButton(
                                  tooltip: _expanded
                                      ? 'Exit expanded view'
                                      : 'Expand PDF',
                                  onPressed: _toggleExpanded,
                                  icon: Icon(
                                    _expanded
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_expanded) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.fileSizeLabel == null
                            ? 'PDF'
                            : 'PDF | ${widget.fileSizeLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '♡  ${widget.likeCount ?? '—'} likes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                          Text(
                            '↓  ${widget.downloadCount ?? '—'} downloads',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onLike,
                              icon: const Icon(Icons.favorite_border),
                              label: const Text('Like'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: widget.onDownload,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download'),
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: widget.onSetReminder,
                          icon: const Icon(Icons.notifications_none),
                          label: const Text('Set study reminder'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewTabs extends StatelessWidget {
  const _PreviewTabs();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Courses',
                style: style?.copyWith(
                  color: const Color(0xFF5B4CF5),
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              Text('Saved', style: style),
              Text('Account', style: style),
            ],
          ),
        ),
      ),
    );
  }
}
