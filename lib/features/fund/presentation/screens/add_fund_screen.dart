import 'package:flutter/material.dart';

class AddFundScreen extends StatefulWidget {
  final String coupleId;

  const AddFundScreen({super.key, required this.coupleId});

  @override
  State<AddFundScreen> createState() => _AddFundScreenState();
}

class _AddFundScreenState extends State<AddFundScreen> {
  late TextEditingController nameController;
  late TextEditingController targetAmountController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    targetAmountController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Fund')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Fund Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: targetAmountController,
              decoration: const InputDecoration(
                labelText: 'Target Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                // Save fund
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

