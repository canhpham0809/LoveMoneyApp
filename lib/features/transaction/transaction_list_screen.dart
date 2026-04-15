import 'package:flutter/material.dart';
import 'package:flutter_app_demo/features/services/transaction_service.dart';
import 'package:flutter_app_demo/features/transaction/add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final service = TransactionService();
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  String? errorMessage;
  double balance = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool showSkeleton = true}) async {
    if (showSkeleton) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final res = await service.getTransactions();
      final loaded = res.cast<Map<String, dynamic>>();

      double newBalance = 0;
      for (final tx in loaded) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
        final type = (tx['type'] ?? '').toString();
        newBalance += type == 'income' ? amount : -amount;
      }

      if (!mounted) return;
      setState(() {
        transactions = loaded;
        balance = newBalance;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted && showSkeleton) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions(showSkeleton: false);
  }

  Future<void> _goToCreateScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );

    if (!mounted) return;
    if (created == true) {
      await _loadTransactions(showSkeleton: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction created.')),
      );
    }
  }

  Future<void> _goToEditScreen(Map<String, dynamic> tx) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialTransaction: tx),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      await _loadTransactions(showSkeleton: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated.')),
      );
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final id = tx['id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: missing transaction id.')),
      );
      return;
    }

    try {
      await service.deleteTransaction(id);
      if (!mounted) return;
      await _loadTransactions(showSkeleton: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete transaction.')),
      );
    }
  }

  Future<void> _showDeleteConfirm(Map<String, dynamic> tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Do you want to delete this transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteTransaction(tx);
    }
  }

  Widget _buildBalanceCard(BuildContext context) {
    final isPositive = balance >= 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isPositive ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                isPositive ? Icons.account_balance_wallet : Icons.warning_amber,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Balance'),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : '-'}${balance.abs().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, index) => const Divider(height: 0),
      itemBuilder: (_, index) {
        return const ListTile(
          leading: CircleAvatar(backgroundColor: Color(0xFFE0E0E0)),
          title: _SkeletonBox(width: 120, height: 12),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 8),
            child: _SkeletonBox(width: 180, height: 10),
          ),
          trailing: _SkeletonBox(width: 64, height: 12),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(Icons.wifi_off, size: 56, color: Colors.red.shade300),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Failed to load transactions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: _loadTransactions,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.receipt_long, size: 54, color: Colors.black26),
          SizedBox(height: 12),
          Center(child: Text('No transactions yet')),
          SizedBox(height: 4),
          Center(child: Text('Tap Create to add your first transaction.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
        final type = (tx['type'] ?? '').toString();
        final category = (tx['category'] ?? '').toString();
        final note = (tx['note'] ?? '').toString();

        return ListTile(
          onTap: () => _goToEditScreen(tx),
          leading: CircleAvatar(
            backgroundColor:
                type == 'income' ? Colors.green.shade100 : Colors.red.shade100,
            child: Icon(
              type == 'income' ? Icons.trending_up : Icons.trending_down,
              color: type == 'income' ? Colors.green : Colors.red,
            ),
          ),
          title: Text(category.isEmpty ? 'Uncategorized' : category),
          subtitle: Text(note.isEmpty ? 'No note' : note),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${type == 'income' ? '+' : '-'}${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: type == 'income' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _goToEditScreen(tx);
                  }
                  if (value == 'delete') {
                    await _showDeleteConfirm(tx);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildBalanceCard(context)),
            if (isLoading)
              SliverFillRemaining(child: _buildSkeletonList())
            else if (errorMessage != null)
              SliverFillRemaining(child: _buildErrorView())
            else
              SliverFillRemaining(child: _buildTransactionList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreateScreen,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
