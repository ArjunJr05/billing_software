import 'dart:convert';

import 'package:shop/main.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class BillDisplayPage extends StatefulWidget {
  final Bill bill;

  const BillDisplayPage({Key? key, required this.bill}) : super(key: key);

  @override
  _BillDisplayPageState createState() => _BillDisplayPageState();
}

class _BillDisplayPageState extends State<BillDisplayPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isReturningCustomer = false;
  bool _customerDetailsAdded = false;
  double _discountAmount = 0.0;
  double _grandTotal = 0.0;
  int _visitCount = 0;

  @override
  void initState() {
    super.initState();
    _grandTotal = widget.bill.grandTotal;
  }

  Future<void> _lookupCustomer() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> customersList = prefs.getStringList('customers_list') ?? [];

    bool found = false;

    for (int i = 0; i < customersList.length; i++) {
      Map<String, dynamic> customer = jsonDecode(customersList[i]);
      if (customer['phone'] == _phoneController.text) {
        // Get and increment visit count
        _visitCount = (customer['visitCount'] as int? ?? 0) + 1;
        _discountAmount = _visitCount.toDouble();

        // Update customer data
        customer['visitCount'] = _visitCount;
        customer['name'] = _nameController.text.isNotEmpty
            ? _nameController.text
            : customer['name'];
        customer['address'] = _addressController.text.isNotEmpty
            ? _addressController.text
            : customer['address'];

        // Save updated customer
        customersList[i] = jsonEncode(customer);
        await prefs.setStringList('customers_list', customersList);

        setState(() {
          _nameController.text = customer['name'] ?? '';
          _addressController.text = customer['address'] ?? '';
          _isReturningCustomer = true;
          _grandTotal = widget.bill.grandTotal - _discountAmount;
          _customerDetailsAdded = true;
        });

        found = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Welcome back! A ₹$_discountAmount discount has been applied (Visit #$_visitCount)')),
        );
        break;
      }
    }

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'New customer! Please complete your details for future discounts')),
      );
    }
  }

  Future<void> _saveCustomerDetails() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> customersList = prefs.getStringList('customers_list') ?? [];

    Map<String, dynamic> customerData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'visitCount': _visitCount,
    };

    String customerJson = jsonEncode(customerData);

    bool exists = false;
    int existingIndex = -1;

    for (int i = 0; i < customersList.length; i++) {
      Map<String, dynamic> customer = jsonDecode(customersList[i]);
      if (customer['phone'] == _phoneController.text) {
        exists = true;
        existingIndex = i;
        break;
      }
    }

    if (exists) {
      // Update existing customer but preserve visit count
      Map<String, dynamic> existingCustomer =
          jsonDecode(customersList[existingIndex]);
      customerData['visitCount'] =
          existingCustomer['visitCount'] ?? _visitCount;
      customersList[existingIndex] = jsonEncode(customerData);
    } else {
      // New customer - initialize visit count to 0
      customerData['visitCount'] = 0;
      customersList.add(jsonEncode(customerData));
    }

    await prefs.setStringList('customers_list', customersList);

    setState(() {
      _customerDetailsAdded = true;
      if (!_isReturningCustomer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Customer details saved for future discounts!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => _printReceipt(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.grey[100],
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    elevation: 4,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: const [
                              Text(
                                "NUT'S & CASHEW GROVE",
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.local_florist, size: 24),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No. 20-21, Privdarshini Nagar,',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            'Gorimedu, Puducherry Nagar. - 6',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            'Cell: 9994912184',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            'mail: sunithay743@gmail.com',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          if (_customerDetailsAdded) ...[
                            const Divider(thickness: 1),
                            const Text(
                              'CUSTOMER DETAILS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Name: ${_nameController.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Courier',
                              ),
                            ),
                            Text(
                              'Phone: ${_phoneController.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Courier',
                              ),
                            ),
                            Text(
                              'Address: ${_addressController.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Courier',
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            'INVOICE #: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                            ),
                          ),
                          const Divider(thickness: 1),

                          // Items Table Header
                          const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Unit Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Weight',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const Divider(thickness: 1),

                          // Items List
                          ...widget.bill.items.map((item) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Courier',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '₹${item.product.price.toStringAsFixed(2)}/kg',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Courier',
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${item.weight}g',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Courier',
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '₹${item.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Courier',
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),

                          const Divider(thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SUBTOTAL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                '₹${widget.bill.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TAX (GST)    5.0 %',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                '₹${(widget.bill.total * 0.05).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          if (_discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'RETURN CUSTOMER DISCOUNT (Visit $_visitCount)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                                Text(
                                  '-₹${_discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                '₹${_grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TENDER',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                '₹${_grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CHANGE DUE',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              const Text(
                                '0.00',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Text(
                                'PAYMENT METHOD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Spacer(),
                              Text(
                                'TOTAL PURCHASE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cash',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              Text(
                                '# ITEMS SOLD ${widget.bill.items.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              height: 40,
                              color: Colors.black,
                              width: 200,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                    20,
                                    (index) => Container(
                                          width: 2,
                                          color: index % 2 == 0
                                              ? Colors.black
                                              : Colors.white,
                                        )),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Thank you for shopping with us!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                            ),
                          ),
                          Text(
                            DateTime.now().toString().substring(0, 16),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!_customerDetailsAdded) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Enter Customer Details for Future Discounts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone*',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _lookupCustomer,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Check'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _saveCustomerDetails,
                          child: const Text(
                            'Save Customer Details',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (_isReturningCustomer) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Welcome back! Your ₹$_discountAmount discount has been applied (Visit #$_visitCount).',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final pdf = await _generatePdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<pw.Document> _generatePdfDocument() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(
          marginLeft: 0,
          marginRight: 15,
          marginTop: 0,
          marginBottom: 0,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  "NUT'S & CASHEW GROVE",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  "The Best For You",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'No. 20-21, Priyadarshni Nagar,',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Gorimedu, Puducherry - 6',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Cell: 9994912184',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'mail: sunithay743@gmail.com',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Divider(),
              pw.SizedBox(height: 4),

              if (_customerDetailsAdded) ...[
                pw.Text(
                  'CUSTOMER DETAILS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Name: ${_nameController.text}',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Phone: ${_phoneController.text}',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Address: ${_addressController.text}',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Items',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Unit Price',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Weight',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(),

              // Items List
              ...widget.bill.items.map((item) {
                return pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            item.product.name,
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Rs.${item.product.price.toStringAsFixed(2)}/kg',
                            style: pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${item.weight}g',
                            style: pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Rs.\n${item.totalPrice.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                  ],
                );
              }).toList(),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SUBTOTAL',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${widget.bill.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TAX (GST)    0.0 %',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${(widget.bill.total * 0.00).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (_discountAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'RETURN CUSTOMER DISCOUNT (Visit $_visitCount)',
                      style: pw.TextStyle(
                        fontSize: 8,
                      ),
                    ),
                    pw.Text(
                      '-Rs ${_discountAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs ${_grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TENDER',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Rs ${_grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CHANGE DUE',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    '0.00',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ITEMS SOLD: ${widget.bill.items.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with us!',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  DateTime.now().toString().substring(0, 16),
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _saveToPdf(BuildContext context) async {
    try {
      final pdf = await _generatePdfDocument();
      final bytes = await pdf.save();
      final fileName =
          'nuts_cashew_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String desktopPath;
      if (Platform.isWindows) {
        final userHomePath = Platform.environment['USERPROFILE']!;
        desktopPath = '$userHomePath\\Desktop';
      } else if (Platform.isMacOS) {
        final userHomePath = Platform.environment['HOME']!;
        desktopPath = '$userHomePath/Desktop';
      } else if (Platform.isLinux) {
        final userHomePath = Platform.environment['HOME']!;
        desktopPath = '$userHomePath/Desktop';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        desktopPath = directory.path;
      }

      final file = File('$desktopPath/$fileName');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt saved to Desktop as $fileName'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save receipt: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
