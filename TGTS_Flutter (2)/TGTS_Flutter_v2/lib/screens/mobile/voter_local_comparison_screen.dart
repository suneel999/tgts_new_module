import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

// ─── MODELS ──────────────────────────────────────────────────────────────────

class _LocalVoter {
  final String voterIdNumber;
  final String voterName;
  final String relativeType;
  final String relativeName;
  final String gender;
  final String age;
  final String address;
  final String houseNumber;
  final String boothNumber;
  final String boothName;
  final String phone;
  final String serialNo;
  final String caste;

  const _LocalVoter({
    required this.voterIdNumber,
    required this.voterName,
    required this.relativeType,
    required this.relativeName,
    required this.gender,
    required this.age,
    required this.address,
    required this.houseNumber,
    required this.boothNumber,
    required this.boothName,
    required this.phone,
    required this.serialNo,
    required this.caste,
  });

  String get relativeDisplay =>
      relativeType.isNotEmpty && relativeName.isNotEmpty
          ? '$relativeType $relativeName'
          : relativeName;
}

class _LocalCompareResult {
  final int sheet1Total;
  final int sheet2Total;
  final List<_LocalVoter> added;
  final List<_LocalVoter> deleted;
  final List<_LocalVoter> duplicated;

  const _LocalCompareResult({
    required this.sheet1Total,
    required this.sheet2Total,
    required this.added,
    required this.deleted,
    required this.duplicated,
  });
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class VoterLocalComparisonScreen extends StatefulWidget {
  const VoterLocalComparisonScreen({super.key});

  @override
  State<VoterLocalComparisonScreen> createState() =>
      _VoterLocalComparisonScreenState();
}

class _VoterLocalComparisonScreenState
    extends State<VoterLocalComparisonScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  String? _sheet1Name;
  Uint8List? _sheet1Bytes;
  String? _sheet2Name;
  Uint8List? _sheet2Bytes;

  bool _comparing = false;
  _LocalCompareResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── File picking ──────────────────────────────────────────────────────────────

  Future<void> _pickFile(bool isSheet1) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    setState(() {
      if (isSheet1) {
        _sheet1Name = f.name;
        _sheet1Bytes = f.bytes;
      } else {
        _sheet2Name = f.name;
        _sheet2Bytes = f.bytes;
      }
      _result = null;
      _error = null;
    });
  }

  // ── Parsing ───────────────────────────────────────────────────────────────────

  List<_LocalVoter> _parseFile(Uint8List bytes, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'csv') return _parseCsv(bytes);
    return _parseExcel(bytes);
  }

  List<_LocalVoter> _parseCsv(Uint8List bytes) {
    final content = String.fromCharCodes(bytes)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.length < 2) return [];
    final headers = rows[0].map((c) => c.toString().trim()).toList();
    final dataRows = rows
        .sublist(1)
        .map((r) => r.map((c) => c.toString().trim()).toList())
        .toList();
    return _rowsToVoters(headers, dataRows);
  }

  List<_LocalVoter> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) return [];
    final headers = sheet.rows[0].map((c) => _cellStr(c)).toList();
    final dataRows =
        sheet.rows.sublist(1).map((r) => r.map(_cellStr).toList()).toList();
    return _rowsToVoters(headers, dataRows);
  }

  String _cellStr(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  String _norm(String h) =>
      h.toLowerCase().trim().replaceAll(RegExp(r'[\s_\-./()]+'), '');

  List<_LocalVoter> _rowsToVoters(
      List<String> headers, List<List<String>> dataRows) {
    String? col(List<String> candidates) {
      final normCandidates = candidates.map(_norm).toSet();
      for (final h in headers) {
        if (normCandidates.contains(_norm(h))) return h;
      }
      return null;
    }

    String val(List<String> row, String? header) {
      if (header == null) return '';
      final idx = headers.indexOf(header);
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    final voterIdCol = col([
      'voter_id_number', 'voteridnumber', 'voter id', 'voter id number',
      'epicno', 'epic no', 'epic number', 'epicnumber', 'id number',
    ]);
    final nameCol = col(['voter_name', 'votername', 'voter name', 'name']);
    final relTypeCol = col([
      'relative_type', 'relativetype', 'relation type', 'reltype',
      'rel type', 's/o d/o w/o',
    ]);
    final relNameCol = col([
      'relative_name', 'relativename', 'relative name',
      'father/husband name', 'father name', 'fathername', 'husband name',
    ]);
    final genderCol   = col(['gender', 'sex']);
    final ageCol      = col(['age', 'voter age', 'voterage']);
    final addressCol  = col(['address', 'full address', 'house address', 'fulladdress']);
    final houseNoCol  = col([
      'house_number', 'houseno', 'house no', 'house number',
      'door no', 'doorno', 'door number',
    ]);
    final boothNoCol  = col([
      'booth_number', 'boothnumber', 'booth no', 'booth number',
      'part no', 'partno', 'part number', 'partnumber',
    ]);
    final boothNameCol = col(['booth_name', 'boothname', 'booth name', 'part name', 'partname']);
    final phoneCol    = col([
      'phone', 'mobile', 'phone number', 'mobilenumber',
      'contact', 'mobile no', 'phone no',
    ]);
    final serialCol   = col([
      'serial_no', 'serialno', 'serial no', 's.no', 'sno',
      'sl no', 'sl.no', 'slno',
    ]);
    final casteCol    = col(['caste', 'community', 'religion caste']);

    return dataRows
        .where((r) => r.any((c) => c.isNotEmpty))
        .map((r) => _LocalVoter(
              voterIdNumber: val(r, voterIdCol),
              voterName:     val(r, nameCol),
              relativeType:  val(r, relTypeCol),
              relativeName:  val(r, relNameCol),
              gender:        val(r, genderCol),
              age:           val(r, ageCol),
              address:       val(r, addressCol),
              houseNumber:   val(r, houseNoCol),
              boothNumber:   val(r, boothNoCol),
              boothName:     val(r, boothNameCol),
              phone:         val(r, phoneCol),
              serialNo:      val(r, serialCol),
              caste:         val(r, casteCol),
            ))
        .toList();
  }

  // ── Comparison logic ──────────────────────────────────────────────────────────

  Future<void> _compare() async {
    if (_sheet1Bytes == null || _sheet2Bytes == null) return;
    setState(() { _comparing = true; _error = null; _result = null; });

    try {
      await Future.delayed(Duration.zero);

      final s1 = _parseFile(_sheet1Bytes!, _sheet1Name!);
      final s2 = _parseFile(_sheet2Bytes!, _sheet2Name!);

      // One entry per voter_id (first occurrence wins) for exact counts.
      Map<String, _LocalVoter> buildMap(List<_LocalVoter> voters) {
        final map = <String, _LocalVoter>{};
        for (final v in voters) {
          final key = v.voterIdNumber.trim().toUpperCase();
          if (key.isEmpty) continue;
          map.putIfAbsent(key, () => v);
        }
        return map;
      }

      final map1 = buildMap(s1); // previous file
      final map2 = buildMap(s2); // present file

      final added      = <_LocalVoter>[];
      final duplicated = <_LocalVoter>[];

      // Partition present file: voter_id in both → duplicated, only in present → added
      for (final e in map2.entries) {
        if (map1.containsKey(e.key)) {
          duplicated.add(e.value);
        } else {
          added.add(e.value);
        }
      }

      // Deleted: voter_id in previous but NOT in present
      final deleted = <_LocalVoter>[];
      for (final e in map1.entries) {
        if (!map2.containsKey(e.key)) deleted.add(e.value);
      }

      setState(() {
        _result = _LocalCompareResult(
          sheet1Total: s1.length,
          sheet2Total: s2.length,
          added:       added,
          deleted:     deleted,
          duplicated:  duplicated,
        );
        _comparing = false;
      });
      _tabCtrl.animateTo(0);
    } catch (e) {
      setState(() {
        _error = 'Failed to parse file: $e';
        _comparing = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Compare Local Files',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _result;
    if (r == null) {
      return SingleChildScrollView(
        child: Column(children: [
          _buildFilePickers(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
        ]),
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (ctx, inner) => [
        SliverToBoxAdapter(child: _buildFilePickers()),
        SliverToBoxAdapter(child: _buildSummaryCard(r)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabDelegate(_tabCtrl, r),
        ),
      ],
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildVoterList(r.added,      AppColors.success,          'No new voters were added.'),
          _buildVoterList(r.deleted,    AppColors.error,            'No voters were deleted.'),
          _buildVoterList(r.duplicated, const Color(0xFFFFB300),    'No voters found in both files.'),
        ],
      ),
    );
  }

  // ── File picker card ──────────────────────────────────────────────────────────

  Widget _buildFilePickers() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Files to Compare',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Supports CSV and Excel (.xlsx) files. Voters are matched by Voter ID Number.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _filePickerTile(
            label: 'Previous Sheet (Old Upload)',
            icon:  Icons.history,
            color: AppColors.error,
            name:  _sheet1Name,
            onTap: () => _pickFile(true),
          ),
          const SizedBox(height: 10),
          _filePickerTile(
            label: 'Present Sheet (New Upload)',
            icon:  Icons.upload_file,
            color: AppColors.success,
            name:  _sheet2Name,
            onTap: () => _pickFile(false),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_sheet1Bytes != null && _sheet2Bytes != null && !_comparing)
                      ? _compare
                      : null,
              icon: _comparing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compare_arrows),
              label: Text(_comparing ? 'Comparing…' : 'Compare Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filePickerTile({
    required String label,
    required IconData icon,
    required Color color,
    required String? name,
    required VoidCallback onTap,
  }) {
    final picked = name != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: picked
              ? color.withValues(alpha: 0.06)
              : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: picked ? color.withValues(alpha: 0.45) : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'Tap to select CSV / Excel file',
                    style: TextStyle(
                      fontSize: 13,
                      color: picked ? AppColors.textPrimary : AppColors.textMuted,
                      fontWeight: picked ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              picked ? Icons.check_circle : Icons.folder_open,
              size: 20,
              color: picked ? color : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(_LocalCompareResult r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparison Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip('Previous',  r.sheet1Total,       AppColors.textSecondary,   Icons.history),
              const SizedBox(width: 6),
              _statChip('Current',   r.sheet2Total,       AppColors.primary,         Icons.people),
              const SizedBox(width: 6),
              _statChip('Added',     r.added.length,      AppColors.success,         Icons.person_add),
              const SizedBox(width: 6),
              _statChip('Deleted',   r.deleted.length,    AppColors.error,           Icons.person_remove),
              const SizedBox(width: 6),
              _statChip('Duplicate', r.duplicated.length, const Color(0xFFFFB300),   Icons.content_copy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Voter list ────────────────────────────────────────────────────────────────

  Widget _buildVoterList(
      List<_LocalVoter> voters, Color accent, String emptyMsg) {
    if (voters.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(emptyMsg,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: voters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LocalVoterCard(voter: voters[i], accent: accent),
    );
  }
}

// ─── STICKY TAB DELEGATE ──────────────────────────────────────────────────────

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final TabController       _tabCtrl;
  final _LocalCompareResult _result;

  _StickyTabDelegate(this._tabCtrl, this._result);

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.white,
      elevation: overlapsContent ? 2 : 0,
      child: TabBar(
        controller: _tabCtrl,
        labelColor:           AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor:       AppColors.primary,
        indicatorWeight:      3,
        tabs: [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_add, size: 14),
              const SizedBox(width: 4),
              Text('Added (${_result.added.length})',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_remove, size: 14),
              const SizedBox(width: 4),
              Text('Deleted (${_result.deleted.length})',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.content_copy, size: 14),
              const SizedBox(width: 4),
              Text('Duplicate (${_result.duplicated.length})',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabDelegate old) =>
      _tabCtrl != old._tabCtrl || _result != old._result;
}

// ─── LOCAL VOTER CARD ─────────────────────────────────────────────────────────

class _LocalVoterCard extends StatelessWidget {
  final _LocalVoter voter;
  final Color accent;

  const _LocalVoterCard({required this.voter, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Text(
                    voter.voterName.isNotEmpty
                        ? voter.voterName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voter.voterName.isNotEmpty ? voter.voterName : 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (voter.relativeDisplay.isNotEmpty)
                        Text(
                          voter.relativeDisplay,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (voter.voterIdNumber.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      voter.voterIdNumber,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (voter.serialNo.isNotEmpty)
                  _chip(Icons.tag, 'S.No ${voter.serialNo}'),
                if (voter.age.isNotEmpty)
                  _chip(Icons.cake,
                      '${voter.age} yrs${voter.gender.isNotEmpty ? ' • ${voter.gender}' : ''}'),
                if (voter.boothNumber.isNotEmpty)
                  _chip(Icons.how_to_vote, 'Booth ${voter.boothNumber}'),
                if (voter.boothName.isNotEmpty)
                  _chip(Icons.location_on, voter.boothName),
                if (voter.address.isNotEmpty) _chip(Icons.home, voter.address),
                if (voter.phone.isNotEmpty)   _chip(Icons.phone, voter.phone),
                if (voter.caste.isNotEmpty)   _chip(Icons.group, voter.caste),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
