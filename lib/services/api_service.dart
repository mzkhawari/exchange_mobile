import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Hook to trigger navigation when auth is invalid.
  static VoidCallback? onUnauthorized;
  // API Configuration for different environments
  // Local API server for debugging
  // Note: For Android emulator, use 10.0.2.2 instead of localhost
  static const String _debugBaseUrl = 'https://10.0.2.2:7179/api';
  static const String _debugImageUrl = 'https://10.0.2.2:7179';
  // Production API server
  static const String _releaseBaseUrl = 'https://10.0.2.2:7179/api';
  static const String _releaseImageUrl = 'https://10.0.2.2:7179';
  
  // Get current base URL based on build mode
  static String get baseUrl {
    return kDebugMode ? _debugBaseUrl : _releaseBaseUrl;
  }
  
  // Get current image URL based on build mode  
  static String get baseImageUrl {
    return kDebugMode ? _debugImageUrl : _releaseImageUrl;
  }
  
  // Helper method to get image URL
  static String getImageUrl() {
    return baseImageUrl;
  }
  
  // Get current environment info
  static String get currentEnvironment {
    return kDebugMode ? 'DEBUG' : 'RELEASE';
  }
  
  // Initialize and log current configuration
  static void logCurrentConfig() {
    print('🌍 API Environment: ${currentEnvironment}');
    print('🔗 Base URL: ${baseUrl}');
    print('🖼️ Image URL: ${baseImageUrl}');
  }
  
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

  // Get stored refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  // Store refresh token
  static Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }
  
  // Remove auth token
  static Future<void> removeAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('login_response');
  }

  // Handle 401 Unauthorized error - clear all data and redirect to login
  static Future<void> handle401Unauthorized() async {
    print('🚨 401 Unauthorized: Token expired or invalid');
    
    // Clear all stored authentication data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    await prefs.remove('login_response');
    
    print('✅ All authentication data cleared');
    
    // Set flag to redirect to login
    await prefs.setBool('should_redirect_to_login', true);
    
    print('🔄 Login redirect flag set');

    if (onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  // Check if should redirect to login (for use in app initialization)
  static Future<bool> shouldRedirectToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRedirect = prefs.getBool('should_redirect_to_login') ?? false;
    if (shouldRedirect) {
      await prefs.remove('should_redirect_to_login'); // Clear flag after checking
    }
    return shouldRedirect;
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

  // Get stored username (if available)
  static Future<String?> getStoredUserName() async {
    final userData = await getStoredUserData();
    if (userData != null) {
      return userData['userName']?.toString() ??
          userData['username']?.toString() ??
          userData['user_name']?.toString();
    }

    final prefs = await SharedPreferences.getInstance();
    final loginResponseString = prefs.getString('login_response');
    if (loginResponseString != null) {
      final loginData = json.decode(loginResponseString);
      if (loginData is Map) {
        if (loginData['userName'] != null) return loginData['userName'].toString();
        if (loginData['username'] != null) return loginData['username'].toString();
        if (loginData['currentUser'] is Map) {
          final currentUser = loginData['currentUser'] as Map;
          return currentUser['userName']?.toString() ??
              currentUser['username']?.toString() ??
              currentUser['user_name']?.toString();
        }
      }
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
  static String? getFullAvatarUrl(String? picUrlAvatar) {
    if (picUrlAvatar == null || picUrlAvatar.isEmpty || picUrlAvatar == 'null') {
      return null;
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
    
    // Split path and encode only the filename to handle spaces
    final parts = cleanPath.split('/');
    if (parts.length > 1) {
      final fileName = parts.last;
      final encodedFileName = Uri.encodeComponent(fileName);
      parts[parts.length - 1] = encodedFileName;
      cleanPath = parts.join('/');
    }
    
    // Construct the full URL using the correct image URL
    final fullUrl = '${currentEnvironment == 'DEBUG' ? _debugImageUrl : _releaseImageUrl}$cleanPath';
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
        print('═══════════════════════════════════════════════════════════');
        print('🔍 getUserInfo API Response Details:');
        print('📍 Endpoint: $baseUrl/user/getUserInfo');
        print('📊 Status Code: ${response.statusCode}');
        print('📋 Response Type: ${data.runtimeType}');
        print('📄 Raw Response Body: ${response.body}');
        print('🔧 Parsed Data: $data');
        
        if (data is List) {
          print('📝 Response is List with ${data.length} items');
          if (data.isNotEmpty) {
            print('👤 First User Data: ${data[0]}');
          }
        } else if (data is Map) {
          print('📝 Response is Map object');
          print('🔑 Keys Available: ${data.keys.toList()}');
          if (data.containsKey('id')) print('👤 User ID: ${data['id']}');
          if (data.containsKey('firstName')) print('👤 First Name: ${data['firstName']}');
          if (data.containsKey('lastName')) print('👤 Last Name: ${data['lastName']}');
          if (data.containsKey('email')) print('📧 Email: ${data['email']}');
          if (data.containsKey('userName')) print('🏷️ Username: ${data['userName']}');
          if (data.containsKey('picUrlAvatar')) print('🖼️ Avatar URL: ${data['picUrlAvatar']}');
        }
        print('═══════════════════════════════════════════════════════════');
        
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
        // Handle 401 Unauthorized - clear data and flag for redirect
        await handle401Unauthorized();
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
      print('🔐 LOGIN DEBUG: Environment = ${currentEnvironment}');
      print('🔐 LOGIN DEBUG: baseUrl = $baseUrl');
      print('🔐 LOGIN DEBUG: Full login URL = $baseUrl/auth/login');
      print('🔐 LOGIN DEBUG: kDebugMode = ${kDebugMode}');
      
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
          final extractedAccessToken = _extractAccessToken(data['token']);
          if (extractedAccessToken != null && extractedAccessToken.isNotEmpty) {
            await setAuthToken(extractedAccessToken);
          }

          final extractedRefreshToken = _extractRefreshToken(data['token']);
          if (extractedRefreshToken != null && extractedRefreshToken.isNotEmpty) {
            await setRefreshToken(extractedRefreshToken);
          }

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

  // Validate refresh token on app startup
  static Future<bool> validateRefreshTokenOnStartup() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return true; // No refresh token stored, skip validation
      }

      final accessToken = await getAuthToken();
      final userName = await getStoredUserName();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refreshToken'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refreshToken': refreshToken,
          'accessToken': accessToken,
          'userName': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract and update access token
        String? accessToken;
        if (data is Map && data['token'] != null) {
          accessToken = _extractAccessToken(data['token']);
        } else if (data is Map) {
          accessToken = _extractAccessToken(data);
        }

        if (accessToken != null && accessToken.isNotEmpty) {
          await setAuthToken(accessToken);
        }

        // Extract and update refresh token if returned
        String? newRefreshToken;
        if (data is Map && data['token'] != null) {
          newRefreshToken = _extractRefreshToken(data['token']);
        } else if (data is Map) {
          newRefreshToken = _extractRefreshToken(data);
        }

        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await setRefreshToken(newRefreshToken);
        }

        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handle401Unauthorized();
        return false;
      } else {
        print('Refresh token validation failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error validating refresh token: $e');
      return false;
    }
  }

  static String? _extractAccessToken(dynamic tokenData) {
    if (tokenData == null) return null;
    if (tokenData is String) return tokenData;
    if (tokenData is Map) {
      if (tokenData['accessToken'] != null) return tokenData['accessToken'].toString();
      if (tokenData['access_token'] != null) return tokenData['access_token'].toString();
      if (tokenData['token'] != null) return tokenData['token'].toString();
    }
    return tokenData.toString();
  }

  static String? _extractRefreshToken(dynamic tokenData) {
    if (tokenData == null) return null;
    if (tokenData is Map) {
      if (tokenData['refreshToken'] != null) return tokenData['refreshToken'].toString();
      if (tokenData['refresh_token'] != null) return tokenData['refresh_token'].toString();
    }
    return null;
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
        // Handle 401 Unauthorized
        await handle401Unauthorized();
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
    String? value,
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
        Uri.parse('$baseUrl/chatDetail/postChatDetail'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['chatMasterId'] = chatMasterId.toString();
      
      // Always include value field - API requires it
      if (value != null && value.isNotEmpty) {
        request.fields['value'] = value;
        request.fields['messageType'] = 'Text';
      } else {
        // For attachments without text, send "_" as default value
        request.fields['value'] = '_';
      }

      // Add voice file if provided
      if (voiceFilePath != null) {
        print('🎤 API DEBUG: Adding voice file: $voiceFilePath');
        final file = File(voiceFilePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('🎤 API DEBUG: Voice file exists, size: $fileSize bytes');
          request.files.add(
            await http.MultipartFile.fromPath('voiceFile', voiceFilePath),
          );
          request.fields['messageType'] = 'Voice';
          print('🎤 API DEBUG: Voice file added to request successfully');
        } else {
          print('🎤 API DEBUG ERROR: Voice file does not exist at path: $voiceFilePath');
          return null;
        }
      }

      // Add attachment file if provided
      if (attachmentFilePath != null) {
        print('🖼️ API DEBUG: Adding attachment file: $attachmentFilePath');
        final file = File(attachmentFilePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('🖼️ API DEBUG: Attachment file exists, size: $fileSize bytes');
          request.files.add(
            await http.MultipartFile.fromPath('attachmentFile', attachmentFilePath),
          );
          request.fields['messageType'] = attachmentType ?? 'Document';
          print('🖼️ API DEBUG: Attachment file added to request successfully');
        } else {
          print('🖼️ API DEBUG ERROR: Attachment file does not exist at path: $attachmentFilePath');
          return null;
        }
      }

      print('Sending chat detail: chatMasterId=$chatMasterId, value=$value, voiceFile=$voiceFilePath, attachmentFile=$attachmentFilePath');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('postChatDetail response: $data (type: ${data.runtimeType})');
        
        // API may return just 'true' or a Map with details
        if (data is bool && data == true) {
          // Success with no additional data - return empty map to indicate success
          print('postChatDetail: Success (boolean true)');
          return {};
        } else if (data is Map) {
          print('postChatDetail: Success with data');
          return Map<String, dynamic>.from(data);
        } else {
          print('postChatDetail: Unexpected response format');
          return {};
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('Token expired while posting chat detail');
        return null;
      } else {
        print('❌ Failed to post chat detail: ${response.statusCode}');
        print('❌ Response body: $responseBody');
        print('❌ Request fields: ${request.fields}');
        print('❌ Request files: ${request.files.map((f) => f.field).toList()}');
        return null;
      }
    } catch (e) {
      print('Error posting chat detail: $e');
      return null;
    }
  }

  // Get chat details by userId - returns both messages and ChatMasterId
  static Future<Map<String, dynamic>?> getChatDetails(int userId) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('No auth token available for getChatDetails');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/ChatDetail/getChatDetails?targetUserId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('getChatDetails API response: $data');
        
        // Extract ChatMasterId from the response
        int? chatMasterId;
        List<Map<String, dynamic>> messages = [];
        
        if (data is Map) {
          // Extract ChatMasterId from response
          chatMasterId = data['chatMasterId'] ?? data['ChatMasterId'];
          
          // Extract messages from different possible response structures
          if (data['data'] != null && data['data'] is List) {
            messages = List<Map<String, dynamic>>.from(data['data']);
          } else if (data['messages'] != null && data['messages'] is List) {
            messages = List<Map<String, dynamic>>.from(data['messages']);
          }
          
          // If ChatMasterId not found at root level, try to get it from first message
          if (chatMasterId == null && messages.isNotEmpty) {
            chatMasterId = messages.first['chatMasterId'] ?? messages.first['ChatMasterId'];
          }
        } else if (data is List) {
          messages = List<Map<String, dynamic>>.from(data);
          // Try to get ChatMasterId from first message
          if (messages.isNotEmpty) {
            chatMasterId = messages.first['chatMasterId'] ?? messages.first['ChatMasterId'];
          }
        }
        
        print('🔍 Extracted ChatMasterId: $chatMasterId');
        print('🔍 Messages count: ${messages.length}');
        
        return {
          'chatMasterId': chatMasterId,
          'messages': messages,
        };
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
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
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('Token expired while updating chat status');
        return false;
      } else {
        print('Failed to update chat status: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating chat status: $e');
      return false;
    }
  }

  /// Get select options for account forms (countries, provinces, zones, etc.)
  static Future<Map<String, dynamic>?> getAccountSelectOptions() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getAccountSelectOptions');
        return null;
      }

      print('📡 Fetching account select options from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/accountMob/GetSelectOptions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Account select options fetched successfully');
        print('📊 Response keys: ${data.keys.toList()}');
        return data;
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting account select options');
        return null;
      } else {
        print('❌ Failed to get account select options: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Error getting account select options: $e');
      return null;
    }
  }

  /// Get select options for transfer cash forms (currencies, branches, etc.)
  static Future<Map<String, dynamic>?> getTransferCashSelectOptions() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getTransferCashSelectOptions');
        return null;
      }

      print('📡 Fetching transfer cash select options from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/transfercashMob/GetSelectOptions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Transfer cash select options fetched successfully');
        print('📊 Response keys: ${data.keys.toList()}');
        return data;
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting transfer cash select options');
        return null;
      } else {
        print('❌ Failed to get transfer cash select options: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Error getting transfer cash select options: $e');
      return null;
    }
  }

  /// Get list of countries
  static Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getCountries');
        return [];
      }

      print('📡 Fetching countries from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/CountryProvinceCity/getCountry'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Countries fetched successfully');
        
        // Handle different response formats
        if (data is List) {
          print('📊 Countries count: ${data.length}');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          print('📊 Countries count: ${(data['data'] as List).length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('countries')) {
          print('📊 Countries count: ${(data['countries'] as List).length}');
          return List<Map<String, dynamic>>.from(data['countries']);
        } else {
          print('⚠️ Unexpected response format for countries');
          return [];
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting countries');
        return [];
      } else {
        print('❌ Failed to get countries: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('💥 Error getting countries: $e');
      return [];
    }
  }

  /// Get list of provinces
  static Future<List<Map<String, dynamic>>> getProvinces() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getProvinces');
        return [];
      }

      print('📡 Fetching provinces from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/CountryProvinceCity/getProvince'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Provinces fetched successfully');
        
        if (data is List) {
          print('📊 Provinces count: ${data.length}');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          print('📊 Provinces count: ${(data['data'] as List).length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('provinces')) {
          print('📊 Provinces count: ${(data['provinces'] as List).length}');
          return List<Map<String, dynamic>>.from(data['provinces']);
        } else {
          print('⚠️ Unexpected response format for provinces');
          return [];
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting provinces');
        return [];
      } else {
        print('❌ Failed to get provinces: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('💥 Error getting provinces: $e');
      return [];
    }
  }

  /// Get list of zones
  static Future<List<Map<String, dynamic>>> getZones() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getZones');
        return [];
      }

      print('📡 Fetching zones from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/CountryProvinceCity/getZone'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Zones fetched successfully');
        
        if (data is List) {
          print('📊 Zones count: ${data.length}');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          print('📊 Zones count: ${(data['data'] as List).length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('zones')) {
          print('📊 Zones count: ${(data['zones'] as List).length}');
          return List<Map<String, dynamic>>.from(data['zones']);
        } else {
          print('⚠️ Unexpected response format for zones');
          return [];
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting zones');
        return [];
      } else {
        print('❌ Failed to get zones: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('💥 Error getting zones: $e');
      return [];
    }
  }

  /// Get list of cities
  static Future<List<Map<String, dynamic>>> getCities() async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getCities');
        return [];
      }

      print('📡 Fetching cities from API...');
      final response = await http.get(
        Uri.parse('$baseUrl/CountryProvinceCity/getCity'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Cities fetched successfully');
        
        if (data is List) {
          print('📊 Cities count: ${data.length}');
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data')) {
          print('📊 Cities count: ${(data['data'] as List).length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('cities')) {
          print('📊 Cities count: ${(data['cities'] as List).length}');
          return List<Map<String, dynamic>>.from(data['cities']);
        } else {
          print('⚠️ Unexpected response format for cities');
          return [];
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting cities');
        return [];
      } else {
        print('❌ Failed to get cities: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('💥 Error getting cities: $e');
      return [];
    }
  }

  /// Submit transfer cash data
  static Future<Map<String, dynamic>?> postTransferCash(
    Map<String, dynamic> transferData, {
    List<String> attachmentPaths = const [],
  }) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for postTransferCash');
        return null;
      }

      print('📡 Posting transfer cash to API...');
      print('📦 Transfer data: $transferData');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/transfercashMob/PostValue'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Send as form-data for [FromForm] binding
      transferData.forEach((key, value) {
        if (value == null) return;
        if (value is DateTime) {
          request.fields[key] = value.toIso8601String();
        } else if (value is bool) {
          request.fields[key] = value ? 'true' : 'false';
        } else {
          request.fields[key] = value.toString();
        }
      });

      if (attachmentPaths.isNotEmpty) {
        for (final path in attachmentPaths) {
          if (path.isEmpty) continue;
          request.files.add(
            await http.MultipartFile.fromPath('attachments', path),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print('📬 Response status: ${streamedResponse.statusCode}');
      print('📬 Response body: $responseBody');

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final data = json.decode(responseBody);
        print('✅ Transfer cash posted successfully');
        return data;
      } else if (streamedResponse.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while posting transfer cash');
        return null;
      } else {
        print('❌ Failed to post transfer cash: ${streamedResponse.statusCode}');
        print('Response body: $responseBody');
        return null;
      }
    } catch (e) {
      print('💥 Error posting transfer cash: $e');
      return null;
    }
  }

  /// Get list of customers/accounts
  static Future<List<Map<String, dynamic>>> getAccounts({int page = 1, int size = 100, String search = ''}) async {
    try {
      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        print('⚠️ No auth token available for getAccounts');
        return [];
      }

      print('📡 Fetching accounts from API...');
      final response = await http.post(
        Uri.parse('$baseUrl/accountMob/PostIncludeByPaging'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'isFullPrint': true,
          'page': page,
          'size': size,
          'status': 0,
          'search': search,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Accounts fetched successfully');
        
        if (data is Map && data.containsKey('data')) {
          print('📊 Accounts count: ${(data['data'] as List).length}');
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          print('⚠️ Unexpected response format for accounts');
          return [];
        }
      } else if (response.statusCode == 401) {
        await handle401Unauthorized();
        print('🚨 Token expired while getting accounts');
        return [];
      } else {
        print('❌ Failed to get accounts: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('💥 Error getting accounts: $e');
      return [];
    }
  }

}