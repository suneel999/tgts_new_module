import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/index.dart';
import '../../utils/lang_ext.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../utils/app_colors.dart';
import '../../mixins/access_level_filter_mixin.dart';
import '../../widgets/access_level_filter_chips.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with AccessLevelFilterMixin {
  List<Document> _allDocuments = [];
  List<Document> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // Delay to get context and auth service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndFetch();
    });
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
          'documents_downloads_channel',
          'Document Downloads',
          description: 'Notifications for downloaded documents',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - open the downloaded file
    // This can be called even when the widget is not mounted (app opened from terminated state)
    if (response.payload != null && response.payload!.isNotEmpty) {
      final filePath = response.payload!;
      // Use a delayed call to ensure the app is fully initialized
      // Also check if widget is still mounted before proceeding
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _openDownloadedDocument(filePath);
        } else {
          // If widget is not mounted, just try to open the file directly
          // without showing any UI feedback
          _openFileDirectly(filePath);
        }
      });
    }
  }

  Future<void> _openFileDirectly(String filePath) async {
    // Direct file opening without UI dependencies
    // Used when widget is not mounted (e.g., app opened from notification)
    // Tries to open file location in file explorer, falls back to opening the file
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File not found: $filePath');
        return;
      }

      if (Platform.isAndroid) {
        // For Android, try to open Downloads folder if file is in Downloads
        final dirPath = file.parent.path;
        if (dirPath.contains('/Download')) {
          try {
            // Try to open Downloads folder using content:// URI
            final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (launched) {
              return; // Successfully opened Downloads folder
            }
          } catch (e) {
            debugPrint('Could not open Downloads folder: $e');
          }
        }
        // Fallback: open the file itself
        final fileUri = Uri.file(filePath);
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else if (Platform.isIOS) {
        // For iOS, open the file directly (iOS Files app integration is limited)
        final uri = Uri.file(filePath);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
    }
  }

  Future<void> _openDownloadedDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        // Only show UI feedback if widget is mounted
        if (mounted) {
          try {
            final languageService = Provider.of<LanguageService>(context, listen: false);
            final language = languageService.language;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  language == Language.en
                      ? 'File not found'
                      : 'ఫైల్ కనుగొనబడలేదు',
                ),
                backgroundColor: Colors.red,
              ),
            );
          } catch (e) {
            debugPrint('Error showing snackbar: $e');
          }
        } else {
          // Log error if widget not mounted
          debugPrint('File not found: $filePath');
        }
        return;
      }

      // Try to open file location in file explorer (Downloads folder on Android)
      // Falls back to opening the file itself if that fails
      bool launched = false;
      final dirPath = file.parent.path;

      if (Platform.isAndroid) {
        // For Android, try to open Downloads folder if file is in Downloads
        if (dirPath.contains('/Download')) {
          try {
            // Try to open Downloads folder using content:// URI
            final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Could not open Downloads folder: $e');
          }
        }
        // If opening folder failed or file is not in Downloads, open the file itself
        if (!launched) {
          try {
            final fileUri = Uri.file(filePath);
            launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Error opening file: $e');
          }
        }
      } else if (Platform.isIOS) {
        // For iOS, open the file directly (iOS Files app integration is limited)
        try {
          final uri = Uri.file(filePath);
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Error opening file: $e');
        }
      }

      if (!launched) {
        // Only show UI feedback if widget is mounted
        if (mounted) {
          try {
            final languageService = Provider.of<LanguageService>(context, listen: false);
            final language = languageService.language;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  language == Language.en
                      ? 'Could not open file. File location: $filePath'
                      : 'ఫైల్‌ను తెరవలేకపోయింది. ఫైల్ స్థానం: $filePath',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          } catch (e) {
            debugPrint('Error showing snackbar: $e');
          }
        } else {
          debugPrint('Could not open file: $filePath');
        }
      }
    } catch (e) {
      // Only show UI feedback if widget is mounted
      if (mounted) {
        try {
          final languageService = Provider.of<LanguageService>(context, listen: false);
          final language = languageService.language;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                language == Language.en
                    ? 'Error opening file: ${e.toString()}'
                    : 'ఫైల్‌ను తెరవడంలో లోపం: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } catch (err) {
          debugPrint('Error showing snackbar: $err');
        }
      } else {
        debugPrint('Error opening file: $e');
      }
    }
  }

  Future<void> _initializeAndFetch() async {
    initializeFilters();
    await _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.accessToken;
      final result = await _apiService.getDocuments(
        page: 1,
        perPage: 100,
        authToken: token,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final documentsList = data['documents'] as List<dynamic>? ?? [];

        final documents = documentsList.map((docJson) {
          try {
            return Document.fromJson(docJson as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing document: $e');
            return null;
          }
        }).whereType<Document>().toList();

        if (mounted) {
          setState(() {
            _allDocuments = documents;
            _isLoading = false;
          });
          // Apply filter after setting documents
          _applyFilter();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load documents';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _documents = applyFilters(
        _allDocuments,
        (doc) => doc.accessLevel,
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.primary,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
                onPressed: () => context.go('/home'),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: _fetchDocuments,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  context.lang == Language.en ? 'Documents' : 'పత్రాలు',
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
                      Icons.description,
                      size: 80,
                      color: colorScheme.onPrimary,
                    ),
                  ),
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
        body: _buildDocumentsList(),
      ),
    );
  }


  Widget _buildDocumentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: Text(
                context.lang == Language.en ? 'Retry' : 'మళ్లీ ప్రయత్నించండి',
              ),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              context.lang == Language.en
                  ? 'No documents available'
                  : 'పత్రాలు అందుబాటులో లేవు',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final document = _documents[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.cardBackground,
            child: InkWell(
              onTap: () => _openDocument(document),
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.primary.withOpacity(0.1),
              highlightColor: AppColors.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getDocumentColor(index),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getDocumentIcon(document.fileType),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.getTitle(context.lang),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            document.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (document.accessLevel.isNotEmpty)
                                Builder(
                                  builder: (context) {
                                    try {
                                      final firstLevel = document.accessLevel.first;
                                      if (firstLevel.isNotEmpty) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getAccessLevelColor(firstLevel),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            firstLevel.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Handle any errors accessing first element
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(document.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: _isValidUrl(document.url) ? () => _downloadFileToDevice(document) : null,
                          icon: Icon(
                            Icons.download,
                            color: _isValidUrl(document.url) ? AppColors.primary : Colors.grey,
                          ),
                        ),
                        IconButton(
                          onPressed: _isValidUrl(document.url) ? () => _shareDocument(document) : null,
                          icon: Icon(
                            Icons.share,
                            color: _isValidUrl(document.url) ? AppColors.textSecondary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDocumentColor(int index) {
    final colors = [
      Colors.red,
      AppColors.primary,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  IconData _getDocumentIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getAccessLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'public':
        return Colors.green;
      case 'cadre':
        return Colors.orange;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '';
    }
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty || url == 'None' || url == 'null') {
      return false;
    }
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Open document in external app (card tap action)
  Future<void> _openDocument(Document document) async {
    // Validate URL before showing dialog
    if (!_isValidUrl(document.url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Document URL is missing or invalid. Please contact support.'
                  : 'పత్రం URL లేదు లేదా చెల్లనిది. దయచేసి మద్దతుకు సంప్రదించండి.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.lang == Language.en ? 'Open Document' : 'పత్రాన్ని తెరవండి',
        ),
        content: Text(
          context.lang == Language.en
              ? 'Do you want to open this document?'
              : 'మీరు ఈ పత్రాన్ని తెరవాలనుకుంటున్నారా?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.lang == Language.en ? 'Cancel' : 'రద్దు చేయండి',
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.lang == Language.en ? 'Open' : 'తెరవండి',
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Validate URL again before parsing
        if (!_isValidUrl(document.url) || document.url == null) {
          throw 'Invalid document URL';
        }

        final url = Uri.parse(document.url);
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.lang == Language.en
                    ? 'Opening document...'
                    : 'పత్రాన్ని తెరుస్తోంది...',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          throw 'Could not launch URL';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.lang == Language.en
                    ? 'Failed to open document: ${e.toString()}'
                    : 'పత్రాన్ని తెరవడంలో విఫలమైంది: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Download file to device (download button action)
  Future<void> _downloadFileToDevice(Document document) async {
    // Validate URL
    if (!_isValidUrl(document.url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Document URL is missing or invalid. Please contact support.'
                  : 'పత్రం URL లేదు లేదా చెల్లనిది. దయచేసి మద్దతుకు సంప్రదించండి.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    BuildContext? loadingDialogContext;

    try {
      // Permission handling for Android
      if (Platform.isAndroid) {
        // Check status first
        PermissionStatus status = await Permission.storage.status;
        
        if (!status.isGranted) {
          // Request permission
          status = await Permission.storage.request();
          
          // If still not granted (denied or permanently denied)
          if (!status.isGranted) {
             // Check if it's Android 13+ where storage permission might be unnecessary for public downloads
             // or split into photos/videos/audio.
             // But for documents, we might need to rely on the fact that we can write to 
             // app-specific directories without permission, or use the public Download folder 
             // which works on some versions without explicit permission if using specific APIs.
             // However, to be safe and explicit as requested:
             
             // Try one more time with manageExternalStorage if storage failed (rare, for specific use cases)
             // largely mostly not needed for standard downloads, but let's just log it and continue to fallback
             debugPrint('Storage permission denied. Trying fallback storage methods.');
             
             // Optional: Show a snackbar telling user about permission if we strictly needed it
             // But since we have fallbacks (app docs dir), we can proceed silently or warn.
             // "Storage permission is required to save to public Downloads folder."
          }
        }
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          loadingDialogContext = dialogContext;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  context.lang == Language.en
                      ? 'Downloading document...'
                      : 'పత్రాన్ని డౌన్‌లోడ్ చేస్తోంది...',
                ),
              ],
            ),
          );
        },
      );

      // Download the file
      final response = await http.get(Uri.parse(document.url!)).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Download timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download document: HTTP ${response.statusCode}');
      }

      // Generate filename
      final fileName = _getFileName(document);
      File? savedFile;
      String? savedFilePath;

      // Try saving to public Download directory first (Android)
      if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final filePath = '${downloadDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            savedFile = file;
            savedFilePath = filePath;
          } else {
            // Try plural 'Downloads'
            final downloadDirPlural = Directory('/storage/emulated/0/Downloads');
            if (await downloadDirPlural.exists()) {
              final filePath = '${downloadDirPlural.path}/$fileName';
              final file = File(filePath);
              await file.writeAsBytes(response.bodyBytes);
              savedFile = file;
              savedFilePath = filePath;
            }
          }
        } catch (e) {
          debugPrint('Failed to write to public download dir: $e');
          // Fallback will handle this
        }
      }

      // If public download failed or not Android, try app-specific external storage
      if (savedFile == null && Platform.isAndroid) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Try to find a Download folder inside app specific storage
            // or just use the root of app specific storage
            final filePath = '${externalDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            savedFile = file;
            savedFilePath = filePath;
          }
        } catch (e) {
          debugPrint('Failed to write to external storage: $e');
        }
      }

      // Final fallback: Application Documents Directory (Internal Storage)
      // This works on iOS and Android (but not visible in external file managers on Android)
      if (savedFile == null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final filePath = '${appDocDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        savedFile = file;
        savedFilePath = filePath;
      }

      // Close loading dialog
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Download successful'
                  : 'డౌన్‌లోడ్ విజయవంతమైంది',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Show push notification
      if (savedFilePath != null) {
        await _showDownloadNotification(savedFilePath, fileName);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Failed to download document: ${e.toString()}'
                  : 'పత్రాన్ని డౌన్‌లోడ్ చేయడంలో విఫలమైంది: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFileName(Document document) {
    // Get title and sanitize it
    final title = document.getTitle(context.lang);
    final safeTitle = title
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    
    // Get file extension from URL or use fileType
    String extension = document.fileType.toLowerCase();
    if (document.url != null) {
      final uri = Uri.parse(document.url!);
      final path = uri.path;
      if (path.contains('.')) {
        final urlExtension = path.split('.').last.toLowerCase();
        if (urlExtension.length <= 5) {
          extension = urlExtension;
        }
      }
    }

    // Add timestamp to avoid conflicts
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${safeTitle}_$timestamp.$extension';
  }

  Future<void> _showDownloadNotification(String filePath, String fileName) async {
    try {
      final notificationTitle = context.lang == Language.en
          ? 'Download Complete'
          : 'డౌన్‌లోడ్ పూర్తయింది';
      
      final notificationBody = context.lang == Language.en
          ? 'Tap to open: $fileName'
          : 'తెరవడానికి నొక్కండి: $fileName';

      // Android notification details
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'documents_downloads_channel',
        'Document Downloads',
        channelDescription: 'Notifications for downloaded documents',
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
      await _notifications.show(
        notificationId,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
        payload: filePath, // Pass file path to open on tap
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> _shareDocument(Document document) async {
    if (!_isValidUrl(document.url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Document URL is missing or invalid. Cannot share.'
                  : 'పత్రం URL లేదు లేదా చెల్లనిది. షేర్ చేయలేము.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    BuildContext? loadingDialogContext;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          loadingDialogContext = dialogContext;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  context.lang == Language.en
                      ? 'Preparing file for sharing...'
                      : 'షేర్ చేయడానికి ఫైల్‌ను సిద్ధం చేస్తోంది...',
                ),
              ],
            ),
          );
        },
      );

      // Download the file
      final response = await http.get(Uri.parse(document.url!)).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Download timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download document: HTTP ${response.statusCode}');
      }

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = _getFileName(document);
      final tempFilePath = '${tempDir.path}/$fileName';
      final tempFile = File(tempFilePath);

      // Write file to temporary location
      await tempFile.writeAsBytes(response.bodyBytes);

      // Close loading dialog
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      }

      // Share the file
      final displayTitle = document.getTitle(context.lang);
      await Share.shareXFiles(
        [XFile(tempFilePath)],
        text: displayTitle,
        subject: displayTitle,
      );

      // Clean up temporary file after a delay (to allow sharing to complete)
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Error deleting temporary file: $e');
        }
      });
    } catch (e) {
      // Close loading dialog if still open
      if (loadingDialogContext != null && Navigator.canPop(loadingDialogContext!)) {
        Navigator.of(loadingDialogContext!).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Failed to share document: ${e.toString()}'
                  : 'పత్రాన్ని షేర్ చేయడంలో విఫలమైంది: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

