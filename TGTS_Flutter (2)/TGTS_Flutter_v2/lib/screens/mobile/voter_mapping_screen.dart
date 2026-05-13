import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'voter_comparison_screen.dart';

// ─── MODEL ───────────────────────────────────────────────────────────────────

class VoterListEntry {
  final int    id;
  final String serialNo;
  final String voterName;
  final String relativeType;
  final String relativeName;
  final String gender;
  final int    age;
  final String dateOfBirth;
  final String address;
  final String houseNumber;
  final String boothNumber;
  final String boothName;
  final String partNumber;
  final String phone;
  final String caste;
  final String color;
  final String voterIdNumber;
  final bool   isBeneficiary;
  final bool   isDuplicate;
  final bool   hasVoted;
  final bool   isEffective;

  const VoterListEntry({
    required this.id,
    required this.serialNo,
    required this.voterName,
    required this.relativeType,
    required this.relativeName,
    required this.gender,
    required this.age,
    required this.dateOfBirth,
    required this.address,
    required this.houseNumber,
    required this.boothNumber,
    required this.boothName,
    required this.partNumber,
    required this.phone,
    required this.caste,
    required this.color,
    required this.voterIdNumber,
    required this.isBeneficiary,
    required this.isDuplicate,
    required this.hasVoted,
    required this.isEffective,
  });

  factory VoterListEntry.fromJson(Map<String, dynamic> j) {
    String s(String k, [String fb = '']) => j[k]?.toString().trim() ?? fb;
    int    n(String k) => (j[k] as num?)?.toInt() ?? 0;
    bool   b(String k) {
      final v = j[k];
      if (v is bool) return v;
      return v?.toString().toLowerCase() == 'true';
    }

    return VoterListEntry(
      id:             n('id'),
      serialNo:       s('serialNo'),
      voterName:      s('voterName'),
      relativeType:   s('relativeType'),
      relativeName:   s('relativeName'),
      gender:         s('gender'),
      age:            n('age'),
      dateOfBirth:    s('dateOfBirth'),
      address:        s('address'),
      houseNumber:    s('houseNumber'),
      boothNumber:    s('boothNumber'),
      boothName:      s('boothName'),
      partNumber:     s('partNumber'),
      phone:          s('phone'),
      caste:          s('caste'),
      color:          s('color'),
      voterIdNumber:  s('voterIdNumber'),
      isBeneficiary:  b('isBeneficiary'),
      isDuplicate:    b('isDuplicate'),
      hasVoted:       b('hasVoted'),
      isEffective:    b('isEffective'),
    );
  }

  String get ageGroup {
    if (age <= 0)  return 'Unknown';
    if (age <= 25) return '18–25 yrs';
    if (age <= 35) return '26–35 yrs';
    if (age <= 45) return '36–45 yrs';
    if (age <= 60) return '46–60 yrs';
    return '60+ yrs';
  }

  String get relativeDisplay =>
      relativeType.isNotEmpty && relativeName.isNotEmpty
          ? '$relativeType $relativeName'
          : relativeName;

  Color get colorIndicator {
    switch (color.toLowerCase()) {
      case 'green':  return const Color(0xFF138808);
      case 'yellow': return const Color(0xFFFFB300);
      case 'red':    return const Color(0xFFC62828);
      case 'orange': return const Color(0xFFE65100);
      default:       return Colors.grey;
    }
  }
}

// ─── CATEGORY CONFIG ─────────────────────────────────────────────────────────

class _Category {
  final String              title;
  final String              subtitle;
  final IconData            icon;
  final Color               color;
  final Map<String, String> params;

  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.params,
  });
}

const _kCategories = <_Category>[
  _Category(
    title:    'Booth Wise',
    subtitle: 'Grouped by booth number',
    icon:     Icons.how_to_vote,
    color:    Color(0xFF19aaed),
    params:   {'sort_by': 'booth'},
  ),
  _Category(
    title:    'Alphabetic',
    subtitle: 'Sorted A–Z by name',
    icon:     Icons.sort_by_alpha,
    color:    Color(0xFF138808),
    params:   {'sort_by': 'name'},
  ),
  _Category(
    title:    'Phone Number List',
    subtitle: 'Voters with phone numbers',
    icon:     Icons.phone,
    color:    Color(0xFF0097A7),
    params:   {'sort_by': 'name', 'has_phone': 'true'},
  ),
  _Category(
    title:    'Address Wise',
    subtitle: 'Sorted by address',
    icon:     Icons.location_on,
    color:    Color(0xFFE65100),
    params:   {'sort_by': 'address'},
  ),
  _Category(
    title:    'Age Wise',
    subtitle: 'Sorted by age',
    icon:     Icons.people,
    color:    Color(0xFF6A1B9A),
    params:   {'sort_by': 'age'},
  ),
  _Category(
    title:    'Caste Wise',
    subtitle: 'Grouped by caste',
    icon:     Icons.groups,
    color:    Color(0xFFC62828),
    params:   {'sort_by': 'caste'},
  ),
  _Category(
    title:    'Color Wise',
    subtitle: 'By political color code',
    icon:     Icons.palette,
    color:    Color(0xFF6D4C41),
    params:   {'sort_by': 'color'},
  ),
  _Category(
    title:    'Effective Voters',
    subtitle: 'Active / effective voters',
    icon:     Icons.verified_user,
    color:    Color(0xFF2E7D32),
    params:   {'is_effective': 'true'},
  ),
  _Category(
    title:    'Duplicate Votes',
    subtitle: 'Detected duplicate entries',
    icon:     Icons.find_replace,
    color:    Color(0xFFF57F17),
    params:   {'is_duplicate': 'true'},
  ),
  _Category(
    title:    'Beneficiary Wise',
    subtitle: 'Scheme beneficiaries',
    icon:     Icons.volunteer_activism,
    color:    Color(0xFF000080),
    params:   {'is_beneficiary': 'true'},
  ),
  _Category(
    title:    'Voted',
    subtitle: 'Voters who have voted',
    icon:     Icons.check_circle,
    color:    Color(0xFF00897B),
    params:   {'has_voted': 'true'},
  ),
  _Category(
    title:    'Non Voted',
    subtitle: 'Voters yet to vote',
    icon:     Icons.cancel,
    color:    Color(0xFFD4183D),
    params:   {'has_voted': 'false'},
  ),
];

// ─── API HELPER ──────────────────────────────────────────────────────────────

Future<Map<String, dynamic>?> _voterGet(
  String path,
  Map<String, String> params,
  String? token,
) async {
  final result = await ApiService().getVoterData(path, params, token ?? '');
  if (result['success'] == true) {
    return result['data'] as Map<String, dynamic>?;
  }
  return null;
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class VoterMappingScreen extends StatefulWidget {
  const VoterMappingScreen({Key? key}) : super(key: key);

  @override
  State<VoterMappingScreen> createState() => _VoterMappingScreenState();
}

class _VoterMappingScreenState extends State<VoterMappingScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  bool   _isSearchActive = false;
  bool   _loading        = false;
  bool   _searched       = false;
  List<VoterListEntry> _results = [];
  Timer? _debounce;

  // Stats banner
  int _total       = 0;
  int _voted       = 0;
  int _duplicates  = 0;

  String? get _token =>
      Provider.of<AuthService>(context, listen: false).accessToken;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadStats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final body = await _voterGet('/stats/', {}, _token);
    if (!mounted || body == null) return;
    setState(() {
      _total      = (body['total']      as num?)?.toInt() ?? 0;
      _voted      = (body['voted']      as num?)?.toInt() ?? 0;
      _duplicates = (body['duplicates'] as num?)?.toInt() ?? 0;
    });
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    setState(() => _isSearchActive = q.isNotEmpty);
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _loading = true; _searched = true; });

    final body = await _voterGet('/', {
      'search':   q,
      'page':     '1',
      'per_page': '30',
    }, _token);

    if (!mounted) return;
    if (body != null) {
      final list = (body['data'] ?? body['results'] ?? []) as List;
      setState(() {
        _results = list.map((e) => VoterListEntry.fromJson(e)).toList();
        _loading  = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _focusNode.unfocus();
    setState(() {
      _isSearchActive = false;
      _results        = [];
      _searched       = false;
    });
  }

  void _openCategory(_Category cat) {
    if (cat.title == 'Beneficiary Wise') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SchemeBeneficiaryScreen(token: _token),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VoterCategoryScreen(category: cat, token: _token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF19aaed), Color(0xFF005f8e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Voter Map',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows, color: Colors.white),
            tooltip: 'Voter List Comparison',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoterComparisonScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isSearchActive
                ? _buildSearchResults()
                : _buildHomeBody(),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF19aaed), Color(0xFF005f8e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: TextField(
        controller:      _searchCtrl,
        focusNode:       _focusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText:  'Search by name, voter ID, phone, caste…',
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.black45),
          suffixIcon: _isSearchActive
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: const Icon(Icons.close, color: Colors.black45),
                )
              : null,
          filled:         true,
          fillColor:      Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide.none),
        ),
      ),
    );
  }

  // ── Home body (stats + tiles) ──────────────────────────────────────────────

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_total > 0) _buildStatsBanner(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Browse by Category',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   16,
                      color:      AppColors.textPrimary),
                ),
              ],
            ),
          ),
          _buildTileGrid(),
        ],
      ),
    );
  }

  Widget _buildStatsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _statCard('Total Voters', _total, Icons.people_alt_rounded,
              [const Color(0xFF19aaed), const Color(0xFF005f8e)]),
          const SizedBox(width: 10),
          _statCard('Voted', _voted, Icons.how_to_vote_rounded,
              [const Color(0xFF00897B), const Color(0xFF00574B)]),
          const SizedBox(width: 10),
          _statCard('Duplicates', _duplicates, Icons.content_copy_rounded,
              [const Color(0xFFE65100), const Color(0xFFBF360C)]),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, List<Color> colors) {
    final display = value > 999999
        ? '${(value / 1000000).toStringAsFixed(1)}M'
        : value > 9999
            ? '${(value / 1000).toStringAsFixed(1)}K'
            : '$value';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors[0].withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: colors[0], size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              display,
              style: TextStyle(
                color: colors[0],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tile grid ──────────────────────────────────────────────────────────────

  Widget _buildTileGrid() {
    return GridView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      padding:     const EdgeInsets.fromLTRB(16, 12, 16, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        crossAxisSpacing: 10,
        mainAxisSpacing:  18,
        childAspectRatio: 0.80,
      ),
      itemCount:   _kCategories.length,
      itemBuilder: (_, i) => _CategoryTile(
        category: _kCategories[i],
        onTap:    () => _openCategory(_kCategories[i]),
      ),
    );
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_results.isEmpty && _searched) {
      return _emptyState(Icons.manage_search,
          'No voters found.\nTry a different keyword.');
    }
    if (_results.isEmpty) {
      return _emptyState(Icons.search, 'Type to search voters…');
    }

    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount:   _results.length,
      itemBuilder: (_, i) => _VoterEntryCard(
        entry:   _results[i],
        onTap:   () => _showDetail(_results[i]),
      ),
    );
  }

  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[350]),
          const SizedBox(height: 16),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  void _showDetail(VoterListEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoterEntryDetailSheet(entry: entry),
    );
  }
}

// ─── CATEGORY TILE ───────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final _Category    category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  // Darken a color slightly for gradient end stop
  Color _darken(Color c, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor:  category.color.withOpacity(0.15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Circle icon ─────────────────────────────────────────────
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [category.color, _darken(category.color)],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:       category.color.withOpacity(0.38),
                    blurRadius:  14,
                    spreadRadius: 1,
                    offset:      const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(category.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            // ── Label ───────────────────────────────────────────────────
            Text(
              category.title,
              textAlign: TextAlign.center,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                color:      AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize:   11,
                height:     1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CATEGORY DETAIL SCREEN ──────────────────────────────────────────────────

class _VoterCategoryScreen extends StatefulWidget {
  final _Category category;
  final String?   token;

  const _VoterCategoryScreen(
      {required this.category, required this.token});

  @override
  State<_VoterCategoryScreen> createState() => _VoterCategoryScreenState();
}

class _VoterCategoryScreenState extends State<_VoterCategoryScreen> {
  final _scrollCtrl  = ScrollController();
  final _filterCtrl  = TextEditingController();

  List<VoterListEntry> _entries     = [];
  bool   _loading      = true;
  bool   _loadingMore  = false;
  bool   _error        = false;
  int    _page         = 1;
  int    _total        = 0;
  int    _totalPages   = 1;
  Timer? _debounce;
  String _filterQuery  = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _filterCtrl.addListener(_onFilterChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _filterQuery = _filterCtrl.text.trim());
      _load(reset: true);
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 250) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore && !reset) return;
    if (!reset && _page > _totalPages) return;

    if (reset) {
      setState(() {
        _entries = [];
        _page    = 1;
        _loading = true;
        _error   = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final params = <String, String>{
      'page':     '$_page',
      'per_page': '25',
      ...widget.category.params,
    };
    if (_filterQuery.isNotEmpty) params['search'] = _filterQuery;

    final body = await _voterGet('/', params, widget.token);

    if (!mounted) return;

    if (body != null) {
      final list  = (body['data'] ?? body['results'] ?? []) as List;
      final items = list.map((e) => VoterListEntry.fromJson(e)).toList();
      setState(() {
        if (reset) { _entries = items; } else { _entries.addAll(items); }
        _total       = (body['total']       as num?)?.toInt() ?? _entries.length;
        _totalPages  = (body['total_pages'] as num?)?.toInt() ?? 1;
        _page        = _page + 1;
        _loading     = false;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _loading     = false;
        _loadingMore = false;
        if (reset) _error = true;
      });
    }
  }

  String _highlightField() {
    switch (widget.category.params['sort_by']) {
      case 'booth':   return 'booth';
      case 'phone':   return 'phone';
      case 'address': return 'address';
      case 'age':     return 'age';
      case 'caste':   return 'caste';
      case 'color':   return 'color';
      default:
        if (widget.category.params['is_duplicate']   == 'true') return 'duplicate';
        if (widget.category.params['is_beneficiary'] == 'true') return 'beneficiary';
        if (widget.category.params['has_voted']      == 'true') return 'voted';
        if (widget.category.params['has_voted']      == 'false') return 'nonvoted';
        if (widget.category.params['is_effective']   == 'true') return 'effective';
        if (widget.category.params['has_phone']      == 'true') return 'phone';
        return 'name';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: widget.category.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.title,
          style: TextStyle(
              color: widget.category.color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color:        widget.category.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(widget.category.icon, color: widget.category.color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loading ? 'Loading…' : '$_total voter${_total != 1 ? 's' : ''}',
                style: TextStyle(
                    color: widget.category.color, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(widget.category.subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: _filterCtrl,
        style:      const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText:   'Filter within this list…',
          hintStyle:  const TextStyle(color: Colors.black38, fontSize: 13),
          prefixIcon: const Icon(Icons.filter_list,
              color: Colors.black38, size: 20),
          suffixIcon: _filterCtrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _filterCtrl.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child:
                      const Icon(Icons.close, color: Colors.black38, size: 18),
                )
              : null,
          filled:         true,
          fillColor:      const Color(0xFFF2F4F7),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
              const SizedBox(height: 12),
              const Text('Failed to load data.',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _load(reset: true),
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.category.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.category.icon,
                  size: 72,
                  color: widget.category.color.withOpacity(0.25)),
              const SizedBox(height: 16),
              Text(
                _filterQuery.isNotEmpty
                    ? 'No voters match your filter.'
                    : 'No voter data available.\nUpload a CSV from the admin panel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 15, height: 1.5),
              ),
            ]),
      );
    }

    return RefreshIndicator(
      color:     widget.category.color,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller:  _scrollCtrl,
        padding:     const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount:   _entries.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _entries.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child:   Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          return _VoterEntryCard(
            entry:          _entries[i],
            highlightField: _highlightField(),
            onTap: () => _showDetail(_entries[i]),
          );
        },
      ),
    );
  }

  void _showDetail(VoterListEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoterEntryDetailSheet(entry: entry),
    );
  }
}

// ─── VOTER ENTRY CARD ────────────────────────────────────────────────────────

class _VoterEntryCard extends StatelessWidget {
  final VoterListEntry entry;
  final String         highlightField;
  final VoidCallback   onTap;

  const _VoterEntryCard({
    required this.entry,
    this.highlightField = 'name',
    required this.onTap,
  });

  Color get _accentColor {
    if (entry.color.isNotEmpty) return entry.colorIndicator;
    return entry.gender.toLowerCase() == 'female'
        ? AppColors.accent
        : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset:     const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left color accent bar
                Container(width: 4, color: _accentColor),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      // Avatar
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _accentColor.withOpacity(0.18),
                              _accentColor.withOpacity(0.06),
                            ],
                            begin: Alignment.topLeft,
                            end:   Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          entry.gender.toLowerCase() == 'female'
                              ? Icons.face_3
                              : Icons.face,
                          color: _accentColor,
                          size:  24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (entry.serialNo.isNotEmpty)
                                Container(
                                  margin:  const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color:        _accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    '#${entry.serialNo}',
                                    style: TextStyle(
                                        fontSize:   10,
                                        fontWeight: FontWeight.w600,
                                        color:      _accentColor),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  entry.voterName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            if (entry.relativeDisplay.isNotEmpty)
                              Text(entry.relativeDisplay,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            _buildSubtitle(),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBadge(),
                          const SizedBox(height: 4),
                          Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey[400]),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    final parts = <String>[];
    switch (highlightField) {
      case 'booth':
        if (entry.boothNumber.isNotEmpty) parts.add('Booth ${entry.boothNumber}');
        if (entry.boothName.isNotEmpty)   parts.add(entry.boothName);
        break;
      case 'phone':
        if (entry.phone.isNotEmpty)   parts.add(entry.phone);
        if (entry.address.isNotEmpty) parts.add(entry.address);
        break;
      case 'address':
        if (entry.houseNumber.isNotEmpty) parts.add('H.No ${entry.houseNumber}');
        if (entry.address.isNotEmpty)     parts.add(entry.address);
        break;
      case 'age':
        if (entry.age > 0) parts.add('${entry.age} yrs');
        if (entry.address.isNotEmpty) parts.add(entry.address);
        break;
      case 'caste':
        if (entry.caste.isNotEmpty)   parts.add(entry.caste);
        if (entry.address.isNotEmpty) parts.add(entry.address);
        break;
      case 'color':
        if (entry.color.isNotEmpty)   parts.add(entry.color.toUpperCase());
        if (entry.caste.isNotEmpty)   parts.add(entry.caste);
        break;
      default:
        if (entry.voterIdNumber.isNotEmpty) parts.add(entry.voterIdNumber);
        if (entry.address.isNotEmpty)       parts.add(entry.address);
    }
    if (parts.isEmpty) {
      if (entry.voterIdNumber.isNotEmpty) parts.add(entry.voterIdNumber);
      if (entry.address.isNotEmpty)       parts.add(entry.address);
    }
    final text = parts.join(' • ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
  }

  Widget _buildBadge() {
    if (entry.isDuplicate) {
      return _badge('Duplicate', const Color(0xFFF57F17));
    }
    if (!entry.isEffective) {
      return _badge('Non-Eff.', Colors.grey);
    }
    if (entry.hasVoted) {
      return _badge('Voted', const Color(0xFF00897B));
    }
    if (entry.isBeneficiary) {
      return _badge('Beneficiary', const Color(0xFF000080));
    }
    if (entry.age > 0 && highlightField == 'age') {
      return _badge(entry.ageGroup, const Color(0xFF6A1B9A));
    }
    if (entry.boothNumber.isNotEmpty && highlightField == 'booth') {
      return _badge('B${entry.boothNumber}', AppColors.primary);
    }
    return const SizedBox.shrink();
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withOpacity(0.3))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── VOTER DETAIL BOTTOM SHEET ───────────────────────────────────────────────

class _VoterEntryDetailSheet extends StatelessWidget {
  final VoterListEntry entry;
  const _VoterEntryDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.92,
      expand:           false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          _buildHeader(context),
          _buildBadgesRow(),
          Expanded(child: _buildDetails(scroll)),
        ]),
      ),
    );
  }

  // ── PDF generation ─────────────────────────────────────────────────────────

  Future<pw.Document> _buildPdf() async {
    final doc = pw.Document();

    const headerBlue = PdfColor.fromInt(0xFF19aaed);
    const darkBlue   = PdfColor.fromInt(0xFF005f8e);
    const labelGrey  = PdfColor.fromInt(0xFF757575);
    const rowBg      = PdfColor.fromInt(0xFFF8F9FA);

    pw.Widget sectionTitle(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Row(children: [
        pw.Container(
          width: 4, height: 16,
          decoration: pw.BoxDecoration(
            color: headerBlue,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ]),
    );

    pw.Widget infoRow(String label, String value) {
      if (value.isEmpty) return pw.SizedBox();
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const pw.BoxDecoration(
          color: rowBg,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
              style: pw.TextStyle(fontSize: 10, color: labelGrey)),
          ),
          pw.Expanded(
            child: pw.Text(value,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
        ]),
      );
    }

    final statusParts = <String>[];
    if (entry.hasVoted)      statusParts.add('Voted');
    if (entry.isBeneficiary) statusParts.add('Beneficiary');
    if (entry.isDuplicate)   statusParts.add('Duplicate');
    if (!entry.isEffective)  statusParts.add('Non-Effective');
    if (entry.color.isNotEmpty) {
      const labels = {
        'green': 'Green – Supporter', 'yellow': 'Yellow – Neutral',
        'red': 'Red – Opponent',      'orange': 'Orange – Unknown',
      };
      statusParts.add(labels[entry.color.toLowerCase()] ?? entry.color);
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(
            colors: [headerBlue, darkBlue],
            begin: pw.Alignment.topLeft,
            end:   pw.Alignment.bottomRight,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VOTER INFORMATION CARD',
                  style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  )),
                pw.SizedBox(height: 6),
                pw.Text(entry.voterName,
                  style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 20,
                    fontWeight: pw.FontWeight.bold)),
                if (entry.voterIdNumber.isNotEmpty)
                  pw.Text('Voter ID: ${entry.voterIdNumber}',
                    style: pw.TextStyle(
                      color: const PdfColor(1, 1, 1, 0.7), fontSize: 11)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Telangana Congress',
                  style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 10)),
                pw.Text('Communication App',
                  style: pw.TextStyle(
                    color: const PdfColor(1, 1, 1, 0.7), fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
      build: (context) => [
        sectionTitle('Personal Information'),
        infoRow('Name',          entry.voterName),
        infoRow('Relative',      entry.relativeDisplay),
        infoRow('Gender',        entry.gender),
        if (entry.age > 0)
          infoRow('Age',         '${entry.age} yrs (${entry.ageGroup})'),
        if (entry.dateOfBirth.isNotEmpty)
          infoRow('Date of Birth', entry.dateOfBirth),

        if (entry.phone.isNotEmpty) ...[
          sectionTitle('Contact'),
          infoRow('Phone', entry.phone),
        ],

        sectionTitle('Address'),
        if (entry.houseNumber.isNotEmpty)
          infoRow('House No.', entry.houseNumber),
        if (entry.address.isNotEmpty)
          infoRow('Address', entry.address),

        sectionTitle('Voter Details'),
        if (entry.serialNo.isNotEmpty)
          infoRow('Serial No.',  entry.serialNo),
        if (entry.voterIdNumber.isNotEmpty)
          infoRow('Voter ID',    entry.voterIdNumber),
        if (entry.partNumber.isNotEmpty)
          infoRow('Part No.',    entry.partNumber),

        if (entry.boothNumber.isNotEmpty || entry.boothName.isNotEmpty) ...[
          sectionTitle('Booth'),
          if (entry.boothNumber.isNotEmpty)
            infoRow('Booth No.',   entry.boothNumber),
          if (entry.boothName.isNotEmpty)
            infoRow('Booth Name',  entry.boothName),
        ],

        if (entry.caste.isNotEmpty) ...[
          sectionTitle('Community'),
          infoRow('Caste', entry.caste),
        ],

        if (statusParts.isNotEmpty) ...[
          sectionTitle('Status'),
          infoRow('Flags', statusParts.join(' | ')),
        ],
      ],
    ));

    return doc;
  }

  Future<void> _onDownload(BuildContext context) async {
    try {
      final doc   = await _buildPdf();
      final bytes = await doc.save();
      final name  = 'voter_${entry.voterIdNumber.isNotEmpty ? entry.voterIdNumber : entry.id}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onPrint(BuildContext context) async {
    try {
      final doc = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF19aaed), Color(0xFF005f8e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            entry.gender.toLowerCase() == 'female'
                ? Icons.face_3
                : Icons.face,
            color: Colors.white, size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.voterName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              if (entry.voterIdNumber.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ID: ${entry.voterIdNumber}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
        // Download button
        GestureDetector(
          onTap: () => _onDownload(context),
          child: Container(
            padding:    const EdgeInsets.all(8),
            margin:     const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.download, color: Colors.white, size: 20),
          ),
        ),
        // Print button
        GestureDetector(
          onTap: () => _onPrint(context),
          child: Container(
            padding:    const EdgeInsets.all(8),
            margin:     const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.print, color: Colors.white, size: 20),
          ),
        ),
        // Close button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildBadgesRow() {
    final badges = <Widget>[];
    if (entry.isDuplicate)
      badges.add(_sheetBadge('Duplicate', const Color(0xFFF57F17), Icons.find_replace));
    if (entry.isBeneficiary)
      badges.add(_sheetBadge('Beneficiary', const Color(0xFF000080), Icons.volunteer_activism));
    if (entry.hasVoted)
      badges.add(_sheetBadge('Voted', const Color(0xFF00897B), Icons.check_circle));
    if (!entry.isEffective)
      badges.add(_sheetBadge('Non-Effective', Colors.grey, Icons.cancel));
    if (entry.color.isNotEmpty)
      badges.add(_colorBadge(entry.color));

    if (badges.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: badges
              .expand((b) => [b, const SizedBox(width: 8)])
              .toList()
              ..removeLast(),
        ),
      ),
    );
  }

  Widget _sheetBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _colorBadge(String color) {
    const _labels = {
      'green':  'Supporter',
      'yellow': 'Neutral',
      'red':    'Opponent',
      'orange': 'Unknown',
    };
    final c     = VoterListEntry(
      id: 0, serialNo: '', voterName: '', relativeType: '', relativeName: '',
      gender: '', age: 0, dateOfBirth: '', address: '', houseNumber: '',
      boothNumber: '', boothName: '', partNumber: '', phone: '', caste: '',
      color: color, voterIdNumber: '', isBeneficiary: false, isDuplicate: false,
      hasVoted: false, isEffective: true,
    ).colorIndicator;
    final label = _labels[color.toLowerCase()] ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color:        c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: c.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: c, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildDetails(ScrollController scroll) {
    return SingleChildScrollView(
      controller: scroll,
      padding:    const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Personal Info'),
          _row(Icons.person,          'Name',          entry.voterName),
          _row(Icons.family_restroom, 'Relative',      entry.relativeDisplay),
          _row(Icons.wc,              'Gender',        entry.gender),
          if (entry.age > 0)
            _row(Icons.cake,          'Age',           '${entry.age} yrs (${entry.ageGroup})'),
          if (entry.dateOfBirth.isNotEmpty)
            _row(Icons.today,         'Date of Birth', entry.dateOfBirth),
          if (entry.phone.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section('Contact'),
            _row(Icons.phone, 'Phone', entry.phone),
          ],
          const SizedBox(height: 20),
          _section('Address'),
          if (entry.houseNumber.isNotEmpty)
            _row(Icons.home,         'House No.',  entry.houseNumber),
          if (entry.address.isNotEmpty)
            _row(Icons.location_on,  'Address',    entry.address),
          const SizedBox(height: 20),
          _section('Voter Details'),
          if (entry.serialNo.isNotEmpty)
            _row(Icons.format_list_numbered, 'Serial No.',  entry.serialNo),
          if (entry.voterIdNumber.isNotEmpty)
            _row(Icons.credit_card,           'Voter ID',   entry.voterIdNumber),
          if (entry.partNumber.isNotEmpty)
            _row(Icons.article,               'Part No.',   entry.partNumber),
          if (entry.boothNumber.isNotEmpty || entry.boothName.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section('Booth'),
            if (entry.boothNumber.isNotEmpty)
              _row(Icons.how_to_vote, 'Booth No.',  entry.boothNumber),
            if (entry.boothName.isNotEmpty)
              _row(Icons.store,       'Booth Name', entry.boothName),
          ],
          if (entry.caste.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section('Community'),
            _row(Icons.groups, 'Caste', entry.caste),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color:        AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                    color:      AppColors.textPrimary)),
          ],
        ),
      );

  Widget _row(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SCHEME BENEFICIARY MODEL ─────────────────────────────────────────────────

class _SchemeEntry {
  final int    id;
  final String schemeName;
  final String schemeDisplay;
  final String uploadBatchId;
  final String name;
  final String phone;
  final String address;
  final String village;
  final String mandal;
  final String district;
  final String aadharNo;
  final String accountNo;
  final String amount;

  const _SchemeEntry({
    required this.id,
    required this.schemeName,
    required this.schemeDisplay,
    required this.uploadBatchId,
    required this.name,
    required this.phone,
    required this.address,
    required this.village,
    required this.mandal,
    required this.district,
    required this.aadharNo,
    required this.accountNo,
    required this.amount,
  });

  factory _SchemeEntry.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k]?.toString().trim() ?? '';
    return _SchemeEntry(
      id:            (j['id'] as num?)?.toInt() ?? 0,
      schemeName:    s('schemeName'),
      schemeDisplay: s('schemeDisplay'),
      uploadBatchId: s('uploadBatchId'),
      name:          s('name'),
      phone:         s('phone'),
      address:       s('address'),
      village:       s('village'),
      mandal:        s('mandal'),
      district:      s('district'),
      aadharNo:      s('aadharNo'),
      accountNo:     s('accountNo'),
      amount:        s('amount'),
    );
  }
}

// ─── SCHEME SELECTION SCREEN ─────────────────────────────────────────────────

class _SchemeBeneficiaryScreen extends StatefulWidget {
  final String? token;
  const _SchemeBeneficiaryScreen({required this.token});

  @override
  State<_SchemeBeneficiaryScreen> createState() => _SchemeBeneficiaryScreenState();
}

class _SchemeBeneficiaryScreenState extends State<_SchemeBeneficiaryScreen> {
  static const _schemes = [
    {
      'key':   'maha_lakshmi',
      'label': 'Maha Lakshmi',
      'desc':  'Women welfare scheme',
      'icon':  Icons.female,
      'color': Color(0xFFAD1457),
    },
    {
      'key':   'cheyutha',
      'label': 'Cheyutha',
      'desc':  'Financial support scheme',
      'icon':  Icons.handshake,
      'color': Color(0xFF1565C0),
    },
    {
      'key':   'rythu_bharosa',
      'label': 'Rythu Bharosa',
      'desc':  'Farmer support scheme',
      'icon':  Icons.agriculture,
      'color': Color(0xFF2E7D32),
    },
    {
      'key':   'indiramma_indlu',
      'label': 'Indiramma Indlu',
      'desc':  'Housing scheme',
      'icon':  Icons.home,
      'color': Color(0xFFE65100),
    },
  ];

  Map<String, int> _counts = {};
  bool _loadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (widget.token == null) return;
    final result = await ApiService().getSchemesSummary(widget.token!);
    if (!mounted) return;
    final counts = <String, int>{};
    if (result['success'] == true) {
      final list = (result['data']?['data'] ?? result['data'] ?? []) as List;
      for (final item in list) {
        final key   = item['schemeName']?.toString() ?? '';
        final count = (item['count'] as num?)?.toInt() ?? 0;
        if (key.isNotEmpty) counts[key] = count;
      }
    }
    setState(() {
      _counts        = counts;
      _loadingCounts = false;
    });
  }

  Color _darken(Color c) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000080), Color(0xFF1a237e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scheme Beneficiaries',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.volunteer_activism, color: Color(0xFF000080), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Government Schemes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('Select a scheme to view beneficiaries',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),

          // Scheme cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _schemes.map((s) {
                final key   = s['key']   as String;
                final label = s['label'] as String;
                final desc  = s['desc']  as String;
                final icon  = s['icon']  as IconData;
                final color = s['color'] as Color;
                final count = _counts[key] ?? 0;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SchemeDetailScreen(
                        schemeKey:   key,
                        schemeLabel: label,
                        color:       color,
                        icon:        icon,
                        token:       widget.token,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [color, _darken(color)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:       color.withOpacity(0.32),
                          blurRadius:  16,
                          spreadRadius: 1,
                          offset:      const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                              const SizedBox(height: 2),
                              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                              const SizedBox(height: 6),
                              if (_loadingCounts)
                                Container(
                                  width: 80, height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                )
                              else
                                Text(
                                  '$count beneficiar${count == 1 ? 'y' : 'ies'}',
                                  style: TextStyle(
                                      color:      Colors.white.withOpacity(0.9),
                                      fontSize:   13,
                                      fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7), size: 16),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SCHEME DETAIL SCREEN ────────────────────────────────────────────────────

class _SchemeDetailScreen extends StatefulWidget {
  final String    schemeKey;
  final String    schemeLabel;
  final Color     color;
  final IconData  icon;
  final String?   token;

  const _SchemeDetailScreen({
    required this.schemeKey,
    required this.schemeLabel,
    required this.color,
    required this.icon,
    required this.token,
  });

  @override
  State<_SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<_SchemeDetailScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_SchemeEntry> _entries     = [];
  bool _loading      = true;
  bool _loadingMore  = false;
  bool _error        = false;
  int  _page         = 1;
  int  _total        = 0;
  int  _totalPages   = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 250) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore && !reset) return;
    if (!reset && _page > _totalPages) return;

    if (reset) {
      setState(() { _entries = []; _page = 1; _loading = true; _error = false; });
    } else {
      setState(() => _loadingMore = true);
    }

    final params = <String, String>{
      'page':     '$_page',
      'per_page': '25',
    };
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) params['search'] = q;

    final result = await ApiService().getSchemeBeneficiaries(
      widget.schemeKey, params, widget.token ?? '');

    if (!mounted) return;

    if (result['success'] == true) {
      final body = result['data'] as Map<String, dynamic>? ?? {};
      final list = (body['data'] ?? []) as List;
      final items = list.map((e) => _SchemeEntry.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        if (reset) { _entries = items; } else { _entries.addAll(items); }
        _total       = (body['total']       as num?)?.toInt() ?? _entries.length;
        _totalPages  = (body['total_pages'] as num?)?.toInt() ?? 1;
        _page        = _page + 1;
        _loading     = false;
        _loadingMore = false;
      });
    } else {
      setState(() { _loading = false; _loadingMore = false; if (reset) _error = true; });
    }
  }

  Color _darken(Color c) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, _darken(widget.color)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.schemeLabel,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(children: [
        // Stats + search header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _loading ? 'Loading…' : '$_total beneficiar${_total != 1 ? 'ies' : 'y'}',
                    style: TextStyle(color: widget.color, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(widget.schemeLabel,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText:   'Search by name, phone, mandal…',
                hintStyle:  const TextStyle(color: Colors.black38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.black38, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); FocusScope.of(context).unfocus(); },
                        child: const Icon(Icons.close, color: Colors.black38, size: 18),
                      )
                    : null,
                filled:         true,
                fillColor:      const Color(0xFFF2F4F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),

        // List body
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: widget.color));
    }
    if (_error) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
        const SizedBox(height: 12),
        const Text('Failed to load data.', style: TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]));
    }
    if (_entries.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(widget.icon, size: 72, color: widget.color.withOpacity(0.22)),
        const SizedBox(height: 16),
        Text(
          _searchCtrl.text.isNotEmpty
              ? 'No beneficiaries match your search.'
              : 'No beneficiary data available.\nUpload data from the admin portal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.5),
        ),
      ]));
    }

    return RefreshIndicator(
      color: widget.color,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller:  _scrollCtrl,
        padding:     const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount:   _entries.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _entries.length) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: widget.color)),
            );
          }
          return _SchemeEntryCard(entry: _entries[i], color: widget.color);
        },
      ),
    );
  }
}

// ─── SCHEME ENTRY CARD ────────────────────────────────────────────────────────

class _SchemeEntryCard extends StatelessWidget {
  final _SchemeEntry entry;
  final Color        color;

  const _SchemeEntryCard({required this.entry, required this.color});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchemeEntryDetailSheet(entry: entry, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = [entry.village, entry.mandal, entry.district]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Name row
                    Row(children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.amount.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.amount,
                            style: const TextStyle(
                                color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                    ]),

                    // Phone + Aadhar
                    if (entry.phone.isNotEmpty || entry.aadharNo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        if (entry.phone.isNotEmpty) ...[
                          const Icon(Icons.phone, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(entry.phone, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        if (entry.aadharNo.isNotEmpty) ...[
                          const Icon(Icons.credit_card, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(entry.aadharNo, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ]),
                    ],

                    // Location
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],

                    // Account no
                    if (entry.accountNo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.account_balance, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(entry.accountNo, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ]),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── SCHEME ENTRY DETAIL SHEET ────────────────────────────────────────────────

class _SchemeEntryDetailSheet extends StatelessWidget {
  final _SchemeEntry entry;
  final Color        color;

  const _SchemeEntryDetailSheet({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand:           false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin:     const EdgeInsets.only(top: 12, bottom: 4),
            width:      40,
            height:     4,
            decoration: BoxDecoration(
              color:        Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Scheme badge + amount
                Row(children: [
                  Container(
                    padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.schemeDisplay,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  if (entry.amount.isNotEmpty)
                    Container(
                      padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.amount,
                        style: const TextStyle(
                          color:      Color(0xFF2E7D32),
                          fontSize:   14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ]),

                const SizedBox(height: 14),
                Text(
                  entry.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // Detail rows
                if (entry.phone.isNotEmpty)
                  _detailRow(Icons.phone, 'Phone', entry.phone),
                if (entry.aadharNo.isNotEmpty)
                  _detailRow(Icons.credit_card, 'Aadhar No', entry.aadharNo),
                if (entry.accountNo.isNotEmpty)
                  _detailRow(Icons.account_balance, 'Account No', entry.accountNo),
                if (entry.village.isNotEmpty)
                  _detailRow(Icons.home_outlined, 'Village', entry.village),
                if (entry.mandal.isNotEmpty)
                  _detailRow(Icons.location_city, 'Mandal', entry.mandal),
                if (entry.district.isNotEmpty)
                  _detailRow(Icons.map_outlined, 'District', entry.district),
                if (entry.address.isNotEmpty)
                  _detailRow(Icons.place_outlined, 'Address', entry.address),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width:  40,
          height: 40,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
