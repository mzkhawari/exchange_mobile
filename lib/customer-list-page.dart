import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final Dio dio = Dio(BaseOptions(baseUrl: "https://10.0.2.2:7179/api"));

  int selectedStatus = 0; // 0=all, 1=awaiting, 2=confirmed
  int currentPage = 1;
  int totalCount = 0;
  List<dynamic> dataList = [];
  bool isLoading = false;
  String searchQuery = '';
  String baseUrlImages = 'https://katawazexchange.com/';

  @override
  void initState() {
    super.initState();
    fetchCustomers();
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  customer['fullName'] ?? 'Customer Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer['picUrlAvatar'] != null)
                          Center(
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage( baseUrlImages + customer['picUrlAvatar']),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text('Account No: ${customer['accountNo']}'),
                        Text('Full Name: ${customer['firstName'] + customer['lastName']}'),
                        Text('Phone: ${customer['phoneNumber'] ?? "-"}'),
                        Text('Job: ${customer['job'] ?? "-"}'),
                        Text('Account Type: ${customer['accountTypeId']}'),
                        Text('Status: ${customer['statusText'] ?? selectedStatus}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
