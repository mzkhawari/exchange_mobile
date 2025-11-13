import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://209.42.25.31:7179/api';
  static const String baseImageUrl = 'https://209.42.25.31:7179';
  
  // Get stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  // Store auth token
  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  // Remove auth token
  static Future<void> removeAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('login_response');
  }
  
  // Get stored user data
  static Future<Map<String, dynamic>?> getStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }
  
  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    final userData = await getStoredUserData();
    return token != null && token.isNotEmpty && userData != null;
  }

  // Helper method to get full avatar URL
  static String getFullAvatarUrl(String? picUrlAvatar) {
    if (picUrlAvatar == null || picUrlAvatar.isEmpty || picUrlAvatar == 'null') {
      return '';
    }
    
    // If it's already a full URL, return as is
    if (picUrlAvatar.startsWith('http://') || picUrlAvatar.startsWith('https://')) {
      return picUrlAvatar;
    }
    
    // Clean up the path - replace backslashes with forward slashes
    String cleanPath = picUrlAvatar.replaceAll('\\', '/');
    
    // Ensure path starts with /
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    
    // Construct the full URL
    final fullUrl = '$baseImageUrl$cleanPath';
    print('Avatar URL constructed: $fullUrl'); // Debug log
    return fullUrl;
  }
  
  // Get user info from API
  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/user/getUserInfo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('getUserInfo API response: $data');
        
        // Handle different response structures
        if (data is List && data.isNotEmpty) {
          // If it returns a list, take the first user (current user)
          return Map<String, dynamic>.from(data[0]);
        } else if (data is Map) {
          // If it's a single user object
          return Map<String, dynamic>.from(data);
        }
        
        return null;
      } else if (response.statusCode == 401) {
        // Token expired, remove it
        await removeAuthToken();
        return null;
      } else {
        throw Exception('Failed to load user info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }
  
  // Login method
  static Future<Map<String, dynamic>?> login(String username, String password, {bool isRemember = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'UserName': username,
          'Password': password,
          'isRemember': isRemember,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['token'] != null) {
          await setAuthToken(data['token']);
          
          // Get user info immediately after login
          final userInfo = await getUserInfo();
          if (userInfo != null) {
            // Store user data locally
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', json.encode(userInfo));
          }
        }
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
  
  // Get chat messages (mock implementation - replace with actual endpoint)
  static Future<List<Map<String, dynamic>>> getChatMessages() async {
    try {
      final token = await getAuthToken();
      if (token == null) return [];
      
      // Replace with actual chat messages endpoint
      final response = await http.get(
        Uri.parse('$baseUrl/chat/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }
    } catch (e) {
      print('Error getting chat messages: $e');
    }
    return [];
  }
  
  // Send chat message (mock implementation)
  static Future<bool> sendChatMessage(String message) async {
    try {
      final token = await getAuthToken();
      if (token == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get all users from API
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('No auth token available for getAllUsers');
        return [];
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/User/getUserInfo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Users API response: $data');
        
        // Handle different response structures
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        } else if (data is Map && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map) {
          // If it's a single user object, wrap it in a list
          return [Map<String, dynamic>.from(data)];
        }
        
        return [];
      } else if (response.statusCode == 401) {
        // Token expired, remove it
        await removeAuthToken();
        print('Token expired while getting users');
        return [];
      } else {
        print('Failed to load users: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Post chat detail (message/voice/attachment)
  static Future<Map<String, dynamic>?> postChatDetail({
    required int chatMasterId,
    String? messageText,
    String? voiceFilePath,
    String? attachmentFilePath,
    String? attachmentType,
  }) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('No auth token available for postChatDetail');
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/postChatDetail'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['chatMasterId'] = chatMasterId.toString();
      
      if (messageText != null && messageText.isNotEmpty) {
        request.fields['messageText'] = messageText;
        request.fields['messageType'] = 'Text';
      }

      // Add voice file if provided
      if (voiceFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('voiceFile', voiceFilePath),
        );
        request.fields['messageType'] = 'Voice';
      }

      // Add attachment file if provided
      if (attachmentFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('attachmentFile', attachmentFilePath),
        );
        request.fields['messageType'] = attachmentType ?? 'Document';
      }

      print('Sending chat detail: chatMasterId=$chatMasterId, messageText=$messageText, voiceFile=$voiceFilePath, attachmentFile=$attachmentFilePath');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('postChatDetail success: $data');
        return Map<String, dynamic>.from(data);
      } else {
        print('Failed to post chat detail: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error posting chat detail: $e');
      return null;
    }
  }

  // Get chat details by chatMasterId
  static Future<List<Map<String, dynamic>>?> getChatDetails(int chatMasterId) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('No auth token available for getChatDetails');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/chat/getChatDetails?chatMasterId=$chatMasterId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('getChatDetails API response: $data');
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['messages'] != null) {
          return List<Map<String, dynamic>>.from(data['messages']);
        }
        
        return [];
      } else if (response.statusCode == 401) {
        await removeAuthToken();
        print('Token expired while getting chat details');
        return null;
      } else {
        print('Failed to load chat details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting chat details: $e');
      return null;
    }
  }

  // Update chat detail status
  static Future<bool> updateChatDetailStatus({
    required List<int> chatDetailIds,
    required String status, // "Delivered", "Seen", "Listen", "Watch"
  }) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('No auth token available for updateChatDetailStatus');
        return false;
      }

      final requestBody = {
        'chatDetailIds': chatDetailIds,
        'status': status,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/chat/updateChatDetailStatus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('updateChatDetailStatus success: status=$status, ids=$chatDetailIds');
        return true;
      } else {
        print('Failed to update chat status: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating chat status: $e');
      return false;
    }
  }
}