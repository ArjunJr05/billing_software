import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Expense {
  final String id;
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final String paymentMethod;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      category: json['category'],
      amount: json['amount'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      paymentMethod: json['paymentMethod'],
    );
  }
}

class ExpenseTrackerPage extends StatefulWidget {
  const ExpenseTrackerPage({Key? key}) : super(key: key);

  @override
  State<ExpenseTrackerPage> createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final List<Expense> _expenses = [];
  final List<String> _categories = [
    'Raw Materials',
    'Packaging',
    'Utilities',
    'Wages',
    'Rent',
    'Equipment',
    'Transportation',
    'Marketing',
    'Maintenance',
    'Others'
  ];
  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Bank Transfer',
    'UPI',
    'Check'
  ];

  String _selectedCategory = 'Raw Materials';
  String _selectedPaymentMethod = 'Cash';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  String _searchQuery = '';
  String _filterCategory = 'All';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];
    
    setState(() {
      _expenses.clear();
      for (final expenseJson in expensesJson) {
        final expenseMap = json.decode(expenseJson) as Map<String, dynamic>;
        _expenses.add(Expense.fromJson(expenseMap));
      }
    });
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = _expenses.map((e) => json.encode(e.toJson())).toList();
    await prefs.setStringList('expenses', expensesJson);
  }

  void _addExpense() {
    if (_amountController.text.isEmpty) {
      _showMessage('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid amount');
      return;
    }

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: _selectedCategory,
      amount: amount,
      description: _descriptionController.text,
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
    );

    setState(() {
      _expenses.add(newExpense);
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    });

    _saveExpenses();
    _resetForm();
    _showMessage('Expense added successfully');
  }

  void _deleteExpense(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _expenses.removeWhere((expense) => expense.id == id);
              });
              _saveExpenses();
              Navigator.pop(context);
              _showMessage('Expense deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = _categories[0];
      _selectedPaymentMethod = _paymentMethods[0];
      _selectedDate = DateTime.now();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  List<Expense> get _filteredExpenses {
    return _expenses.where((expense) {
      final matchesSearch = expense.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          expense.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _filterCategory == 'All' || expense.category == _filterCategory;
      final matchesDateRange = expense.date.isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(_dateRange.end.add(const Duration(days: 1)));
      return matchesSearch && matchesCategory && matchesDateRange;
    }).toList();
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final category in _categories) {
      totals[category] = 0;
    }
    
    for (final expense in _filteredExpenses) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  double get _totalAmount {
    return _filteredExpenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  String _getFormattedDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 185, 206, 224),
      appBar: AppBar(
        title: const Text('Cashew & Nuts Shop Expense Tracker'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 216, 224, 228),
              Color.fromARGB(255, 196, 232, 245),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Form and Summary
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.add_circle_outline, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Add New Expense',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Category dropdown
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              value: _selectedCategory,
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Amount field
                            TextField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount (₹)',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            
                            // Description field
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            
                            // Date picker
                            InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(_getFormattedDate(_selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Payment method dropdown
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Payment Method',
                              ),
                              value: _selectedPaymentMethod,
                              items: _paymentMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedPaymentMethod = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addExpense,
                                    child: const Text('Add Expense'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _resetForm,
                                    child: const Text('Reset'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Card(
                         color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.pie_chart_outline, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Expense Summary',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Total amount
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Expenses:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '₹${_totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Category breakdown
                              Expanded(
                                child: ListView(
                                  children: _categoryTotals.entries.map((entry) {
                                    final percentage = _totalAmount > 0
                                        ? (entry.value / _totalAmount) * 100
                                        : 0.0;
                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(entry.key),
                                              Text('₹${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)'),
                                            ],
                                          ),
                                        ),
                                        LinearProgressIndicator(
                                          value: _totalAmount > 0 ? entry.value / _totalAmount : 0,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.blue[400] ?? Colors.blue,
                                          ),
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Right side - Expenses list
              Expanded(
                flex: 2,
                child: Card(
                   color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.list_alt, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Expense Records',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_filteredExpenses.length} items',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Search and filter
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Search expenses...',
                                  prefixIcon: Icon(Icons.search),
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Filter Category',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                value: _filterCategory,
                                items: ['All', ..._categories].map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _filterCategory = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(
                                '${_getFormattedDate(_dateRange.start)} - ${_getFormattedDate(_dateRange.end)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Expense list header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              Expanded(flex: 2, child: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
                              SizedBox(width: 40), // Space for delete button
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Expense list
                        Expanded(
                          child: _filteredExpenses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No expenses found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _filteredExpenses.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final expense = _filteredExpenses[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              expense.category.substring(0, 1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                expense.description.isEmpty
                                                    ? expense.category
                                                    : expense.description,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '₹${expense.amount.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${expense.category} • ${expense.paymentMethod}',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                _getFormattedDate(expense.date),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteExpense(expense.id),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        
                        const SizedBox(height: 12),
                        // Export button
                        
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.insert_drive_file),
              label: const Text('Export as CSV'),
              onPressed: () {
                Navigator.pop(context);
                _showMessage('CSV export would be implemented in the full version');
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export as PDF'),
              onPressed: () {
                Navigator.pop(context);
                _showMessage('PDF export would be implemented in the full version');
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Export as Image'),
              onPressed: () {
                Navigator.pop(context);
                _showMessage('Image export would be implemented in the full version');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

}