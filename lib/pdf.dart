import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:shop/main.dart';

class BillDisplayPage extends StatelessWidget {
  final Bill bill;

  BillDisplayPage({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Receipt',
          style: TextStyle(color: Colors.white), // Setting text color to white
        ),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(
            color: Colors.white), // Setting back button color to white
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: Colors.white, // Setting save icon color to white
            ),
            onPressed: () {
              _saveToPdf(context);
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 16),

                      // Grove logo and name
                      Row(
                        children: [
                          Text(
                            "NUT'S & CASHEW GROVE",
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.local_florist, size: 24),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Store info
                      Text(
                        'No. 20-21, Privdarshini Nagar,',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Gorimedu, Puducherry Nagar. - 6',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Cell: 9994912184',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'mail: sunithay743@gmail.com',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 8),

                      // Receipt info
                      Text(
                        'INVOICE #: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          letterSpacing: -0.5,
                        ),
                      ),
                      Divider(thickness: 1),

                      // Items
                      ...List.generate(bill.items.length, (index) {
                        final item = bill.items[index];
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    item.product.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Courier',
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.quantity} X',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Code: NGR-${(index + 101).toString()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'SUBTOTAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '\$${_getRunningTotal(bill.items, index).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                          ],
                        );
                      }),

                      // Totals section
                      Divider(thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SUBTOTAL',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '\$${bill.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TAX (GST)    5.0 %',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '\$${(bill.total * 0.05).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '\$${bill.grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TENDER',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '\$${bill.grandTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CHANGE DUE',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '0.00',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Payment method
                      Row(
                        children: [
                          Text(
                            'PAYMENT METHOD',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'TOTAL PURCHASE',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cash',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '# ITEMS SOLD ${bill.items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Footer
                      Center(
                        child: Container(
                          height: 40,
                          color: Colors.black,
                          width: 200,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      SizedBox(height: 8),
                      Text(
                        'Thank you for shopping with us!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        DateTime.now().toString().substring(0, 16),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to calculate running total
  double _getRunningTotal(List<BillItem> items, int currentIndex) {
    double total = 0;
    for (int i = 0; i <= currentIndex; i++) {
      total += items[i].totalPrice;
    }
    return total;
  }

  Future<void> _saveToPdf(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                color: PdfColors.green800,
                padding: pw.EdgeInsets.all(10),
                child: pw.Text("NUT'S & CASHEW GROVE",
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              pw.SizedBox(height: 16),
              pw.Text('No. 20-21, Privdarshini Nagar,',
                  style: pw.TextStyle(fontSize: 10)),
              pw.Text('Gorimedu, Puducherry Nagar. - 6',
                  style: pw.TextStyle(fontSize: 10)),
              pw.Text('Cell: 9994912184', style: pw.TextStyle(fontSize: 10)),
              pw.Text('mail: sunithay743@gmail.com',
                  style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text(
                  'INVOICE #: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}',
                  style: pw.TextStyle(fontSize: 10)),
              pw.Divider(),

              // Items
              ...bill.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(item.product.name,
                              style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Text('${item.quantity} X',
                            style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Code: NGR-${(index + 101).toString()}',
                            style: pw.TextStyle(fontSize: 10)),
                        pw.Text('\$${item.totalPrice.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                  ],
                );
              }).toList(),

              pw.Divider(),
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('\$${bill.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TAX (GST)    5.0 %',
                      style: pw.TextStyle(fontSize: 12)),
                  pw.Text('\$${(bill.total * 0.05).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$${bill.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text('Thank you for shopping with us!',
                    style: pw.TextStyle(fontSize: 10)),
              ),
              pw.Center(
                child: pw.Text(DateTime.now().toString().substring(0, 16),
                    style: pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'nuts_cashew_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // Get the desktop directory path based on platform
    final String desktopPath;
    if (Platform.isWindows) {
      // On Windows
      final userHomePath = Platform.environment['USERPROFILE']!;
      desktopPath = '$userHomePath\\Desktop';
    } else if (Platform.isMacOS) {
      // On macOS
      final userHomePath = Platform.environment['HOME']!;
      desktopPath = '$userHomePath/Desktop';
    } else if (Platform.isLinux) {
      // On Linux
      final userHomePath = Platform.environment['HOME']!;
      desktopPath = '$userHomePath/Desktop';
    } else {
      // For other platforms or fallback, use application documents directory
      final directory = await getApplicationDocumentsDirectory();
      desktopPath = directory.path;
    }

    final file = File('$desktopPath/$fileName');

    try {
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt saved to Desktop as PDF'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save receipt as PDF: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
