import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  // Cache manager for images
  static final CacheManager _imageCacheManager = CacheManager(
    Config(
      'media_images',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'media_images'),
    ),
  );

  // Cache manager for videos
  static final CacheManager _videoCacheManager = CacheManager(
    Config(
      'media_videos',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100, // Fewer videos as they're larger
      repo: JsonCacheInfoRepository(databaseName: 'media_videos'),
    ),
  );

  static const String _keyCachedPhotos = 'cached_photos';
  static const String _keyCachedVideos = 'cached_videos';
  static const String _keyLastSyncTime = 'media_last_sync_time';

  // Get cached image file
  Future<File?> getCachedImageFile(String url) async {
    try {
      final fileInfo = await _imageCacheManager.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e) {
      print('Error getting cached image: $e');
      return null;
    }
  }

  // Get cached video file
  Future<File?> getCachedVideoFile(String url) async {
    try {
      final fileInfo = await _videoCacheManager.getFileFromCache(url);
      return fileInfo?.file;
    } catch (e) {
      print('Error getting cached video: $e');
      return null;
    }
  }

  // Download and cache image
  Future<File?> cacheImage(String url) async {
    try {
      final file = await _imageCacheManager.getSingleFile(url);
      return file;
    } catch (e) {
      print('Error caching image: $e');
      return null;
    }
  }

  // Download and cache video
  Future<File?> cacheVideo(String url) async {
    try {
      final file = await _videoCacheManager.getSingleFile(url);
      return file;
    } catch (e) {
      print('Error caching video: $e');
      return null;
    }
  }

  // Get cached media list
  Future<List<MediaItem>> getCachedPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = prefs.getString(_keyCachedPhotos);
      if (photosJson == null) return [];

      final List<dynamic> photosList = json.decode(photosJson);
      return photosList
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting cached photos: $e');
      return [];
    }
  }

  Future<List<MediaItem>> getCachedVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_keyCachedVideos);
      if (videosJson == null) return [];

      final List<dynamic> videosList = json.decode(videosJson);
      return videosList
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting cached videos: $e');
      return [];
    }
  }

  // Cache media list
  Future<void> cachePhotosList(List<MediaItem> photos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photosJson = json.encode(
        photos.map((photo) => photo.toJson()).toList(),
      );
      await prefs.setString(_keyCachedPhotos, photosJson);
    } catch (e) {
      print('Error caching photos list: $e');
    }
  }

  Future<void> cacheVideosList(List<MediaItem> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = json.encode(
        videos.map((video) => video.toJson()).toList(),
      );
      await prefs.setString(_keyCachedVideos, videosJson);
    } catch (e) {
      print('Error caching videos list: $e');
    }
  }

  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeMillis = prefs.getInt(_keyLastSyncTime);
      if (timeMillis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timeMillis);
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  // Clear all cached media data (useful when data format changes)
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedPhotos);
      await prefs.remove(_keyCachedVideos);
      await prefs.remove(_keyLastSyncTime);
      print('Media cache cleared successfully');
    } catch (e) {
      print('Error clearing media cache: $e');
    }
  }

  // Save last sync time
  Future<void> saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _keyLastSyncTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error saving last sync time: $e');
    }
  }


  // Clear all cache
  Future<void> clearCache() async {
    try {
      await _imageCacheManager.emptyCache();
      await _videoCacheManager.emptyCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedPhotos);
      await prefs.remove(_keyCachedVideos);
      await prefs.remove(_keyLastSyncTime);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Get cache size
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCachePath = Directory('${cacheDir.path}/media_images');
      final videoCachePath = Directory('${cacheDir.path}/media_videos');
      
      int totalSize = 0;
      
      // Calculate image cache size
      if (await imageCachePath.exists()) {
        await for (final file in imageCachePath.list(recursive: true)) {
          if (file is File) {
            try {
              totalSize += await file.length();
            } catch (e) {
              // Skip files that can't be accessed
            }
          }
        }
      }
      
      // Calculate video cache size
      if (await videoCachePath.exists()) {
        await for (final file in videoCachePath.list(recursive: true)) {
          if (file is File) {
            try {
              totalSize += await file.length();
            } catch (e) {
              // Skip files that can't be accessed
            }
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
      return 0;
    }
  }

  // Preload images in background
  Future<void> preloadImages(List<String> urls) async {
    for (final url in urls) {
      try {
        await _imageCacheManager.getSingleFile(url);
      } catch (e) {
        // Continue with other images if one fails
      }
    }
  }

  // Preload video thumbnails
  Future<void> preloadVideoThumbnails(List<String> thumbnailUrls) async {
    for (final url in thumbnailUrls) {
      try {
        await _imageCacheManager.getSingleFile(url);
      } catch (e) {
        // Continue with other thumbnails if one fails
      }
    }
  }
}

