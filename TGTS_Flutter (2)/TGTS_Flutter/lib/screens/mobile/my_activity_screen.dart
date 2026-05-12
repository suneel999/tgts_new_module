import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';

// ─── MODEL ────────────────────────────────────────────────────────────────────

class ActivityPost {
  final String id;
  final String userId;
  final String userName;
  final String userDesignation;
  final String title;
  final String description;
  final String location;
  final List<String> imageUrls;
  final DateTime createdAt;
  bool isUploading;

  ActivityPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userDesignation,
    required this.title,
    required this.description,
    required this.location,
    required this.imageUrls,
    required this.createdAt,
    this.isUploading = false,
  });

  factory ActivityPost.fromJson(Map<String, dynamic> json) {
    return ActivityPost(
      id:              json['id'] ?? '',
      userId:          json['userId'] ?? '',
      userName:        json['userName'] ?? 'Unknown',
      userDesignation: json['userDesignation'] ?? '',
      title: (json['title'] is Map)
          ? (json['title']['en'] ?? '')
          : (json['title'] ?? ''),
      description: (json['description'] is Map)
          ? (json['description']['en'] ?? '')
          : (json['description'] ?? ''),
      location:  json['location'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ─── MAIN SCREEN ──────────────────────────────────────────────────────────────

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({Key? key}) : super(key: key);

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<ActivityPost> _myPosts   = [];
  final List<ActivityPost> _feedPosts = [];

  bool _isLoadingMy   = true;
  bool _isLoadingFeed = true;
  bool _hasErrorMy    = false;
  bool _hasErrorFeed  = false;
  String _feedErrorMsg = 'Something went wrong.';
  String _myErrorMsg   = 'Something went wrong.';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyPosts();
    _loadFeedPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _token =>
      Provider.of<AuthService>(context, listen: false).accessToken;

  String get _userName =>
      Provider.of<AuthService>(context, listen: false).currentUser?.name ?? 'You';

  String get _currentUserId =>
      Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';

  // ── Load my posts ─────────────────────────────────────────────────────────

  Future<void> _loadMyPosts() async {
    if (!mounted) return;
    setState(() { _isLoadingMy = true; _hasErrorMy = false; });
    try {
      final token = _token;
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _hasErrorMy  = true;
          _myErrorMsg  = 'Please login again.';
          _isLoadingMy = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/activities/my'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List list = data['activities'] ?? [];
        setState(() {
          _myPosts
            ..clear()
            ..addAll(list.map((a) => ActivityPost.fromJson(a)));
          _isLoadingMy = false;
        });
      } else {
        setState(() {
          _hasErrorMy  = true;
          _myErrorMsg  = 'Failed to load. (Error ${res.statusCode})';
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasErrorMy  = true;
        _myErrorMsg  = 'Network error. Check your connection.';
        _isLoadingMy = false;
      });
    }
  }

  // ── Load feed posts ───────────────────────────────────────────────────────

  Future<void> _loadFeedPosts() async {
    if (!mounted) return;
    setState(() { _isLoadingFeed = true; _hasErrorFeed = false; });
    try {
      final token = _token;
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _hasErrorFeed  = true;
          _feedErrorMsg  = 'Please login again.';
          _isLoadingFeed = false;
        });
        return;
      }

      final url = '${ApiConfig.baseUrl}/activities';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List list = data['activities'] ?? [];
        setState(() {
          _feedPosts
            ..clear()
            ..addAll(list.map((a) => ActivityPost.fromJson(a)));
          _isLoadingFeed = false;
        });
      } else {
        setState(() {
          _hasErrorFeed  = true;
          _feedErrorMsg  = 'Failed to load feed. (Error ${res.statusCode})';
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasErrorFeed  = true;
        _feedErrorMsg  = 'Network error. Check your connection.';
        _isLoadingFeed = false;
      });
    }
  }

  // ── Upload new post ───────────────────────────────────────────────────────

  Future<void> _uploadPost(String title, String description,
      String location, List<XFile> images) async {

    final tempPost = ActivityPost(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      userId:          _currentUserId,
      userName:        _userName,
      userDesignation: '',
      title:           title,
      description:     description,
      location:        location,
      imageUrls:       [],
      createdAt:       DateTime.now(),
      isUploading:     true,
    );

    setState(() => _myPosts.insert(0, tempPost));

    try {
      final token = _token;
      if (token == null) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/activities/upload'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['title']       = json.encode({'en': title, 'te': title})
        ..fields['description'] =
        json.encode({'en': description, 'te': description});

      if (location.isNotEmpty) request.fields['location'] = location;

      for (final img in images) {
        request.files.add(await http.MultipartFile.fromPath(
          'images', img.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 201) {
        final newPost = ActivityPost.fromJson(json.decode(res.body));
        setState(() {
          final idx = _myPosts.indexWhere((p) => p.id == tempPost.id);
          if (idx != -1) _myPosts[idx] = newPost;
        });
        _loadFeedPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Post published successfully!'),
            backgroundColor: AppColors.success,
          ));
        }
      } else {
        setState(
                () => _myPosts.removeWhere((p) => p.id == tempPost.id));
        _showError('Failed to publish. Please try again.');
      }
    } catch (e) {
      setState(() => _myPosts.removeWhere((p) => p.id == tempPost.id));
      _showError('Network error. Please try again.');
    }
  }

  // ── Delete post ───────────────────────────────────────────────────────────

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePost(id);
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _deletePost(String id) async {
    try {
      final token = _token;
      if (token == null) return;
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/activities/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          _myPosts.removeWhere((p) => p.id == id);
          _feedPosts.removeWhere((p) => p.id == id);
        });
      }
    } catch (_) {
      _showError('Failed to delete. Try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        userName: _userName,
        onSubmit: (title, desc, loc, images) =>
            _uploadPost(title, desc, loc, images),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Activity Feed',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor:       Colors.white,
          indicatorWeight:      3,
          labelColor:           Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'My Posts'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Feed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(
            posts:        _myPosts,
            isLoading:    _isLoadingMy,
            hasError:     _hasErrorMy,
            errorMsg:     _myErrorMsg,
            onRefresh:    _loadMyPosts,
            showDelete:   true,
            emptyMessage: 'No posts yet!\nTap "+ New Post" to share.',
          ),
          _buildList(
            posts:        _feedPosts,
            isLoading:    _isLoadingFeed,
            hasError:     _hasErrorFeed,
            errorMsg:     _feedErrorMsg,
            onRefresh:    _loadFeedPosts,
            showDelete:   false,
            emptyMessage: 'No activities in the feed yet.',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       _openCreatePost,
        backgroundColor: AppColors.primary,
        icon:  const Icon(Icons.add, color: Colors.white),
        label: const Text('New Post',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildList({
    required List<ActivityPost> posts,
    required bool isLoading,
    required bool hasError,
    required String errorMsg,
    required Future<void> Function() onRefresh,
    required bool showDelete,
    required String emptyMessage,
  }) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      );
    }
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 80),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color:     AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: posts.length,
        itemBuilder: (_, i) => _PostCard(
          post:          posts[i],
          showDelete:    showDelete,
          currentUserId: _currentUserId,
          onDelete:      () => _confirmDelete(posts[i].id),
        ),
      ),
    );
  }
}

// ─── POST CARD ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final ActivityPost post;
  final bool         showDelete;
  final String       currentUserId;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.showDelete,
    required this.currentUserId,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = post.userId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset:     const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius:          22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    post.userName.isNotEmpty
                        ? post.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize:   18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(_formatDate(post.createdAt),
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                          if (post.location.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(post.location,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.isUploading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                else if (showDelete && isOwner)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Title ──
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(post.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.4)),
            ),

          // ── Description ──
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(post.description,
                  style: TextStyle(
                      color: Colors.grey[700], fontSize: 14, height: 1.5)),
            ),
          ],

          // ── Images ──
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImages(post.imageUrls),
          ],

          if (post.isUploading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Uploading...',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildImages(List<String> urls) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: Image.network(urls[0],
            width: double.infinity, height: 240, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey)))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap:     true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 6,
        mainAxisSpacing:  6,
        children: urls.take(4).map((url) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey))),
        )).toList(),
      ),
    );
  }
}

// ─── CREATE POST BOTTOM SHEET ─────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final String userName;
  final Function(String title, String description, String location,
      List<XFile> images) onSubmit;

  const _CreatePostSheet({required this.userName, required this.onSubmit});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  bool _isSubmitting = false;

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        final remaining = 4 - _images.length;
        _images.addAll(picked.take(remaining));
      });
    }
  }

  Future<void> _pickVideo() async {
    await _picker.pickVideo(source: ImageSource.gallery);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Video selected! (Upload coming soon)'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final desc  = _descCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a title.'),
          backgroundColor: Colors.orange));
      return;
    }
    if (desc.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a description or at least one photo.'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isSubmitting = true);
    widget.onSubmit(
        title, desc, _locationCtrl.text.trim(), List.from(_images));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.6,
      maxChildSize:     0.96,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [

              // ── Blue header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_note,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Post',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   20,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Share your activity with the community',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ──
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _label('Title', required: true),
                      const SizedBox(height: 8),
                      _field(controller: _titleCtrl,
                          hint: 'Enter activity title...',
                          icon: Icons.title, maxLines: 1, maxLength: 100),

                      const SizedBox(height: 16),

                      _label('Description', required: true),
                      const SizedBox(height: 8),
                      _field(controller: _descCtrl,
                          hint: 'Describe your activity...',
                          icon: Icons.notes, maxLines: 5, maxLength: 500),

                      const SizedBox(height: 16),

                      _label('Location'),
                      const SizedBox(height: 8),
                      _field(controller: _locationCtrl,
                          hint: 'Add location (optional)',
                          icon: Icons.location_on_outlined, maxLines: 1),

                      const SizedBox(height: 20),

                      _label('Add Media'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _mediaBtn(
                              icon:      Icons.photo_library_outlined,
                              label:     'Photos',
                              bgColor:   const Color(0xFFE3F2FD),
                              iconColor: AppColors.primary,
                              onTap:     _images.length < 4 ? _pickPhotos : null,
                              badge:     _images.isNotEmpty ? '${_images.length}/4' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _mediaBtn(
                              icon:      Icons.videocam_outlined,
                              label:     'Video',
                              bgColor:   const Color(0xFFF3E5F5),
                              iconColor: const Color(0xFF9C27B0),
                              onTap:     _pickVideo,
                            ),
                          ),
                        ],
                      ),

                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:       _images.length,
                            itemBuilder: (_, i) => Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 90, height: 90,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                        File(_images[i].path),
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 2, right: 10,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _images.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: _isSubmitting
                              ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upload, color: Colors.white),
                          label: Text(
                            _isSubmitting ? 'Publishing...' : 'Publish Post',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines:   maxLines,
      maxLength:  maxLength,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled:     true,
        fillColor:  const Color(0xFFF5F5F5),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize:   15,
                color:      Colors.black87)),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(color: Colors.red, fontSize: 15)),
        ],
      ],
    );
  }

  Widget _mediaBtn({
    required IconData icon,
    required String   label,
    required Color    bgColor,
    required Color    iconColor,
    VoidCallback?     onTap,
    String?           badge,
  }) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color:        active ? bgColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? iconColor.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? iconColor : Colors.grey, size: 28),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        color:      active ? iconColor : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize:   14)),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color:        iconColor,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}