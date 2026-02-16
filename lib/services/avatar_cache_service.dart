import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'file_cache_service.dart';

class AvatarCacheService {
  static final Map<String, Uint8List> _memoryBytesCache = <String, Uint8List>{};
  static final Map<String, ImageProvider> _memoryProviderCache =
      <String, ImageProvider>{};
  static final Map<String, Future<Uint8List?>> _inFlightRequests =
      <String, Future<Uint8List?>>{};

  static String? _resolveAvatarUrl(String? avatarPath) {
    return ApiService.getFullAvatarUrl(avatarPath);
  }

  static Future<Map<String, String>?> _buildAuthHeaders() async {
    final token = await ApiService.getAuthToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  static Future<Uint8List?> _loadAvatarBytes(
    String fullUrl, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedBytes = _memoryBytesCache[fullUrl];
      if (cachedBytes != null) {
        return cachedBytes;
      }

      final pending = _inFlightRequests[fullUrl];
      if (pending != null) {
        return pending;
      }
    }

    final request = () async {
      try {
        if (!forceRefresh) {
          final cachedPath = await FileCacheService.getCachedFilePath(fullUrl);
          if (cachedPath != null) {
            final cachedFile = File(cachedPath);
            if (await cachedFile.exists()) {
              final bytes = await cachedFile.readAsBytes();
              _memoryBytesCache[fullUrl] = bytes;
              return bytes;
            }
          }
        }

        final headers = await _buildAuthHeaders();
        final filePath = await FileCacheService.getFile(
          fullUrl,
          headers: headers,
          forceRefresh: forceRefresh,
        );
        if (filePath == null) return null;

        final downloadedFile = File(filePath);
        if (!await downloadedFile.exists()) return null;

        final bytes = await downloadedFile.readAsBytes();
        _memoryBytesCache[fullUrl] = bytes;
        return bytes;
      } catch (e) {
        if (kDebugMode) {
          print('AvatarCacheService load error: $e');
        }
        return null;
      }
    }();

    _inFlightRequests[fullUrl] = request;
    try {
      return await request;
    } finally {
      _inFlightRequests.remove(fullUrl);
    }
  }

  static Future<ImageProvider?> getAvatarImageProvider(
    String? avatarPath, {
    bool forceRefresh = false,
  }) async {
    final fullUrl = _resolveAvatarUrl(avatarPath);
    if (fullUrl == null) return null;

    if (!forceRefresh) {
      final provider = _memoryProviderCache[fullUrl];
      if (provider != null) {
        return provider;
      }
    }

    final bytes = await _loadAvatarBytes(fullUrl, forceRefresh: forceRefresh);
    if (bytes == null) return null;

    final provider = MemoryImage(bytes);
    _memoryProviderCache[fullUrl] = provider;
    return provider;
  }

  static Future<void> warmUpUsersAvatars(
    List<Map<String, dynamic>> users,
  ) async {
    final urls = <String>{};
    for (final user in users) {
      final avatarPath = user['picUrlAvatar']?.toString();
      final fullUrl = _resolveAvatarUrl(avatarPath);
      if (fullUrl != null) {
        urls.add(fullUrl);
      }
    }

    if (urls.isEmpty) return;

    await Future.wait(
      urls.map((url) => _loadAvatarBytes(url)),
      eagerError: false,
    );
  }

  static void clearMemoryCache() {
    _memoryBytesCache.clear();
    _memoryProviderCache.clear();
    _inFlightRequests.clear();
  }
}
