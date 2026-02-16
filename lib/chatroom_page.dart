import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';
import 'services/voice_recorder_service.dart';
import 'services/file_cache_service.dart';
import 'services/local_users_db_service.dart';
import 'services/pending_chat_queue_service.dart';
import 'services/chat_sync_service.dart';
import 'services/avatar_cache_service.dart';

class ChatroomPage extends StatefulWidget {
  final Map<String, dynamic>? initialUser;
  final bool standalone;

  const ChatroomPage({super.key, this.initialUser, this.standalone = false});

  @override
  State<ChatroomPage> createState() => _ChatroomPageState();
}

class _ChatroomPageState extends State<ChatroomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  String _currentUserName = 'You';

  // User selection variables
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoadingUsers = true;
  bool _isExpanded = false; // Track if left sidebar is expanded
  int? _chatMasterId; // Chat master ID for API calls

  // Voice recording variables
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  bool _isRecordingLocked = false; // حالت قفل شده (کشیدن به بالا)
  double _micDragOffset = 0.0; // فاصله کشیدن میکروفن
  double _micDragXOffset = 0.0; // فاصله کشیدن به چپ برای کنسل
  bool _cancelRecordingByGesture = false;
  Duration _recordingDuration = Duration.zero; // مدت زمان ضبط
  List<double> _waveformData = []; // داده‌های نمودار صوتی
  final Set<String> _downloadingAttachmentKeys = <String>{};
  final Map<String, String> _downloadedAttachmentPaths = <String, String>{};
  final Set<int> _resolvingVoiceDurationIds = <int>{};
  final Set<String> _failedVoiceDurationKeys = <String>{};
  bool _isPrimingChatsCache = false;
  static const Duration _minVoiceDuration = Duration(seconds: 1);
  StreamSubscription<Duration>? _voicePositionSubscription;
  StreamSubscription<dynamic>? _voiceStateSubscription;
  int? _activeVoiceMessageId;
  Duration _activeVoicePosition = Duration.zero;
  Duration _activeVoiceDuration = Duration.zero;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Log API configuration for this session
    ApiService.logCurrentConfig();

    // If standalone mode with initialUser, set immediately
    if (widget.initialUser != null) {
      _selectedUser = widget.initialUser;
      _chatMasterId = widget.initialUser!['id'] as int?;
    }

    _loadUserData().then((_) async {
      // Always load available users, regardless of authentication status
      await _loadAvailableUsers();

      await _startBackgroundChatSync();

      // If a chat partner is already selected, refresh messages on page open
      if (_selectedUser != null) {
        await _loadChatMessages();
        _markAllMessagesAsSeen();
        await _flushPendingQueue();
      }
    });

    // Add listener to message controller to update send button
    _messageController.addListener(() {
      setState(() {
        // This will update the send button icon based on text content
      });
    });

    _voicePositionSubscription = _voiceRecorder.positionStream.listen((
      position,
    ) {
      if (!mounted || _activeVoiceMessageId == null) return;
      setState(() {
        _activeVoicePosition = position;
        final maybeDuration = _voiceRecorder.duration;
        if (maybeDuration != null && maybeDuration > Duration.zero) {
          _activeVoiceDuration = maybeDuration;
        }
      });
    });

    _voiceStateSubscription = _voiceRecorder.playerStateStream.listen((state) {
      final processingState = state.processingState.toString().toLowerCase();
      final isCompleted = processingState.contains('completed');
      if (!mounted || !isCompleted) return;

      setState(() {
        _activeVoiceMessageId = null;
        _activeVoicePosition = Duration.zero;
        _activeVoiceDuration = Duration.zero;
        _messages = _messages
            .map(
              (m) => ChatMessage(
                id: m.id,
                value: m.value,
                fileUrl: m.fileUrl,
                fileUrlThumb: m.fileUrlThumb,
                date: m.date,
                userId: m.userId,
                isSent: m.isSent,
                status: m.status,
                isMine: m.isMine,
                sender: m.sender,
                messageType: m.messageType,
                duration: m.duration,
                isPlaying: false,
              ),
            )
            .toList();
      });
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService.getUserInfo();

      if (userData != null) {
        setState(() {
          _userInfo = userData;
          _currentUserName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();
          if (_currentUserName.isEmpty) _currentUserName = 'You';
        });
      } else {
        setState(() {
          _currentUserName = 'Guest User';
        });
        // No login prompt - allow guest access
      }
    } catch (e) {
      setState(() {
        _currentUserName = 'Guest User';
      });
      // No login prompt on error - allow guest access
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableUsers() async {
    try {
      setState(() => _isLoadingUsers = true);
      final cachedUsers = await LocalUsersDbService.getUsers();
      unawaited(AvatarCacheService.warmUpUsersAvatars(cachedUsers));
      if (!mounted) return;
      setState(() {
        _availableUsers = cachedUsers;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshUsersFromLocalDb() async {
    final cachedUsers = await LocalUsersDbService.getUsers();
    unawaited(AvatarCacheService.warmUpUsersAvatars(cachedUsers));
    if (!mounted) return;
    setState(() {
      _availableUsers = cachedUsers;
    });
  }

  Future<bool> _loadSelectedChatFromLocalDb() async {
    final selectedUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');
    if (selectedUserId == null) return false;

    final cachedMessages = await LocalUsersDbService.getCachedMessagesForUser(
      selectedUserId,
    );
    if (cachedMessages.isEmpty || !mounted) return false;

    final parsedCached =
        cachedMessages.map(_mapStoredMessageToChatMessage).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _messages = _mergeMessages(_messages, parsedCached);
    });
    _scrollToBottom();
    return true;
  }

  Future<void> _startBackgroundChatSync() async {
    final targetUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');
    final lastMessageId = targetUserId != null
        ? await _resolveLastMessageIdForChat(targetUserId)
        : null;
    await ChatSyncService.start(
      targetUserId: targetUserId,
      lastMessageId: lastMessageId,
      onSynced: () async {
        if (!mounted) return;
        await _refreshUsersFromLocalDb();
        await _loadSelectedChatFromLocalDb();
      },
    );
  }

  Future<void> _primeChatsCacheFromApi(List<Map<String, dynamic>> users) async {
    if (_isPrimingChatsCache) return;
    if (_userInfo == null) return;

    _isPrimingChatsCache = true;
    try {
      for (final user in users) {
        final targetUserId = int.tryParse('${user['id'] ?? ''}');
        if (targetUserId == null || targetUserId <= 0) continue;

        final myUserId = int.tryParse('${_userInfo?['id'] ?? ''}');
        if (myUserId != null && targetUserId == myUserId) continue;

        final lastMsgId = await _resolveLastMessageIdForChat(targetUserId);
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
      }

      await _refreshUsersFromLocalDb();
    } catch (e) {
      print('Error priming chats cache: $e');
    } finally {
      _isPrimingChatsCache = false;
    }
  }

  void _selectUser(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _messages.clear(); // Clear previous messages
      _isExpanded = false; // Return to primary state (pictures only)
      // For now, we'll use the user's ID as chatMasterId
      // In a real app, you might need to create or find an existing chat master
      _chatMasterId = user['id'];
    });
    await _loadChatMessages(); // Load messages for selected user
    _markAllMessagesAsSeen(); // Mark messages as seen when chat is opened
    await _flushPendingQueue();
  }

  Future<void> _loadChatMessages() async {
    final selectedUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');

    final hasLocalData = await _loadSelectedChatFromLocalDb();

    if (hasLocalData) {
      return;
    }

    // Then fetch ONLY new messages from API (using last local msgId)
    if (_userInfo != null && selectedUserId != null) {
      try {
        final targetUserId = selectedUserId;
        final lastMsgId = await _resolveLastMessageIdForChat(targetUserId);

        // Fetch by target user id; msgId is per-chat based on local cache
        final response = await ApiService.getChatDetails(
          targetUserId,
          msgId: lastMsgId,
        );
        if (response != null) {
          // Extract ChatMasterId from API response - this is unique for each chat partner
          final chatMasterId = response['chatMasterId'];
          final messages =
              response['messages'] as List<Map<String, dynamic>>? ?? [];

          if (chatMasterId != null) {
            _chatMasterId = chatMasterId;
          }

          final parsedMessages =
              messages.map(_mapApiMessageToChatMessage).toList()
                ..sort((a, b) => a.date.compareTo(b.date));

          if (parsedMessages.isNotEmpty) {
            await LocalUsersDbService.cacheMessagesForUserChat(
              userId: selectedUserId,
              messages: parsedMessages
                  .map(
                    (message) => {
                      'id': message.id,
                      'value': message.value,
                      'fileUrl': message.fileUrl,
                      'fileUrlThumb': message.fileUrlThumb,
                      'date': message.date,
                      'userId': message.userId,
                      'isSent': message.isSent,
                      'status': message.status,
                      'isMine': message.isMine,
                      'messageType': message.messageType.name,
                    },
                  )
                  .toList(),
            );
            await _refreshUsersFromLocalDb();

            final mergedFromDb =
                await LocalUsersDbService.getCachedMessagesForUser(
                  selectedUserId,
                );
            if (mounted) {
              setState(() {
                final mergedMessages =
                    mergedFromDb.map(_mapStoredMessageToChatMessage).toList()
                      ..sort((a, b) => a.date.compareTo(b.date));
                _messages = _mergeMessages(_messages, mergedMessages);
              });
            }
          }

          if (_messages.isNotEmpty) {
            _scrollToBottom();
          }
        }
      } catch (e) {
        print('Error loading chat messages: $e');
      }
    } else if (_userInfo == null) {
      // Guest mode - show welcome message
      setState(() {
        _messages.add(
          ChatMessage(
            id: 0,
            value:
                'Welcome to the chat room! You are in guest mode. Login to sync with your conversations.',
            date: DateTime.now(),
            userId: 0,
            isSent: true,
            status: 'Delivered',
            isMine: false,
            sender: 'System',
            messageType: MessageType.text,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<int?> _resolveLastMessageIdForChat(int targetUserId) async {
    int? selectedUserLastMessageId;
    final selectedUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');
    if (selectedUserId == targetUserId) {
      selectedUserLastMessageId = int.tryParse(
        '${_selectedUser?['lastMessageId'] ?? ''}',
      );
    }

    int? availableUserLastMessageId;
    final matchedUser = _availableUsers.where((u) {
      final userId = int.tryParse('${u['id'] ?? ''}');
      return userId == targetUserId;
    }).cast<Map<String, dynamic>>().toList();
    if (matchedUser.isNotEmpty) {
      availableUserLastMessageId = int.tryParse(
        '${matchedUser.first['lastMessageId'] ?? ''}',
      );
    }

    final localDbLastMessageId =
        await LocalUsersDbService.getLastCachedMessageIdForUser(targetUserId);

    final candidates = <int>[
      if (selectedUserLastMessageId != null && selectedUserLastMessageId > 0)
        selectedUserLastMessageId,
      if (availableUserLastMessageId != null && availableUserLastMessageId > 0)
        availableUserLastMessageId,
      if (localDbLastMessageId != null && localDbLastMessageId > 0)
        localDbLastMessageId,
    ];

    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  ChatMessage _mapStoredMessageToChatMessage(Map<String, dynamic> msg) {
    final messageId = int.tryParse('${msg['id'] ?? 0}') ?? 0;
    final messageValue = (msg['value'] ?? '').toString();
    final storedType = (msg['messageType'] ?? 'text').toString().toLowerCase();
    final messageDate = msg['date'] is DateTime
        ? msg['date'] as DateTime
        : DateTime.now();
    final senderId = int.tryParse('${msg['userId'] ?? 0}') ?? 0;
    final isSent = msg['isSent'] == true;
    final messageStatus = (msg['status'] ?? 'None').toString();
    final isMine = msg['isMine'] == true;
    final fileUrl = (msg['fileUrl'] ?? '').toString();
    final fileThumb = (msg['fileUrlThumb'] ?? '').toString();

    MessageType msgType;
    switch (storedType) {
      case 'voice':
        msgType = MessageType.voice;
        break;
      case 'image':
        msgType = MessageType.image;
        break;
      case 'file':
        msgType = MessageType.file;
        break;
      default:
        msgType = MessageType.text;
    }

    return ChatMessage(
      id: messageId,
      value: messageValue,
      fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
      fileUrlThumb: fileThumb.isNotEmpty ? fileThumb : null,
      date: messageDate,
      userId: senderId,
      isSent: isSent,
      status: messageStatus,
      isMine: isMine,
      sender: isMine
          ? _currentUserName
          : (_selectedUser?['firstName'] ?? 'Unknown'),
      messageType: msgType,
    );
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    final mergedByKey = <String, ChatMessage>{
      for (final message in existing) _messageMergeKey(message): message,
    };

    for (final message in incoming) {
      mergedByKey[_messageMergeKey(message)] = message;
    }

    final merged = mergedByKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return merged;
  }

  String _messageMergeKey(ChatMessage message) {
    if (message.id > 0) {
      return 'id:${message.id}';
    }
    return 'tmp:${message.userId}:${message.isMine}:${message.date.millisecondsSinceEpoch}:${message.value}';
  }

  ChatMessage _mapApiMessageToChatMessage(Map<String, dynamic> msg) {
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

    var msgType = _resolveMessageType(
      rawType: rawType,
      fileUrl: rawFileUrl,
      fileUrlThumb: rawFileUrlThumb,
      value: messageValue,
    );

    String? fullFileUrl = fileUrl;
    if (fullFileUrl == null && msgType == MessageType.image) {
      fullFileUrl = fileUrlThumb;
    }

    return ChatMessage(
      id: messageId,
      value: messageValue,
      fileUrl: fullFileUrl,
      fileUrlThumb: fileUrlThumb,
      date: messageDate,
      userId: senderId,
      isSent: isSent,
      status: messageStatus,
      isMine: isMine,
      sender: isMine
          ? _currentUserName
          : (_selectedUser?['firstName'] ?? 'Unknown'),
      messageType: msgType,
      duration: msgType == MessageType.voice
          ? _extractVoiceDuration(msg)
          : null,
    );
  }

  Map<String, dynamic> _mapApiMessageToCachePayload(Map<String, dynamic> msg) {
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

    final msgType = _resolveMessageType(
      rawType: rawType,
      fileUrl: rawFileUrl,
      fileUrlThumb: rawFileUrlThumb,
      value: messageValue,
    );

    String? fullFileUrl = rawFileUrl != null && rawFileUrl.isNotEmpty
        ? _buildRemoteFileUrl(rawFileUrl)
        : null;
    final fullFileThumb = rawFileUrlThumb != null && rawFileUrlThumb.isNotEmpty
        ? _buildRemoteFileUrl(rawFileUrlThumb)
        : null;
    if (fullFileUrl == null && msgType == MessageType.image) {
      fullFileUrl = fullFileThumb;
    }

    return {
      'id': messageId,
      'value': messageValue,
      'fileUrl': fullFileUrl,
      'fileUrlThumb': fullFileThumb,
      'date': messageDate,
      'userId': senderId,
      'isSent': isSent,
      'status': messageStatus,
      'isMine': isMine,
      'messageType': msgType.name,
    };
  }

  // Message status tracking methods
  Future<void> _markMessagesAsSeen(List<int> messageIds) async {
    if (messageIds.isEmpty) return;

    try {
      await ApiService.updateChatDetailStatus(
        chatDetailIds: messageIds,
        status: 'Seen',
      );
      print('Marked ${messageIds.length} messages as seen');
    } catch (e) {
      print('Error marking messages as seen: $e');
    }
  }

  Future<void> _markVoiceAsListened(int messageId) async {
    try {
      await ApiService.updateChatDetailStatus(
        chatDetailIds: [messageId],
        status: 'Listen',
      );
      print('Marked voice message $messageId as listened');
    } catch (e) {
      print('Error marking voice message as listened: $e');
    }
  }

  Future<void> _markImageAsWatched(int messageId) async {
    try {
      await ApiService.updateChatDetailStatus(
        chatDetailIds: [messageId],
        status: 'Watch',
      );
      print('Marked image message $messageId as watched');
    } catch (e) {
      print('Error marking image message as watched: $e');
    }
  }

  // Method to mark all unread messages as seen when chat is opened
  void _markAllMessagesAsSeen() async {
    final unseenMessageIds = _messages
        .where(
          (msg) => !msg.isMe && msg.messageId != null && (msg.status != 'Seen'),
        )
        .map((msg) => msg.messageId!)
        .toList();

    if (unseenMessageIds.isNotEmpty) {
      await _markMessagesAsSeen(unseenMessageIds);
    }

    final selectedUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');
    if (selectedUserId != null) {
      await LocalUsersDbService.markUserChatAsSeen(selectedUserId);
      await _refreshUsersFromLocalDb();
    }
  }

  ChatMessage _copyMessageWithStatus(
    ChatMessage message, {
    required bool isSent,
    required String status,
    int? id,
  }) {
    return ChatMessage(
      id: id ?? message.id,
      value: message.value,
      date: message.date,
      userId: message.userId,
      isSent: isSent,
      status: status,
      isMine: message.isMine,
      fileUrl: message.fileUrl,
      fileUrlThumb: message.fileUrlThumb,
      sender: message.sender,
      messageType: message.messageType,
      duration: message.duration,
      isPlaying: message.isPlaying,
    );
  }

  Future<void> _cacheSingleMessageForSelectedChat(
    ChatMessage message, {
    required bool includeServerId,
  }) async {
    final selectedUserId = int.tryParse('${_selectedUser?['id'] ?? ''}');
    if (selectedUserId == null) return;

    await LocalUsersDbService.cacheMessagesForUserChat(
      userId: selectedUserId,
      messages: [
        {
          'id': includeServerId ? message.id : null,
          'value': message.value,
          'fileUrl': message.fileUrl,
          'fileUrlThumb': message.fileUrlThumb,
          'date': message.date,
          'userId': message.userId,
          'isSent': message.isSent,
          'status': message.status,
          'isMine': message.isMine,
          'messageType': message.messageType.name,
        },
      ],
    );
    await _refreshUsersFromLocalDb();
  }

  void _markMessagePending(int localId) {
    final index = _messages.indexWhere((m) => m.id == localId);
    if (index == -1) return;

    setState(() {
      _messages[index] = _copyMessageWithStatus(
        _messages[index],
        isSent: false,
        status: 'Pending',
      );
    });
  }

  Future<void> _enqueuePendingItem({
    required int localId,
    required String type,
    String? value,
    String? filePath,
    String? attachmentType,
  }) async {
    if (_chatMasterId == null) return;

    await PendingChatQueueService.addItem({
      'localId': localId.toString(),
      'chatMasterId': _chatMasterId,
      'targetUserId': _selectedUser?['id'],
      'type': type,
      'value': value,
      'filePath': filePath,
      'attachmentType': attachmentType,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _markMessagePending(localId);
  }

  Future<void> _flushPendingQueue() async {
    if (_chatMasterId == null) return;

    final sentItems = await PendingChatQueueService.flushForChat(
      _chatMasterId!,
      targetUserId: _selectedUser?['id'],
    );
    if (sentItems.isEmpty) return;

    setState(() {
      for (final item in sentItems) {
        final localId = int.tryParse(item['localId']?.toString() ?? '');
        if (localId == null) continue;
        final index = _messages.indexWhere((m) => m.id == localId);
        if (index == -1) continue;

        final serverId = item['serverId'] as int?;
        _messages[index] = _copyMessageWithStatus(
          _messages[index],
          isSent: true,
          status: 'Delivered',
          id: serverId ?? _messages[index].id,
        );
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final message = ChatMessage(
      id: tempId, // Temporary ID
      value: messageText,
      date: DateTime.now(),
      userId: _userInfo?['id'] ?? 0,
      isSent: false, // Will be updated after API call
      status: 'None',
      isMine: true,
      sender: _currentUserName,
      messageType: MessageType.text,
    );

    setState(() {
      _messages.add(message);
    });

    await _cacheSingleMessageForSelectedChat(message, includeServerId: false);

    _messageController.clear();
    _scrollToBottom();

    // Send message to API only if user is authenticated and chatMasterId is available
    if (_userInfo != null && _chatMasterId != null) {
      try {
        final result = await ApiService.postChatDetail(
          chatMasterId: _chatMasterId!,
          value: messageText,
        );

        if (result == null) {
          await _enqueuePendingItem(
            localId: tempId,
            type: 'text',
            value: messageText,
          );
        } else {
          // API returned success - update message status to show check mark
          setState(() {
            final index = _messages.indexWhere((m) => m.id == tempId);
            if (index != -1) {
              _messages[index] = ChatMessage(
                id: result.containsKey('id') ? result['id'] : tempId,
                value: _messages[index].value,
                date: _messages[index].date,
                userId: _messages[index].userId,
                isSent: true, // Show check mark
                status: 'Delivered',
                isMine: _messages[index].isMine,
                sender: _messages[index].sender,
                messageType: _messages[index].messageType,
              );
            }
          });

          final updatedMessage = _messages.firstWhere(
            (m) => m.id == (result.containsKey('id') ? result['id'] : tempId),
            orElse: () => message,
          );
          await _cacheSingleMessageForSelectedChat(
            updatedMessage,
            includeServerId: true,
          );

          // Mark message as delivered if ID is available
          if (result.containsKey('id') && result['id'] != null) {
            await ApiService.updateChatDetailStatus(
              chatDetailIds: [result['id']],
              status: 'Delivered',
            );
          }
        }
      } catch (e) {
        print('Error sending message: $e');
        await _enqueuePendingItem(
          localId: tempId,
          type: 'text',
          value: messageText,
        );
      }
    }
  }

  // Voice recording methods
  // Send voice message to API
  Future<void> _sendVoiceMessage(String recordingPath) async {
    // Create voice message
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final voiceMessage = ChatMessage(
      id: tempId,
      value: 'Voice message',
      date: DateTime.now(),
      userId: _userInfo?['id'] ?? 0,
      isSent: false,
      status: 'None',
      isMine: true,
      fileUrl: recordingPath,
      sender: _currentUserName,
      messageType: MessageType.voice,
      duration: null,
    );

    setState(() {
      _messages.add(voiceMessage);
    });

    await _cacheSingleMessageForSelectedChat(
      voiceMessage,
      includeServerId: false,
    );

    _scrollToBottom();

    // Send voice message to API if authenticated and chatMasterId available
    if (_userInfo != null && _chatMasterId != null && _selectedUser != null) {
      try {
        print('🎤 DEBUG: Sending voice message...');
        print('🎤 DEBUG: Recording path: $recordingPath');
        print('🎤 DEBUG: File exists: ${await File(recordingPath).exists()}');
        print(
          '🎤 DEBUG: File size: ${await File(recordingPath).length()} bytes',
        );
        print('🎤 DEBUG: ChatMasterId: $_chatMasterId');

        final result = await ApiService.postChatDetail(
          chatMasterId: _chatMasterId!,
          value: 'Voice message', // API requires value field
          voiceFilePath: recordingPath,
        );

        if (result != null) {
          // API returned success - update message status to show check mark
          setState(() {
            final index = _messages.indexWhere((m) => m.id == tempId);
            if (index != -1) {
              _messages[index] = ChatMessage(
                id: result.containsKey('id') ? result['id'] : tempId,
                value: _messages[index].value,
                date: _messages[index].date,
                userId: _messages[index].userId,
                isSent: true, // Show check mark
                status: 'Delivered',
                isMine: _messages[index].isMine,
                fileUrl: _messages[index].fileUrl,
                sender: _messages[index].sender,
                messageType: _messages[index].messageType,
                duration: _messages[index].duration,
              );
            }
          });

          final updatedVoiceMessage = _messages.firstWhere(
            (m) => m.id == (result.containsKey('id') ? result['id'] : tempId),
            orElse: () => voiceMessage,
          );
          await _cacheSingleMessageForSelectedChat(
            updatedVoiceMessage,
            includeServerId: true,
          );

          // Mark voice message as delivered
          if (result.containsKey('id') && result['id'] != null) {
            await ApiService.updateChatDetailStatus(
              chatDetailIds: [result['id']],
              status: 'Delivered',
            );
          }
        } else {
          await _enqueuePendingItem(
            localId: tempId,
            type: 'voice',
            value: 'Voice message',
            filePath: recordingPath,
          );
        }
      } catch (e) {
        print('Error sending voice message: $e');
        await _enqueuePendingItem(
          localId: tempId,
          type: 'voice',
          value: 'Voice message',
          filePath: recordingPath,
        );
      }
    }
  }

  // Camera functionality
  void _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch;
        final imageMessage = ChatMessage(
          id: tempId, // Temporary ID
          value: 'Photo',
          date: DateTime.now(),
          userId: _userInfo?['id'] ?? 0,
          isSent: false, // Will be updated after API call
          status: 'None',
          isMine: true,
          fileUrl: photo.path,
          sender: _currentUserName,
          messageType: MessageType.image,
        );

        setState(() {
          _messages.add(imageMessage);
        });

        await _cacheSingleMessageForSelectedChat(
          imageMessage,
          includeServerId: false,
        );

        _scrollToBottom();

        // Send photo to API if authenticated and chatMasterId available
        if (_userInfo != null &&
            _chatMasterId != null &&
            _selectedUser != null) {
          try {
            print('📸 DEBUG: Sending photo...');
            print('📸 DEBUG: Photo path: ${photo.path}');
            print('📸 DEBUG: File exists: ${await File(photo.path).exists()}');
            print(
              '📸 DEBUG: File size: ${await File(photo.path).length()} bytes',
            );
            print('📸 DEBUG: ChatMasterId: $_chatMasterId');

            final result = await ApiService.postChatDetail(
              chatMasterId: _chatMasterId!,
              value: 'Photo', // API requires value field
              attachmentFilePath: photo.path,
              attachmentType: 'Image',
            );

            if (result != null) {
              // API returned success - update message status to show check mark
              setState(() {
                final index = _messages.indexWhere((m) => m.id == tempId);
                if (index != -1) {
                  _messages[index] = ChatMessage(
                    id: result.containsKey('id') ? result['id'] : tempId,
                    value: _messages[index].value,
                    date: _messages[index].date,
                    userId: _messages[index].userId,
                    isSent: true, // Show check mark
                    status: 'Delivered',
                    isMine: _messages[index].isMine,
                    fileUrl: _messages[index].fileUrl,
                    sender: _messages[index].sender,
                    messageType: _messages[index].messageType,
                  );
                }
              });

              final updatedImageMessage = _messages.firstWhere(
                (m) =>
                    m.id == (result.containsKey('id') ? result['id'] : tempId),
                orElse: () => imageMessage,
              );
              await _cacheSingleMessageForSelectedChat(
                updatedImageMessage,
                includeServerId: true,
              );

              // Mark image message as delivered
              if (result.containsKey('id') && result['id'] != null) {
                await ApiService.updateChatDetailStatus(
                  chatDetailIds: [result['id']],
                  status: 'Delivered',
                );
              }
            } else {
              await _enqueuePendingItem(
                localId: tempId,
                type: 'image',
                value: 'Photo',
                filePath: photo.path,
                attachmentType: 'Image',
              );
            }
          } catch (e) {
            print('Error sending photo: $e');
            await _enqueuePendingItem(
              localId: tempId,
              type: 'image',
              value: 'Photo',
              filePath: photo.path,
              attachmentType: 'Image',
            );
          }
        }
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to take photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Gallery functionality
  void _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final imageMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
          value: 'Image',
          date: DateTime.now(),
          userId: _userInfo?['id'] ?? 0,
          isSent: false, // Will be updated after API call
          status: 'None',
          isMine: true,
          fileUrl: image.path,
          sender: _currentUserName,
          messageType: MessageType.image,
        );

        setState(() {
          _messages.add(imageMessage);
        });

        await _cacheSingleMessageForSelectedChat(
          imageMessage,
          includeServerId: false,
        );

        _scrollToBottom();

        // Send image to API if authenticated and chatMasterId available
        if (_userInfo != null &&
            _chatMasterId != null &&
            _selectedUser != null) {
          try {
            print('🖼️ DEBUG: Sending gallery image...');
            print('🖼️ DEBUG: Image path: ${image.path}');
            print('🖼️ DEBUG: File exists: ${await File(image.path).exists()}');
            print(
              '🖼️ DEBUG: File size: ${await File(image.path).length()} bytes',
            );
            print('🖼️ DEBUG: ChatMasterId: $_chatMasterId');

            final result = await ApiService.postChatDetail(
              chatMasterId: _chatMasterId!,
              value: 'Image', // API requires value field
              attachmentFilePath: image.path,
              attachmentType: 'Image',
            );

            if (result != null) {
              // Mark image message as delivered
              if (result['id'] != null) {
                await ApiService.updateChatDetailStatus(
                  chatDetailIds: [result['id']],
                  status: 'Delivered',
                );
              }
              setState(() {
                final index = _messages.indexWhere(
                  (m) => m.id == imageMessage.id,
                );
                if (index != -1) {
                  _messages[index] = _copyMessageWithStatus(
                    _messages[index],
                    isSent: true,
                    status: 'Delivered',
                    id: result['id'] ?? imageMessage.id,
                  );
                }
              });

              final updatedGalleryMessage = _messages.firstWhere(
                (m) => m.id == (result['id'] ?? imageMessage.id),
                orElse: () => imageMessage,
              );
              await _cacheSingleMessageForSelectedChat(
                updatedGalleryMessage,
                includeServerId: true,
              );
            } else {
              await _enqueuePendingItem(
                localId: imageMessage.id,
                type: 'image',
                value: imageMessage.value,
                filePath: image.path,
                attachmentType: 'Image',
              );
            }
          } catch (e) {
            print('Error sending image: $e');
            await _enqueuePendingItem(
              localId: imageMessage.id,
              type: 'image',
              value: imageMessage.value,
              filePath: image.path,
              attachmentType: 'Image',
            );
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pick image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Send Attachment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Document picker (placeholder)
  void _pickDocument() {
    // For now, just show a message. You can implement file_picker later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document picker not implemented yet'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Standalone mode: render only chat detail
    if (widget.standalone) {
      return Scaffold(
        body: SafeArea(
          child: _selectedUser == null
              ? const Center(child: Text('Select a contact'))
              : _buildChatArea(standalone: true),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Katawaz Exchange Chat'),
            if (kDebugMode)
              Text(
                '${ApiService.currentEnvironment} - ${ApiService.baseUrl}',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
        elevation: 1,
      ),
      body: Row(
        children: [
          // Left sidebar with toggle icon
          Container(
            width: _isExpanded ? MediaQuery.of(context).size.width * 0.8 : 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Toggle icon at top
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    ),
                  ),
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.close : Icons.menu,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      tooltip: _isExpanded ? 'Collapse' : 'Expand',
                    ),
                  ),
                ),
                // Users list
                Expanded(
                  child: _isExpanded
                      ? ListView.builder(
                          itemCount: _availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected =
                                _selectedUser?['id'] == user['id'];

                            return _buildUserListItem(user, isSelected);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected =
                                _selectedUser?['id'] == user['id'];

                            return _buildCircularUserItem(user, isSelected);
                          },
                        ),
                ),
              ],
            ),
          ),
          // Right side - Chat area
          Expanded(
            child: _selectedUser == null
                ? _buildNoChatSelected()
                : _buildChatArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user, bool isSelected) {
    final fullName = '${user['firstName']} ${user['lastName']}';
    final isOnline = user['isOnline'] ?? false;
    final unreadCount = user['unreadCount'] ?? 0;
    final avatarUrl = user['picUrlAvatar'] ?? '';

    return InkWell(
      onTap: () => _selectUser(user),
      child: Container(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    _buildCachedAvatarBox(
                      avatarPath: avatarUrl,
                      fullName: fullName,
                      size: 50,
                      borderRadius: BorderRadius.circular(25),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected
                                    ? const Color(0xFF075E54)
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF075E54),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['lastMessage'] ?? 'No messages yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 2,
                color: const Color(0xFF075E54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularUserItem(Map<String, dynamic> user, bool isSelected) {
    final fullName = '${user['firstName']} ${user['lastName']}';
    final avatarUrl = user['picUrlAvatar'] ?? '';
    final unreadRaw = user['unreadCount'];
    final unreadCount = unreadRaw is int
        ? unreadRaw
        : int.tryParse('${unreadRaw ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _selectUser(user),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _buildCachedAvatarBox(
                  avatarPath: avatarUrl,
                  fullName: fullName,
                  size: 56,
                  borderRadius: BorderRadius.circular(28),
                  backgroundColor: const Color(0xFF075E54),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String fullName, {double fontSize = 18}) {
    return Center(
      child: Text(
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildCachedAvatarBox({
    required String avatarPath,
    required String fullName,
    required double size,
    required BorderRadius borderRadius,
    required Color backgroundColor,
    double fallbackFontSize = 18,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        color: backgroundColor,
        child: FutureBuilder<ImageProvider?>(
          future: AvatarCacheService.getAvatarImageProvider(avatarPath),
          builder: (context, snapshot) {
            final provider = snapshot.data;
            if (provider == null) {
              return _buildAvatarFallback(fullName, fontSize: fallbackFontSize);
            }

            return Image(
              image: provider,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildAvatarFallback(
                  fullName,
                  fontSize: fallbackFontSize,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoChatSelected() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Color(0xFFBDBDBD)),
            SizedBox(height: 16),
            Text(
              'Select a contact to start chatting',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Choose from the list on the left',
              style: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea({bool standalone = false}) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFECE5DD)),
      child: Column(
        children: [
          // Chat header
          _buildChatHeader(standalone: standalone),
          // Messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100], // Simple background color instead
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final showDateHeader =
                      index == 0 ||
                      !_isSameDay(
                        message.timestamp,
                        _messages[index - 1].timestamp,
                      );

                  return Column(
                    children: [
                      if (showDateHeader) _buildDateHeader(message.timestamp),
                      _buildWhatsAppMessageBubble(message),
                    ],
                  );
                },
              ),
            ),
          ),
          // Message input
          _buildWhatsAppInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatHeader({bool standalone = false}) {
    if (_selectedUser == null) return const SizedBox.shrink();

    final fullName =
        '${_selectedUser!['firstName']} ${_selectedUser!['lastName']}';
    final isOnline = _selectedUser!['isOnline'] ?? false;
    final avatarUrl = _selectedUser!['picUrlAvatar'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        border: Border(bottom: BorderSide(color: Color(0xFF054A42), width: 1)),
      ),
      child: Row(
        children: [
          // Back button in standalone mode
          if (standalone)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          Stack(
            children: [
              FutureBuilder<ImageProvider?>(
                future: AvatarCacheService.getAvatarImageProvider(avatarUrl),
                builder: (context, snapshot) {
                  final provider = snapshot.data;
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: provider,
                    child: provider == null
                        ? Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  );
                },
              ),
              if (isOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedUser!['fullName'] ?? fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Last seen recently',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (_selectedUser!['userRoleTitle'] != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedUser!['userRoleTitle'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Add more actions like call, video call, etc.
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // Start voice recording (hold or lock mode)
  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;

    final hasPermission = await _voiceRecorder.checkPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎤 Microphone permission required'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              right: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    try {
      final didStart = await _voiceRecorder.startRecording();
      if (!didStart) {
        return;
      }

      setState(() {
        _isRecording = true;
        _isRecordingLocked = false;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
        _recordingDuration = Duration.zero;
        _waveformData = [];
      });

      HapticFeedback.lightImpact();

      // Start waveform animation
      _startWaveformAnimation();
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  // Stop and send voice (for hold mode)
  Future<void> _stopAndSendVoice() async {
    if (!_isRecording) return;

    try {
      final recordedDuration = _recordingDuration;
      final path = await _voiceRecorder.stopRecording();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
        _recordingDuration = Duration.zero;
        _waveformData = [];
      });

      if (recordedDuration < _minVoiceDuration) {
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice message is too short'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }

      if (path != null && path.isNotEmpty) {
        await _sendVoiceMessage(path);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
      });
    }
  }

  // Lock recording (for slide-up mode)
  Future<void> _lockRecording() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isRecordingLocked = true;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
      });
    } catch (e) {
      print('Error locking recording: $e');
    }
  }

  // Cancel recording
  void _cancelRecording() async {
    if (_isRecording) {
      await _voiceRecorder.cancelRecording();
    }
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _micDragOffset = 0.0;
      _micDragXOffset = 0.0;
      _cancelRecordingByGesture = false;
      _recordingDuration = Duration.zero;
      _waveformData = [];
    });
  }

  // Send locked voice message
  Future<void> _sendLockedVoiceMessage() async {
    if (!_isRecording && !_isRecordingLocked) return;

    final recordedDuration = _recordingDuration;
    final path = await _voiceRecorder.stopRecording();

    if (path == null || path.isEmpty) {
      await _voiceRecorder.cancelRecording();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
        _recordingDuration = Duration.zero;
        _waveformData = [];
      });
      return;
    }

    if (recordedDuration < _minVoiceDuration) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message is too short'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _micDragOffset = 0.0;
        _micDragXOffset = 0.0;
        _cancelRecordingByGesture = false;
        _recordingDuration = Duration.zero;
        _waveformData = [];
      });
      return;
    }

    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _micDragOffset = 0.0;
      _micDragXOffset = 0.0;
      _cancelRecordingByGesture = false;
      _recordingDuration = Duration.zero;
      _waveformData = [];
    });

    await _sendVoiceMessage(path);
  }

  // Animate waveform
  void _startWaveformAnimation() {
    Future.doWhile(() async {
      if (!_isRecording) return false;

      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration += const Duration(milliseconds: 100);
          // Generate random waveform data
          if (_waveformData.length >= 30) {
            _waveformData.removeAt(0);
          }
          _waveformData.add(
            0.2 + (0.8 * (DateTime.now().millisecond % 100) / 100),
          );
        });
      }
      return _isRecording;
    });
  }

  Widget _buildWhatsAppInputArea() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final cancelProgress = ((-_micDragXOffset) / 120)
        .clamp(0.0, 1.0)
        .toDouble();

    // Show locked recording UI
    if (_isRecordingLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            // Waveform visualization
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.mic, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildWaveform(isLocked: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Cancel button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _cancelRecording,
            ),
            // Send button
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendLockedVoiceMessage,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              // Text input area with emoji, attach, camera
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Emoji picker coming soon!',
                                textAlign: TextAlign.center,
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top + 10,
                                left: 20,
                                right: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          maxLines: null,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        onPressed: _showAttachmentOptions,
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.grey),
                        onPressed: _takePhoto,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right-side action: mic when empty, send when has text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: hasText
                    ? Container(
                        key: const ValueKey('send'),
                        decoration: const BoxDecoration(
                          color: Color(0xFF075E54),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _sendMessage,
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('mic'),
                        onPanStart: (_) {
                          setState(() {
                            _micDragOffset = 0.0;
                            _micDragXOffset = 0.0;
                            _cancelRecordingByGesture = false;
                          });
                          _startVoiceRecording();
                        },
                        onPanUpdate: (details) {
                          if (!_isRecording || _isRecordingLocked) return;

                          final wasLockArmed = _micDragOffset < -60;
                          final wasCancelArmed = _cancelRecordingByGesture;

                          var nextY = _micDragOffset + details.delta.dy;
                          var nextX = _micDragXOffset + details.delta.dx;

                          if (nextY < -80) nextY = -80;
                          if (nextY > 0) nextY = 0;

                          if (nextX < -120) nextX = -120;
                          if (nextX > 0) nextX = 0;

                          final nextCancelArmed = nextX < -75;
                          final nextLockArmed = nextY < -60;

                          if (!wasCancelArmed && nextCancelArmed) {
                            HapticFeedback.mediumImpact();
                          } else if (!wasLockArmed && nextLockArmed) {
                            HapticFeedback.selectionClick();
                          }

                          setState(() {
                            _micDragOffset = nextY;
                            _micDragXOffset = nextX;
                            _cancelRecordingByGesture = nextCancelArmed;
                          });
                        },
                        onPanEnd: (_) {
                          if (!_isRecording) return;

                          if (_cancelRecordingByGesture) {
                            _cancelRecording();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voice recording canceled'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          } else if (_micDragOffset < -60) {
                            // Locked mode (slid up far enough)
                            _lockRecording();
                          } else {
                            // Send immediately (hold mode)
                            _stopAndSendVoice();
                          }
                        },
                        child: Transform.translate(
                          offset: _isRecording
                              ? Offset(
                                  _micDragXOffset * 0.22,
                                  _micDragOffset * 0.22,
                                )
                              : Offset.zero,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            scale: _isRecording ? 2.0 : 1,
                            alignment: Alignment.bottomRight,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? Colors.red
                                    : const Color(0xFF075E54),
                                shape: BoxShape.circle,
                                boxShadow: _isRecording
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          // Recording indicator overlay
          if (_isRecording && !_isRecordingLocked)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 92,
              child: Container(
                color: Colors.white,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 44, child: _buildWaveform(isLocked: false)),
                    const SizedBox(width: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 17,
                        ),
                        tooltip: 'Cancel recording',
                        onPressed: _cancelRecording,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 126,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Slide left to cancel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: _cancelRecordingByGesture
                                    ? Colors.red
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_left,
                            size: 14,
                            color: _cancelRecordingByGesture
                                ? Colors.red
                                : Colors.grey,
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            height: 4,
                            width: 26 * cancelProgress,
                            decoration: BoxDecoration(
                              color: _cancelRecordingByGesture
                                  ? Colors.red
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Waveform widget
  Widget _buildWaveform({required bool isLocked}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(isLocked ? 30 : 20, (index) {
        final amplitude =
            _waveformData.isNotEmpty && index < _waveformData.length
            ? _waveformData[index]
            : 0.3;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: 20 * amplitude,
          decoration: BoxDecoration(
            color: isLocked ? Colors.red : Colors.red.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // Format duration for recording
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildWhatsAppMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: EdgeInsets.only(
                left: message.isMe ? 50 : 0,
                right: message.isMe ? 0 : 50,
              ),
              decoration: BoxDecoration(
                color: message.isMe
                    ? Colors.blue[100]! // WhatsApp light green
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(message.isMe ? 12 : 2),
                  bottomRight: Radius.circular(message.isMe ? 2 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!message.isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.sender,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _getSenderColor(message.sender),
                          ),
                        ),
                      ),
                    // Message content based on type
                    _buildMessageContent(message),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(
                            message.date,
                          ), // Use date field from new API format
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (message.isMine) ...[
                          const SizedBox(width: 4),
                          _buildMessageStatusIcon(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    if (message.messageType == MessageType.text &&
        (message.fileUrl != null || message.fileUrlThumb != null)) {
      final inferredType = _resolveMessageType(
        rawType: '',
        fileUrl: message.fileUrl,
        fileUrlThumb: message.fileUrlThumb,
        value: message.value,
      );

      if (inferredType == MessageType.voice) {
        return _buildVoiceMessageWidget(message);
      }
      if (inferredType == MessageType.image) {
        return _buildImageMessageWidget(message);
      }
      return _buildFileMessageWidget(message);
    }

    switch (message.messageType) {
      case MessageType.voice:
        return _buildVoiceMessageWidget(message);
      case MessageType.image:
        return _buildImageMessageWidget(message);
      case MessageType.file:
        return _buildFileMessageWidget(message);
      case MessageType.text:
        return Text(
          message.value, // Use value field from new API format
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        );
    }
  }

  Widget _buildMessageStatusIcon(ChatMessage message) {
    // Show status only for messages sent by current user
    if (!message.isMine) return const SizedBox.shrink();

    if (!message.isSent) {
      // Message not sent yet (sending...)
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      );
    }

    // Message sent successfully, show status based on Status field
    final statusLower = message.status.toLowerCase();

    // For seen/read messages - Blue double check
    if (statusLower == 'seen' ||
        statusLower == 'listen' ||
        statusLower == 'watch') {
      return Icon(
        Icons.done_all,
        size: 16,
        color: Colors.blue[700], // ✓✓ آبی - دیده شده
      );
    }

    // For delivered messages - Grey double check
    if (statusLower == 'delivered') {
      return Icon(
        Icons.done_all,
        size: 16,
        color: Colors.grey[600], // ✓✓ خاکستری - دریافت شده
      );
    }

    // For sent but not delivered - Single grey check
    return Icon(
      Icons.done,
      size: 16,
      color: Colors.grey[600], // ✓ تک - ارسال شده
    );
  }

  Widget _buildVoiceMessageWidget(ChatMessage message) {
    _ensureVoiceDurationLoaded(message);

    final hasDuration =
        message.duration != null && message.duration! > Duration.zero;
    final durationLabel = hasDuration
        ? _formatDuration(message.duration!)
        : (_resolvingVoiceDurationIds.contains(message.id) ? '...' : '--:--');
    final isCurrentlyPlaying = message.isPlaying ?? false;
    final totalDuration =
        (message.duration != null && message.duration! > Duration.zero)
        ? message.duration!
        : _activeVoiceDuration;
    final currentPosition = _activeVoiceMessageId == message.id
        ? _activeVoicePosition
        : Duration.zero;
    final effectiveCurrent =
        totalDuration > Duration.zero && currentPosition > totalDuration
        ? totalDuration
        : currentPosition;
    final progress = totalDuration > Duration.zero
        ? (effectiveCurrent.inMilliseconds / totalDuration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;
    final attachmentKey = _attachmentKey(message);
    final isDownloading = _downloadingAttachmentKeys.contains(attachmentKey);
    final isDownloaded = _downloadedAttachmentPaths.containsKey(attachmentKey);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () => _toggleVoicePlayback(message),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF075E54).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF075E54),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Voice waveform visualization (simplified)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF075E54),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDuration(effectiveCurrent)} / $durationLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDownloading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[600],
              ),
            )
          else
            GestureDetector(
              onTap: () => _downloadMessageAttachment(message),
              child: Icon(
                isDownloaded ? Icons.check_circle : Icons.download,
                color: isDownloaded ? Colors.green : Colors.grey[600],
                size: 18,
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.mic, color: Colors.grey[400], size: 16),
        ],
      ),
    );
  }

  Widget _buildImageMessageWidget(ChatMessage message) {
    final attachmentKey = _attachmentKey(message);
    final isDownloading = _downloadingAttachmentKeys.contains(attachmentKey);
    final isDownloaded = _downloadedAttachmentPaths.containsKey(attachmentKey);
    final imageSource = message.fileUrl ?? message.fileUrlThumb;

    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              // Mark image as watched when tapped (only if it's not from current user)
              if (!message.isMe && message.messageId != null) {
                _markImageAsWatched(message.messageId!);
              }
              // Here you could also implement full-screen image viewing
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  imageSource != null
                      ? FutureBuilder<File>(
                          future: _getCachedImage(imageSource),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              // Show loading indicator while downloading/caching
                              return Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            } else if (snapshot.hasError || !snapshot.hasData) {
                              // Show error state if download failed
                              return Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Display cached image file
                              return Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.grey[200],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image error',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        )
                      : Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                  if (imageSource != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isDownloading
                              ? null
                              : () => _downloadMessageAttachment(message),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: isDownloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isDownloaded
                                        ? Icons.check_circle
                                        : Icons.download,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (message.value.isNotEmpty &&
              message.value != 'Photo' &&
              message.value != 'Image')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message.value, // Use value field from new API format
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get cached image with authentication
  Future<File> _getCachedImage(String imageUrl) async {
    final token = await ApiService.getAuthToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

    final filePath = await _resolveAttachmentSourcePath(
      imageUrl,
      headers: headers,
    );
    if (filePath == null) {
      throw Exception('Failed to download image');
    }
    return File(filePath);
  }

  Widget _buildFileMessageWidget(ChatMessage message) {
    final attachmentKey = _attachmentKey(message);
    final isDownloading = _downloadingAttachmentKeys.contains(attachmentKey);
    final isDownloaded = _downloadedAttachmentPaths.containsKey(attachmentKey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.value, // Use value field from new API format
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDownloading
                      ? 'Downloading...'
                      : isDownloaded
                      ? 'Saved to device'
                      : 'Document',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          isDownloading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isDownloaded ? Icons.check_circle : Icons.download,
                    color: isDownloaded ? Colors.green : Colors.grey[600],
                  ),
                  onPressed: () {
                    _downloadMessageAttachment(message);
                  },
                ),
        ],
      ),
    );
  }

  String _attachmentKey(ChatMessage message) {
    final attachmentRef = message.fileUrl ?? message.fileUrlThumb ?? '';
    return '${message.id}_${attachmentRef}_${message.messageType.name}';
  }

  MessageType _resolveMessageType({
    required String rawType,
    String? fileUrl,
    String? fileUrlThumb,
    required String value,
  }) {
    final normalizedType = rawType.trim().toLowerCase();
    final probe =
        '$normalizedType ${fileUrl ?? ''} ${fileUrlThumb ?? ''} ${value.toLowerCase()}';

    if (normalizedType == '2') {
      return MessageType.image;
    }
    if (normalizedType == '3') {
      return MessageType.voice;
    }
    if (normalizedType == '4') {
      return MessageType.file;
    }

    if (probe.contains('voice') ||
        probe.contains('audio') ||
        probe.contains('.mp3') ||
        probe.contains('.wav') ||
        probe.contains('.m4a') ||
        probe.contains('.aac') ||
        probe.contains('.ogg') ||
        probe.contains('.opus')) {
      return MessageType.voice;
    }

    if (probe.contains('image') ||
        probe.contains('photo') ||
        probe.contains('picture') ||
        probe.contains('.jpg') ||
        probe.contains('.jpeg') ||
        probe.contains('.png') ||
        probe.contains('.gif') ||
        probe.contains('.webp') ||
        probe.contains('.bmp') ||
        probe.contains('.heic')) {
      return MessageType.image;
    }

    if ((fileUrl != null && fileUrl.trim().isNotEmpty) ||
        (fileUrlThumb != null && fileUrlThumb.trim().isNotEmpty)) {
      return MessageType.file;
    }

    return MessageType.text;
  }

  Duration? _extractVoiceDuration(Map<String, dynamic> msg) {
    final raw = _readStringFromKeys(msg, const [
      'Duration',
      'duration',
      'VoiceDuration',
      'voiceDuration',
      'DurationSeconds',
      'durationSeconds',
      'DurationSecond',
      'durationSecond',
      'VoiceTime',
      'voiceTime',
      'Seconds',
      'seconds',
      'Length',
      'length',
      'Time',
      'time',
    ]);

    if (raw == null || raw.isEmpty) return null;

    final numeric = double.tryParse(raw);
    if (numeric != null) {
      if (numeric > 1000) {
        return Duration(milliseconds: numeric.round());
      }
      return Duration(seconds: numeric.round());
    }

    final parts = raw.split(':');
    if (parts.length == 2 || parts.length == 3) {
      final values = parts.map((p) => int.tryParse(p.trim()) ?? 0).toList();
      if (parts.length == 2) {
        return Duration(minutes: values[0], seconds: values[1]);
      }
      return Duration(hours: values[0], minutes: values[1], seconds: values[2]);
    }

    return null;
  }

  void _ensureVoiceDurationLoaded(ChatMessage message) {
    if (message.messageType != MessageType.voice) return;
    if (message.duration != null && message.duration! > Duration.zero) return;
    if (_activeVoiceMessageId != null) return;
    if (_resolvingVoiceDurationIds.contains(message.id)) return;

    final durationKey = _attachmentKey(message);
    if (_failedVoiceDurationKeys.contains(durationKey)) return;

    _resolvingVoiceDurationIds.add(message.id);

    Future(() async {
      final token = await ApiService.getAuthToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

      final sourcePath = await _prepareVoicePlaybackPath(
        message,
        headers: headers,
      );
      if (sourcePath == null) {
        _failedVoiceDurationKeys.add(durationKey);
        return;
      }

      final resolved = await _voiceRecorder.getAudioDuration(sourcePath);
      if (resolved == null || resolved <= Duration.zero) {
        _failedVoiceDurationKeys.add(durationKey);
        return;
      }

      _failedVoiceDurationKeys.remove(durationKey);
      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: _messages[index].id,
            value: _messages[index].value,
            fileUrl: _messages[index].fileUrl,
            fileUrlThumb: _messages[index].fileUrlThumb,
            date: _messages[index].date,
            userId: _messages[index].userId,
            isSent: _messages[index].isSent,
            status: _messages[index].status,
            isMine: _messages[index].isMine,
            sender: _messages[index].sender,
            messageType: _messages[index].messageType,
            duration: resolved,
            isPlaying: _messages[index].isPlaying,
          );
        }
      });
    }).whenComplete(() {
      _resolvingVoiceDurationIds.remove(message.id);
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool _hasKnownAudioExtension(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus');
  }

  bool _looksLikeAudioReference(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.contains('.mp3') ||
        lower.contains('.wav') ||
        lower.contains('.m4a') ||
        lower.contains('.aac') ||
        lower.contains('.ogg') ||
        lower.contains('.opus') ||
        lower.contains('/voice') ||
        lower.contains('voice_') ||
        lower.contains('audio');
  }

  String? _pickVoiceAttachmentUrl(ChatMessage message) {
    final fileUrl = message.fileUrl;
    final thumbUrl = message.fileUrlThumb;

    if (_looksLikeAudioReference(fileUrl)) return fileUrl;
    if (_looksLikeAudioReference(thumbUrl)) return thumbUrl;

    return fileUrl ?? thumbUrl;
  }

  Future<String?> _prepareVoicePlaybackPath(
    ChatMessage message, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final attachmentUrl = _pickVoiceAttachmentUrl(message);
    if (attachmentUrl == null || attachmentUrl.isEmpty) return null;

    final sourcePath = await _resolveAttachmentSourcePath(
      attachmentUrl,
      headers: headers,
      forceRefresh: forceRefresh,
    );
    if (sourcePath == null) return null;

    if (_hasKnownAudioExtension(sourcePath)) {
      return sourcePath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final convertedPath =
          '${tempDir.path}/voice_${message.id}_${DateTime.now().millisecondsSinceEpoch}.aac';
      await File(sourcePath).copy(convertedPath);
      return convertedPath;
    } catch (_) {
      return sourcePath;
    }
  }

  String? _readStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final normalized = value.toString().trim();
      if (normalized.isEmpty) continue;
      if (normalized.toLowerCase() == 'null' ||
          normalized.toLowerCase() == 'undefined') {
        continue;
      }
      return normalized;
    }
    return null;
  }

  bool _isLikelyLocalPath(String value) {
    return value.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }

  String _buildRemoteFileUrl(String fileUrl) {
    final raw = fileUrl.trim();
    if (raw.isEmpty) return raw;

    final cleaned = raw.replaceAll('\\', '/');
    final hasHttpScheme =
        cleaned.startsWith('http://') || cleaned.startsWith('https://');

    if (hasHttpScheme) {
      return Uri.encodeFull(cleaned);
    }

    final normalizedPath = cleaned.startsWith('/') ? cleaned : '/$cleaned';
    return Uri.encodeFull('${ApiService.baseImageUrl}$normalizedPath');
  }

  Future<String?> _resolveAttachmentSourcePath(
    String fileUrl, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    final raw = fileUrl.trim();
    if (raw.isEmpty) return null;

    final fileUri = Uri.tryParse(raw);
    if (fileUri != null && fileUri.scheme == 'file') {
      final localPath = fileUri.toFilePath();
      if (await File(localPath).exists()) {
        return localPath;
      }
    }

    if (_isLikelyLocalPath(raw)) {
      final localFile = File(raw);
      if (await localFile.exists()) {
        return localFile.path;
      }
    }

    final remoteUrl = _buildRemoteFileUrl(raw);
    return FileCacheService.getFile(
      remoteUrl,
      headers: headers,
      forceRefresh: forceRefresh,
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${appDir.path}/downloads');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  String _extractFileName(String fileUrl, MessageType type) {
    try {
      final uri = Uri.parse(fileUrl);
      final fromUrl = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (fromUrl.isNotEmpty && fromUrl.contains('.')) {
        return fromUrl;
      }
    } catch (_) {}

    switch (type) {
      case MessageType.image:
        return 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      case MessageType.voice:
        return 'chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      default:
        return 'chat_file_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _downloadMessageAttachment(ChatMessage message) async {
    final attachmentUrl = message.fileUrl ?? message.fileUrlThumb;
    if (attachmentUrl == null || attachmentUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available for download')),
      );
      return;
    }

    final attachmentKey = _attachmentKey(message);

    if (_downloadingAttachmentKeys.contains(attachmentKey)) {
      return;
    }

    final existingPath = _downloadedAttachmentPaths[attachmentKey];
    if (existingPath != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Already saved: $existingPath')));
      return;
    }

    setState(() {
      _downloadingAttachmentKeys.add(attachmentKey);
    });

    try {
      final token = await ApiService.getAuthToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      final sourcePath = await _resolveAttachmentSourcePath(
        attachmentUrl,
        headers: headers,
      );

      if (sourcePath == null) {
        throw Exception('Download failed');
      }

      final downloadsDir = await _resolveDownloadDirectory();
      final sourceFile = File(sourcePath);
      final originalName = _extractFileName(attachmentUrl, message.messageType);
      var targetPath = '${downloadsDir.path}/$originalName';
      var counter = 1;

      while (await File(targetPath).exists()) {
        final dotIndex = originalName.lastIndexOf('.');
        final baseName = dotIndex > 0
            ? originalName.substring(0, dotIndex)
            : originalName;
        final extension = dotIndex > 0 ? originalName.substring(dotIndex) : '';
        targetPath = '${downloadsDir.path}/${baseName}_$counter$extension';
        counter++;
      }

      await sourceFile.copy(targetPath);

      setState(() {
        _downloadingAttachmentKeys.remove(attachmentKey);
        _downloadedAttachmentPaths[attachmentKey] = targetPath;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to: $targetPath')));
    } catch (e) {
      setState(() {
        _downloadingAttachmentKeys.remove(attachmentKey);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  void _toggleVoicePlayback(ChatMessage message) async {
    print('🎵 _toggleVoicePlayback called: fileUrl=${message.fileUrl}');

    if ((message.fileUrl ?? '').isEmpty &&
        (message.fileUrlThumb ?? '').isEmpty) {
      return;
    }

    final isCurrentlyPlaying = message.isPlaying ?? false;

    if (isCurrentlyPlaying) {
      await _voiceRecorder.pauseVoiceMessage();
      if (!mounted) return;
      setState(() {
        if (_activeVoiceMessageId == message.id) {
          _activeVoiceMessageId = null;
        }
        final messageIndex = _messages.indexOf(message);
        if (messageIndex != -1) {
          _messages[messageIndex] = ChatMessage(
            id: message.id,
            value: message.value,
            fileUrl: message.fileUrl,
            fileUrlThumb: message.fileUrlThumb,
            date: message.date,
            userId: message.userId,
            isSent: message.isSent,
            status: message.status,
            isMine: message.isMine,
            sender: message.sender,
            messageType: message.messageType,
            duration: message.duration,
            isPlaying: false,
          );
        }
      });
      return;
    } else {
      // Get authentication token for API downloads
      final token = await ApiService.getAuthToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

      final sourcePath = await _prepareVoicePlaybackPath(
        message,
        headers: headers,
      );
      if (sourcePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load voice file')),
          );
        }
        return;
      }
      final didPlay = await _voiceRecorder.playVoiceMessage(sourcePath);
      if (!didPlay) {
        final refreshedSourcePath = await _prepareVoicePlaybackPath(
          message,
          headers: headers,
          forceRefresh: true,
        );

        if (refreshedSourcePath != null) {
          final retryDidPlay = await _voiceRecorder.playVoiceMessage(
            refreshedSourcePath,
          );

          if (retryDidPlay) {
            if (!mounted) return;
            setState(() {
              _activeVoiceMessageId = message.id;
              _activeVoicePosition = Duration.zero;
              _activeVoiceDuration = message.duration ?? Duration.zero;

              _messages = _messages
                  .map(
                    (m) => ChatMessage(
                      id: m.id,
                      value: m.value,
                      fileUrl: m.fileUrl,
                      fileUrlThumb: m.fileUrlThumb,
                      date: m.date,
                      userId: m.userId,
                      isSent: m.isSent,
                      status: m.status,
                      isMine: m.isMine,
                      sender: m.sender,
                      messageType: m.messageType,
                      duration: m.duration,
                      isPlaying: m.id == message.id,
                    ),
                  )
                  .toList();
            });
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to play voice file')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _activeVoiceMessageId = message.id;
          _activeVoicePosition = Duration.zero;
          _activeVoiceDuration = message.duration ?? Duration.zero;

          _messages = _messages
              .map(
                (m) => ChatMessage(
                  id: m.id,
                  value: m.value,
                  fileUrl: m.fileUrl,
                  fileUrlThumb: m.fileUrlThumb,
                  date: m.date,
                  userId: m.userId,
                  isSent: m.isSent,
                  status: m.status,
                  isMine: m.isMine,
                  sender: m.sender,
                  messageType: m.messageType,
                  duration: m.duration,
                  isPlaying: m.id == message.id,
                ),
              )
              .toList();

          final messageIndex = _messages.indexOf(message);
          if (messageIndex != -1) {
            _messages[messageIndex] = ChatMessage(
              id: message.id,
              value: message.value,
              fileUrl: message.fileUrl,
              fileUrlThumb: message.fileUrlThumb,
              date: message.date,
              userId: message.userId,
              isSent: message.isSent,
              status: message.status,
              isMine: message.isMine,
              sender: message.sender,
              messageType: message.messageType,
              duration: message.duration,
              isPlaying: true,
            );
          }
        });
      }

      // Mark voice message as listened when played (only if it's not from current user)
      if (!message.isMe && message.messageId != null) {
        await _markVoiceAsListened(message.messageId!);
      }
    }
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _getSenderColor(String sender) {
    final colors = [
      Colors.red[700]!,
      Colors.blue[700]!,
      Colors.green[700]!,
      Colors.purple[700]!,
      Colors.orange[700]!,
      Colors.teal[700]!,
    ];
    return colors[sender.hashCode % colors.length];
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  @override
  void dispose() {
    ChatSyncService.stop();
    _voicePositionSubscription?.cancel();
    _voiceStateSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }
}

enum MessageType { text, image, file, voice }

class ChatMessage {
  final int id; // Message ID from API
  final String value; // Message text content
  final String? fileUrl; // Full file URL
  final String? fileUrlThumb; // Thumbnail URL for files
  final DateTime date; // Message date
  final int userId; // Sender's user ID
  final bool isSent; // Whether message was sent successfully
  final String status; // Message status (None, Delivered, Seen, etc.)
  final bool isMine; // Whether current user sent this message

  // Additional UI properties
  final String sender;
  final MessageType messageType;
  final Duration? duration; // For voice messages
  final bool? isPlaying; // For voice message playback state

  ChatMessage({
    required this.id,
    required this.value,
    required this.date,
    required this.userId,
    required this.isSent,
    required this.status,
    required this.isMine,
    this.fileUrl,
    this.fileUrlThumb,
    required this.sender,
    this.messageType = MessageType.text,
    this.duration,
    this.isPlaying,
  });

  // Backward compatibility getters
  String get message => value;
  DateTime get timestamp => date;
  bool get isMe => isMine;
  String? get filePath => fileUrl;
  int? get messageId => id;
}
