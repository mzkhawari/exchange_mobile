import 'dart:async';

import 'api_service.dart';
import 'local_users_db_service.dart';

class ChatSyncService {
  static Timer? _timer;
  static bool _isSyncing = false;

  static Future<void> start({
    Duration interval = const Duration(seconds: 30),
    Future<void> Function()? onSynced,
  }) async {
    stop();
    await _syncOnce(onSynced: onSynced);
    _timer = Timer.periodic(interval, (_) {
      _syncOnce(onSynced: onSynced);
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _syncOnce({Future<void> Function()? onSynced}) async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      var hasUpdates = false;
      final isLoggedIn = await ApiService.isLoggedIn();
      if (!isLoggedIn) return;

      final users = await LocalUsersDbService.getUsers();
      if (users.isEmpty) return;

      for (final user in users) {
        final targetUserId = int.tryParse('${user['id'] ?? ''}');
        if (targetUserId == null || targetUserId <= 0) continue;

        final lastMsgId =
            await LocalUsersDbService.getLastCachedMessageIdForUser(
              targetUserId,
            );

        final response = await ApiService.getChatDetails(
          targetUserId,
          msgId: lastMsgId,
        );
        if (response == null) continue;

        final messages =
            response['messages'] as List<Map<String, dynamic>>? ?? const [];
        if (messages.isEmpty) continue;

        await LocalUsersDbService.cacheMessagesForUserChat(
          userId: targetUserId,
          messages: messages.map(_mapApiMessageToCachePayload).toList(),
        );
        hasUpdates = true;
      }

      if (hasUpdates && onSynced != null) {
        await onSynced();
      }
    } catch (e) {
      print('ChatSyncService sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static Map<String, dynamic> _mapApiMessageToCachePayload(
    Map<String, dynamic> msg,
  ) {
    final messageId =
        int.tryParse((msg['Id'] ?? msg['id'] ?? 0).toString()) ?? 0;
    final messageValue = (msg['Value'] ?? msg['value'] ?? '').toString();
    final rawFileUrl = _readStringFromKeys(msg, const [
      'FileUrl',
      'fileUrl',
      'AttachmentFileUrl',
      'attachmentFileUrl',
      'AttachmentUrl',
      'attachmentUrl',
      'VoiceUrl',
      'voiceUrl',
      'ImageUrl',
      'imageUrl',
      'Url',
      'url',
      'FilePath',
      'filePath',
    ]);
    final rawFileUrlThumb = _readStringFromKeys(msg, const [
      'FileUrlThumb',
      'fileUrlThumb',
      'ThumbUrl',
      'thumbUrl',
      'ThumbnailUrl',
      'thumbnailUrl',
    ]);
    final rawType =
        _readStringFromKeys(msg, const [
          'Type',
          'type',
          'AttachmentType',
          'attachmentType',
          'MessageType',
          'messageType',
          'Kind',
          'kind',
        ]) ??
        '';

    final dateString = (msg['Date'] ?? msg['date'] ?? '').toString();
    final messageDate = DateTime.tryParse(dateString) ?? DateTime.now();
    final senderId =
        int.tryParse((msg['UserId'] ?? msg['userId'] ?? 0).toString()) ?? 0;
    final isSent = (msg['IsSent'] ?? msg['isSent'] ?? false) == true;
    final messageStatus = (msg['Status'] ?? msg['status'] ?? 'None').toString();
    final isMine = (msg['IsMine'] ?? msg['isMine'] ?? false) == true;

    final fileUrl = (rawFileUrl != null && rawFileUrl.isNotEmpty)
        ? _buildRemoteFileUrl(rawFileUrl)
        : null;
    final fileUrlThumb = (rawFileUrlThumb != null && rawFileUrlThumb.isNotEmpty)
        ? _buildRemoteFileUrl(rawFileUrlThumb)
        : null;

    final messageType = _resolveMessageType(
      rawType: rawType,
      fileUrl: rawFileUrl,
      fileUrlThumb: rawFileUrlThumb,
      value: messageValue,
    );

    String? fullFileUrl = fileUrl;
    if (fullFileUrl == null && messageType == 'image') {
      fullFileUrl = fileUrlThumb;
    }

    return {
      'id': messageId,
      'value': messageValue,
      'fileUrl': fullFileUrl,
      'fileUrlThumb': fileUrlThumb,
      'date': messageDate,
      'userId': senderId,
      'isSent': isSent,
      'status': messageStatus,
      'isMine': isMine,
      'messageType': messageType,
    };
  }

  static String? _readStringFromKeys(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  static String? _buildRemoteFileUrl(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return null;
    final trimmed = filePath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var normalized = trimmed.replaceAll('\\', '/');
    if (!normalized.startsWith('/')) normalized = '/$normalized';

    final imageBase = ApiService.baseImageUrl;
    return '$imageBase$normalized';
  }

  static String _resolveMessageType({
    required String rawType,
    String? fileUrl,
    String? fileUrlThumb,
    required String value,
  }) {
    final typeLower = rawType.toLowerCase();
    final fileRef = (fileUrl ?? fileUrlThumb ?? '').toLowerCase();
    final valueLower = value.toLowerCase();

    if (typeLower.contains('voice') ||
        typeLower.contains('audio') ||
        fileRef.endsWith('.m4a') ||
        fileRef.endsWith('.aac') ||
        fileRef.endsWith('.mp3') ||
        fileRef.endsWith('.wav') ||
        valueLower.contains('voice')) {
      return 'voice';
    }

    if (typeLower.contains('image') ||
        typeLower.contains('photo') ||
        fileRef.endsWith('.jpg') ||
        fileRef.endsWith('.jpeg') ||
        fileRef.endsWith('.png') ||
        fileRef.endsWith('.webp') ||
        valueLower.contains('image') ||
        valueLower.contains('photo')) {
      return 'image';
    }

    if ((fileUrl != null && fileUrl.isNotEmpty) ||
        (fileUrlThumb != null && fileUrlThumb.isNotEmpty)) {
      return 'file';
    }

    return 'text';
  }
}
