import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class PendingChatQueueService {
  static const String _prefsKey = 'pending_chat_queue_v1';

  static Future<List<Map<String, dynamic>>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  static Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(queue));
  }

  static Future<void> addItem(Map<String, dynamic> item) async {
    final queue = await _readQueue();
    final localId = item['localId']?.toString();
    final exists = localId != null &&
        queue.any((q) => q['localId']?.toString() == localId);
    if (!exists) {
      queue.add(item);
      await _writeQueue(queue);
    }
  }

  static Future<List<Map<String, dynamic>>> flushForChat(
    int chatMasterId, {
    int? targetUserId,
  }) async {
    final queue = await _readQueue();
    if (queue.isEmpty) return [];

    final remaining = <Map<String, dynamic>>[];
    final sent = <Map<String, dynamic>>[];

    for (final item in queue) {
      final itemChatId = item['chatMasterId'] as int?;
      final itemTargetUserId = item['targetUserId'] as int?;
      final matchesChat = itemChatId == chatMasterId;
      final matchesUser = targetUserId != null && itemTargetUserId == targetUserId;
      if (!matchesChat && !matchesUser) {
        remaining.add(item);
        continue;
      }

      final type = item['type'] as String? ?? 'text';
      final value = item['value'] as String?;
      final filePath = item['filePath'] as String?;
      final attachmentType = item['attachmentType'] as String?;

      if ((type == 'voice' || type == 'image') &&
          !await _fileExists(filePath)) {
        continue;
      }

      Map<String, dynamic>? result;
      if (type == 'voice') {
        result = await ApiService.postChatDetail(
          chatMasterId: chatMasterId,
          value: value ?? 'Voice message',
          voiceFilePath: filePath,
        );
      } else if (type == 'image') {
        result = await ApiService.postChatDetail(
          chatMasterId: chatMasterId,
          value: value ?? 'Image',
          attachmentFilePath: filePath,
          attachmentType: attachmentType ?? 'Image',
        );
      } else {
        result = await ApiService.postChatDetail(
          chatMasterId: chatMasterId,
          value: value ?? '',
        );
      }

      if (result != null) {
        sent.add({
          'localId': item['localId']?.toString(),
          'serverId': result['id'],
        });
      } else {
        remaining.add(item);
      }
    }

    await _writeQueue(remaining);
    return sent;
  }

  static Future<bool> _fileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    return file.exists();
  }
}
