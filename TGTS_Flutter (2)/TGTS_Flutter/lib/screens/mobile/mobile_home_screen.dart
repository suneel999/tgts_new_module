import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../models/index.dart';
import '../../utils/lang_ext.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../utils/timezone.dart';
import '../../widgets/news_links_widget.dart';

class DisplayEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String? image;
  final int rsvpCount;
  final bool isUpcoming;

  DisplayEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.image,
    required this.rsvpCount,
    required this.isUpcoming,
  });

  factory DisplayEvent.fromEvent(Event event, Language language) {
    final now = getISTNow();
    final eventDate = parseToIST(event.date);
    final eventDateTime = _combineEventDateTime(event.date, event.time) ?? eventDate;
    final isUpcoming = eventDateTime.isAfter(now) || eventDateTime.isAtSameMomentAs(now);

    return DisplayEvent(
      id: event.id,
      title: event.title[language == Language.en ? 'en' : 'te'] ?? event.title['en'] ?? 'Untitled Event',
      description: event.description[language == Language.en ? 'en' : 'te'] ?? event.description['en'] ?? '',
      date: eventDate,
      time: event.time,
      location: event.location[language == Language.en ? 'en' : 'te'] ?? event.location['en'] ?? '',
      image: event.image,
      rsvpCount: event.rsvpCount,
      isUpcoming: isUpcoming,
    );
  }
}

DateTime? _combineEventDateTime(String dateStr, String timeStr) {
  try {
    final eventDate = parseToIST(dateStr);
    int hours = 0;
    int minutes = 0;
    final timeLower = timeStr.toLowerCase().trim();
    final isPM = timeLower.contains('pm');
    final isAM = timeLower.contains('am');
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = timeRegex.firstMatch(timeStr);
    if (match == null) return eventDate;
    hours = int.parse(match.group(1)!);
    minutes = int.parse(match.group(2)!);
    if (isPM && hours != 12) { hours += 12; }
    else if (isAM && hours == 12) { hours = 0; }
    return tz.TZDateTime(istLocation, eventDate.year, eventDate.month, eventDate.day, hours, minutes, 0, 0, 0);
  } catch (e) {
    try { return parseToIST(dateStr); } catch (_) { return null; }
  }
}

class MobileHomeScreen extends StatefulWidget {
  final UserRole userRole;
  final Function(int)? onTabChange;

  const MobileHomeScreen({
    super.key,
    required this.userRole,
    this.onTabChange,
  });

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  final ApiService _apiService = ApiService();
  List<DisplayEvent> _upcomingEvents = [];
  bool _isLoadingEvents = true;
  List<NewsItem> _stateNewsItems = [];
  List<NewsItem> _localNewsItems = [];
  bool _isLoadingNews = true;
  LanguageService? _languageService;
  int _activeTabIndex = 0; // 0=News, 1=Events, 2=Social, 3=Counters
  int _newsSubTab = 0; // 0=State, 1=Local
  late PageController _newsPageController;
  int _currentNewsPage = 0;

  @override
  void initState() {
    super.initState();
    _newsPageController = PageController();
    _fetchUpcomingEvents();
    _fetchNews();
    _languageService = Provider.of<LanguageService>(context, listen: false);
    _languageService?.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) {
      _fetchUpcomingEvents();
      _fetchNews();
    }
  }

  @override
  void dispose() {
    _languageService?.removeListener(_onLanguageChanged);
    _newsPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);
    final authToken = Provider.of<AuthService>(context, listen: false).accessToken;
    try {
      final futures = await Future.wait([
        _apiService.getNews(page: 1, perPage: 10),
        if (authToken != null)
          _apiService.getLocalNews(page: 1, perPage: 10, authToken: authToken)
        else
          Future.value({'success': false}),
      ]);

      List<NewsItem> stateItems = [];
      List<NewsItem> localItems = [];

      if (futures[0]['success'] == true && futures[0]['data'] != null) {
        final newsList = futures[0]['data']['news'] as List<dynamic>? ?? [];
        stateItems = newsList.map((j) {
          try { return NewsItem.fromJson(j); } catch (_) { return null; }
        }).whereType<NewsItem>().toList();
      }

      if (futures[1]['success'] == true && futures[1]['data'] != null) {
        final newsList = futures[1]['data']['news'] as List<dynamic>? ?? [];
        localItems = newsList.map((j) {
          try { return NewsItem.fromJson(j); } catch (_) { return null; }
        }).whereType<NewsItem>().toList();
      }

      if (mounted) {
        setState(() {
          _stateNewsItems = stateItems;
          _localNewsItems = localItems;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading news: $e');
      if (mounted) {
        setState(() {
          _stateNewsItems = [];
          _localNewsItems = [];
          _isLoadingNews = false;
        });
      }
    }

  }

  Future<void> _fetchUpcomingEvents() async {
    if (!mounted) return;
    setState(() => _isLoadingEvents = true);
    try {
      final result = await _apiService.getEvents(page: 1, perPage: 5, upcomingOnly: true);
      if (result['success'] == true && result['data'] != null) {
        final eventsList = result['data']['events'] as List<dynamic>? ?? [];
        Language language = Language.en;
        if (mounted) {
          language = Provider.of<LanguageService>(context, listen: false).language;
        }
        final displayEvents = eventsList.map((j) {
          try { return DisplayEvent.fromEvent(Event.fromJson(j), language); } catch (_) { return null; }
        }).whereType<DisplayEvent>().toList();

        final upcomingOnly = displayEvents.where((e) => e.isUpcoming).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (mounted) {
          setState(() {
            _upcomingEvents = upcomingOnly.take(5).toList();
            _isLoadingEvents = false;
          });
        }
      } else {
        if (mounted) setState(() { _upcomingEvents = []; _isLoadingEvents = false; });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (mounted) setState(() { _upcomingEvents = []; _isLoadingEvents = false; });
    }
  }

  String _formatNewsDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = getISTNow();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return context.lang == Language.en ? '$m ${m == 1 ? 'min' : 'mins'} ago' : '$m నిమిషాల క్రితం';
      } else if (diff.inHours < 24) {
        final h = diff.inHours;
        return context.lang == Language.en ? '$h ${h == 1 ? 'hr' : 'hrs'} ago' : '$h గంటల క్రితం';
      } else if (diff.inDays < 7) {
        final d = diff.inDays;
        return context.lang == Language.en ? '$d ${d == 1 ? 'day' : 'days'} ago' : '$d రోజుల క్రితం';
      } else {
        return DateFormat('MMM d, yyyy').format(date);
      }
    } catch (_) {
      return dateStr;
    }
  }

  String _formatEventDate(DisplayEvent event) {
    final now = getISTNow();
    final nowDate = DateTime(now.year, now.month, now.day);
    final evDate = DateTime(event.date.year, event.date.month, event.date.day);
    final diff = evDate.difference(nowDate).inDays;
    if (diff == 0) return context.lang == Language.en ? 'Today' : 'ఈరోజు';
    if (diff == 1) return context.lang == Language.en ? 'Tomorrow' : 'రేపు';
    if (diff < 7) return DateFormat('EEEE').format(event.date);
    return DateFormat('MMM d').format(event.date);
  }

  void _showNewsDialog(BuildContext context, NewsItem news) {
    final hasImage = news.image.isNotEmpty && news.image != 'null';

    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.of(context).size;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Consumer<LanguageService>(
          builder: (context, langSvc, _) {
            final lang = langSvc.language;
            final key = lang == Language.en ? 'en' : 'te';
            final currentTitle = news.title[key]?.trim().isNotEmpty == true
                ? news.title[key]!.trim()
                : (news.title['en']?.trim() ?? 'Untitled News');
            final currentDesc = news.description[key]?.trim().isNotEmpty == true
                ? news.description[key]!.trim()
                : (news.description['en']?.trim() ?? '');

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: Container(
                constraints: BoxConstraints(maxHeight: screenSize.height * 0.9, maxWidth: screenSize.width * 0.95),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: hasImage
                                  ? ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: screenSize.height * 0.45,
                                      ),
                                      child: Image.network(
                                        news.image,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, err, st) => _newsImagePlaceholder(colorScheme),
                                      ),
                                    )
                                  : _newsImagePlaceholder(colorScheme),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (news.category.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      news.category,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (news.links != null && news.links!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: NewsLinksWidget(links: news.links!),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              currentTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 5),
                                Text(
                                  _formatNewsDate(news.date),
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            if (currentDesc.isNotEmpty)
                              Text(currentDesc, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6))
                            else
                              Text(
                                lang == Language.en ? 'No description available.' : 'వివరణ అందుబాటులో లేదు.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.outline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
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

  Widget _newsImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Icon(Icons.article_outlined, size: 56, color: colorScheme.primary.withValues(alpha: 0.4)),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header (unchanged) ──────────────────
          SliverAppBar(
            expandedHeight: 210,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.primary,
            centerTitle: true,
            leadingWidth: 200,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.lang == Language.en ? 'Home' : 'హోమ్',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: TextButton.icon(
                  onPressed: () => context.push('/language'),
                  icon: const Icon(Icons.language, size: 18),
                  label: Text(context.lang == Language.en ? 'తెలుగు' : 'English'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(color: colorScheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.none,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: colorScheme.primary),
                  Transform.translate(
                    offset: const Offset(0, 55),
                    child: Image.asset(
                      'assets/images/header.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, err, st) => const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.80),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabContent(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB SELECTOR
  // ──────────────────────────────────────────────

  Widget _buildTabSelector() {
    final isEn = context.lang == Language.en;
    final colorScheme = Theme.of(context).colorScheme;

    final tabs = <Map<String, dynamic>>[
      {'icon': Icons.newspaper_rounded, 'label': isEn ? 'News' : 'వార్తలు'},
      {'icon': Icons.event_rounded, 'label': isEn ? 'Events' : 'కార్యక్రమాలు'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _activeTabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i]['icon'] as IconData,
                      size: 13,
                      color: active ? colorScheme.primary : colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? colorScheme.primary : colorScheme.onPrimary.withValues(alpha: 0.85),
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB CONTENT ROUTER
  // ──────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_activeTabIndex) {
      case 0: return _buildNewsTab();
      case 1: return _buildEventsTab();
      default: return _buildNewsTab();
    }
  }

  // ──────────────────────────────────────────────
  // NEWS TAB  (Way2News-style swipeable cards)
  // ──────────────────────────────────────────────

  Widget _buildNewsTab() {
    if (_isLoadingNews) {
      return const SizedBox(
        height: 440,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewsSubTabs(),
          const SizedBox(height: 10),
          _buildNewsPageView(),
        ],
      ),
    );
  }

  Widget _buildNewsSubTabs() {
    final isEn = context.lang == Language.en;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _newsSubTabChip(label: isEn ? 'State News' : 'రాష్ట్ర వార్తలు', index: 0, colorScheme: colorScheme),
          const SizedBox(width: 8),
          _newsSubTabChip(label: isEn ? 'Area News' : 'స్థానిక వార్తలు', index: 1, colorScheme: colorScheme),
        ],
      ),
    );
  }

  Widget _newsSubTabChip({
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final active = _newsSubTab == index;
    return GestureDetector(
      onTap: () => _switchNewsSubTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: active ? null : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _switchNewsSubTab(int tab) {
    if (_newsSubTab == tab) return;
    setState(() {
      _newsSubTab = tab;
      _currentNewsPage = 0;
    });
    final items = tab == 0 ? _stateNewsItems : _localNewsItems;
    if (_newsPageController.hasClients && items.isNotEmpty) {
      _newsPageController.jumpToPage(0);
    }
  }

  Widget _buildNewsPageView() {
    final isEn = context.lang == Language.en;
    final items = _newsSubTab == 0 ? _stateNewsItems : _localNewsItems;
    final emptyText = _newsSubTab == 0
        ? (isEn ? 'No state news available' : 'రాష్ట్ర వార్తలు లేవు')
        : (isEn ? 'No area news available' : 'స్థానిక వార్తలు లేవు');
    final colorScheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _newsPageController,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            onPageChanged: (page) => setState(() => _currentNewsPage = page),
            itemBuilder: (context, index) => _buildWay2NewsCard(items[index]),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ...List.generate(
                items.length > 8 ? 8 : items.length,
                (i) {
                  final dotIndex = items.length > 8
                      ? ((_currentNewsPage / (items.length - 1)) * 7).round()
                      : _currentNewsPage;
                  final active = i == dotIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 5),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                },
              ),
              const Spacer(),
              Text(
                '${_currentNewsPage + 1} / ${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildMoreNewsList(items, colorScheme),
      ],
    );
  }

  Widget _buildMoreNewsList(List<NewsItem> items, ColorScheme colorScheme) {
    if (items.length <= 1) return const SizedBox.shrink();
    final isEn = context.lang == Language.en;
    final theme = Theme.of(context);
    final titleKey = isEn ? 'en' : 'te';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                isEn ? 'More News' : 'మరిన్ని వార్తలు',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final news = items[index];
            final newsTitle = news.title[titleKey]?.trim().isNotEmpty == true
                ? news.title[titleKey]!.trim()
                : (news.title['en']?.trim() ?? 'Untitled');
            final hasImage = news.image.isNotEmpty && news.image != 'null';
            final isActive = index == _currentNewsPage;

            return GestureDetector(
              onTap: () {
                setState(() => _currentNewsPage = index);
                if (_newsPageController.hasClients) {
                  _newsPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
                _showNewsDialog(context, news);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: isActive ? colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 56,
                        child: hasImage
                            ? Image.network(
                                news.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  child: Icon(Icons.article_outlined, size: 24, color: colorScheme.primary.withValues(alpha: 0.4)),
                                ),
                              )
                            : Container(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                child: Icon(Icons.article_outlined, size: 24, color: colorScheme.primary.withValues(alpha: 0.4)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            newsTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                              height: 1.3,
                              fontSize: 13,
                              color: isActive ? colorScheme.primary : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 11, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(
                                _formatNewsDate(news.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWay2NewsCard(NewsItem news) {
    final titleKey = context.lang == Language.en ? 'en' : 'te';
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final newsTitle = news.title[titleKey]?.trim().isNotEmpty == true
        ? news.title[titleKey]!.trim()
        : (news.title['en']?.trim().isNotEmpty == true
            ? news.title['en']!.trim()
            : news.title.values.firstWhere((v) => v.isNotEmpty, orElse: () => 'Untitled'));

    final newsDesc = news.description[titleKey]?.trim().isNotEmpty == true
        ? news.description[titleKey]!.trim()
        : (news.description['en']?.trim() ?? '');

    final hasImage = news.image.isNotEmpty && news.image != 'null';

    return GestureDetector(
      onTap: () => _showNewsDialog(context, news),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section — top 57%
            Expanded(
              flex: 57,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasImage
                      ? Image.network(
                          news.image,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, e, st) => Container(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                            child: Icon(Icons.article_outlined, size: 56, color: colorScheme.primary.withValues(alpha: 0.4)),
                          ),
                        )
                      : Container(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          child: Icon(Icons.article_outlined, size: 56, color: colorScheme.primary.withValues(alpha: 0.4)),
                        ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.45, 1.0],
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.50)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Row(
                      children: [
                        Icon(Icons.swipe_rounded, size: 13, color: Colors.white.withValues(alpha: 0.65)),
                        const SizedBox(width: 4),
                        Text(
                          context.lang == Language.en ? 'Swipe for more' : 'స్వైప్ చేయండి',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content section — bottom 43%
            Expanded(
              flex: 43,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          _formatNewsDate(news.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (newsDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          newsDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                            height: 1.45,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        context.lang == Language.en ? 'Tap to read more →' : 'మరిన్ని చదవండి →',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // EVENTS TAB
  // ──────────────────────────────────────────────

  Widget _buildEventsTab() {
    final isEn = context.lang == Language.en;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3, height: 18,
                      decoration: BoxDecoration(color: colorScheme.secondary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEn ? 'Upcoming Events' : 'రాబోయే కార్యక్రమాలు',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () { if (widget.onTabChange != null) widget.onTabChange!(2); },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(isEn ? 'View All →' : 'అన్నీ చూడండి →'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoadingEvents)
            const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
          else if (_upcomingEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 40, color: colorScheme.outline.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      isEn ? 'No upcoming events' : 'రాబోయే కార్యక్రమాలు లేవు',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 185,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _upcomingEvents.length,
                itemBuilder: (context, index) => _buildEventCard(_upcomingEvents[index], colorScheme, theme),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DisplayEvent event, ColorScheme colorScheme, ThemeData theme) {
    return GestureDetector(
      onTap: () { if (widget.onTabChange != null) widget.onTabChange!(2); },
      child: Container(
        width: 195,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.secondary, colorScheme.secondary.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(event.date),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1),
                  ),
                  Text(
                    DateFormat('MMM yyyy').format(event.date),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          fontSize: 12.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 10, color: colorScheme.secondary),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatEventDate(event)}  •  ${event.time}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (event.location.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 10, color: colorScheme.error),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SOCIAL MEDIA TAB
  // ──────────────────────────────────────────────

  Widget _buildSocialTab() {
    final isEn = context.lang == Language.en;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final platforms = [
      {
        'name': 'Facebook',
        'handle': '@TelanganaCongress',
        'icon': Icons.facebook_rounded,
        'color': const Color(0xFF1877F2),
        'bgColor': const Color(0xFFE8F0FD),
        'url': 'https://www.facebook.com/TelanganaCongress',
      },
      {
        'name': 'YouTube',
        'handle': 'Telangana Congress',
        'icon': Icons.smart_display_rounded,
        'color': const Color(0xFFFF0000),
        'bgColor': const Color(0xFFFFECEC),
        'url': 'https://www.youtube.com/@TelanganaCongress',
      },
      {
        'name': 'Instagram',
        'handle': '@telangana_inc',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFFE1306C),
        'bgColor': const Color(0xFFFDE8F0),
        'url': 'https://www.instagram.com/telangana_inc',
      },
      {
        'name': 'Twitter / X',
        'handle': '@INCTelangana',
        'icon': Icons.tag_rounded,
        'color': const Color(0xFF14171A),
        'bgColor': const Color(0xFFEEEEEE),
        'url': 'https://twitter.com/INCTelangana',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Follow Us' : 'మమ్మల్ని అనుసరించండి',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: platforms.length,
            itemBuilder: (context, index) {
              final p = platforms[index];
              final color = p['color'] as Color;
              final bgColor = p['bgColor'] as Color;

              return GestureDetector(
                onTap: () async {
                  final url = Uri.parse(p['url'] as String);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(p['icon'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p['handle'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: color.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Media gallery button
          GestureDetector(
            onTap: () { if (widget.onTabChange != null) widget.onTabChange!(1); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEn ? 'Browse Media Gallery' : 'మీడియా గ్యాలరీ చూడండి',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // COUNTERS TAB
  // ──────────────────────────────────────────────

  Widget _buildCountersTab() {
    final isEn = context.lang == Language.en;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final counters = [
      {
        'label': isEn ? 'Total Members' : 'మొత్తం సభ్యులు',
        'value': '2,40,000+',
        'icon': Icons.groups_rounded,
        'color': colorScheme.primary,
      },
      {
        'label': isEn ? 'Active Members' : 'క్రియాశీల సభ్యులు',
        'value': '1,80,000+',
        'icon': Icons.person_pin_rounded,
        'color': colorScheme.secondary,
      },
      {
        'label': isEn ? 'Districts' : 'జిల్లాలు',
        'value': '33',
        'icon': Icons.location_city_rounded,
        'color': const Color(0xFF7B1FA2),
      },
      {
        'label': isEn ? 'Mandals' : 'మండలాలు',
        'value': '584',
        'icon': Icons.holiday_village_rounded,
        'color': const Color(0xFFE65100),
      },
      {
        'label': isEn ? 'Constituencies' : 'నియోజకవర్గాలు',
        'value': '119',
        'icon': Icons.account_balance_rounded,
        'color': const Color(0xFF00695C),
      },
      {
        'label': isEn ? 'Party Units' : 'పార్టీ యూనిట్లు',
        'value': '10,000+',
        'icon': Icons.flag_rounded,
        'color': const Color(0xFFC62828),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Party Statistics' : 'పార్టీ గణాంకాలు',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: counters.length,
            itemBuilder: (context, index) {
              final c = counters[index];
              final color = c['color'] as Color;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(c['icon'] as IconData, color: color, size: 24),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['value'] as String,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c['label'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Membership CTA
          GestureDetector(
            onTap: () { if (widget.onTabChange != null) widget.onTabChange!(5); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.secondary, colorScheme.secondary.withValues(alpha: 0.80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.secondary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEn ? 'Join as a Member' : 'సభ్యుడిగా చేరండి',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
