import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final Dio dio = Dio(BaseOptions(baseUrl: "https://209.42.25.31:7179/api"));

  int selectedStatus = 0; // 0=all, 1=awaiting, 2=confirmed
  int currentPage = 1;
  int totalCount = 0;
  List<dynamic> dataList = [];
  bool isLoading = false;
  String searchQuery = '';
  String baseUrlImages = 'https://katawazexchange.com/';
  
  // Settings data
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
  
  /// Load settings data
  Future<void> _loadSettingsData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load account types
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
    
    // Load identity types
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
    
    // Load countries
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
    
    // Load provinces
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
    
    // Load zones
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
        '/accountMob/PostIncludeByPaging',
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
    // Get readable names from settings data
    final accountTypeName = _accountTypeNames[customer['accountTypeId']?.toString()] ?? 'Unknown';
    final identityTypeName = _identityTypeNames[customer['identityTypeId']?.toString()] ?? 'Unknown';
    final countryName = _countryNames[customer['countryId']?.toString()] ?? 'Unknown';
    final provinceName = _provinceNames[customer['provinceId']?.toString()] ?? 'Unknown';
    final zoneName = _zoneNames[customer['zoneId']?.toString()] ?? 'Unknown';
    
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
                        customer['fullName'] ?? 'Customer Details',
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
                        // Profile picture
                        if (customer['picUrlAvatar'] != null)
                          Center(
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(baseUrlImages + customer['picUrlAvatar']),
                            ),
                          ),
                        const SizedBox(height: 16),
                        
                        // Personal info
                        _buildInfoSection(
                          'Personal Info',
                          Icons.person,
                          [
                            _buildInfoRow('Account No', customer['accountNo']?.toString() ?? '-'),
                            _buildInfoRow('Full Name', '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'),
                            _buildInfoRow('Phone Number', customer['phoneNumber']?.toString() ?? '-'),
                            _buildInfoRow('Job', customer['job']?.toString() ?? '-'),
                            _buildInfoRow('Account Type', accountTypeName),
                            _buildInfoRow('Identity Type', identityTypeName),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Location info
                        _buildInfoSection(
                          'Location Info',
                          Icons.location_on,
                          [
                            _buildInfoRow('Country', countryName),
                            _buildInfoRow('Province', provinceName),
                            _buildInfoRow('Zone', zoneName),
                            if (customer['address'] != null)
                              _buildInfoRow('Address', customer['address'].toString()),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Status
                        _buildInfoSection(
                          'Status',
                          Icons.info_outline,
                          [
                            _buildInfoRow(
                              'Status',
                              customer['statusText']?.toString() ?? 'Unknown',
                              valueColor: _getStatusColor(customer['statusText']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.purple.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Customer Accounts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: fetchCustomers,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        onSubmitted: onSearch,
                        decoration: InputDecoration(
                          hintText: 'Search by name or account number...',
                          prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.green.shade600),
                            onPressed: onAddCustomer,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Status filter chips
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildStatusChip('All', 0, Icons.list, Colors.grey),
                    _buildStatusChip('Awaiting', 1, Icons.pending, Colors.orange),
                    _buildStatusChip('Confirmed', 2, Icons.check_circle, Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Stats bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.people, 'Total', totalCount.toString(), Colors.blue),
                    _buildStatItem(Icons.layers, 'Page', currentPage.toString(), Colors.purple),
                    _buildStatItem(Icons.dataset, 'Showing', dataList.length.toString(), Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Customer list
              Expanded(
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.blue.shade700),
                            const SizedBox(height: 15),
                            Text(
                              'Loading customers...',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : dataList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                                const SizedBox(height: 15),
                                Text(
                                  'No customers found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchCustomers,
                            color: Colors.blue.shade700,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              itemCount: dataList.length,
                              itemBuilder: (context, index) {
                                final item = dataList[index];
                                return _buildCustomerCard(item);
                              },
                            ),
                          ),
              ),

              // Pagination
              if (!isLoading && totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: currentPage > 1 ? prevPage : null,
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: currentPage > 1 ? Colors.blue.shade700 : Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.purple.shade500],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page $currentPage of ${(totalCount / 10).ceil()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (currentPage * 10) < totalCount ? nextPage : null,
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          color: (currentPage * 10) < totalCount ? Colors.blue.shade700 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int value, IconData icon, Color color) {
    final isSelected = selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
        onSelected: (_) => onStatusChange(value),
        backgroundColor: Colors.white,
        selectedColor: color,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        elevation: isSelected ? 4 : 2,
        shadowColor: color.withOpacity(0.4),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> item) {
    final statusColor = _getStatusColor(item['statusText']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => showCustomerPopup(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.transparent,
                    backgroundImage: item['picUrlAvatarThumb'] != null
                        ? NetworkImage(baseUrlImages + item['picUrlAvatarThumb'])
                        : null,
                    child: item['picUrlAvatarThumb'] == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                ),
                
                const SizedBox(width: 15),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim().isEmpty 
                          ? 'No Name' 
                          : '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(
                            item['phoneNumber']?.toString() ?? 'No Phone',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(
                            'Acc: ${item['accountNo']?.toString() ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status badge
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Text(
                        item['statusText']?.toString() ?? 'N/A',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
