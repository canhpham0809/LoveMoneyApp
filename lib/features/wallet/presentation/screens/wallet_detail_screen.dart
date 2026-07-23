import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/wallet/data/models/wallet_model.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class WalletDetailScreen extends StatefulWidget {
  final WalletModel wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  final _service = WalletService();
  late WalletModel _wallet;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
  }

  void _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final wallets = await _service.getWallets(_wallet.coupleId);
      final current = wallets.firstWhere((w) => w.id == _wallet.id);
      if (mounted) {
        setState(() {
          _wallet = current;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGoldTypeName(String code) {
    switch (code) {
      case 'SJ9999':
        return 'SJC Nhẫn Trơn (24K)';
      case 'SJL1L10':
        return 'SJC Vàng Miếng 9999';
      case 'PQHN24NTT':
        return 'PNJ Nhẫn Trơn 24K';
      case 'DOHNL':
        return 'DOJI Nhẫn Trơn';
      default:
        return 'Tự nhập giá thủ công';
    }
  }

  Future<double?> _showManualPriceDialog({String? title, String? message}) {
    final ctrl = TextEditingController();
    final meta = _wallet.goldMetadata ?? {};
    if (meta['last_known_price'] != null) {
      ctrl.text = formatAmountInput((meta['last_known_price'] as num).toStringAsFixed(0));
    }
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title ?? 'Nhập giá vàng hiện tại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) ...[
              Text(message, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Giá vàng hiện tại (VND/1 chỉ)',
                border: OutlineInputBorder(),
              ),
            ),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(null),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseAmountInput(ctrl.text);
              Navigator.of(dialogContext).maybePop(parsed);
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshGoldPrice() async {
    setState(() => _isRefreshing = true);
    try {
      final meta = _wallet.goldMetadata ?? {};
      final goldType = meta['gold_type'] as String? ?? 'SJ9999';

      double newPricePerChi = 0;

      if (goldType == 'manual') {
        final double? price = await _showManualPriceDialog();
        if (price == null) {
          setState(() => _isRefreshing = false);
          return;
        }
        newPricePerChi = price;
      } else {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse('https://www.vang.today/api/prices'));
        final response = await request.close();
        
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final prices = data['prices'] as Map<String, dynamic>?;
          if (prices != null && prices[goldType] != null) {
            final typeData = prices[goldType] as Map<String, dynamic>;
            final buyPriceTael = (typeData['buy'] as num).toDouble();
            newPricePerChi = buyPriceTael / 10.0;
          } else {
            throw Exception('Không tìm thấy dữ liệu cho loại vàng này.');
          }
        } else {
          throw Exception('Lỗi kết nối API (Status: ${response.statusCode})');
        }
      }

      if (newPricePerChi > 0) {
        final double totalQty = (meta['total_quantity'] as num?)?.toDouble() ?? 0.0;
        final double newBalance = totalQty * newPricePerChi;

        final nextMeta = Map<String, dynamic>.from(meta);
        nextMeta['last_known_price'] = newPricePerChi;
        nextMeta['last_updated_price'] = DateTime.now().toUtc().toIso8601String();

        final Map<String, dynamic> updateData = {
          'balance': newBalance,
          'name': '[GOLD]${_wallet.name}|${jsonEncode(nextMeta)}',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        await _service.updateWallet(_wallet.id, updateData);
        _isModified = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cập nhật giá vàng thành công: ${formatVnd(newPricePerChi)}/chỉ')),
          );
          _loadWallet();
        }
      }
    } catch (e) {
      if (mounted) {
        final double? price = await _showManualPriceDialog(
          title: 'Lỗi tải giá vàng tự động',
          message: 'Không tải được giá vàng từ máy chủ ($e). Bạn có muốn tự nhập giá vàng hiện tại không?',
        );
        if (price != null && price > 0) {
          final meta = _wallet.goldMetadata ?? {};
          final double totalQty = (meta['total_quantity'] as num?)?.toDouble() ?? 0.0;
          final double newBalance = totalQty * price;

          final nextMeta = Map<String, dynamic>.from(meta);
          nextMeta['last_known_price'] = price;
          nextMeta['last_updated_price'] = DateTime.now().toUtc().toIso8601String();

          final Map<String, dynamic> updateData = {
            'balance': newBalance,
            'name': '[GOLD]${_wallet.name}|${jsonEncode(nextMeta)}',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };

          await _service.updateWallet(_wallet.id, updateData);
          _isModified = true;
          _loadWallet();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _showAddRoundDialog() async {
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final storeCtrl = TextEditingController();
    DateTime date = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm đợt mua vàng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng chỉ vàng (ví dụ: 1.0, 0.5)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Đơn giá mua 1 chỉ (VND)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cửa hàng mua',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Ngày mua'),
                  subtitle: Text('${date.day}/${date.month}/${date.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).maybePop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text.trim());
                final price = parseAmountInput(priceCtrl.text.trim());
                final store = storeCtrl.text.trim();
                if (qty == null || qty <= 0 || price == null || price <= 0 || store.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin hợp lệ.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).maybePop(true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final qty = double.parse(qtyCtrl.text.trim());
    final price = parseAmountInput(priceCtrl.text.trim())!;
    final store = storeCtrl.text.trim();

    setState(() => _isLoading = true);
    try {
      final meta = _wallet.goldMetadata ?? {};
      final List<dynamic> rounds = List<dynamic>.from(meta['rounds'] ?? []);

      final newRound = {
        'id': const Uuid().v4(),
        'quantity': qty,
        'unit_price': price,
        'total_price': qty * price,
        'store': store,
        'date': date.toIso8601String(),
      };
      rounds.add(newRound);

      double totalQty = 0;
      double purchaseCost = 0;
      for (final r in rounds) {
        totalQty += (r['quantity'] as num).toDouble();
        purchaseCost += (r['total_price'] as num).toDouble();
      }

      final double lastKnownPrice = (meta['last_known_price'] as num?)?.toDouble() ?? price;
      final double newBalance = totalQty * lastKnownPrice;

      final nextMeta = Map<String, dynamic>.from(meta);
      nextMeta['rounds'] = rounds;
      nextMeta['total_quantity'] = totalQty;
      nextMeta['purchase_cost'] = purchaseCost;
      nextMeta['last_known_price'] = lastKnownPrice;

      final Map<String, dynamic> updateData = {
        'balance': newBalance,
        'name': '[GOLD]${_wallet.name}|${jsonEncode(nextMeta)}',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _service.updateWallet(_wallet.id, updateData);
      _isModified = true;
      _loadWallet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm đợt mua: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRound(Map<String, dynamic> round) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa đợt mua ngày ${formatDate(DateTime.parse(round['date'] as String))} không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final meta = _wallet.goldMetadata ?? {};
      final List<dynamic> rounds = List<dynamic>.from(meta['rounds'] ?? []);
      rounds.removeWhere((r) => r['id'] == round['id']);

      double totalQty = 0;
      double purchaseCost = 0;
      for (final r in rounds) {
        totalQty += (r['quantity'] as num).toDouble();
        purchaseCost += (r['total_price'] as num).toDouble();
      }

      final double lastKnownPrice = (meta['last_known_price'] as num?)?.toDouble() ?? 0.0;
      final double newBalance = totalQty * lastKnownPrice;

      final nextMeta = Map<String, dynamic>.from(meta);
      nextMeta['rounds'] = rounds;
      nextMeta['total_quantity'] = totalQty;
      nextMeta['purchase_cost'] = purchaseCost;

      final Map<String, dynamic> updateData = {
        'balance': newBalance,
        'name': '[GOLD]${_wallet.name}|${jsonEncode(nextMeta)}',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _service.updateWallet(_wallet.id, updateData);
      _isModified = true;
      _loadWallet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa đợt mua: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ví vàng'),
        content: Text('Bạn có chắc muốn xóa ví "${_wallet.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.deleteWallet(_wallet.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa ví: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _wallet.goldMetadata ?? {};
    final List<dynamic> rounds = meta['rounds'] as List<dynamic>? ?? [];
    final double totalQty = (meta['total_quantity'] as num?)?.toDouble() ?? 0.0;
    final double purchaseCost = (meta['purchase_cost'] as num?)?.toDouble() ?? 0.0;
    final double lastKnownPrice = (meta['last_known_price'] as num?)?.toDouble() ?? 0.0;
    final double currentVal = _wallet.balance;
    final double profit = currentVal - purchaseCost;
    final double profitPct = purchaseCost > 0 ? (profit / purchaseCost) * 100 : 0.0;

    final String goldType = meta['gold_type'] as String? ?? 'SJ9999';
    final String lastUpdatedStr = meta['last_updated_price'] != null
        ? formatDateTime(DateTime.parse(meta['last_updated_price'] as String).toLocal())
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(_wallet.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _isModified),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Xóa ví',
            onPressed: _deleteWallet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshGoldPrice,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Golden/Amber Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TÀI SẢN VÀNG',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'VÀNG',
                                  style: GoogleFonts.roboto(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            formatVnd(currentVal),
                            style: GoogleFonts.roboto(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Số lượng',
                                    style: GoogleFonts.roboto(fontSize: 11, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalQty chỉ',
                                    style: GoogleFonts.roboto(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Giá trị mua',
                                    style: GoogleFonts.roboto(fontSize: 11, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatVnd(purchaseCost),
                                    style: GoogleFonts.roboto(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Lời / Lỗ',
                                    style: GoogleFonts.roboto(fontSize: 11, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${profit >= 0 ? '+' : ''}${formatVnd(profit)} (${profitPct.toStringAsFixed(2)}%)',
                                      style: GoogleFonts.roboto(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isRefreshing ? null : _refreshGoldPrice,
                            icon: _isRefreshing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: Text('Cập nhật giá', style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.tealDeep,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showAddRoundDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Thêm đợt mua', style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Market Meta Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Loại Vàng:', style: GoogleFonts.roboto(fontSize: 13, color: Colors.black54)),
                                Text(_getGoldTypeName(goldType), style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Giá thị trường:', style: GoogleFonts.roboto(fontSize: 13, color: Colors.black54)),
                                Text('${formatVnd(lastKnownPrice)}/chỉ', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber[800])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cập nhật lúc:', style: GoogleFonts.roboto(fontSize: 13, color: Colors.black54)),
                                Text(lastUpdatedStr, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title section
                    Text(
                      'LỊCH SỬ CÁC ĐỢT MUA',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Purchase Rounds List
                    if (rounds.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Chưa có đợt mua vàng nào.',
                              style: GoogleFonts.roboto(color: Colors.black45),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rounds.length,
                        itemBuilder: (context, index) {
                          final round = rounds[index] as Map<String, dynamic>;
                          final double qty = (round['quantity'] as num).toDouble();
                          final double price = (round['unit_price'] as num).toDouble();
                          final double total = (round['total_price'] as num).toDouble();
                          final String store = round['store'] as String? ?? 'N/A';
                          final DateTime buyDate = DateTime.parse(round['date'] as String);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$qty chỉ @ $store',
                                    style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    formatVnd(total),
                                    style: GoogleFonts.roboto(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.tealDeep),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đơn giá: ${formatVnd(price)}/chỉ',
                                      style: GoogleFonts.roboto(fontSize: 12, color: Colors.black54),
                                    ),
                                    Text(
                                      formatDate(buyDate),
                                      style: GoogleFonts.roboto(fontSize: 12, color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteRound(round),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
