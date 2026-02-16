import 'package:sqflite/sqflite.dart';
import 'api_service.dart';

class LocalUsersDbService {
  static const String _databaseName = 'exchange_local.db';
  static const int _databaseVersion = 2;
  static const String _tableUsers = 'users_cache';
  static const String _tableMessages = 'chat_messages';

  static Database? _database;
  static const int _maxServerMessageId = 2147483647;

  static Future<Database> get _db async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      '$dbPath/$_databaseName',
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableUsers (
            id INTEGER PRIMARY KEY,
            firstName TEXT,
            lastName TEXT,
            picUrlAvatar TEXT,
            userName TEXT,
            email TEXT,
            isOnline INTEGER,
            lastMessage TEXT,
            lastMessageTime INTEGER,
            unreadCount INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE $_tableMessages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peerUserId INTEGER NOT NULL,
            messageId INTEGER,
            value TEXT,
            fileUrl TEXT,
            fileUrlThumb TEXT,
            dateMillis INTEGER,
            senderUserId INTEGER,
            isMine INTEGER,
            isSent INTEGER,
            status TEXT,
            messageType TEXT,
            isSeen INTEGER,
            UNIQUE(peerUserId, messageId) ON CONFLICT REPLACE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_tableMessages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              peerUserId INTEGER NOT NULL,
              messageId INTEGER,
              value TEXT,
              fileUrl TEXT,
              fileUrlThumb TEXT,
              dateMillis INTEGER,
              senderUserId INTEGER,
              isMine INTEGER,
              isSent INTEGER,
              status TEXT,
              messageType TEXT,
              isSeen INTEGER,
              UNIQUE(peerUserId, messageId) ON CONFLICT REPLACE
            )
          ''');
        }
      },
    );

    return _database!;
  }

  static Future<void> replaceUsers(List<Map<String, dynamic>> users) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.delete(_tableUsers);
      final batch = txn.batch();

      for (final user in users) {
        final lastMessageTime = user['lastMessageTime'];
        final lastMessageMillis = lastMessageTime is DateTime
            ? lastMessageTime.millisecondsSinceEpoch
            : (lastMessageTime is int
                  ? lastMessageTime
                  : DateTime.now().millisecondsSinceEpoch);

        batch.insert(_tableUsers, {
          'id': user['id'] ?? 0,
          'firstName': (user['firstName'] ?? '').toString(),
          'lastName': (user['lastName'] ?? '').toString(),
          'picUrlAvatar': (user['picUrlAvatar'] ?? '').toString(),
          'userName': (user['userName'] ?? '').toString(),
          'email': (user['email'] ?? '').toString(),
          'isOnline': user['isOnline'] == true ? 1 : 0,
          'lastMessage': (user['lastMessage'] ?? '').toString(),
          'lastMessageTime': lastMessageMillis,
          'unreadCount': user['unreadCount'] ?? 0,
        });
      }

      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await _db;
    final rows = await db.query(
      _tableUsers,
      orderBy: 'firstName ASC, lastName ASC',
    );

    final unreadByUser = await _getUnreadCountsByUser(db);
    final latestByUser = await _getLatestMessageByUser(db);

    final users = rows.map((row) {
      final userId = (row['id'] as int?) ?? 0;
      final latest = latestByUser[userId];
      final fallbackMillis = (row['lastMessageTime'] as int?) ?? 0;
      final millis = (latest?['dateMillis'] as int?) ?? fallbackMillis;
      final latestText = latest?['value']?.toString();
      final unreadValue = unreadByUser[userId] ?? (row['unreadCount'] ?? 0);
      final unreadCount = unreadValue is int
          ? unreadValue
          : int.tryParse('$unreadValue') ?? 0;
      final lastMessageTime = millis > 0
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now().subtract(const Duration(minutes: 1));

      return {
        'id': row['id'] ?? 0,
        'firstName': row['firstName'] ?? 'Unknown',
        'lastName': row['lastName'] ?? 'User',
        'picUrlAvatar': row['picUrlAvatar'] ?? '',
        'userName': row['userName'] ?? '',
        'email': row['email'] ?? '',
        'isOnline': (row['isOnline'] as int? ?? 0) == 1,
        'lastMessage': (latestText != null && latestText.trim().isNotEmpty)
            ? latestText
            : (row['lastMessage'] ?? 'Available for chat'),
        'lastMessageTime': lastMessageTime,
        'unreadCount': unreadCount,
      };
    }).toList();

    users.sort((a, b) {
      final unreadA = a['unreadCount'] is int
          ? a['unreadCount'] as int
          : int.tryParse('${a['unreadCount']}') ?? 0;
      final unreadB = b['unreadCount'] is int
          ? b['unreadCount'] as int
          : int.tryParse('${b['unreadCount']}') ?? 0;

      final hasUnreadA = unreadA > 0;
      final hasUnreadB = unreadB > 0;
      if (hasUnreadA != hasUnreadB) {
        return hasUnreadA ? -1 : 1;
      }

      final timeA = a['lastMessageTime'] is DateTime
          ? a['lastMessageTime'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b['lastMessageTime'] is DateTime
          ? b['lastMessageTime'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);

      return timeB.compareTo(timeA);
    });

    return users;
  }

  static Future<void> cacheMessagesForUserChat({
    required int userId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final message in messages) {
        final rawId = message['id'];
        final parsedId = rawId is int ? rawId : int.tryParse('$rawId');
        final normalizedMessageId =
            (parsedId != null &&
                parsedId > 0 &&
                parsedId <= _maxServerMessageId)
            ? parsedId
            : null;

        final status = (message['status'] ?? 'None').toString();
        final isMine = message['isMine'] == true;
        final isSeen = isMine || _isSeenStatus(status);

        final rawDate = message['date'];
        final dateMillis = rawDate is DateTime
            ? rawDate.millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;

        batch.insert(_tableMessages, {
          'peerUserId': userId,
          'messageId': normalizedMessageId,
          'value': (message['value'] ?? '').toString(),
          'fileUrl': message['fileUrl']?.toString(),
          'fileUrlThumb': message['fileUrlThumb']?.toString(),
          'dateMillis': dateMillis,
          'senderUserId': message['userId'] is int
              ? message['userId']
              : int.tryParse('${message['userId']}'),
          'isMine': isMine ? 1 : 0,
          'isSent': message['isSent'] == true ? 1 : 0,
          'status': status,
          'messageType': (message['messageType'] ?? 'text').toString(),
          'isSeen': isSeen ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
      await _refreshUserMetaFromMessages(txn, userId);
    });
  }

  static Future<void> markUserChatAsSeen(int userId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        _tableMessages,
        {'isSeen': 1, 'status': 'Seen'},
        where: 'peerUserId = ? AND isMine = 0 AND isSeen = 0',
        whereArgs: [userId],
      );

      await txn.update(
        _tableUsers,
        {'unreadCount': 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  static Future<int?> getLastCachedMessageIdForUser(int userId) async {
    final db = await _db;
    final rows = await db.query(
      _tableMessages,
      columns: ['messageId'],
      where:
          'peerUserId = ? AND messageId IS NOT NULL AND messageId > 0 AND messageId <= ?',
      whereArgs: [userId, _maxServerMessageId],
      orderBy: 'messageId DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final value = rows.first['messageId'];
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static Future<List<Map<String, dynamic>>> getCachedMessagesForUser(
    int userId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      _tableMessages,
      where: 'peerUserId = ?',
      whereArgs: [userId],
      orderBy: 'dateMillis ASC, id ASC',
    );

    return rows.map((row) {
      final dateMillis = row['dateMillis'] as int?;
      return {
        'id': row['messageId'] ?? 0,
        'value': (row['value'] ?? '').toString(),
        'fileUrl': row['fileUrl']?.toString(),
        'fileUrlThumb': row['fileUrlThumb']?.toString(),
        'date': dateMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
            : DateTime.now(),
        'userId': row['senderUserId'] ?? 0,
        'isSent': (row['isSent'] as int? ?? 0) == 1,
        'status': (row['status'] ?? 'None').toString(),
        'isMine': (row['isMine'] as int? ?? 0) == 1,
        'messageType': (row['messageType'] ?? 'text').toString(),
      };
    }).toList();
  }

  static Future<void> syncUsersFromApi() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) return;

    final users = await ApiService.getAllUsers();
    if (users.isEmpty) return;

    final transformedUsers = users.map(_mapApiUserToUiUser).toList();
    await replaceUsers(transformedUsers);
  }

  static bool _isSeenStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'seen' ||
        normalized == 'watch' ||
        normalized == 'listen';
  }

  static Future<Map<int, int>> _getUnreadCountsByUser(
    DatabaseExecutor db,
  ) async {
    final rows = await db.rawQuery('''
      SELECT peerUserId, COUNT(*) AS unreadCount
      FROM $_tableMessages
      WHERE isMine = 0 AND isSeen = 0
      GROUP BY peerUserId
      ''');

    final result = <int, int>{};
    for (final row in rows) {
      final userId = row['peerUserId'] as int?;
      final unread = row['unreadCount'] as int?;
      if (userId != null) {
        result[userId] = unread ?? 0;
      }
    }
    return result;
  }

  static Future<Map<int, Map<String, Object?>>> _getLatestMessageByUser(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query(
      _tableMessages,
      columns: ['peerUserId', 'value', 'dateMillis'],
      orderBy: 'peerUserId ASC, dateMillis DESC',
    );

    final result = <int, Map<String, Object?>>{};
    for (final row in rows) {
      final userId = row['peerUserId'] as int?;
      if (userId == null || result.containsKey(userId)) continue;
      result[userId] = row;
    }
    return result;
  }

  static Future<void> _refreshUserMetaFromMessages(
    DatabaseExecutor db,
    int userId,
  ) async {
    final latest = await db.query(
      _tableMessages,
      columns: ['value', 'dateMillis'],
      where: 'peerUserId = ?',
      whereArgs: [userId],
      orderBy: 'dateMillis DESC',
      limit: 1,
    );

    final unreadRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS unreadCount
      FROM $_tableMessages
      WHERE peerUserId = ? AND isMine = 0 AND isSeen = 0
      ''',
      [userId],
    );

    final unread = unreadRows.isNotEmpty
        ? (unreadRows.first['unreadCount'] as int? ?? 0)
        : 0;

    final updateData = <String, Object?>{'unreadCount': unread};
    if (latest.isNotEmpty) {
      updateData['lastMessage'] = latest.first['value']?.toString() ?? '';
      updateData['lastMessageTime'] = latest.first['dateMillis'] as int?;
    }

    await db.update(
      _tableUsers,
      updateData,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Map<String, dynamic> _mapApiUserToUiUser(Map<String, dynamic> user) {
    return {
      'id': user['id'] ?? 0,
      'firstName': user['firstName'] ?? 'Unknown',
      'lastName': user['lastName'] ?? 'User',
      'picUrlAvatar':
          user['picUrlAvatar'] ??
          user['picUrlAvatarThumb'] ??
          user['avatarUrl'] ??
          user['avatar'] ??
          user['profileImage'] ??
          '',
      'userName': user['userName'] ?? '',
      'email': user['email'] ?? '',
      'isOnline': true,
      'lastMessage': 'Available for chat',
      'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 1)),
      'unreadCount': 0,
    };
  }
}
