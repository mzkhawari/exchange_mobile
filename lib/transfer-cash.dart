import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// 📦 مدل درخواست (Request)
class TransactionRequestModel {
  final int baseCurrencyId;
  final bool isFullPrint;
  final int page;
  final int size;

  TransactionRequestModel({
    this.baseCurrencyId = 1,
    this.isFullPrint = true,
    required this.page,
    required this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      "baseCurrencyId": baseCurrencyId,
      "isFullPrint": isFullPrint,
      "page": page,
      "size": size,
    };
  }
}

/// 📦 مدل پاسخ (Response)
class TransactionResponse {
  final int count;
  final List<TransactionModel> data;

  TransactionResponse({required this.count, required this.data});

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      count: json['count'] ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => TransactionModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 📦 مدل آیتم تراکنش
class TransactionModel {
  final int id;
  final String? createDateFa;
  final double? amount;
  final double? amountAfg;
  final double? buySellRate;
  final double? marketRate;

  TransactionModel({
    required this.id,
    this.createDateFa,
    this.amount,
    this.amountAfg,
    this.buySellRate,
    this.marketRate,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? 0,
      createDateFa: json['createDateFa'],
      amount: (json['amount'] as num?)?.toDouble(),
      amountAfg: (json['amountAfg'] as num?)?.toDouble(),
      buySellRate: (json['buySellRate'] as num?)?.toDouble(),
      marketRate: (json['marketRate'] as num?)?.toDouble(),
    );
  }
}

/// 📋 صفحه لیست تراکنش‌ها
class TransactionListPage extends StatefulWidget {
  final int initialStatus;
  const TransactionListPage({super.key, this.initialStatus = 0});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final Dio dio = Dio();
  final String apiUrl =
      "https://10.0.2.2:7179/api/transfercashMob/PostIncludeByPaging";

  List<TransactionModel> dataList = [];
  int dataListCount = 0;
  int currentPage = 1;
  bool isLoading = false;
  int selectedStatus = 0;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialStatus;
    fetchTransactions();
  }

  /// 📡 متد فراخوانی API
  Future<void> fetchTransactions({int page = 1}) async {
    setState(() => isLoading = true);
    
    final request = TransactionRequestModel(page: page, size: 10);
    try {
      final response = await dio.post(apiUrl, data: request.toJson());
      if (response.statusCode == 200) {
        final result = TransactionResponse.fromJson(response.data);
        setState(() {
          dataList = result.data;
          dataListCount = result.count;
          currentPage = page;
        });
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching transactions: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 📘 دکمه تغییر وضعیت (فیلتر)
  void statusButton(int status) {
    setState(() => selectedStatus = status);
    fetchTransactions(page: 1);
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
              Colors.green.shade50,
              Colors.teal.shade50,
              Colors.blue.shade50,
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
                    colors: [Colors.green.shade700, Colors.teal.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '💸 Transaction List',
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
                      onPressed: () => fetchTransactions(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Status filter section
              _buildStatusButtons(),

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
                    _buildStatItem(Icons.receipt_long, 'Total', dataListCount.toString(), Colors.green),
                    _buildStatItem(Icons.layers, 'Page', currentPage.toString(), Colors.teal),
                    _buildStatItem(Icons.dataset, 'Showing', dataList.length.toString(), Colors.blue),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Transaction list
              Expanded(
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.green.shade700),
                            const SizedBox(height: 15),
                            Text(
                              'Loading transactions...',
                              style: TextStyle(color: Colors.green.shade700, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : _buildTransactionList(),
              ),

              // Pagination
              _buildPagination(),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎛️ Status filter buttons
  Widget _buildStatusButtons() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _statusChip('All', 0, Icons.list, Colors.grey),
          _statusChip('Awaiting', 1, Icons.pending_actions, Colors.orange),
          _statusChip('Confirmed', 2, Icons.check_circle, Colors.purple),
          _statusChip('Completed', 4, Icons.done_all, Colors.green),
          _statusChip('Rejected', 5, Icons.cancel, Colors.red),
          _statusChip('Rejected w/o C', 55, Icons.block, Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int value, IconData icon, Color color) {
    final isSelected = selectedStatus == value;
    return GestureDetector(
      onTap: () => statusButton(value),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color, color.withOpacity(0.7)])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  /// 🧾 Transaction list
  Widget _buildTransactionList() {
    if (dataList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            Text(
              'No transactions found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        return _buildTransactionCard(item);
      },
    );
  }

  Widget _buildTransactionCard(TransactionModel item) {
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            // ID Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.teal.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${item.id}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 15),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        'Amount: ${item.amount?.toStringAsFixed(2) ?? "-"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        item.createDateFa ?? "N/A",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.currency_exchange, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        'AFG: ${item.amountAfg?.toStringAsFixed(2) ?? "-"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Rate badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Rate',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    item.buySellRate?.toStringAsFixed(2) ?? "-",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📄 Pagination
  Widget _buildPagination() {
    final totalPages = (dataListCount / 10).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
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
            onPressed: currentPage > 1 ? () => fetchTransactions(page: currentPage - 1) : null,
            icon: Icon(
              Icons.arrow_back_ios,
              color: currentPage > 1 ? Colors.green.shade700 : Colors.grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.teal.shade500],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $currentPage of $totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages ? () => fetchTransactions(page: currentPage + 1) : null,
            icon: Icon(
              Icons.arrow_forward_ios,
              color: currentPage < totalPages ? Colors.green.shade700 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
