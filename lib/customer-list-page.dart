import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'settings_page.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final Dio dio = Dio(BaseOptions(baseUrl: "https://api1.katawazexchange.com/api"));

  int selectedStatus = 0; // 0=all, 1=awaiting, 2=confirmed
  int currentPage = 1;
  int totalCount = 0;
  List<dynamic> dataList = [];
  bool isLoading = false;
  String searchQuery = '';
  String baseUrlImages = 'https://katawazexchange.com/';
  
  // داده‌های تنظیمات
  Map<String, String> _accountTypeNames = {};
  Map<String, String> _identityTypeNames = {};
  Map<String, String> _countryNames = {};
  Map<String, String> _provinceNames = {};
  Map<String, String> _zoneNames = {};

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
    fetchCustomers();
  }
  
  /// بارگذاری داده‌های تنظیمات
  Future<void> _loadSettingsData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // بارگذاری انواع حساب
    final accountTypesJson = prefs.getString('settings_account_types');
    if (accountTypesJson != null) {
      final accountTypes = List<Map<String, dynamic>>.from(jsonDecode(accountTypesJson));
      setState(() {
        _accountTypeNames = {
          for (var item in accountTypes) 
            item['id'].toString(): item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'
        };
      });
    }
    
    // بارگذاری انواع شناسنامه
    final identityTypesJson = prefs.getString('settings_identity_types');
    if (identityTypesJson != null) {
      final identityTypes = List<Map<String, dynamic>>.from(jsonDecode(identityTypesJson));
      setState(() {
        _identityTypeNames = {
          for (var item in identityTypes) 
            item['id'].toString(): item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'
        };
      });
    }
    
    // بارگذاری کشورها
    final countriesJson = prefs.getString('settings_countries');
    if (countriesJson != null) {
      final countries = List<Map<String, dynamic>>.from(jsonDecode(countriesJson));
      setState(() {
        _countryNames = {
          for (var item in countries) 
            item['id'].toString(): item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'
        };
      });
    }
    
    // بارگذاری استان‌ها
    final provincesJson = prefs.getString('settings_provinces');
    if (provincesJson != null) {
      final provinces = List<Map<String, dynamic>>.from(jsonDecode(provincesJson));
      setState(() {
        _provinceNames = {
          for (var item in provinces) 
            item['id'].toString(): item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'
        };
      });
    }
    
    // بارگذاری مناطق
    final zonesJson = prefs.getString('settings_zones');
    if (zonesJson != null) {
      final zones = List<Map<String, dynamic>>.from(jsonDecode(zonesJson));
      setState(() {
        _zoneNames = {
          for (var item in zones) 
            item['id'].toString(): item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'
        };
      });
    }
  }

  Future<void> fetchCustomers() async {
    setState(() => isLoading = true);

    try {
      final response = await dio.post(
        '/account/PostIncludeByPaging',
        data: {
          "isFullPrint": true,
          "page": currentPage,
          "size": 10,
          "status": selectedStatus,
          "search": searchQuery,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = response.data;
        setState(() {
          dataList = result['data'] ?? [];
          totalCount = result['count'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching data from server")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void onAddCustomer() {
    debugPrint("Add new customer");
  }

  void onSearch(String query) {
    searchQuery = query;
    currentPage = 1;
    fetchCustomers();
  }

  void onStatusChange(int status) {
    selectedStatus = status;
    currentPage = 1;
    fetchCustomers();
  }

  void nextPage() {
    if ((currentPage * 10) < totalCount) {
      setState(() => currentPage++);
      fetchCustomers();
    }
  }

  void prevPage() {
    if (currentPage > 1) {
      setState(() => currentPage--);
      fetchCustomers();
    }
  }

  void showCustomerPopup(Map<String, dynamic> customer) {
    // دریافت نام‌های قابل خواندن از داده‌های تنظیمات
    final accountTypeName = _accountTypeNames[customer['accountTypeId']?.toString()] ?? 'نامشخص';
    final identityTypeName = _identityTypeNames[customer['identityTypeId']?.toString()] ?? 'نامشخص';
    final countryName = _countryNames[customer['countryId']?.toString()] ?? 'نامشخص';
    final provinceName = _provinceNames[customer['provinceId']?.toString()] ?? 'نامشخص';
    final zoneName = _zoneNames[customer['zoneId']?.toString()] ?? 'نامشخص';
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer['fullName'] ?? 'جزئیات مشتری',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // عکس پروفایل
                        if (customer['picUrlAvatar'] != null)
                          Center(
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(baseUrlImages + customer['picUrlAvatar']),
                            ),
                          ),
                        const SizedBox(height: 16),
                        
                        // اطلاعات شخصی
                        _buildInfoSection(
                          'اطلاعات شخصی',
                          Icons.person,
                          [
                            _buildInfoRow('شماره حساب', customer['accountNo']?.toString() ?? '-'),
                            _buildInfoRow('نام کامل', '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'),
                            _buildInfoRow('شماره تماس', customer['phoneNumber']?.toString() ?? '-'),
                            _buildInfoRow('شغل', customer['job']?.toString() ?? '-'),
                            _buildInfoRow('نوع حساب', accountTypeName),
                            _buildInfoRow('نوع شناسنامه', identityTypeName),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // اطلاعات مکانی
                        _buildInfoSection(
                          'اطلاعات مکانی',
                          Icons.location_on,
                          [
                            _buildInfoRow('کشور', countryName),
                            _buildInfoRow('استان', provinceName),
                            _buildInfoRow('منطقه', zoneName),
                            if (customer['address'] != null)
                              _buildInfoRow('آدرس', customer['address'].toString()),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // وضعیت
                        _buildInfoSection(
                          'وضعیت',
                          Icons.info_outline,
                          [
                            _buildInfoRow(
                              'وضعیت',
                              customer['statusText']?.toString() ?? 'نامشخص',
                              valueColor: _getStatusColor(customer['statusText']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // دکمه بستن
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('بستن'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black54,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('Confirmed') || status.contains('تایید')) return Colors.green;
    if (status.contains('Awaiting') || status.contains('انتظار')) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Accounts List'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search & Add
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onSubmitted: onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or account number...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAddCustomer,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusButton('All Accounts', 0, Colors.grey),
                _statusButton('Awaiting Confirmation', 1, Colors.amber),
                _statusButton('Confirmed', 2, Colors.blue),
              ],
            ),

            const SizedBox(height: 12),

            // Customer list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dataList.isEmpty
                      ? const Center(child: Text('No data found'))
                      : RefreshIndicator(
                          onRefresh: fetchCustomers,
                          child: ListView.builder(
                            itemCount: dataList.length,
                            itemBuilder: (context, index) {
                              final item = dataList[index];
                              return Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    radius: 28,
                                    backgroundImage: item['picUrlAvatarThumb'] != null
                                        ? NetworkImage(baseUrlImages + item['picUrlAvatarThumb'])
                                        : null,
                                    child: item['picUrlAvatarThumb'] == null
                                        ? const Icon(Icons.person, size: 28)
                                        : null,
                                  ),
                                  title: Text(
                                    item['firstName'] + item['lastName'] ?? 'No Name',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['phoneNumber'] ?? 'No Phone'),
                                      Text('Account No: ${item['accountNo']}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () => showCustomerPopup(item),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),

            // Pagination
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Count: $totalCount'),
                    Row(
                      children: [
                        IconButton(
                          onPressed: prevPage,
                          icon: const Icon(Icons.arrow_back_ios),
                        ),
                        Text('$currentPage'),
                        IconButton(
                          onPressed: nextPage,
                          icon: const Icon(Icons.arrow_forward_ios),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(String title, int id, Color color) {
    final isSelected = selectedStatus == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => onStatusChange(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: 3,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
