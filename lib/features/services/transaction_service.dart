import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
  final supabase = Supabase.instance.client;

  Future<void> addTransaction(Map<String, dynamic> data) async {
    await supabase.from('transactions').insert(data);
  }

  Future<List<dynamic>> getTransactions() async {
    final res = await supabase
        .from('transactions')
        .select()
        .order('created_at', ascending: false);

    return res;
  }

  Future<void> updateTransaction(dynamic id, Map<String, dynamic> data) async {
    await supabase.from('transactions').update(data).eq('id', id);
  }

  Future<void> deleteTransaction(dynamic id) async {
    await supabase.from('transactions').delete().eq('id', id);
  }
}
