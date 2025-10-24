import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../auth/providers/auth_provider.dart';
import '../../transaction/service_providers/transaction_service_providers.dart';
import '../models/report_data.dart';

class ReportDetailsScreen extends ConsumerStatefulWidget {
  const ReportDetailsScreen({super.key});

  @override
  ConsumerState<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen> {
  String _selectedFilter = 'Year';
  String _selectedTransactionType = 'Income';

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;

    if (uid == null) {
      return _buildUnauthenticatedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          ref.watch(transactionStreamProvider(uid)).when(
                data: (transactions) => IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _showDownloadDialog(context, transactions),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
        ],
      ),
      body: ref.watch(transactionStreamProvider(uid)).when(
            data: (transactions) => _buildReportContent(transactions),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
    );
  }

  void _showDownloadDialog(
      BuildContext context, List<dynamic> allTransactions) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime selectedDate = DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Download Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Picker
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDialog<DateTime>(
                        context: context,
                        builder: (BuildContext context) {
                          return _YearPickerDialog(
                            initialDate: selectedDate,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = DateTime(
                            picked.year,
                            selectedDate.month,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Year:',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Text(
                            selectedDate.year.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Month Picker
                  InkWell(
                    onTap: () async {
                      final int? picked = await showDialog<int>(
                        context: context,
                        builder: (BuildContext context) {
                          return _MonthPickerDialog(
                            initialMonth: selectedDate.month,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = DateTime(
                            selectedDate.year,
                            picked,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Month:',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat.MMMM().format(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Download PDF'),
                  onPressed: () {
                    _generateAndShareReport(
                      allTransactions,
                      selectedDate.year,
                      selectedDate.month,
                      'pdf',
                    );
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Download CSV'),
                  onPressed: () {
                    _generateAndShareReport(
                      allTransactions,
                      selectedDate.year,
                      selectedDate.month,
                      'csv',
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndShareReport(
      List<dynamic> allTransactions, int year, int month, String format) async {
    final transactions = allTransactions
        .where((t) => t.date.year == year && t.date.month == month)
        .toList();

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No transactions found for the selected period.')),
      );
      return;
    }

    final monthName = DateFormat.MMMM().format(DateTime(0, month));
    final fileName = 'Report-$monthName-$year';

    if (format == 'csv') {
      await _generateAndShareCsv(transactions, fileName);
    } else {
      await _generateAndSharePdf(transactions, fileName, monthName, year);
    }
  }

  Future<void> _generateAndShareCsv(
      List<dynamic> transactions, String fileName) async {
    final List<List<dynamic>> rows = [];
    rows.add(['Date', 'Category', 'Description', 'Amount', 'Type']);
    for (var t in transactions) {
      rows.add([
        DateFormat.yMd().format(t.date),
        t.categoryName,
        t.description,
        t.amount,
        t.categoryType,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Financial Report');
  }

  Future<void> _generateAndSharePdf(List<dynamic> transactions, String fileName,
      String monthName, int year) async {
    final pdf = pw.Document();

    final totalIncome = transactions
        .where((t) => t.categoryType == 'Income')
        .fold(0.0, (sum, item) => sum + item.amount);
    final totalExpense = transactions
        .where((t) => t.categoryType == 'Expense')
        .fold(0.0, (sum, item) => sum + item.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Financial Report - $monthName $year',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryBox(
                    'Total Income',
                    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                        .format(totalIncome),
                    PdfColors.green),
                _buildSummaryBox(
                    'Total Expense',
                    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                        .format(totalExpense),
                    PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Date', 'Category', 'Description', 'Amount', 'Type'],
              data: transactions.map((t) {
                return [
                  DateFormat.yMd().format(t.date),
                  t.categoryName,
                  t.description,
                  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                      .format(t.amount),
                  t.categoryType,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '$fileName.pdf');
  }

  pw.Widget _buildSummaryBox(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(value),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: const Center(child: Text('User not logged in')),
    );
  }

  Widget _buildReportContent(List<dynamic> transactions) {
    final reportData = _processTransactionData(transactions);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterButtons(),
            const SizedBox(height: 8),
            _buildReportChart(reportData),
            const SizedBox(height: 8),
            _buildTransactionSection(reportData.filteredTransactions),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Week', 'Month', 'Year'].map((filter) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedFilter = filter),
            style: _getFilterButtonStyle(filter),
            child: Text(filter),
          ),
        );
      }).toList(),
    );
  }

  ButtonStyle _getFilterButtonStyle(String filter) {
    final theme = Theme.of(context);
    return ElevatedButton.styleFrom(
      backgroundColor: _selectedFilter == filter
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.2),
      foregroundColor: _selectedFilter == filter
          ? Colors.white
          : theme.colorScheme.onSurface,
    );
  }

  Widget _buildReportChart(ReportData reportData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildBarChart(reportData),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(ReportData reportData) {
    return SizedBox(
      width: reportData.xCount * 84.0,
      child: BarChart(
        BarChartData(
          barGroups: _generateBarGroups(reportData),
          titlesData: _buildChartTitlesData(reportData),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          barTouchData: _buildBarTouchData(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups(ReportData reportData) {
    return List.generate(reportData.xCount, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          _createBarRod(reportData.incomeData[index], Colors.green),
          _createBarRod(reportData.expenseData[index], Colors.red),
        ],
      );
    });
  }

  BarChartRodData _createBarRod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 20,
      borderRadius: BorderRadius.circular(4),
    );
  }

  FlTitlesData _buildChartTitlesData(ReportData reportData) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) => Text(
            reportData.labelFormatter(value.toInt()),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        tooltipMargin: 0,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final label = rodIndex == 0 ? 'Income' : 'Expense';
          return BarTooltipItem(
            '$label\n ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(rod.toY)}',
            const TextStyle(color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildTransactionSection(List<dynamic> filteredTransactions) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 500,
        minHeight: 150,
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildTransactionTypeButtons(),
            const SizedBox(height: 4),
            _buildTransactionList(filteredTransactions),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Income', 'Expense'].map((type) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedTransactionType = type),
            style: _getTransactionTypeButtonStyle(type),
            child: Text(type),
          ),
        );
      }).toList(),
    );
  }

  ButtonStyle _getTransactionTypeButtonStyle(String type) {
    final theme = Theme.of(context);
    return ElevatedButton.styleFrom(
      backgroundColor: _selectedTransactionType == type
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withOpacity(0.2),
      foregroundColor: _selectedTransactionType == type
          ? Colors.white
          : theme.colorScheme.onSurface,
    );
  }

  Widget _buildTransactionList(List<dynamic> filteredTransactions) {
    return Expanded(
      child: ListView.builder(
        itemCount: filteredTransactions.length,
        itemBuilder: (context, index) =>
            _buildTransactionItem(filteredTransactions[index]),
      ),
    );
  }

  Widget _buildTransactionItem(dynamic transaction) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceBright,
      child: ListTile(
        leading: _buildTransactionLeadingIcon(transaction),
        title: Text(
          transaction.description.isNotEmpty
              ? transaction.description
              : transaction.categoryName,
        ),
        subtitle: Text(_formatTransactionDate(transaction.date)),
        trailing: Text(
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits:
                transaction.amount == transaction.amount.toInt() ? 0 : 2,
          ).format(transaction.amount),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTransactionLeadingIcon(dynamic transaction) {
    final isIncome = transaction.categoryType == 'Income';
    return CircleAvatar(
      backgroundColor: isIncome ? Colors.green : Colors.red,
      child: Icon(
        transaction.categoryIcon,
      ),
    );
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  ReportData _processTransactionData(List<dynamic> transactions) {
    final now = DateTime.now();
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    // Hitung endOfWeek (Minggu pukul 23:59:59)
    final endOfWeek = startOfWeek
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final startOfMonth = DateTime(now.year, now.month, 1);
    final currentYear = now.year;

    // Initialize data lists
    final weeklyIncome = List.filled(7, 0.0);
    final weeklyExpense = List.filled(7, 0.0);
    final monthlyIncome = List.filled(4, 0.0);
    final monthlyExpense = List.filled(4, 0.0);
    final yearlyIncome = List.filled(12, 0.0);
    final yearlyExpense = List.filled(12, 0.0);
    final filteredTransactions = <dynamic>[];

    // Process transactions
    for (var transaction in transactions) {
      _processTransaction(
        transaction,
        now,
        startOfWeek,
        endOfWeek,
        startOfMonth,
        currentYear,
        weeklyIncome,
        weeklyExpense,
        monthlyIncome,
        monthlyExpense,
        yearlyIncome,
        yearlyExpense,
        filteredTransactions,
      );
    }

    // Determine data based on selected filter
    List<double> incomeData;
    List<double> expenseData;
    int xCount;
    String Function(int index) labelFormatter;

    switch (_selectedFilter) {
      case 'Week':
        incomeData = weeklyIncome;
        expenseData = weeklyExpense;
        xCount = 7;
        labelFormatter = (index) => DateFormat.E()
            .format(startOfWeek.add(Duration(days: index)))
            .substring(0, 3);
        break;
      case 'Month':
        incomeData = monthlyIncome;
        expenseData = monthlyExpense;
        xCount = 4;
        labelFormatter = (index) => 'Week ${index + 1}';
        break;
      default: // Year
        incomeData = yearlyIncome;
        expenseData = yearlyExpense;
        xCount = 12;
        labelFormatter = (index) {
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];
          return months[index];
        };
    }

    // Filter transactions by selected type
    final typedFilteredTransactions = filteredTransactions
        .where((transaction) =>
            transaction.categoryType == _selectedTransactionType)
        .toList();

    return ReportData(
      incomeData: incomeData,
      expenseData: expenseData,
      xCount: xCount,
      labelFormatter: labelFormatter,
      filteredTransactions: typedFilteredTransactions,
    );
  }

  void _processTransaction(
    dynamic transaction,
    DateTime now,
    DateTime startOfWeek,
    DateTime endOfWeek,
    DateTime startOfMonth,
    int currentYear,
    List<double> weeklyIncome,
    List<double> weeklyExpense,
    List<double> monthlyIncome,
    List<double> monthlyExpense,
    List<double> yearlyIncome,
    List<double> yearlyExpense,
    List<dynamic> filteredTransactions,
  ) {
    final date = transaction.date;

    // Filter transactions based on selected period
    if (_selectedFilter == 'Week' &&
        date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
      filteredTransactions.add(transaction);
    } else if (_selectedFilter == 'Month' &&
        (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth))) {
      filteredTransactions.add(transaction);
    } else if (_selectedFilter == 'Year' && date.year == currentYear) {
      filteredTransactions.add(transaction);
    }

    // Aggregate yearly data
    if (date.year == currentYear) {
      final monthIndex = date.month - 1;
      if (transaction.categoryType == 'Income') {
        yearlyIncome[monthIndex] += transaction.amount;
      } else if (transaction.categoryType == 'Expense') {
        yearlyExpense[monthIndex] += transaction.amount;
      }
    }

    // Aggregate monthly data
    if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
      final weekIndex = ((date.day - 1) ~/ 7).clamp(0, 3);
      if (transaction.categoryType == 'Income') {
        monthlyIncome[weekIndex] += transaction.amount;
      } else if (transaction.categoryType == 'Expense') {
        monthlyExpense[weekIndex] += transaction.amount;
      }
    }

    // Aggregate weekly data
    if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
      final dayIndex = date.weekday - 1;
      if (transaction.categoryType == 'Income') {
        weeklyIncome[dayIndex] += transaction.amount;
      } else if (transaction.categoryType == 'Expense') {
        weeklyExpense[dayIndex] += transaction.amount;
      }
    }
  }
}

// Custom Year Picker Dialog
class _YearPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _YearPickerDialog({
    required this.initialDate,
  });

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _selectedYear;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;

    // Calculate initial scroll position to center selected year
    final currentYear = DateTime.now().year;
    final yearDiff = currentYear - _selectedYear;
    _scrollController = ScrollController(
      initialScrollOffset:
          yearDiff * 56.0, // 56 is the height of each year item
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    // Generate years from 1900 to 100 years in the future
    final years = List.generate(
      currentYear - 1900 + 100,
      (index) => currentYear - index + 99,
    );

    return Dialog(
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select Year',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = year == _selectedYear;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedYear = year;
                      });
                    },
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      DateTime(_selectedYear, widget.initialDate.month),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Month Picker Dialog
class _MonthPickerDialog extends StatefulWidget {
  final int initialMonth;

  const _MonthPickerDialog({
    required this.initialMonth,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Month',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthIndex = index + 1;
                  final isSelected = monthIndex == _selectedMonth;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMonth = monthIndex;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        months[index].substring(0, 3),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_selectedMonth);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
