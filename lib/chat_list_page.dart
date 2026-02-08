import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'chatroom_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiService.getAllUsers();
      final transformed = users.map<Map<String, dynamic>>((u) {
        return {
          'id': u['id'] ?? 0,
          'firstName': u['firstName'] ?? 'Unknown',
          'lastName': u['lastName'] ?? 'User',
          'fullName': (u['fullName'] ?? '').toString().isNotEmpty
              ? u['fullName']
              : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
          'userName': u['userName'] ?? u['username'] ?? '',
          'mobile': u['mobile'] ?? u['mobileNo'] ?? u['phoneNumber'] ?? u['phone'] ?? '',
          'picUrlAvatar': u['picUrlAvatar'] ?? '',
          'lastMessage': u['lastMessage'] ?? 'Available for chat',
          'lastMessageTime': DateTime.now(),
          'unreadCount': u['unreadCount'] ?? 0,
          'isOnline': true,
        };
      }).toList();
      setState(() {
        _users = transformed;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  List<Map<String, dynamic>> _filteredUsers() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _users;

    return _users.where((u) {
      final fullName = (u['fullName'] ?? '').toString().toLowerCase();
      final firstName = (u['firstName'] ?? '').toString().toLowerCase();
      final lastName = (u['lastName'] ?? '').toString().toLowerCase();
      final userName = (u['userName'] ?? '').toString().toLowerCase();
      final mobile = (u['mobile'] ?? '').toString().toLowerCase();
      return fullName.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query) ||
          userName.contains(query) ||
          mobile.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: const Color(0xFF075E54),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search contacts',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filtered = _filteredUsers();
                      if (filtered.isEmpty) {
                        return const Center(child: Text('No contacts found'));
                      }
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
                        itemBuilder: (context, index) {
                          final u = filtered[index];
                          final name = (u['fullName'] ?? '').toString().isNotEmpty
                              ? u['fullName']
                              : '${u['firstName']} ${u['lastName']}';
                          final avatarUrl = (u['picUrlAvatar'] ?? '').toString();
                          final unread = u['unreadCount'] ?? 0;
                          final time = (u['lastMessageTime'] is DateTime)
                              ? u['lastMessageTime'] as DateTime
                              : DateTime.now();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF075E54),
                              backgroundImage: () {
                                final url = ApiService.getFullAvatarUrl(avatarUrl);
                                return url != null ? NetworkImage(url) : null;
                              }(),
                              child: () {
                                final url = ApiService.getFullAvatarUrl(avatarUrl);
                                return url == null
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null;
                              }(),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              (u['lastMessage'] ?? 'Available for chat').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_formatTime(time), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                if (unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                    ),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatroomPage(
                                    initialUser: u,
                                    standalone: true,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
