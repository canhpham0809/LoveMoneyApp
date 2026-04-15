import 'package:flutter/material.dart';
import 'package:flutter_app_demo/features/services/transaction_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.initialTransaction,
  });

  final Map<String, dynamic>? initialTransaction;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final noteController = TextEditingController();
  final service = TransactionService();

  String type = 'expense';
  bool isSaving = false;

  bool get isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    if (tx == null) return;

    final amount = (tx['amount'] as num?)?.toDouble();
    amountController.text = amount?.toString() ?? '';
    categoryController.text = (tx['category'] ?? '').toString();
    noteController.text = (tx['note'] ?? '').toString();

    final initialType = (tx['type'] ?? 'expense').toString();
    type = initialType == 'income' ? 'income' : 'expense';
  }

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> saveTransaction() async {
    if (isSaving) return;

    final amount = double.tryParse(amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final payload = {
        'amount': amount,
        'type': type,
        'category': categoryController.text.trim(),
        'note': noteController.text.trim(),
      };

      if (isEditing) {
        final id = widget.initialTransaction!['id'];
        await service.updateTransaction(id, payload);
      } else {
        await service.addTransaction(payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save transaction.')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  String get pageTitle => isEditing ? 'Edit Transaction' : 'Add Transaction';

  String get buttonText => isEditing ? 'Update Transaction' : 'Save Transaction';

  String get savingText => isEditing ? 'Updating...' : 'Saving...';

  String get helperText {
    if (isEditing) {
      return 'Update details and save changes.';
    }
    return 'Fill details for your new transaction.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              helperText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSaving ? null : saveTransaction,
              child: Text(isSaving ? savingText : buttonText),
            ),
          ],
        ),
      ),
    );
  }
}