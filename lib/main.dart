import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/transaction/transaction_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uaxbmxfsmhawtdjrifhm.supabase.co',
    anonKey: 'sb_publishable_LvW16OStM_gtP7Vkf92YXQ_EwXawd7e',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fintech App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const TransactionListScreen(),
    );
  }
}
