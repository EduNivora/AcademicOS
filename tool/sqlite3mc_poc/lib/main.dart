import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  runApp(const Sqlite3McProofApp());
}

class Sqlite3McProofApp extends StatelessWidget {
  const Sqlite3McProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('SQLite3MC isolated native proof only'),
        ),
      ),
    );
  }
}
