import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class FileCacheService {
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
  
  // Check if file exists in cache
  static Future<bool> isCached(String url) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      print('Error checking cache: $e');
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
        print('📦 Cache HIT: ${file.path}');
        return file.path;
      }
      
      print('❌ Cache MISS: $url');
      return null;
    } catch (e) {
      print('Error getting cached file: $e');
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
      print('⬇️ Downloading: $url');
      
      final cacheDir = await _getCacheDirectory();
      final fileName = _getCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      
      // Download file
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        // Save to cache
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Downloaded and cached: ${file.path}');
        print('📊 File size: ${response.bodyBytes.length} bytes');
        return file.path;
      } else {
        print('❌ Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }
  
  // Get file (from cache or download)
  static Future<String?> getFile(
    String url, {
    Map<String, String>? headers,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // First check cache
      final cachedPath = await getCachedFilePath(url);
      if (cachedPath != null) {
        return cachedPath;
      }
      
      // If not in cache, download and cache
      return await downloadAndCache(
        url,
        headers: headers,
        onProgress: onProgress,
      );
    } catch (e) {
      print('Error getting file: $e');
      return null;
    }
  }
  
  // Clear all cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ Cache cleared');
      }
    } catch (e) {
      print('Error clearing cache: $e');
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
      print('Error getting cache size: $e');
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
        print('🗑️ Deleted cached file: $url');
      }
    } catch (e) {
      print('Error deleting cached file: $e');
    }
  }
}
