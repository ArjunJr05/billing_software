// File: main.dart
import 'package:shop/Expenses.dart';
import 'package:shop/analyticsPage.dart';
import 'package:shop/menupage.dart';
import 'package:shop/pdfpage.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.initDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Billing System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
          secondary: Colors.orange,
        ),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: MainPage(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final double price;
  final int serialNumber;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.serialNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'serialNumber': serialNumber,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      serialNumber: map['serialNumber'],
    );
  }
}

class BillItem {
  final Product product;
  double weight; // in grams
  double get totalPrice =>
      product.price *
      (weight / 1000); // Convert grams to kg for price calculation

  BillItem({
    required this.product,
    this.weight = 1000, // Default weight is 1kg (1000g)
  });
}

class Bill {
  final int id;
  final DateTime date;
  final List<BillItem> items;
  final double total;
  final double tax;
  final double grandTotal;

  Bill({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.tax,
    required this.grandTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'total': total,
      'tax': tax,
      'grandTotal': grandTotal,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map, List<BillItem> items) {
    return Bill(
      id: map['id'],
      date: DateTime.parse(map['date']),
      items: items,
      total: map['total'],
      tax: map['tax'],
      grandTotal: map['grandTotal'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    // For desktop apps, use a fixed path relative to current directory
    String dbPath;
    if (Platform.isWindows) {
      dbPath = 'shop.db';
    } else if (Platform.isLinux || Platform.isMacOS) {
      final homeDir = Platform.environment['HOME'];
      dbPath = homeDir != null ? '$homeDir/shop.db' : 'shop.db';
    } else {
      // For mobile platforms
      dbPath = 'shop.db';
    }

    return await openDatabase(
      dbPath,
      version: 2, // Incremented version number for schema change
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Added onUpgrade callback
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      serialNumber INTEGER NOT NULL UNIQUE
    )
  ''');

    await db.execute('''
    CREATE TABLE bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      total REAL NOT NULL,
      tax REAL NOT NULL,
      grandTotal REAL NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE bill_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      billId INTEGER NOT NULL,
      productId INTEGER NOT NULL,
      weight REAL NOT NULL,  /* Changed from quantity to weight */
      price REAL NOT NULL,
      FOREIGN KEY (billId) REFERENCES bills(id),
      FOREIGN KEY (productId) REFERENCES products(id)
    )
  ''');
  }

  // Add this new method to handle database upgrades
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from version 1 to 2
      await db.execute('''
        CREATE TABLE bill_items_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          billId INTEGER NOT NULL,
          productId INTEGER NOT NULL,
          weight REAL NOT NULL,
          price REAL NOT NULL,
          FOREIGN KEY (billId) REFERENCES bills(id),
          FOREIGN KEY (productId) REFERENCES products(id)
        )
      ''');

      // Copy data from old table to new table
      await db.execute('''
        INSERT INTO bill_items_new (id, billId, productId, weight, price)
        SELECT id, billId, productId, quantity * 1000, price FROM bill_items
      ''');

      // Drop old table
      await db.execute('DROP TABLE bill_items');

      // Rename new table
      await db.execute('ALTER TABLE bill_items_new RENAME TO bill_items');
    }
  }

  // Product operations
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', {
      'name': product.name,
      'price': product.price,
      'serialNumber': product.serialNumber,
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product(
        id: maps[i]['id'],
        name: maps[i]['name'],
        price: maps[i]['price'],
        serialNumber: maps[i]['serialNumber'],
      );
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Product?> getProductBySerialNumber(int serialNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'serialNumber = ?',
      whereArgs: [serialNumber],
    );

    if (maps.isNotEmpty) {
      return Product(
        id: maps[0]['id'],
        name: maps[0]['name'],
        price: maps[0]['price'],
        serialNumber: maps[0]['serialNumber'],
      );
    }
    return null;
  }

  Future<int> saveBill(Bill bill, List<BillItem> items) async {
    final db = await database;
    final billId = await db.insert('bills', {
      'date': bill.date.toIso8601String(),
      'total': bill.total,
      'tax': bill.tax,
      'grandTotal': bill.grandTotal,
    });

    // Insert bill items with weight
    for (var item in items) {
      await db.insert('bill_items', {
        'billId': billId,
        'productId': item.product.id,
        'weight': item.weight, // Store weight in grams
        'price': item.totalPrice,
      });
    }

    return billId;
  }

  Future<List<Bill>> getBills() async {
    final db = await database;
    final List<Map<String, dynamic>> billMaps = await db.query('bills');

    return Future.wait(billMaps.map((billMap) async {
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'bill_items',
        where: 'billId = ?',
        whereArgs: [billMap['id']],
      );

      List<BillItem> items = [];
      for (var itemMap in itemMaps) {
        final productMap = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [itemMap['productId']],
        );

        if (productMap.isNotEmpty) {
          final product = Product.fromMap(productMap.first);
          items.add(BillItem(
            product: product,
            weight: itemMap['weight'], // Now using weight directly
          ));
        }
      }

      return Bill.fromMap(billMap, items);
    }).toList());
  }
}

// Main Page where items can be selected for billing
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<Product> _products = [];
  List<BillItem> _currentBill = [];
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = products;
    });
  }

  void _incrementQuantity(int index) {
    setState(() {
      _currentBill[index].weight += 100; // Increase by 100g
    });
  }

  void _decrementQuantity(int index) {
    if (_currentBill[index].weight > 100) {
      setState(() {
        _currentBill[index].weight -= 100; // Decrease by 100g
      });
    } else {
      _removeItemFromBill(index);
    }
  }

  void _addProductToCurrentBill(Product product) {
    bool found = false;
    for (var i = 0; i < _currentBill.length; i++) {
      if (_currentBill[i].product.id == product.id) {
        // For weight-based items, we'll show a dialog to input new weight instead of incrementing
        _showWeightInputDialog(i);
        found = true;
        break;
      }
    }

    if (!found) {
      // Add new product with default weight and immediately show dialog to adjust
      setState(() {
        _currentBill.add(BillItem(product: product));
      });
      _showWeightInputDialog(_currentBill.length - 1);
    }

    // Show confirmation animation
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to bill'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showWeightInputDialog(int index) {
    final weightController = TextEditingController(
        text: _currentBill[index].weight.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Enter weight for ${_currentBill[index].product.name} in grams:'),
            SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Weight (g)',
                border: OutlineInputBorder(),
                suffixText: 'g',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final newWeight = double.parse(weightController.text);
                if (newWeight > 0) {
                  setState(() {
                    _currentBill[index].weight = newWeight;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Weight must be greater than 0'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid number'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _removeItemFromBill(int index) {
    final productName = _currentBill[index].product.name;
    setState(() {
      _currentBill.removeAt(index);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$productName removed from bill'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
  }

  double _calculateTotal() {
    double total = 0;
    for (var item in _currentBill) {
      total += item.totalPrice;
    }
    return total;
  }

  void _searchBySerialNumber() async {
    if (_serialNumberController.text.isNotEmpty) {
      try {
        final serialNumber = int.parse(_serialNumberController.text);
        final product = await DatabaseHelper.instance
            .getProductBySerialNumber(serialNumber);
        if (product != null) {
          _addProductToCurrentBill(product);
          _serialNumberController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product not found'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid serial number'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _finalizeBill() async {
    if (_currentBill.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items in the bill'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final total = _calculateTotal();
    final tax = total * 0.00; // Assuming 18% tax
    final grandTotal = total + tax;

    final bill = Bill(
      id: DateTime.now().millisecondsSinceEpoch, // Unique ID
      date: DateTime.now(),
      items: _currentBill,
      total: total,
      tax: tax,
      grandTotal: grandTotal,
    );

    await DatabaseHelper.instance.saveBill(bill, _currentBill);

    setState(() {
      _currentBill = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Bill saved successfully'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BillDisplayPage(bill: bill)),
    );
  }

  List<Product> get filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }

    final query = _searchQuery.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.serialNumber.toString().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLargeScreen = screenSize.width > 1200;
    final bool isMediumScreen =
        screenSize.width <= 1200 && screenSize.width >= 800;

    // Determine grid columns based on screen width
    int gridColumns = 4;
    if (isLargeScreen) {
      gridColumns = 4;
    } else if (isMediumScreen) {
      gridColumns = 3;
    } else {
      gridColumns = 2;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_cart, size: 28),
            SizedBox(width: 10),
            Text('Billing System'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Add new product',
            child: IconButton(
              icon: Icon(Icons.add_circle, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MenuPage()),
                ).then((_) => _loadProducts());
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.analytics),
            tooltip: 'View analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AnalyticsPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.money_off_rounded),
            tooltip: 'Expense Tracker',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ExpenseTrackerPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.history),
            tooltip: 'View sales history',
            onPressed: () {
              // Implement view sales history
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sales history feature coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Row(
          children: [
            // Product selection area (left side)
            Expanded(
              flex: isLargeScreen ? 3 : 2,
              child: Card(
                color: Colors.white,
                margin: EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Products',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${filteredProducts.length} items',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          // Product search
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Search Products',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          // Serial number search
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _serialNumberController,
                              decoration: InputDecoration(
                                labelText: 'Serial Number',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.qr_code_scanner),
                                  tooltip: 'Scan barcode',
                                  onPressed: () {
                                    // Implement barcode scanning
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Barcode scanning feature coming soon'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 12),
                              ),
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _searchBySerialNumber(),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _searchBySerialNumber,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Search'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No products found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => MenuPage()),
                                      ).then((_) => _loadProducts());
                                    },
                                    icon: Icon(Icons.add),
                                    label: Text('Add Products'),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridColumns,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return InkWell(
                                  onTap: () =>
                                      _addProductToCurrentBill(product),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                product.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'SN: ${product.serialNumber}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '₹${product.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Current bill area (right side)
            Expanded(
              flex: isLargeScreen ? 2 : 3,
              child: Card(
                color: Colors.white,
                margin: EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Current Bill',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentBill.length} items',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                        child: _currentBill.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No items in the bill',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Click on a product to add it to the bill',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.all(16),
                                itemCount: _currentBill.length,
                                separatorBuilder: (context, index) =>
                                    Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _currentBill[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.product.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'SN: ${item.product.serialNumber}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '₹${item.product.price.toStringAsFixed(2)}/kg',
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey.shade300),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () =>
                                                      _decrementQuantity(index),
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    bottomLeft:
                                                        Radius.circular(8),
                                                  ),
                                                  child: Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(8),
                                                        bottomLeft:
                                                            Radius.circular(8),
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.remove,
                                                      size: 16,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () =>
                                                        _showWeightInputDialog(
                                                            index),
                                                    child: Container(
                                                      alignment:
                                                          Alignment.center,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8),
                                                      child: Text(
                                                        '${item.weight.toStringAsFixed(0)}g',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () =>
                                                      _incrementQuantity(index),
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topRight:
                                                        Radius.circular(8),
                                                    bottomRight:
                                                        Radius.circular(8),
                                                  ),
                                                  child: Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.only(
                                                        topRight:
                                                            Radius.circular(8),
                                                        bottomRight:
                                                            Radius.circular(8),
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.add,
                                                      size: 16,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '₹${item.totalPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _removeItemFromBill(index),
                                          tooltip: 'Remove item',
                                          splashRadius: 24,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            offset: Offset(0, -2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Summary
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal:',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      '₹${_calculateTotal().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tax (0%):',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      '₹${(_calculateTotal() * 0.00).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Divider(),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Grand Total:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹${(_calculateTotal() * 1.0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _currentBill = [];
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Bill cleared'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.delete_outline),
                                  label: Text('Clear Bill'),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    side:
                                        BorderSide(color: Colors.grey.shade400),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _currentBill.isEmpty
                                      ? null
                                      : _finalizeBill,
                                  icon: Icon(Icons.receipt_long),
                                  label: Text('Finalize Bill'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Additional responsive features could be implemented
// For MenuPage which would need similar responsive treatment
class CashierDashboard extends StatelessWidget {
  const CashierDashboard({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLargeScreen = screenSize.width > 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cashier Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: isLargeScreen ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDashboardCard(
              context,
              'New Sale',
              Icons.shopping_cart,
              Colors.blue,
              () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => MainPage()),
              ),
            ),
            _buildDashboardCard(
              context,
              'Products',
              Icons.inventory,
              Colors.green,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => MenuPage()),
              ),
            ),
            _buildDashboardCard(
              context,
              'Sales History',
              Icons.history,
              Colors.purple,
              () {
                // Navigate to sales history
              },
            ),
            _buildDashboardCard(
              context,
              'Reports',
              Icons.bar_chart,
              Colors.orange,
              () {
                // Navigate to reports
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: color,
              ),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for responsive sizing
class ResponsiveSize {
  static double getWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double getHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200;
  }

  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <= 1200 &&
        MediaQuery.of(context).size.width >= 800;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 800;
  }
}
