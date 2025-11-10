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
      "https://api1.katawazexchange.com/api/TransactionCash/PostIncludeByPaging";

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
      appBar: AppBar(
        title: const Text('List of Financial Transactions'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildStatusButtons(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTransactionList(),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  /// 🎛️ دکمه‌های فیلتر وضعیت
  Widget _buildStatusButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _statusButton('All', 0, Colors.grey.shade300),
          _statusButton('Awaiting Approval', 1, Colors.yellow.shade100),
          _statusButton('Confirmed', 2, Colors.purple.shade200),
          _statusButton('Completed', 4, Colors.green.shade100),
          _statusButton('Rejected', 5, Colors.red.shade100),
          _statusButton('Rejected w/o Commission', 55, Colors.red.shade200),
        ],
      ),
    );
  }

  Widget _statusButton(String text, int value, Color color) {
    final isActive = selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: isActive ? Colors.blue.shade900 : Colors.black87,
          elevation: isActive ? 3 : 0,
        ),
        onPressed: () => statusButton(value),
        child: Text(text),
      ),
    );
  }

  /// 🧾 لیست تراکنش‌ها
  Widget _buildTransactionList() {
    if (dataList.isEmpty) {
      return const Center(child: Text("No transactions found."));
    }

    return ListView.builder(
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text('${item.id}'),
            ),
            title: Text(
              'Amount: ${item.amount?.toStringAsFixed(2) ?? "-"}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Date: ${item.createDateFa ?? "-"}  |  Afg: ${item.amountAfg?.toStringAsFixed(2) ?? "-"}',
            ),
            trailing: Text(
              'Rate: ${item.buySellRate ?? "-"}',
              style: const TextStyle(color: Colors.blueAccent),
            ),
          ),
        );
      },
    );
  }

  /// 📄 صفحه‌بندی
  Widget _buildPagination() {
    final totalPages = (dataListCount / 10).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: currentPage > 1
                ? () => fetchTransactions(page: currentPage - 1)
                : null,
            child: const Text('Previous'),
          ),
          const SizedBox(width: 12),
          Text('Page $currentPage of $totalPages'),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: currentPage < totalPages
                ? () => fetchTransactions(page: currentPage + 1)
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
