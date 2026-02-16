import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class FileCacheService {
  static void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // Get cache directory
  static Future<Directory> _getCacheDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/file_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  // Generate cache file name from URL
  static String _getCacheFileName(String url) {
    // Use MD5 hash of URL as filename to avoid special characters
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes);

    // Get file extension from URL
    String extension = '';
    final uri = Uri.parse(url);
    final path = uri.path;
    if (path.contains('.')) {
      extension = path.substring(path.lastIndexOf('.'));
    }

    return '$hash$extension';
  }

  static bool _looksLikeMediaRequest(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.aac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static bool _isLikelyInvalidMediaResponse(
    String url,
    http.Response response,
  ) {
    if (!_looksLikeMediaRequest(url)) return false;

    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('text/html') ||
        contentType.contains('application/json') ||
        contentType.contains('text/plain')) {
      return true;
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return true;

    final probeLength = bytes.length < 64 ? bytes.length : 64;
    final probe = utf8
        .decode(bytes.sublist(0, probeLength), allowMalformed: true)
        .toLowerCase();
    if (probe.contains('<html') ||
        probe.contains('{"type"') ||
        probe.contains('error')) {
      return true;
    }

    return false;
  }

  // Check if file exists in cache
  static Future<bool> isCached(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      _log('Error checking cache: $e');
      return false;
    }
  }

  // Get cached file path
  static Future<String?> getCachedFilePath(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        _log('📦 Cache HIT: ${file.path}');
        return file.path;
      }

      _log('❌ Cache MISS: $url');
      return null;
    } catch (e) {
      _log('Error getting cached file: $e');
      return null;
    }
  }

  // Download and cache file
  static Future<String?> downloadAndCache(
    String url, {
    Map<String, String>? headers,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      _log('⬇️ Downloading: $url');

      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');

      // Download file
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        if (_isLikelyInvalidMediaResponse(url, response)) {
          _log('❌ Invalid media payload received, skip caching: $url');
          return null;
        }

        // Save to cache
        await file.writeAsBytes(response.bodyBytes);
        _log('✅ Downloaded and cached: ${file.path}');
        _log('📊 File size: ${response.bodyBytes.length} bytes');
        return file.path;
      } else {
        _log('❌ Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Error downloading file: $e');
      return null;
    }
  }

  // Get file (from cache or download)
  static Future<String?> getFile(
    String url, {
    Map<String, String>? headers,
    Function(int received, int total)? onProgress,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await deleteCachedFile(url);
      } else {
        final cachedPath = await getCachedFilePath(url);
        if (cachedPath != null) {
          return cachedPath;
        }
      }

      // If not in cache, download and cache
      return await downloadAndCache(
        url,
        headers: headers,
        onProgress: onProgress,
      );
    } catch (e) {
      _log('Error getting file: $e');
      return null;
    }
  }

  // Clear all cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        _log('🗑️ Cache cleared');
      }
    } catch (e) {
      _log('Error clearing cache: $e');
    }
  }

  // Get cache size
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      _log('Error getting cache size: $e');
      return 0;
    }
  }

  // Delete specific cached file
  static Future<void> deleteCachedFile(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        _log('🗑️ Deleted cached file: $url');
      }
    } catch (e) {
      _log('Error deleting cached file: $e');
    }
  }
}
