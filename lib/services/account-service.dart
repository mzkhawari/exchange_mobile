import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account-form-model.dart';

class ApiService {
  static const String baseUrl = 'https://209.42.25.31:7179/api';

  static Future<Map<String, dynamic>> postAccountAttachment({
    required int accountId,
    required String fileBase64,
    required String fileName,
    required int fileType, // 1: عکس مشتری, 2: جلوی مدرک, 3: پشت مدرک
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/accountMob/postAccountAttachment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'accountId': accountId,
          'fileBase64': fileBase64,
          'fileName': fileName,
          'fileType': fileType,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('خطا در آپلود فایل: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطا در ارتباط با سرور: $e');
    }
  }

  static Future<Map<String, dynamic>> saveCustomer(CustomerModel model) async {
    // API برای ذخیره اطلاعات مشتری
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/accountMob/postAccountAttachment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(model.toJson()),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('خطا در ذخیره مشتری: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطا در ارتباط با سرور: $e');
    }
  }
}