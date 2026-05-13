import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/index.dart';
import '../../utils/lang_ext.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../utils/timezone.dart';
import '../../widgets/news_links_widget.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _stateScrollController = ScrollController();
  final ScrollController _localScrollController = ScrollController();
  late final TabController _tabController;
  LanguageService? _languageService;

  // ── State news tab ─────────────────────────────────────────────────────────
  List<NewsItem> _stateItems = [];
  bool _isLoadingState = true;
  bool _isLoadingMoreState = false;
  String? _stateError;
  int _statePage = 1;
  int _stateTotalPages = 1;
  bool _stateHasMore = true;

  // ── Local news tab ─────────────────────────────────────────────────────────
  List<NewsItem> _localItems = [];
  bool _isLoadingLocal = false;
  bool _isLoadingMoreLocal = false;
  String? _localError;
  int _localPage = 1;
  int _localTotalPages = 1;
  bool _localHasMore = true;
  bool _localFetchStarted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _stateScrollController.addListener(_onStateScroll);
    _localScrollController.addListener(_onLocalScroll);
    _languageService = Provider.of<LanguageService>(context, listen: false);
    _languageService?.addListener(_onLanguageChanged);
    Provider.of<AuthService>(context, listen: false).addListener(_onAuthChanged);
    _fetchStateNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateScrollController.dispose();
    _localScrollController.dispose();
    _languageService?.removeListener(_onLanguageChanged);
    Provider.of<AuthService>(context, listen: false).removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging && !_localFetchStarted) {
      _fetchLocalNews();
    }
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    _resetAll();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_tabController.index == 1 && !_localFetchStarted) {
      _fetchLocalNews();
    }
  }

  void _onStateScroll() {
    if (_stateScrollController.position.pixels >= _stateScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreState && _stateHasMore) _loadMoreStateNews();
    }
  }

  void _onLocalScroll() {
    if (_localScrollController.position.pixels >= _localScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreLocal && _localHasMore) _loadMoreLocalNews();
    }
  }

  void _resetAll() {
    setState(() {
      _stateItems = [];
      _isLoadingState = true;
      _stateError = null;
      _statePage = 1;
      _stateTotalPages = 1;
      _stateHasMore = true;

      _localItems = [];
      _isLoadingLocal = false;
      _isLoadingMoreLocal = false;
      _localError = null;
      _localPage = 1;
      _localTotalPages = 1;
      _localHasMore = true;
      _localFetchStarted = false;
    });
    _fetchStateNews();
    if (_tabController.index == 1) _fetchLocalNews();
  }

  // ── State news ─────────────────────────────────────────────────────────────

  Future<void> _fetchStateNews({bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _isLoadingState = true;
        _stateError = null;
        _statePage = 1;
        _stateItems = [];
      });
    }

    final authToken = Provider.of<AuthService>(context, listen: false).accessToken;
    try {
      final result = await _apiService.getNews(page: _statePage, perPage: 20, authToken: authToken);
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final parsed = _parseNewsList(data['news']);
        final pages = data['pages'] as int? ?? 1;

        // Keep only items with no geographic restriction for the state tab
        final stateOnly = parsed.where((n) =>
          (n.districtIds == null || n.districtIds!.isEmpty) &&
          (n.mandalIds == null || n.mandalIds!.isEmpty) &&
          (n.assemblyConstituencyIds == null || n.assemblyConstituencyIds!.isEmpty) &&
          (n.parliamentaryConstituencyIds == null || n.parliamentaryConstituencyIds!.isEmpty),
        ).toList();

        setState(() {
          if (reset) {
            _stateItems = stateOnly;
          } else {
            _stateItems.addAll(stateOnly);
          }
          _stateTotalPages = pages;
          _stateHasMore = _statePage < _stateTotalPages;
          _isLoadingState = false;
          _isLoadingMoreState = false;
        });
      } else {
        setState(() {
          _stateError = result['message'] ?? 'Failed to load news';
          _isLoadingState = false;
          _isLoadingMoreState = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stateError = 'Network error: ${e.toString()}';
          _isLoadingState = false;
          _isLoadingMoreState = false;
        });
      }
    }
  }

  Future<void> _loadMoreStateNews() async {
    if (_isLoadingMoreState || !_stateHasMore) return;
    setState(() {
      _isLoadingMoreState = true;
      _statePage++;
    });
    await _fetchStateNews();
  }

  // ── Local news ─────────────────────────────────────────────────────────────

  Future<void> _fetchLocalNews({bool reset = false}) async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final authToken = authService.accessToken;

    // Need a valid token — the backend resolves location from DB automatically
    if (authToken == null) return;

    _localFetchStarted = true;

    if (reset) {
      setState(() {
        _isLoadingLocal = true;
        _localError = null;
        _localPage = 1;
        _localItems = [];
        _localHasMore = true;
      });
    } else if (!_isLoadingMoreLocal) {
      setState(() => _isLoadingLocal = _localItems.isEmpty);
    }

    try {
      final result = await _apiService.getLocalNews(
        page: _localPage,
        perPage: 20,
        authToken: authToken,
      );
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];

        // Log debug info from backend to help diagnose issues
        final debug = data['debug'];
        if (debug != null) {
          debugPrint('[LocalNews] backend debug: $debug');
        }

        final parsed = _parseNewsList(data['news']);
        final pages = data['pages'] as int? ?? 1;

        setState(() {
          if (reset) {
            _localItems = parsed;
          } else {
            _localItems.addAll(parsed);
          }
          _localTotalPages = pages;
          _localHasMore = _localPage < _localTotalPages;
          _isLoadingLocal = false;
          _isLoadingMoreLocal = false;
        });
      } else {
        setState(() {
          _localError = result['message'] ?? 'Failed to load local news';
          _isLoadingLocal = false;
          _isLoadingMoreLocal = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localError = 'Network error: ${e.toString()}';
          _isLoadingLocal = false;
          _isLoadingMoreLocal = false;
        });
      }
    }
  }

  Future<void> _loadMoreLocalNews() async {
    if (_isLoadingMoreLocal || !_localHasMore) return;
    setState(() {
      _isLoadingMoreLocal = true;
      _localPage++;
    });
    await _fetchLocalNews();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<NewsItem> _parseNewsList(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw.map((j) {
      try {
        return NewsItem.fromJson(j);
      } catch (e) {
        debugPrint('Error parsing news item: $e');
        return null;
      }
    }).whereType<NewsItem>().toList();
  }

  bool _matchesUser(NewsItem news, User user) {
    final hasLocationIds =
        (news.districtIds != null && news.districtIds!.isNotEmpty) ||
        (news.mandalIds != null && news.mandalIds!.isNotEmpty) ||
        (news.assemblyConstituencyIds != null && news.assemblyConstituencyIds!.isNotEmpty) ||
        (news.parliamentaryConstituencyIds != null && news.parliamentaryConstituencyIds!.isNotEmpty);

    if (!hasLocationIds) { return false; }

    if (user.districtId != null &&
        news.districtIds != null &&
        news.districtIds!.contains(user.districtId)) { return true; }

    if (user.mandalId != null &&
        news.mandalIds != null &&
        news.mandalIds!.contains(user.mandalId)) { return true; }

    if (user.assemblyConstituencyId != null &&
        news.assemblyConstituencyIds != null &&
        news.assemblyConstituencyIds!.contains(user.assemblyConstituencyId)) { return true; }

    if (user.parliamentConstituencyId != null &&
        news.parliamentaryConstituencyIds != null &&
        news.parliamentaryConstituencyIds!.contains(user.parliamentConstituencyId)) { return true; }

    return false;
  }

  String _formatNewsDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = getISTNow();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return context.lang == Language.en
            ? '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago'
            : '$minutes ${minutes == 1 ? 'నిమిషం' : 'నిమిషాల'} క్రితం';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return context.lang == Language.en
            ? '$hours ${hours == 1 ? 'hour' : 'hours'} ago'
            : '$hours ${hours == 1 ? 'గంట' : 'గంటల'} క్రితం';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return context.lang == Language.en
            ? '$days ${days == 1 ? 'day' : 'days'} ago'
            : '$days ${days == 1 ? 'రోజు' : 'రోజుల'} క్రితం';
      } else {
        final dateFormat = DateFormat('MMM d, yyyy', context.lang == Language.en ? 'en_US' : 'te_IN');
        return dateFormat.format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _getNewsTitle(NewsItem news) {
    final key = context.lang == Language.en ? 'en' : 'te';
    if (news.title[key]?.trim().isNotEmpty == true) return news.title[key]!.trim();
    if (news.title['en']?.trim().isNotEmpty == true) return news.title['en']!.trim();
    return 'Untitled News';
  }

  String _getNewsDescription(NewsItem news) {
    final key = context.lang == Language.en ? 'en' : 'te';
    if (news.description[key]?.trim().isNotEmpty == true) return news.description[key]!.trim();
    if (news.description['en']?.trim().isNotEmpty == true) return news.description['en']!.trim();
    return '';
  }

  String _getMatchedLocationName(NewsItem news, User user, Language lang) {
    if (user.districtId != null && (news.districtIds?.contains(user.districtId) ?? false)) {
      return lang == Language.te
          ? (user.districtRef?.nameTe.isNotEmpty == true ? user.districtRef!.nameTe : user.districtRef?.nameEn ?? user.district ?? '')
          : (user.districtRef?.nameEn ?? user.district ?? '');
    }
    if (user.mandalId != null && (news.mandalIds?.contains(user.mandalId) ?? false)) {
      return lang == Language.te
          ? (user.mandalRef?.nameTe.isNotEmpty == true ? user.mandalRef!.nameTe : user.mandalRef?.nameEn ?? user.mandal ?? '')
          : (user.mandalRef?.nameEn ?? user.mandal ?? '');
    }
    if (user.assemblyConstituencyId != null && (news.assemblyConstituencyIds?.contains(user.assemblyConstituencyId) ?? false)) {
      return lang == Language.te
          ? (user.assemblyConstituencyRef?.nameTe.isNotEmpty == true ? user.assemblyConstituencyRef!.nameTe : user.assemblyConstituencyRef?.nameEn ?? user.assemblyConstituency ?? '')
          : (user.assemblyConstituencyRef?.nameEn ?? user.assemblyConstituency ?? '');
    }
    if (user.parliamentConstituencyId != null && (news.parliamentaryConstituencyIds?.contains(user.parliamentConstituencyId) ?? false)) {
      return lang == Language.te
          ? (user.parliamentConstituencyRef?.nameTe.isNotEmpty == true ? user.parliamentConstituencyRef!.nameTe : user.parliamentConstituencyRef?.nameEn ?? user.parliamentConstituency ?? '')
          : (user.parliamentConstituencyRef?.nameEn ?? user.parliamentConstituency ?? '');
    }
    return '';
  }

  void _showNewsDialog(BuildContext context, NewsItem news) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.of(context).size;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final hasImage = news.image.isNotEmpty && news.image != 'null';

        return Consumer<LanguageService>(
          builder: (context, languageService, child) {
            final currentTitle = _getNewsTitle(news);
            final currentDescription = _getNewsDescription(news);
            final currentLang = languageService.language;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * 0.9,
                  maxWidth: screenSize.width * 0.95,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close, size: 24),
                              color: Colors.white,
                              padding: const EdgeInsets.all(8),
                              tooltip: currentLang == Language.en ? 'Close' : 'మూసివేయి',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  news.image,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context2, err, st) => Container(
                                    height: 200,
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    child: Center(child: Icon(Icons.article, size: 60, color: colorScheme.onPrimaryContainer)),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(child: Icon(Icons.article, size: 60, color: colorScheme.onPrimaryContainer)),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (news.category.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      news.category,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (news.links != null && news.links!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: NewsLinksWidget(links: news.links!),
                                  ),
                              ],
                            ),
                            Text(
                              currentTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 18, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  _formatNewsDate(news.date),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            if (currentDescription.isNotEmpty)
                              Text(
                                currentDescription,
                                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 16),
                              )
                            else
                              Text(
                                currentLang == Language.en ? 'No description available.' : 'వివరణ అందుబాటులో లేదు.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.outline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEn = context.lang == Language.en;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEn ? 'Latest News' : 'తాజా వార్తలు',
          style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.6),
          indicatorColor: colorScheme.onPrimary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: isEn ? 'State News' : 'రాష్ట్ర వార్తలు'),
            Tab(text: isEn ? 'Local News' : 'స్థానిక వార్తలు'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStateTab(isEn: isEn),
          _buildLocalTab(isEn: isEn),
        ],
      ),
    );
  }

  Widget _buildStateTab({required bool isEn}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingState && _stateItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stateError != null && _stateItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_stateError!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchStateNews(reset: true),
              child: Text(isEn ? 'Retry' : 'మళ్లీ ప్రయత్నించండి'),
            ),
          ],
        ),
      );
    }

    return _buildNewsList(
      items: _stateItems,
      scrollController: _stateScrollController,
      isLoadingMore: _isLoadingMoreState,
      emptyMessage: isEn ? 'No state news available' : 'రాష్ట్ర వార్తలు లేవు',
      onRefresh: () => _fetchStateNews(reset: true),
    );
  }

  Widget _buildLocalTab({required bool isEn}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingLocal && _localItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              isEn ? 'Loading local news...' : 'స్థానిక వార్తలు లోడ్ అవుతున్నాయి...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_localError != null && _localItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_localError!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchLocalNews(reset: true),
              child: Text(isEn ? 'Retry' : 'మళ్లీ ప్రయత్నించండి'),
            ),
          ],
        ),
      );
    }

    final user = Provider.of<AuthService>(context).currentUser;
    return _buildNewsList(
      items: _localItems,
      scrollController: _localScrollController,
      isLoadingMore: _isLoadingMoreLocal,
      emptyMessage: isEn ? 'No local news for your area' : 'మీ ప్రాంతానికి స్థానిక వార్తలు లేవు',
      onRefresh: () => _fetchLocalNews(reset: true),
      user: user,
    );
  }

  Widget _buildNewsList({
    required List<NewsItem> items,
    required ScrollController scrollController,
    required bool isLoadingMore,
    required String emptyMessage,
    required Future<void> Function() onRefresh,
    User? user,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (items.isEmpty && !isLoadingMore) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 64, color: colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(emptyMessage, style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final news = items[index];
          final title = _getNewsTitle(news);
          final description = _getNewsDescription(news);
          final hasImage = news.image.isNotEmpty && news.image != 'null';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _showNewsDialog(context, news),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        news.image,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context2, err, st) => Container(
                          height: 200,
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          child: Center(child: Icon(Icons.image_not_supported, size: 48, color: colorScheme.outline)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _formatNewsDate(news.date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 8),
                          Builder(builder: (_) {
                            final locationName = _getMatchedLocationName(news, user, context.lang);
                            if (locationName.isEmpty) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 13, color: AppColors.secondary),
                                const SizedBox(width: 3),
                                Text(
                                  locationName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                        if (news.links != null && news.links!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          NewsLinksWidget(links: news.links!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
