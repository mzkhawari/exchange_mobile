import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  Map<String, dynamic> _settingsData = {};
  
  // API Data Storage
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _identityTypes = [];
  List<Map<String, dynamic>> _accountTypes = [];
  List<Map<String, dynamic>> _transferTypes = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _banks = [];
  
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  /// بارگذاری داده‌های ذخیره شده از SharedPreferences
  Future<void> _loadCachedData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load cached API data
      final countriesJson = prefs.getString('settings_countries');
      final provincesJson = prefs.getString('settings_provinces');
      final zonesJson = prefs.getString('settings_zones');
      final citiesJson = prefs.getString('settings_cities');
      final currenciesJson = prefs.getString('settings_currencies');
      final branchesJson = prefs.getString('settings_branches');
      final identityTypesJson = prefs.getString('settings_identity_types');
      final accountTypesJson = prefs.getString('settings_account_types');
      final transferTypesJson = prefs.getString('settings_transfer_types');
      final paymentMethodsJson = prefs.getString('settings_payment_methods');
      final banksJson = prefs.getString('settings_banks');
      final lastSync = prefs.getString('settings_last_sync');
      
      setState(() {
        _countries = countriesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(countriesJson)) : [];
        _provinces = provincesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(provincesJson)) : [];
        _zones = zonesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(zonesJson)) : [];
        _cities = citiesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(citiesJson)) : [];
        _currencies = currenciesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(currenciesJson)) : [];
        _branches = branchesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(branchesJson)) : [];
        _identityTypes = identityTypesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(identityTypesJson)) : [];
        _accountTypes = accountTypesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(accountTypesJson)) : [];
        _transferTypes = transferTypesJson != null ? List<Map<String, dynamic>>.from(jsonDecode(transferTypesJson)) : [];
        _paymentMethods = paymentMethodsJson != null ? List<Map<String, dynamic>>.from(jsonDecode(paymentMethodsJson)) : [];
        _banks = banksJson != null ? List<Map<String, dynamic>>.from(jsonDecode(banksJson)) : [];
        _lastSyncTime = lastSync != null ? DateTime.parse(lastSync) : null;
      });
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// دریافت همه داده‌ها از API و ذخیره در SharedPreferences
  Future<void> _syncAllData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // فراخوانی API اطلاعات پایه حساب (Account)
      print('📡 Syncing account data from API...');
      final accountData = await ApiService.getAccountSelectOptions();
      
      // فراخوانی API اطلاعات پایه حواله (Transfer Cash)
      print('📡 Syncing transfer cash data from API...');
      final transferData = await ApiService.getTransferCashSelectOptions();
      
      // فراخوانی API‌های مکان‌ها
      print('📡 Syncing location data from API...');
      final countriesData = await ApiService.getCountries();
      final provincesData = await ApiService.getProvinces();
      final zonesData = await ApiService.getZones();
      // final citiesData = await ApiService.getCities(); // TEMPORARILY DISABLED
      final citiesData = <Map<String, dynamic>>[]; // Empty placeholder
      
      if (accountData == null && transferData == null && 
          countriesData.isEmpty && provincesData.isEmpty && 
          zonesData.isEmpty) {
        throw Exception('Failed to fetch data from all APIs');
      }
      
      // ترکیب داده‌ها از همه API‌ها
      final combinedData = <String, dynamic>{};
      
      if (accountData != null) {
        print('✅ Account API Data received: ${accountData.keys.toList()}');
        combinedData.addAll(accountData);
      }
      
      if (transferData != null) {
        print('✅ Transfer Cash API Data received: ${transferData.keys.toList()}');
        combinedData.addAll(transferData);
      }
      
      // اضافه کردن داده‌های مکان‌ها
      if (countriesData.isNotEmpty) {
        print('✅ Countries API: ${countriesData.length} items');
        combinedData['countries'] = countriesData;
      }
      
      if (provincesData.isNotEmpty) {
        print('✅ Provinces API: ${provincesData.length} items');
        combinedData['provinces'] = provincesData;
      }
      
      if (zonesData.isNotEmpty) {
        print('✅ Zones API: ${zonesData.length} items');
        combinedData['zones'] = zonesData;
      }
      
      if (citiesData.isNotEmpty) {
        print('✅ Cities API: ${citiesData.length} items');
        combinedData['cities'] = citiesData;
      }
      
      print('📊 Combined data keys: ${combinedData.keys.toList()}');
      
      // ذخیره داده‌های استاندارد
      final standardFields = {
        'countries': 'settings_countries',
        'provinces': 'settings_provinces', 
        'zones': 'settings_zones',
        'cities': 'settings_cities',
        'currencies': 'settings_currencies',
        'branches': 'settings_branches',
        'identityTypes': 'settings_identity_types',
        'accountTypes': 'settings_account_types',
        'transferTypes': 'settings_transfer_types',
        'paymentMethods': 'settings_payment_methods',
        'banks': 'settings_banks',
        'exchangeRates': 'settings_exchange_rates',
      };
      
      int savedCount = 0;
      for (var entry in standardFields.entries) {
        final apiKey = entry.key;
        final storageKey = entry.value;
        
        if (combinedData.containsKey(apiKey) && combinedData[apiKey] != null) {
          await prefs.setString(storageKey, jsonEncode(combinedData[apiKey]));
          final count = (combinedData[apiKey] is List) ? (combinedData[apiKey] as List).length : 1;
          print('✅ $apiKey saved: $count items');
          savedCount++;
        }
      }
      
      // ذخیره سایر فیلدهای احتمالی که در لیست استاندارد نیستند
      for (var key in combinedData.keys) {
        if (!standardFields.containsKey(key)) {
          print('⚠️ Unknown API field: $key - Saving as settings_$key');
          await prefs.setString('settings_$key', jsonEncode(combinedData[key]));
          savedCount++;
        }
      }
      
      await prefs.setString('settings_last_sync', DateTime.now().toIso8601String());
      
      // بارگذاری مجدد
      await _loadCachedData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $savedCount data sets synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error syncing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// پاک کردن همه داده‌های کش شده
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all stored data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('settings_countries');
      await prefs.remove('settings_provinces');
      await prefs.remove('settings_zones');
      await prefs.remove('settings_cities');
      await prefs.remove('settings_currencies');
      await prefs.remove('settings_branches');
      await prefs.remove('settings_identity_types');
      await prefs.remove('settings_account_types');
      await prefs.remove('settings_transfer_types');
      await prefs.remove('settings_payment_methods');
      await prefs.remove('settings_banks');
      await prefs.remove('settings_exchange_rates');
      await prefs.remove('settings_last_sync');
      
      await _loadCachedData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cache Cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRecords = _countries.length + _provinces.length + _zones.length + 
                         _cities.length + _currencies.length + _branches.length +
                         _identityTypes.length + _accountTypes.length + _transferTypes.length +
                         _paymentMethods.length + _banks.length;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _syncAllData,
            tooltip: 'Sync Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Syncing...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _syncAllData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // کارت آمار کلی
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.storage, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stored Data',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalRecords Records',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_lastSyncTime != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Last Update: ${_formatDateTime(_lastSyncTime!)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // دکمه‌های اکشن
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _syncAllData,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Sync'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _clearCache,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.red[300]!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // هدر بخش داده‌ها
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Data Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Location Group
                  _buildCategorySection(
                    'Geographic Information',
                    Icons.location_on,
                    Colors.green,
                    [
                      _buildDataCard('Countries', _countries, Icons.public, Colors.green),
                      _buildDataCard('Provinces', _provinces, Icons.location_city, Colors.green),
                      _buildDataCard('Zones', _zones, Icons.map, Colors.green),
                      _buildDataCard('Cities', _cities, Icons.location_city_outlined, Colors.green),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Financial Group
                  _buildCategorySection(
                    'Financial Information',
                    Icons.account_balance,
                    Colors.orange,
                    [
                      _buildDataCard('Currencies', _currencies, Icons.attach_money, Colors.orange),
                      _buildDataCard('Banks', _banks, Icons.account_balance_wallet, Colors.orange),
                      _buildDataCard('Payment Methods', _paymentMethods, Icons.payment, Colors.orange),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Organizational Settings Group
                  _buildCategorySection(
                    'Organizational Settings',
                    Icons.business,
                    Colors.purple,
                    [
                      _buildDataCard('Branches', _branches, Icons.business, Colors.purple),
                      _buildDataCard('Identity Types', _identityTypes, Icons.badge, Colors.purple),
                      _buildDataCard('Account Types', _accountTypes, Icons.account_balance, Colors.purple),
                      _buildDataCard('Transfer Types', _transferTypes, Icons.swap_horiz, Colors.purple),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySection(String title, IconData icon, MaterialColor color, List<Widget> cards) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color[700], size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color[800],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...cards,
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, List<Map<String, dynamic>> data, IconData icon, MaterialColor color) {
    final isEmpty = data.isEmpty;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEmpty ? null : () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildDataDetailsSheet(title, data, icon, color),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black12, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.grey[200] : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isEmpty ? Colors.grey[400] : color[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isEmpty ? Colors.grey[600] : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.grey[200] : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isEmpty ? Colors.grey[600] : color[700],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isEmpty ? Icons.remove_circle_outline : Icons.chevron_left,
                color: isEmpty ? Colors.grey[400] : Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataDetailsSheet(String title, List<Map<String, dynamic>> data, IconData icon, MaterialColor color) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color[600]!, color[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data.length} Items',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        item['title']?.toString() ?? item['name']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: item['code'] != null 
                          ? Text('Code: ${item['code']}')
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ID: ${item['id']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// کلاس Helper برای دسترسی آسان به داده‌های تنظیمات از سایر صفحات
class SettingsDataHelper {
  /// دریافت لیست کشورها
  static Future<List<Map<String, dynamic>>> getCountries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_countries');
    if (data != null) {
      var countries = List<Map<String, dynamic>>.from(jsonDecode(data));
      countries = countries.where((c) => c['isActive'] == true || c['isActive'] == 1).toList();
      return countries;
    }
    return [];
  }
  
  /// دریافت لیست استان‌ها
  static Future<List<Map<String, dynamic>>> getProvinces({int? countryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_provinces');
    if (data != null) {
      var provinces = List<Map<String, dynamic>>.from(jsonDecode(data));
      provinces = provinces.where((p) => p['isActive'] == true || p['isActive'] == 1).toList();
      if (countryId != null) {
        provinces = provinces.where((p) => p['parentId'] == countryId).toList();
      }
      return provinces;
    }
    return [];
  }
  
  /// درىافت لىست مناطق
  static Future<List<Map<String, dynamic>>> getZones({int? provinceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_zones');
    if (data != null) {
      var zones = List<Map<String, dynamic>>.from(jsonDecode(data));
      zones = zones.where((z) => z['isActive'] == true || z['isActive'] == 1).toList();
      if (provinceId != null) {
        zones = zones.where((z) => z['parentId'] == provinceId).toList();
      }
      return zones;
    }
    return [];
  }
  
  /// درىافت لىست شهرها
  static Future<List<Map<String, dynamic>>> getCitiesData({int? provinceId, int? zoneId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_cities');
    if (data != null) {
      var cities = List<Map<String, dynamic>>.from(jsonDecode(data));
      cities = cities.where((c) => c['isActive'] == true || c['isActive'] == 1).toList();
      if (provinceId != null) {
        cities = cities.where((c) => c['parentId'] == provinceId).toList();
      }
      if (zoneId != null) {
        cities = cities.where((c) => c['parentId'] == zoneId).toList();
      }
      return cities;
    }
    return [];
  }
  
  /// دریافت لیست ارزها
  static Future<List<Map<String, dynamic>>> getCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_currencies');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست شعبات
  static Future<List<Map<String, dynamic>>> getBranches() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_branches');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست انواع شناسنامه
  static Future<List<Map<String, dynamic>>> getIdentityTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_identity_types');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست انواع حساب
  static Future<List<Map<String, dynamic>>> getAccountTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_account_types');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست انواع حواله
  static Future<List<Map<String, dynamic>>> getTransferTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_transfer_types');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست روش‌های پرداخت
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_payment_methods');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست بانک‌ها
  static Future<List<Map<String, dynamic>>> getBanks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_banks');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت لیست نرخ‌های تبدیل ارز
  static Future<List<Map<String, dynamic>>> getExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_exchange_rates');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// دریافت هر داده دلخواه با کلید
  static Future<List<Map<String, dynamic>>> getCustomData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_$key');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
  
  /// بررسی آیا داده‌ها همگام‌سازی شده‌اند
  static Future<bool> isDataSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('settings_last_sync') != null;
  }
  
  /// دریافت زمان آخرین همگام‌سازی
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('settings_last_sync');
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }
}
