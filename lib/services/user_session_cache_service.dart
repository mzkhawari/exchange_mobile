import 'package:shared_preferences/shared_preferences.dart';

import 'avatar_cache_service.dart';
import 'local_users_db_service.dart';
import 'pending_chat_queue_service.dart';

class UserSessionCacheService {
  static const Set<String> _directKeysToClear = {
    'auth_token',
    'refresh_token',
    'user_data',
    'login_response',
    'should_redirect_to_login',
  };

  static Future<void> clearAllUserCache() async {
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove = prefs
        .getKeys()
        .where((key) =>
            _directKeysToClear.contains(key) ||
            key.startsWith('pending_chat_queue'))
        .toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    await PendingChatQueueService.clearQueue();
    await LocalUsersDbService.clearAllCachedData();
    AvatarCacheService.clearMemoryCache();
  }
}
