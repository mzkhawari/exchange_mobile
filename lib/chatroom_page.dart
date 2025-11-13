import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'services/voice_recorder_service.dart';

class ChatroomPage extends StatefulWidget {
  const ChatroomPage({super.key});

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
  bool _showPicturesOnly = true; // Start with pictures only (primary state)
  bool _isExpanded = false; // Track if left sidebar is expanded
  int? _chatMasterId; // Chat master ID for API calls
  
  // Voice recording variables
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  bool _isHoldingMic = false;
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadUserData().then((_) {
      // Always load available users, regardless of authentication status
      _loadAvailableUsers();
    });
    
    // Add listener to message controller to update send button
    _messageController.addListener(() {
      setState(() {
        // This will update the send button icon based on text content
      });
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService.getUserInfo();
      
      if (userData != null) {
        setState(() {
          _userInfo = userData;
          _currentUserName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
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
      
      // Get users from API
      final users = await ApiService.getAllUsers();
      
      if (users.isNotEmpty) {
        // Transform API user data to match UI requirements
        final transformedUsers = users.map((user) {
          // Debug: Print user data to see what we're getting
          print('User data: ${user.toString()}');
          return {
            'id': user['id'] ?? 0,
            'firstName': user['firstName'] ?? 'Unknown',
            'lastName': user['lastName'] ?? 'User',
            'picUrlAvatar': user['picUrlAvatar'] ?? '', // Store raw URL
            'userName': user['userName'] ?? '',
            'email': user['email'] ?? '',
            'isOnline': true, // Default to online, can be updated with real status
            'lastMessage': 'Available for chat',
            'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 1)),
            'unreadCount': 0,
          };
        }).toList();
        
        setState(() {
          _availableUsers = transformedUsers;
          _isLoadingUsers = false;
        });
      } else {
        // Fallback to mock data if API fails or no users found
        final mockUsers = [
          {
            'id': 1,
            'firstName': 'Ahmad',
            'lastName': 'Hassan',
            'picUrlAvatar': '/content/user/thumb/ahmad_avatar.png',
            'isOnline': true,
            'lastMessage': 'Hello! How can I help you today?',
            'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 5)),
            'unreadCount': 2,
          },
          {
            'id': 2,
            'firstName': 'Sara',
            'lastName': 'Ali',
            'picUrlAvatar': '/content/user/thumb/sara_avatar.png',
            'isOnline': false,
            'lastMessage': 'Thanks for the transaction details.',
            'lastMessageTime': DateTime.now().subtract(const Duration(hours: 2)),
            'unreadCount': 0,
          },
        ];
        
        setState(() {
          _availableUsers = mockUsers;
          _isLoadingUsers = false;
        });
      }
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
  }



  void _initializeChat() {
    _messages = [
      ChatMessage(
        sender: 'Admin',
        message: 'Welcome to Katawaz Exchange! 👋',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isMe: false,
        messageType: MessageType.text,
      ),
      ChatMessage(
        sender: 'System',
        message: 'Exchange rates updated successfully ✅',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isMe: false,
        messageType: MessageType.text,
      ),
      ChatMessage(
        sender: 'Support',
        message: 'How can we help you today?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
        messageType: MessageType.text,
      ),
    ];
  }

  Future<void> _loadChatMessages() async {
    // Only load messages from API if user is authenticated and chatMasterId is available
    if (_userInfo != null && _chatMasterId != null) {
      try {
        final messages = await ApiService.getChatDetails(_chatMasterId!);
        if (messages != null && messages.isNotEmpty) {
          setState(() {
            _messages.addAll(messages.map((msg) => ChatMessage(
              sender: msg['senderName'] ?? msg['sender'] ?? 'Unknown',
              message: msg['messageText'] ?? msg['message'] ?? '',
              timestamp: DateTime.tryParse(msg['createdAt'] ?? msg['timestamp'] ?? '') ?? DateTime.now(),
              isMe: msg['senderId'] == _userInfo?['id'],
              messageType: _getMessageType(msg['messageType'] ?? 'Text'),
              filePath: msg['voiceFilePath'] ?? msg['attachmentFilePath'],
              duration: msg['duration'],
              messageId: msg['id'],
              status: msg['status'],
            )));
          });
        }
      } catch (e) {
        print('Error loading chat messages: $e');
      }
    } else if (_userInfo == null) {
      // Guest mode - show welcome message
      setState(() {
        _messages.add(ChatMessage(
          sender: 'System',
          message: 'Welcome to the chat room! You are in guest mode. Login to sync with your conversations.',
          timestamp: DateTime.now(),
          isMe: false,
          messageType: MessageType.text,
        ));
      });
    }
  }

  // Helper method to convert API message type to local MessageType
  MessageType _getMessageType(String apiType) {
    switch (apiType.toLowerCase()) {
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      case 'document':
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
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
        .where((msg) => !msg.isMe && 
                      msg.messageId != null && 
                      (msg.status == null || msg.status != 'Seen'))
        .map((msg) => msg.messageId!)
        .toList();
    
    if (unseenMessageIds.isNotEmpty) {
      await _markMessagesAsSeen(unseenMessageIds);
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    final message = ChatMessage(
      sender: _currentUserName,
      message: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      messageType: MessageType.text,
    );

    setState(() {
      _messages.add(message);
    });
    
    _messageController.clear();
    _scrollToBottom();

    // Send message to API only if user is authenticated and chatMasterId is available
    if (_userInfo != null && _chatMasterId != null) {
      try {
        final result = await ApiService.postChatDetail(
          chatMasterId: _chatMasterId!,
          messageText: messageText,
        );
        
        if (result == null) {
          // Show error if message failed to send
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          // Mark message as delivered
          if (result['id'] != null) {
            await ApiService.updateChatDetailStatus(
              chatDetailIds: [result['id']],
              status: 'Delivered',
            );
          }
        }
      } catch (e) {
        print('Error sending message: $e');
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent in offline mode. Login to sync with server.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Guest mode - show info message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent in guest mode. Login to sync with server.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // Voice recording methods
  void _startRecording() async {
    final hasPermission = await _voiceRecorder.checkPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice messages'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await _voiceRecorder.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
      });
      
      // Show recording UI feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.red),
              SizedBox(width: 8),
              Text('Recording voice message...'),
            ],
          ),
          duration: Duration(seconds: 60), // Long duration for recording
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    
    final recordingPath = await _voiceRecorder.stopRecording();
    setState(() {
      _isRecording = false;
    });
    
    // Hide recording feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (recordingPath != null) {
      // Get audio duration
      final duration = await _voiceRecorder.getAudioDuration(recordingPath);
      
      // Create voice message
      final voiceMessage = ChatMessage(
        sender: _currentUserName,
        message: 'Voice message',
        timestamp: DateTime.now(),
        isMe: true,
        messageType: MessageType.voice,
        filePath: recordingPath,
        duration: duration,
      );

      setState(() {
        _messages.add(voiceMessage);
      });
      
      _scrollToBottom();
      
      // Send voice message to API if authenticated and chatMasterId available
      if (_userInfo != null && _chatMasterId != null) {
        try {
          final result = await ApiService.postChatDetail(
            chatMasterId: _chatMasterId!,
            voiceFilePath: recordingPath,
          );
          
          if (result != null) {
            // Mark voice message as delivered
            if (result['id'] != null) {
              await ApiService.updateChatDetailStatus(
                chatDetailIds: [result['id']],
                status: 'Delivered',
              );
            }
            
            // Show success feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice message sent!'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            // Show error feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send voice message'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          print('Error sending voice message: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error sending voice message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Show success feedback for guest mode
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message sent!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record voice message'),
          backgroundColor: Colors.red,
        ),
      );
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
        final imageMessage = ChatMessage(
          sender: _currentUserName,
          message: 'Photo',
          timestamp: DateTime.now(),
          isMe: true,
          messageType: MessageType.image,
          filePath: photo.path,
        );

        setState(() {
          _messages.add(imageMessage);
        });
        
        _scrollToBottom();
        
        // Send photo to API if authenticated and chatMasterId available
        if (_userInfo != null && _chatMasterId != null) {
          try {
            final result = await ApiService.postChatDetail(
              chatMasterId: _chatMasterId!,
              attachmentFilePath: photo.path,
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
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo sent!'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to send photo'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            print('Error sending photo: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error sending photo'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo sent!'),
              duration: Duration(seconds: 2),
            ),
          );
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
          sender: _currentUserName,
          message: 'Image',
          timestamp: DateTime.now(),
          isMe: true,
          messageType: MessageType.image,
          filePath: image.path,
        );

        setState(() {
          _messages.add(imageMessage);
        });
        
        _scrollToBottom();
        
        // Send image to API if authenticated and chatMasterId available
        if (_userInfo != null && _chatMasterId != null) {
          try {
            final result = await ApiService.postChatDetail(
              chatMasterId: _chatMasterId!,
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
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image sent!'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to send image'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            print('Error sending image: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error sending image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image sent!'),
              duration: Duration(seconds: 2),
            ),
          );
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
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
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
        appBar: AppBar(
          backgroundColor: const Color(0xFF075E54),
          title: const Text('Chat', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF075E54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text('Katawaz Exchange Chat', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF075E54),
                    border: Border(
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
                          final isSelected = _selectedUser?['id'] == user['id'];
                          
                          return _buildUserListItem(user, isSelected);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = _availableUsers[index];
                          final isSelected = _selectedUser?['id'] == user['id'];
                          
                          return _buildCircularUserItem(user, isSelected);
                        },
                      ),
                ),
              ],
            ),
          ),
          // Right side - Chat area
          Expanded(
            child: _selectedUser == null ? _buildNoChatSelected() : _buildChatArea(),
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
        color: isSelected ? const Color(0xFFE8F5E8) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF075E54),
                        child: avatarUrl.isNotEmpty 
                          ? Image.network(
                              ApiService.getFullAvatarUrl(avatarUrl),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading avatar for $fullName: $error');
                                return Center(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                      ),
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
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected ? const Color(0xFF075E54) : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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

  Widget _buildUserPictureItem(Map<String, dynamic> user, bool isSelected) {
    final fullName = '${user['firstName']} ${user['lastName']}';
    final avatarUrl = user['picUrlAvatar'] ?? '';
    
    return InkWell(
      onTap: () => _selectUser(user),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF075E54) : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? const Color(0xFFE8F5E8) : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF075E54),
                  backgroundImage: avatarUrl.isNotEmpty 
                    ? NetworkImage(avatarUrl) 
                    : null,
                  child: avatarUrl.isEmpty 
                    ? Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      )
                    : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                fullName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF075E54) : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularUserItem(Map<String, dynamic> user, bool isSelected) {
    final fullName = '${user['firstName']} ${user['lastName']}';
    final avatarUrl = user['picUrlAvatar'] ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _selectUser(user),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF075E54) : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFF075E54),
              child: avatarUrl.isNotEmpty 
                ? Image.network(
                    ApiService.getFullAvatarUrl(avatarUrl),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading avatar for $fullName: $error');
                      return Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
            ),
          ),
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
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Color(0xFFBDBDBD),
            ),
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
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFECE5DD),
      ),
      child: Column(
        children: [
          // Chat header
          _buildChatHeader(),
          // Messages area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/whatsapp_bg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.05,
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final showDateHeader = index == 0 || 
                      !_isSameDay(message.timestamp, _messages[index - 1].timestamp);
                  
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

  Widget _buildChatHeader() {
    if (_selectedUser == null) return const SizedBox.shrink();
    
    final fullName = '${_selectedUser!['firstName']} ${_selectedUser!['lastName']}';
    final isOnline = _selectedUser!['isOnline'] ?? false;
    final avatarUrl = _selectedUser!['picUrlAvatar'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        border: Border(
          bottom: BorderSide(color: Color(0xFF054A42), width: 1),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: avatarUrl.isNotEmpty 
                  ? NetworkImage(avatarUrl) 
                  : null,
                child: avatarUrl.isEmpty 
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF075E54),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  PreferredSizeWidget _buildWhatsAppAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF075E54), // WhatsApp green
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Icon(Icons.support_agent, color: Color(0xFF075E54)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Katawaz Exchange Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _userInfo != null ? 'Welcome $_currentUserName' : 'Online now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            // Handle menu actions
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'info', child: Text('Contact info')),
            const PopupMenuItem(value: 'media', child: Text('Media, links, docs')),
            const PopupMenuItem(value: 'search', child: Text('Search')),
            const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
            const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
          ],
        ),
      ],
    );
  }

  Widget _buildWhatsAppInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Voice message button (outside text input)
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hold to record voice message'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRecording 
                      ? Colors.red.withOpacity(0.2)
                      : const Color(0xFF075E54).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none,
                  color: _isRecording ? Colors.red : const Color(0xFF075E54),
                  size: 24,
                ),
              ),
            ),
          ),
          // Text input area
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
                    icon: const Icon(Icons.emoji_emotions_outlined, 
                        color: Colors.grey),
                    onPressed: () {
                      // TODO: Implement emoji picker
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Emoji picker coming soon!'),
                          duration: Duration(seconds: 1),
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _messageController.text.trim().isNotEmpty 
                  ? const Color(0xFF075E54) 
                  : Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _messageController.text.trim().isNotEmpty 
                  ? _sendMessage 
                  : null,
            ),
          ),
        ],
      ),
    );
  }  Widget _buildWhatsAppMessageBubble(ChatMessage message) {
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
                    ? const Color(0xFFDCF8C6) // WhatsApp light green
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (message.isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all, // Double check mark
                            size: 16,
                            color: Colors.blue[700], // Read receipt
                          ),
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
    switch (message.messageType) {
      case MessageType.voice:
        return _buildVoiceMessageWidget(message);
      case MessageType.image:
        return _buildImageMessageWidget(message);
      case MessageType.file:
        return _buildFileMessageWidget(message);
      case MessageType.text:
      default:
        return Text(
          message.message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        );
    }
  }

  Widget _buildVoiceMessageWidget(ChatMessage message) {
    final duration = message.duration ?? Duration.zero;
    final isCurrentlyPlaying = message.isPlaying ?? false;
    
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
                // Simplified waveform
                Row(
                  children: List.generate(15, (index) {
                    final heights = [2.0, 8.0, 4.0, 12.0, 6.0, 10.0, 3.0, 9.0, 5.0, 11.0, 7.0, 4.0, 8.0, 6.0, 3.0];
                    return Container(
                      margin: const EdgeInsets.only(right: 2),
                      width: 3,
                      height: heights[index],
                      decoration: BoxDecoration(
                        color: isCurrentlyPlaying 
                            ? const Color(0xFF075E54)
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                // Duration
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Microphone icon
          Icon(
            Icons.mic,
            color: Colors.grey[400],
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessageWidget(ChatMessage message) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 250,
        maxHeight: 300,
      ),
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
              child: message.filePath != null
                  ? Image.file(
                      File(message.filePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Image not found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
                  ),
            ),
          ),
          if (message.message.isNotEmpty && message.message != 'Photo' && message.message != 'Image')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message.message,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileMessageWidget(ChatMessage message) {
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
            child: Icon(Icons.insert_drive_file, color: Colors.blue[700], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Document',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.grey[600]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File download not implemented yet'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleVoicePlayback(ChatMessage message) async {
    if (message.filePath == null) return;
    
    final isCurrentlyPlaying = message.isPlaying ?? false;
    
    if (isCurrentlyPlaying) {
      await _voiceRecorder.pauseVoiceMessage();
    } else {
      await _voiceRecorder.playVoiceMessage(message.filePath!);
      
      // Mark voice message as listened when played (only if it's not from current user)
      if (!message.isMe && message.messageId != null) {
        await _markVoiceAsListened(message.messageId!);
      }
    }
    
    // Update the message playing state
    setState(() {
      final messageIndex = _messages.indexOf(message);
      if (messageIndex != -1) {
        _messages[messageIndex] = ChatMessage(
          sender: message.sender,
          message: message.message,
          timestamp: message.timestamp,
          isMe: message.isMe,
          messageType: message.messageType,
          filePath: message.filePath,
          duration: message.duration,
          isPlaying: !isCurrentlyPlaying,
          messageId: message.messageId,
          status: message.status,
        );
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    _messageController.dispose();
    _scrollController.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }
}

enum MessageType {
  text,
  image,
  file,
  voice,
}

class ChatMessage {
  final String sender;
  final String message;
  final DateTime timestamp;
  final bool isMe;
  final MessageType messageType;
  final String? filePath;  // For voice messages and files
  final Duration? duration; // For voice messages
  final bool? isPlaying;   // For voice message playback state
  final int? messageId;    // API message ID for status updates
  final String? status;    // Message status: Delivered, Seen, Listen, Watch

  ChatMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
    required this.isMe,
    this.messageType = MessageType.text,
    this.filePath,
    this.duration,
    this.isPlaying,
    this.messageId,
    this.status,
  });
}