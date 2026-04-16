import 'package:flutter/material.dart';

class AddDebtScreen extends StatefulWidget {
  final String coupleId;

  const AddDebtScreen({super.key, required this.coupleId});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  late TextEditingController nameController;
  late TextEditingController amountController;
  late TextEditingController creditorController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    amountController = TextEditingController();
    creditorController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    creditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Debt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Debt Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: creditorController,
              decoration: const InputDecoration(
                labelText: 'Creditor Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                // Save debt
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

