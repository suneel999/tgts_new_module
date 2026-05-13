import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/index.dart';
import '../../utils/timezone.dart';
import '../../utils/lang_ext.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/media_cache_service.dart';
import '../../utils/app_colors.dart';
import '../../mixins/access_level_filter_mixin.dart';
import '../../widgets/access_level_filter_chips.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen>
    with SingleTickerProviderStateMixin, AccessLevelFilterMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final MediaCacheService _cacheService = MediaCacheService();
  List<MediaItem> _allPhotos = [];
  List<MediaItem> _allVideos = [];
  List<MediaItem> _photos = [];
  List<MediaItem> _videos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _videoInitialized = {};
  final Map<String, String?> _extractedThumbnails = {}; // Cache for extracted thumbnails
  static bool _dateFormattingInitialized = false;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    // Initialize user role and filters, then load media
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoad();
    });
  }

  Future<void> _initializeAndLoad() async {
    initializeFilters();
    // Clear cache once to ensure fresh data with correct access_level format
    // This is a one-time clear after the backend fix
    final prefs = await SharedPreferences.getInstance();
    final cacheCleared = prefs.getBool('media_cache_cleared_v2') ?? false;
    if (!cacheCleared) {
      await _cacheService.clearAllCache();
      await prefs.setBool('media_cache_cleared_v2', true);
    }
    await _loadMediaFromCacheFirst();
  }

  void _applyFilter() {
    setState(() {
      _photos = applyFilters(
        _allPhotos,
        (item) => item.accessLevel,
      );
      _videos = applyFilters(
        _allVideos,
        (item) => item.accessLevel,
      );
    });
  }


  void _openUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserMediaUploadSheet(
        onSubmit: _uploadUserMedia,
      ),
    );
  }

  Future<void> _uploadUserMedia(
      String titleEn, String titleTe, String type, XFile file) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.accessToken;

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.lang == Language.en
                ? 'Session expired. Please log in again to upload media.'
                : 'సెషన్ ముగిసింది. మీడియా అప్‌లోడ్ చేయడానికి మళ్లీ లాగిన్ అవ్వండి.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final result = await ApiService().uploadMedia(
        authToken: token,
        filePath: file.path,
        titleEn: titleEn,
        titleTe: titleTe,
        type: type,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Media uploaded successfully!'
                  : 'మీడియా విజయవంతంగా అప్‌లోడ్ చేయబడింది!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadMediaFromNetwork();
      } else {
        final statusCode = result['statusCode'] as int?;
        String errorMsg;
        if (statusCode == 401 || statusCode == 422) {
          errorMsg = context.lang == Language.en
              ? 'Authentication failed. Please log in again.'
              : 'ప్రమాణీకరణ విఫలమైంది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.';
        } else if (result['error'] == 'timeout_error') {
          errorMsg = context.lang == Language.en
              ? 'Upload timed out. Check your connection and try again.'
              : 'అప్‌లోడ్ సమయం ముగిసింది. మళ్లీ ప్రయత్నించండి.';
        } else if (result['error'] == 'network_error') {
          errorMsg = context.lang == Language.en
              ? 'No internet connection. Please check your network.'
              : 'నెట్‌వర్క్ లోపం. దయచేసి మళ్లీ ప్రయత్నించండి.';
        } else {
          errorMsg = result['message']?.toString() ??
              (context.lang == Language.en
                  ? 'Upload failed. Please try again.'
                  : 'అప్‌లోడ్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Request notification permission
      await androidImplementation?.requestNotificationsPermission();
      
      // Create notification channel for Android 8.0+
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'downloads_channel',
          'Downloads',
          description: 'Notifications for downloaded media',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - file is now in gallery, just show a message
    if (response.payload != null && response.payload!.isNotEmpty) {
      // Try to open if file exists (for backwards compatibility)
      final filePath = response.payload!;
      if (File(filePath).existsSync()) {
        _openDownloadedMedia(filePath);
      } else {
        // File is in gallery, show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File saved to gallery'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _openDownloadedMedia(String filePath) async {
    if (!await File(filePath).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show the downloaded image/video in a dialog
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: Image.file(
                    File(filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 80),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDownloadNotification(
    Language language,
    String title,
    String filePath,
    bool isVideo,
  ) async {
    try {
      final notificationTitle = language == Language.en
          ? 'Download Complete'
          : 'డౌన్‌లోడ్ పూర్తయింది';
      
      final notificationBody = language == Language.en
          ? 'Downloaded successfully: ${title.isEmpty ? "Media" : title}'
          : 'విజయవంతంగా డౌన్‌లోడ్ చేయబడింది: ${title.isEmpty ? "మీడియా" : title}';

      // Android notification details
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'downloads_channel',
        'Downloads',
        channelDescription: 'Notifications for downloaded media',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      // iOS notification details
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combined notification details
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Show notification with file path as payload
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      print('Displaying notification with ID: $notificationId');
      await _notifications.show(
        notificationId,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
        payload: filePath, // Pass file path to open on tap
      );
      print('Notification displayed successfully');
    } catch (e) {
      print('Error showing notification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Load media from cache first, then update from network
  Future<void> _loadMediaFromCacheFirst() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (!_dateFormattingInitialized) {
        await initializeDateFormatting('en', null);
        await initializeDateFormatting('te', null);
        _dateFormattingInitialized = true;
      }

      // Load from cache first for offline support
      final cachedPhotos = await _cacheService.getCachedPhotos();
      final cachedVideos = await _cacheService.getCachedVideos();

      if (mounted) {
        setState(() {
          _allPhotos = cachedPhotos;
          _allVideos = cachedVideos;
          _photos = cachedPhotos;
          _videos = cachedVideos;
          _isLoading = false;
        });
        _applyFilter();

        // Preload thumbnails in background
        if (cachedPhotos.isNotEmpty) {
          final imageUrls = cachedPhotos
              .map((photo) => (photo.thumbnail != null && photo.thumbnail!.isNotEmpty)
                  ? photo.thumbnail!
                  : photo.url)
              .toList();
          _cacheService.preloadImages(imageUrls);
        }

        if (cachedVideos.isNotEmpty) {
          final thumbnailUrls = cachedVideos
              .map((video) => (video.thumbnail != null && video.thumbnail!.isNotEmpty)
                  ? video.thumbnail!
                  : video.url)
              .toList();
          _cacheService.preloadVideoThumbnails(thumbnailUrls);
        }
      }

      // Now try to update from network
      _loadMediaFromNetwork();
    } catch (e) {
      print('Error loading media from cache: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Still try to load from network
      _loadMediaFromNetwork();
    }
  }

  // Load media from network and update cache
  Future<void> _loadMediaFromNetwork() async {
    try {
      // Get auth token if user is authenticated
      final authService = Provider.of<AuthService>(context, listen: false);
      final authToken = authService.accessToken;
      
      // Load photos
      final photosResult = await _apiService.getMedia(
        page: 1,
        perPage: 50,
        type: 'photo',
        authToken: authToken,
      );

      // Load videos
      final videosResult = await _apiService.getMedia(
        page: 1,
        perPage: 50,
        type: 'video',
        authToken: authToken,
      );

      if (!mounted) return;
      setState(() {
        if (photosResult['success'] && photosResult['data'] != null) {
          try {
            final data = photosResult['data'];
            _allPhotos = (data['media'] as List?)
                    ?.map((item) {
                      try {
                        return MediaItem.fromJson(item as Map<String, dynamic>);
                      } catch (e) {
                        print('Error parsing photo item: $e');
                        return null;
                      }
                    })
                    .whereType<MediaItem>()
                    .toList() ?? [];

            _cacheService.cachePhotosList(_allPhotos);
            final imageUrls = _allPhotos
                .map((photo) => (photo.thumbnail != null && photo.thumbnail!.isNotEmpty)
                    ? photo.thumbnail!
                    : photo.url)
                .toList();
            _cacheService.preloadImages(imageUrls);
          } catch (e) {
            print('Error parsing photos response: $e');
          }
        }

        if (videosResult['success'] && videosResult['data'] != null) {
          try {
            final data = videosResult['data'];
            _allVideos = (data['media'] as List?)
                    ?.map((item) {
                      try {
                        return MediaItem.fromJson(item as Map<String, dynamic>);
                      } catch (e) {
                        print('Error parsing video item: $e');
                        return null;
                      }
                    })
                    .whereType<MediaItem>()
                    .toList() ?? [];

            _cacheService.cacheVideosList(_allVideos);
            final thumbnailUrls = _allVideos
                .map((video) => (video.thumbnail != null && video.thumbnail!.isNotEmpty)
                    ? video.thumbnail!
                    : video.url)
                .toList();
            _cacheService.preloadVideoThumbnails(thumbnailUrls);
          } catch (e) {
            print('Error parsing videos response: $e');
          }
        }
      });
      // Apply filter and save sync time outside setState to avoid nested setState
      if (mounted) {
        _applyFilter();
        _cacheService.saveLastSyncTime();
      }
    } catch (e) {
      print('Error loading media from network: $e');
      // If network fails, cached data is already displayed
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      floatingActionButton: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (authService.accessToken == null) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: _isUploading ? null : _openUploadSheet,
            backgroundColor: AppColors.primary,
            tooltip: context.lang == Language.en ? 'Upload Media' : 'మీడియా అప్‌లోడ్',
            child: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate, color: Colors.white),
          );
        },
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.primary,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    // Clear cache and reload
                    await _cacheService.clearAllCache();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('media_cache_cleared_v2', false);
                    await _loadMediaFromCacheFirst();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  context.lang == Language.en ? 'Media' : 'మీడియా',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorScheme.primary, colorScheme.primaryContainer],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo_library,
                      size: 80,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 18),
                          const SizedBox(width: 6),
                          Text(context.lang == Language.en ? 'Photos' : 'ఫోటోలు'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 18),
                          const SizedBox(width: 6),
                          Text(context.lang == Language.en ? 'Videos' : 'వీడియోలు'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips
            if (availableAccessLevels.isNotEmpty)
              SliverToBoxAdapter(
                child: AccessLevelFilterChips(
                  availableAccessLevels: availableAccessLevels,
                  selectedAccessLevel: selectedAccessLevel,
                  onLevelSelected: (level) {
                    setSelectedAccessLevel(level);
                    _applyFilter();
                  },
                ),
              ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPhotosGrid(),
            _buildVideosGrid(),
          ],
        ),
      ),
    );
  }


  Widget _buildPhotosGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_photos.isEmpty) {
      return Center(
        child: Text(
          context.lang == Language.en
              ? 'No photos available'
              : 'ఫోటోలు అందుబాటులో లేవు',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Adjusted for title and date below
      ),
      // Lazy loading: only load visible items
      cacheExtent: 500,
      itemCount: _photos.length,
      itemBuilder: (context, index) {
          final photo = _photos[index];
          final imageUrl = (photo.thumbnail != null && photo.thumbnail!.isNotEmpty)
              ? photo.thumbnail!
              : photo.url;

          // Cache image in background when it comes into view
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (index < _photos.length) {
              _cacheService.cacheImage(imageUrl);
            }
          });

          return _buildPhotoCard(
            context: context,
            url: imageUrl,
            mediaUrl: photo.url,
            title: photo.title,
            date: photo.date,
            index: index,
          );
        },
    );
  }

  // Photo card with title and date below image (matching reference)
  Widget _buildPhotoCard({
    required BuildContext context,
    required String url,
    required String mediaUrl,
    required Map<String, String> title,
    required String date,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {
        _showMediaDialog(context, url, mediaUrl, title, index, false);
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: ClipRect(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                    memCacheWidth: 400,
                    memCacheHeight: 600,
                    maxWidthDiskCache: 800,
                    maxHeightDiskCache: 1200,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.lang == Language.en ? title['en']! : title['te']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date, context.lang),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString, Language lang) {
    try {
      // Parse ISO format and convert to IST
      final date = parseToIST(dateString);
      
      // Format: dd-MMM-yyyy, hh:mm AM/PM (12-hour format with hours and minutes only)
      // Example: 30-Oct-2025, 11:08 AM
      final locale = lang == Language.en ? 'en' : 'te';
      return formatISTForDisplay(date, locale: locale, format: 'hh:mm a, dd MMM yyyy');
    } catch (e) {
      print('Error formatting date: $dateString, error: $e');
      return dateString;
    }
  }

  // Video card with large play button overlay (matching reference)
  // Build thumbnail image widget that handles both network URLs and local file paths
  Widget _buildThumbnailImage(String url) {
    // Check if it's a local file path
    if (url.startsWith('/') || url.startsWith('file://')) {
      final filePath = url.replaceFirst('file://', '');
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              size: 50,
              color: Colors.grey,
            ),
          ),
        );
      }
    }

    // Default to network image
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(
          Icons.broken_image,
          size: 50,
          color: Colors.grey,
        ),
      ),
      memCacheWidth: 400,
      memCacheHeight: 225,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 450,
    );
  }

  Widget _buildVideoCard({
    required BuildContext context,
    required String url,
    required String mediaUrl,
    required Map<String, String> title,
    required String date,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {
        _showMediaDialog(context, url, mediaUrl, title, index, true);
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: _buildThumbnailImage(url),
                  ),
                ),
                // Large play button overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.lang == Language.en ? title['en']! : title['te']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date, context.lang),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem({
    required BuildContext context,
    required String url,
    required String mediaUrl,
    required Map<String, String> title,
    required int index,
    required bool isVideo,
  }) {
          return GestureDetector(
            onTap: () {
              _showMediaDialog(context, url, mediaUrl, title, index, isVideo);
            },
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[300],
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.white,
                          ),
                          memCacheWidth: 400,
                          memCacheHeight: 600,
                          maxWidthDiskCache: 800,
                          maxHeightDiskCache: 1200,
                        ),
                      ),
                    ),
                    if (isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: Text(
                          context.lang == Language.en ? title['en']! : title['te']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildVideosGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Text(
          context.lang == Language.en
              ? 'No videos available'
              : 'వీడియోలు అందుబాటులో లేవు',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _videos.length,
      // Lazy loading: only build items that are visible
      cacheExtent: 500,
      itemBuilder: (context, index) {
          final video = _videos[index];
          String? thumbnailUrl = (video.thumbnail != null && video.thumbnail!.isNotEmpty)
              ? video.thumbnail!
              : null;

          // If no thumbnail, extract from video
          if (thumbnailUrl == null) {
            // Check if we have an extracted thumbnail
            if (_extractedThumbnails.containsKey(video.url)) {
              thumbnailUrl = _extractedThumbnails[video.url];
            } else {
              // Trigger thumbnail extraction in background
              _extractVideoThumbnail(video.url).then((extractedThumbnail) {
                if (mounted && extractedThumbnail != null) {
                  setState(() {
                    // Thumbnail extracted, will rebuild
                  });
                }
              });
            }
          }

          // Fallback to video URL if still no thumbnail (will show placeholder)
          final displayThumbnail = thumbnailUrl ?? video.url;

          // Lazy load video when it comes into view
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (index < _videos.length && !_videoInitialized.containsKey(index)) {
              _initializeVideoIfNeeded(index, video.url);
            }
          });

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildVideoCard(
              context: context,
              url: displayThumbnail,
              mediaUrl: video.url,
              title: video.title,
              date: video.date,
              index: index,
            ),
          );
        },
    );
  }

  // Extract thumbnail from video if not already cached
  Future<String?> _extractVideoThumbnail(String videoUrl) async {
    // Check if we've already extracted this thumbnail
    if (_extractedThumbnails.containsKey(videoUrl)) {
      return _extractedThumbnails[videoUrl];
    }

    try {
      // Try to get cached video first
      File? cachedFile = await _cacheService.getCachedVideoFile(videoUrl);
      String? videoPath;

      if (cachedFile != null && await cachedFile.exists()) {
        videoPath = cachedFile.path;
      } else {
        // For network videos, we need to download first or use network URL
        // video_thumbnail supports network URLs on some platforms
        videoPath = videoUrl;
      }

      // Generate thumbnail from first frame (timeMs: 0)
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 0, // First frame
      );

      if (thumbnailPath != null && await File(thumbnailPath).exists()) {
        _extractedThumbnails[videoUrl] = thumbnailPath;
        return thumbnailPath;
      }
    } catch (e) {
      print('Error extracting video thumbnail: $e');
      // Cache the failure so we don't retry repeatedly
      _extractedThumbnails[videoUrl] = null;
    }

    return null;
  }

  // Lazy initialize video controller when needed
  Future<void> _initializeVideoIfNeeded(int index, String videoUrl) async {
    if (_videoInitialized[index] == true || _videoControllers[index] != null) {
      return;
    }

    _videoInitialized[index] = false;

    try {
      // Try to get cached video first
      File? cachedFile = await _cacheService.getCachedVideoFile(videoUrl);
      VideoPlayerController? controller;

      if (cachedFile != null && await cachedFile.exists()) {
        // Use cached video
        controller = VideoPlayerController.file(cachedFile);
      } else {
        // Use network URL and cache in background
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        // Cache video in background
        _cacheService.cacheVideo(videoUrl);
      }

      await controller.initialize();
      
      if (mounted) {
        setState(() {
          _videoControllers[index] = controller;
          _videoInitialized[index] = true;
        });
      }
    } catch (e) {
      print('Error initializing video $index: $e');
      if (mounted) {
        setState(() {
          _videoInitialized[index] = false;
        });
      }
    }
  }

  Future<void> _shareMedia(BuildContext context, String thumbnailUrl, String mediaUrl, Map<String, String> title, Language language, bool isVideo) async {
    final displayTitle = (language == Language.en ? title['en'] : title['te']) ?? 'Media';

    try {

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Download the media file
      final response = await http.get(Uri.parse(mediaUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download media');
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final extension = isVideo ? 'mp4' : 'jpg';
      final fileName = '${displayTitle!.replaceAll(RegExp(r'[^\w\s]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${tempDir.path}/$fileName');

      // Write file
      await file.writeAsBytes(response.bodyBytes);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share the file (sharePositionOrigin is optional and mainly for iPad)
      // For mobile, we can omit it or use a default rect

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$displayTitle - Telangana Congress',
        subject: displayTitle,
      );

      // Clean up temporary file
      await file.delete();

    } catch (e) {
      print('Error sharing media: $e');

      // Close loading dialog if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == Language.en
                  ? 'Failed to share media. Sharing link instead...'
                  : 'మీడియాను షేర్ చేయడంలో విఫలమైంది. లింక్‌ను షేర్ చేస్తున్నాము...',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        // Fallback to sharing the link
        final shareText = '$displayTitle - Telangana Congress\n$mediaUrl';
        await Share.share(
          shareText,
          subject: displayTitle!,
        );
      }
    }
  }

  Future<void> _downloadMedia(BuildContext context, String mediaUrl, Map<String, String> title, Language language, bool isVideo) async {
    final displayTitle = (language == Language.en ? title['en'] : title['te']) ?? 'Media';
    BuildContext? loadingDialogContext;

    try {
      print('Starting download for: $displayTitle, URL: $mediaUrl');

      // Request permission using system dialog only (no custom dialogs)
      // System will show its native permission dialog
      if (Platform.isAndroid || Platform.isIOS) {
        await Permission.photosAddOnly.request();
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          loadingDialogContext = dialogContext;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Small delay to ensure dialog is shown
      await Future.delayed(const Duration(milliseconds: 100));

      print('Downloading media from: $mediaUrl');

      // Download the media file with timeout
      final response = await http.get(Uri.parse(mediaUrl)).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Download timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download media: HTTP ${response.statusCode}');
      }

      print('Download completed, file size: ${response.bodyBytes.length} bytes');

      // Save to temporary directory first
      final tempDir = await getTemporaryDirectory();
      final extension = isVideo ? 'mp4' : 'jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = displayTitle.replaceAll(RegExp(r'[^\w\s]'), '_').replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${safeTitle}_${timestamp}.$extension';
      final tempFilePath = '${tempDir.path}/$fileName';
      final tempFile = File(tempFilePath);

      print('Saving to temporary file: $tempFilePath');
      print('File size to write: ${response.bodyBytes.length} bytes');

      // Write file to temporary location
      try {
        await tempFile.writeAsBytes(response.bodyBytes);
        
        // Verify file was written
        if (await tempFile.exists()) {
          final savedFileSize = await tempFile.length();
          print('File saved to temp location! Size: $savedFileSize bytes');
          if (savedFileSize != response.bodyBytes.length) {
            print('WARNING: Saved file size ($savedFileSize) does not match downloaded size (${response.bodyBytes.length})');
          }
        } else {
          throw Exception('File was not created after write operation');
        }
      } catch (e) {
        print('Error writing file: $e');
        print('File path: $tempFilePath');
        rethrow;
      }

      // Save to gallery using gal package
      print('Saving to gallery: $tempFilePath');
      try {
        if (isVideo) {
          // For videos, use putVideo method
          await Gal.putVideo(tempFilePath);
          print('Video saved to gallery successfully');
        } else {
          // For images, use putImage method
          await Gal.putImage(tempFilePath);
          print('Image saved to gallery successfully');
        }
      } catch (e) {
        print('Error saving to gallery: $e');
        rethrow;
      } finally {
        // Clean up temporary file
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('Temporary file deleted');
          }
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
      }

      // Close loading dialog
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      }

      // Small delay to ensure dialog is closed before showing snackbar
      await Future.delayed(const Duration(milliseconds: 100));

      // Show success message - use the scaffold context
      if (mounted) {
        final locationInfo = Platform.isAndroid 
          ? 'Gallery'
          : 'Photos';
        
        print('Showing success snackbar');
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              language == Language.en
                  ? 'Saved successfully to $locationInfo'
                  : '$locationInfo కు విజయవంతంగా సేవ్ చేయబడింది',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Show push notification
        print('Showing download notification');
        await _showDownloadNotification(
          language,
          displayTitle,
          '', // Empty payload since file is in gallery
          isVideo,
        );
      }

    } catch (e) {
      print('Error downloading media: $e');

      // Close loading dialog if still open
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
      }

      if (context.mounted) {
        final errorMessage = e.toString();
        final shortError = errorMessage.length > 50 
          ? '${errorMessage.substring(0, 47)}...'
          : errorMessage;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == Language.en
                  ? 'Failed to download media. Error: $shortError'
                  : 'మీడియాను డౌన్‌లోడ్ చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: language == Language.en ? 'Details' : 'వివరాలు',
              textColor: Colors.white,
              onPressed: () {
                print('Full error details: $errorMessage');
                print('Stack trace: ${StackTrace.current}');
              },
            ),
          ),
        );
      }
    }
  }

  void _showMediaDialog(BuildContext context, String url, String mediaUrl, Map<String, String> title, int index, bool isVideo) {
    // Use read instead of watch for event handlers
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final language = languageService.language;
    final displayTitle = language == Language.en ? title['en'] : title['te'];
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.of(context).size;
        // Use 85% of screen height for image, leaving room for buttons and title
        final maxImageHeight = screenSize.height * 0.75;
        final maxImageWidth = screenSize.width * 0.95;
        
        return Consumer<LanguageService>(
          builder: (context, languageService, child) {
            final currentLang = languageService.language;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * 0.9,
                  maxWidth: screenSize.width * 0.95,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button at the top - very visible for users
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.close, size: 24),
                            color: Colors.white,
                            padding: const EdgeInsets.all(8),
                            tooltip: currentLang == Language.en ? 'Close' : 'మూసివేయి',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SizedBox(
                        height: isVideo ? maxImageHeight : maxImageHeight,
                        width: maxImageWidth,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isVideo 
                            ? _VideoPlayerWidget(videoUrl: mediaUrl)
                            : Container(
                                width: double.infinity,
                                height: maxImageHeight,
                                color: Colors.grey[200],
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: maxImageHeight,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  memCacheWidth: 1200,
                                  memCacheHeight: 1200,
                                  maxWidthDiskCache: 2000,
                                  maxHeightDiskCache: 2000,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayTitle ?? 'Media',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  if (!isVideo)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _shareMedia(dialogContext, url, mediaUrl, title, currentLang, false);
                          },
                          icon: const Icon(Icons.share),
                          label: Text(
                            currentLang == Language.en ? 'Share' : 'షేర్ చేయండి',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            // Use the scaffold context, not dialog context
                            _downloadMedia(context, mediaUrl, title, currentLang, false);
                          },
                          icon: const Icon(Icons.download),
                          label: Text(
                            currentLang == Language.en ? 'Download' : 'డౌన్‌లోడ్',
                          ),
                        ),
                      ],
                    ),
                  if (isVideo)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _shareMedia(dialogContext, url, mediaUrl, title, currentLang, true);
                          },
                          icon: const Icon(Icons.share),
                          label: Text(
                            currentLang == Language.en ? 'Share' : 'షేర్ చేయండి',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            // Use the scaffold context, not dialog context
                            _downloadMedia(context, mediaUrl, title, currentLang, true);
                          },
                          icon: const Icon(Icons.download),
                          label: Text(
                            currentLang == Language.en ? 'Download' : 'డౌన్‌లోడ్',
                          ),
                        ),
                      ],
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
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  double _volume = 1.0;
  bool _showVolumeSlider = false;
  Timer? _hideControlsTimer;
  final MediaCacheService _cacheService = MediaCacheService();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Try to get cached video first
      File? cachedFile = await _cacheService.getCachedVideoFile(widget.videoUrl);
      
      if (cachedFile != null && await cachedFile.exists()) {
        // Use cached video for offline support
        _controller = VideoPlayerController.file(cachedFile);
        print('Using cached video: ${cachedFile.path}');
      } else {
        // Use network URL and cache in background
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
        // Cache video in background
        _cacheService.cacheVideo(widget.videoUrl).then((file) {
          if (file != null && _controller != null) {
            print('Video cached successfully: ${file.path}');
          }
        });
      }

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.setVolume(_volume);
        _controller!.play();
        _controller!.setLooping(true);
        _startHideControlsTimer();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller != null && _controller!.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _seekBackward() {
    final currentPosition = _controller!.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _controller!.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _startHideControlsTimer();
  }

  void _seekForward() {
    final currentPosition = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _controller!.seekTo(newPosition > duration ? duration : newPosition);
    _startHideControlsTimer();
  }

  void _toggleFullscreen(BuildContext context) async {
    if (_controller == null) {
      return;
    }

    if (_isFullscreen) {
      Navigator.of(context).maybePop();
      return;
    }

    _hideControlsTimer?.cancel();

    setState(() {
      _isFullscreen = true;
      _showControls = true;
    });

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final updatedVolume = await Navigator.of(context).push<double>(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _FullScreenVideoPage(
          controller: _controller!,
          initialVolume: _volume,
        ),
      ),
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isFullscreen = false;
      _showControls = true;
      if (updatedVolume != null) {
        _volume = updatedVolume.clamp(0.0, 1.0);
        _controller!.setVolume(_volume);
      }
    });

    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.dispose();
    // Reset orientation on dispose
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 8),
              Text(
                'Failed to load video',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          // Controls overlay
          if (_showControls)
            Stack(
              children: [
                // Gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Top controls: Fullscreen button
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _toggleFullscreen(context),
                    tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                  ),
                ),
                // Center: Play/Pause button with skip buttons aligned - vertically centered to screen
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Skip backward button
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                        onPressed: _seekBackward,
                        tooltip: 'Rewind 10s',
                      ),
                      const SizedBox(width: 8),
                      // Play/Pause button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                              _startHideControlsTimer();
                            } else {
                              _controller!.play();
                              _startHideControlsTimer();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Skip forward button
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                        onPressed: _seekForward,
                        tooltip: 'Forward 10s',
                      ),
                    ],
                  ),
                ),
                // Bottom controls: Progress bar, time, volume, seek buttons
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Time label
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar and volume control on the same line
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0, left: 8.0, right: 8.0),
                        child: Row(
                          children: [
                            // Volume control with horizontal slider toggle
                            // Give it space when slider is visible
                            SizedBox(
                              width: _showVolumeSlider ? 156 : 36,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                // Volume icon button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showVolumeSlider = !_showVolumeSlider;
                                    });
                                    _startHideControlsTimer();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      _volume == 0
                                          ? Icons.volume_off
                                          : _volume < 0.5
                                              ? Icons.volume_down
                                              : Icons.volume_up,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                // Horizontal volume slider (shown when toggled) - aligned with seek bar
                                if (_showVolumeSlider)
                                  Positioned(
                                    left: 36,
                                    bottom: 0,
                                    child: Container(
                                      width: 120,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${(_volume * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 3,
                                              thumbShape: const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                              overlayShape: const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                            ),
                                            child: Slider(
                                              value: _volume,
                                              min: 0.0,
                                              max: 1.0,
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.white38,
                                              onChanged: (value) {
                                                setState(() {
                                                  _volume = value;
                                                  _controller!.setVolume(_volume);
                                                });
                                                _startHideControlsTimer();
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Progress bar with red circle thumb and lifted from edge
                            // Reduce size when volume slider is visible
                            Expanded(
                              flex: _showVolumeSlider ? 2 : 3,
                              child: _CustomVideoSeekBar(
                                controller: _controller!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

// Custom video seek bar with red circle thumb (YouTube-style)
class _CustomVideoSeekBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _CustomVideoSeekBar({
    required this.controller,
  });

  @override
  State<_CustomVideoSeekBar> createState() => _CustomVideoSeekBarState();
}

class _CustomVideoSeekBarState extends State<_CustomVideoSeekBar> {
  bool _isDragging = false;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!_isDragging && mounted) {
      setState(() {});
    }
  }

  double _getProgress() {
    if (!widget.controller.value.isInitialized) return 0.0;
    final duration = widget.controller.value.duration;
    if (duration.inMilliseconds == 0) return 0.0;
    return widget.controller.value.position.inMilliseconds /
        duration.inMilliseconds;
  }

  double _getBufferedProgress() {
    if (!widget.controller.value.isInitialized) return 0.0;
    final duration = widget.controller.value.duration;
    if (duration.inMilliseconds == 0) return 0.0;
    
    // Get the buffered end position
    final bufferedEnd = widget.controller.value.buffered.isEmpty
        ? Duration.zero
        : widget.controller.value.buffered.last.end;
    
    return bufferedEnd.inMilliseconds / duration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isDragging ? (_dragValue ?? 0.0) : _getProgress();
    final bufferedProgress = _getBufferedProgress();

    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderWidth = constraints.maxWidth;
        final thumbPosition = (progress.clamp(0.0, 1.0) * sliderWidth) - 8.0;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
            });
          },
          onHorizontalDragUpdate: (details) {
            final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              final actualWidth = renderBox.size.width;
              final newValue = (localPosition.dx / actualWidth).clamp(0.0, 1.0);
              setState(() {
                _dragValue = newValue;
              });
            }
          },
          onHorizontalDragEnd: (details) {
            if (_dragValue != null && widget.controller.value.duration.inMilliseconds > 0) {
              final newPosition = Duration(
                milliseconds: (_dragValue! * widget.controller.value.duration.inMilliseconds).round(),
              );
              widget.controller.seekTo(newPosition);
            }
            setState(() {
              _isDragging = false;
              _dragValue = null;
            });
          },
          onTapDown: (details) {
            final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              final actualWidth = renderBox.size.width;
              final newValue = (localPosition.dx / actualWidth).clamp(0.0, 1.0);
              if (widget.controller.value.duration.inMilliseconds > 0) {
                final newPosition = Duration(
                  milliseconds: (newValue * widget.controller.value.duration.inMilliseconds).round(),
                );
                widget.controller.seekTo(newPosition);
              }
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background track
              Container(
                height: 4.0,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              // Buffered progress (gray)
              FractionallySizedBox(
                widthFactor: bufferedProgress.clamp(0.0, 1.0),
                child: Container(
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              // Played progress (red)
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              // Red circle thumb (larger touch target for easier interaction)
              Positioned(
                left: thumbPosition.clamp(-8.0, sliderWidth - 8.0),
                top: -8.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20.0,
                    height: 20.0,
                    alignment: Alignment.center,
                    child: Container(
                      width: 16.0,
                      height: 16.0,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final double initialVolume;

  const _FullScreenVideoPage({
    required this.controller,
    required this.initialVolume,
  });

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  bool _showControls = true;
  late double _volume;
  bool _showVolumeSlider = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume.clamp(0.0, 1.0);
    widget.controller.setVolume(_volume);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && widget.controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _togglePlayback() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
    _startHideControlsTimer();
  }

  void _seekBackward() {
    final currentPosition = widget.controller.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    widget.controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _startHideControlsTimer();
  }

  void _seekForward() {
    final currentPosition = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    widget.controller
        .seekTo(newPosition > duration ? duration : newPosition);
    _startHideControlsTimer();
  }

  void _updateVolume(double value) {
    setState(() {
      _volume = value;
      widget.controller.setVolume(_volume);
    });
    _startHideControlsTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_volume);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: SizedBox.expand(
            child: Stack(
              children: [
                Center(
                  child: controller.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
            if (_showControls)
              Positioned.fill(
                child: Stack(
                  children: [
                    // Gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                    // Top controls: Exit fullscreen button
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_exit,
                              color: Colors.white, size: 28),
                          onPressed: () {
                            Navigator.of(context).pop(_volume);
                          },
                        ),
                      ),
                    ),
                    // Center: Play/Pause button with skip buttons aligned - vertically centered to screen
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Skip backward button
                          IconButton(
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white, size: 36),
                            onPressed: _seekBackward,
                          ),
                          const SizedBox(width: 12),
                          // Play/Pause button
                          GestureDetector(
                            onTap: _togglePlayback,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Skip forward button
                          IconButton(
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white, size: 36),
                            onPressed: _seekForward,
                          ),
                        ],
                      ),
                    ),
                    // Bottom controls: Progress bar, time, volume, seek buttons
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Time label
                            Text(
                              '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Volume control and progress bar on the same line
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  // Volume control with horizontal slider toggle
                                  // Give it space when slider is visible
                                  SizedBox(
                                    width: _showVolumeSlider ? 190 : 40,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                      // Volume icon button
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showVolumeSlider = !_showVolumeSlider;
                                          });
                                          _startHideControlsTimer();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            _volume == 0
                                                ? Icons.volume_off
                                                : _volume < 0.5
                                                    ? Icons.volume_down
                                                    : Icons.volume_up,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      // Horizontal volume slider (shown when toggled) - aligned with seek bar
                                      if (_showVolumeSlider)
                                        Positioned(
                                          left: 40,
                                          bottom: 0,
                                          child: Container(
                                            width: 150,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${(_volume * 100).round()}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                SliderTheme(
                                                  data: SliderTheme.of(context).copyWith(
                                                    trackHeight: 3,
                                                    thumbShape: const RoundSliderThumbShape(
                                                      enabledThumbRadius: 6,
                                                    ),
                                                    overlayShape: const RoundSliderOverlayShape(
                                                      overlayRadius: 12,
                                                    ),
                                                  ),
                                                  child: Slider(
                                                    value: _volume,
                                                    min: 0.0,
                                                    max: 1.0,
                                                    activeColor: Colors.white,
                                                    inactiveColor: Colors.white38,
                                                    onChanged: _updateVolume,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Progress bar with red circle thumb and lifted from edge
                                  // Reduce size when volume slider is visible
                                  Expanded(
                                    flex: _showVolumeSlider ? 2 : 3,
                                    child: _CustomVideoSeekBar(
                                      controller: controller,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── User Media Upload Sheet ───────────────────────────────────────────────────

class _UserMediaUploadSheet extends StatefulWidget {
  final Future<void> Function(
      String titleEn, String titleTe, String type, XFile file) onSubmit;

  const _UserMediaUploadSheet({required this.onSubmit});

  @override
  State<_UserMediaUploadSheet> createState() => _UserMediaUploadSheetState();
}

class _UserMediaUploadSheetState extends State<_UserMediaUploadSheet> {
  final _titleEnController = TextEditingController();
  final _titleTeController = TextEditingController();
  String _mediaType = 'photo';
  XFile? _pickedFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleEnController.dispose();
    _titleTeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_mediaType == 'photo') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _pickedFile = picked);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) setState(() => _pickedFile = XFile(path));
      }
    }
  }

  Future<void> _submit() async {
    final titleEn = _titleEnController.text.trim();
    final titleTe = _titleTeController.text.trim();

    if (titleEn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title in English')),
      );
      return;
    }
    if (titleTe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title in Telugu')),
      );
      return;
    }
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mediaType == 'photo'
              ? 'Please pick a photo'
              : 'Please pick a video'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(titleEn, titleTe, _mediaType, _pickedFile!);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Media',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your upload will be reviewed by admin before appearing in gallery.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Media type toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _mediaType = 'photo';
                      _pickedFile = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mediaType == 'photo'
                            ? AppColors.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _mediaType == 'photo'
                              ? AppColors.primary
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 18,
                            color: _mediaType == 'photo'
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Photo',
                            style: TextStyle(
                              color: _mediaType == 'photo'
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _mediaType = 'video';
                      _pickedFile = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mediaType == 'video'
                            ? AppColors.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _mediaType == 'video'
                              ? AppColors.primary
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam,
                            size: 18,
                            color: _mediaType == 'video'
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Video',
                            style: TextStyle(
                              color: _mediaType == 'video'
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // English title
            TextField(
              controller: _titleEnController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Title (English)',
                hintText: 'Enter title in English',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Telugu title
            TextField(
              controller: _titleTeController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'శీర్షిక (తెలుగు)',
                hintText: 'తెలుగులో శీర్షిక నమోదు చేయండి',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // File picker
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                height: _pickedFile != null ? null : 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _pickedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _mediaType == 'photo'
                                ? Icons.add_photo_alternate
                                : Icons.video_call,
                            size: 40,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mediaType == 'photo'
                                ? 'Tap to pick photo'
                                : 'Tap to pick video',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _mediaType == 'photo'
                                ? Image.file(
                                    File(_pickedFile!.path),
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.video_file,
                                            size: 36, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _pickedFile!.path.split('/').last,
                                            style: const TextStyle(
                                                fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _pickedFile = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit for Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for SliverPersistentHeader with TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
