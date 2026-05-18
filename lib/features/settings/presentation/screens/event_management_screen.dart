import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/settings/data/models/event_model.dart';
import 'package:flutter_app_demo/features/settings/data/services/event_service.dart';

class EventManagementScreen extends StatefulWidget {
  final String coupleId;

  const EventManagementScreen({super.key, required this.coupleId});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final _service = EventService();
  List<EventModel> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }

    try {
      final events = await _service.getEvents(widget.coupleId);
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEventDialog({EventModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime endDate = existing?.endDate ?? DateTime.now().add(const Duration(days: 7));
    bool isActive = existing?.isActive ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Thêm sự kiện mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên sự kiện',
                      hintText: 'Ví dụ: Du lịch Phú Quốc',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Ngày bắt đầu'),
                    subtitle: Text(formatDate(startDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Ngày kết thúc'),
                    subtitle: Text(formatDate(endDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    title: const Text('Kích hoạt hoạt động'),
                    subtitle: const Text('Nếu tắt, sự kiện sẽ luôn không hoạt động'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).maybePop(false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Tên sự kiện không được để trống.')),
                    );
                    return;
                  }
                  if (endDate.isBefore(startDate)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Ngày kết thúc phải sau ngày bắt đầu.')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).maybePop(true);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();

    try {
      if (existing == null) {
        await _service.createEvent(
          coupleId: widget.coupleId,
          name: name,
          startDate: startDate,
          endDate: endDate,
          isActive: isActive,
        );
      } else {
        await _service.updateEvent(
          eventId: existing.id,
          name: name,
          startDate: startDate,
          endDate: endDate,
          isActive: isActive,
        );
      }
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu sự kiện: $e')));
    }
  }

  Future<void> _deleteEvent(EventModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá sự kiện'),
        content: Text('Xác nhận xoá sự kiện "${item.name}"?\n(Các giao dịch đã gắn thẻ sự kiện này sẽ bị gỡ thẻ).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteEvent(item.id);
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xoá sự kiện: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sự kiện'),
        actions: [
          IconButton(
            onPressed: () => _load(showLoader: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _load(showLoader: true),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_note, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Chưa có sự kiện nào.'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _openEventDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo sự kiện đầu tiên'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final item = _events[index];
                        final active = item.isCurrentlyActive(today);
                        final pastEnd = DateTime(today.year, today.month, today.day)
                            .isAfter(DateTime(item.endDate.year, item.endDate.month, item.endDate.day));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? AppColors.successSoft
                                            : pastEnd
                                                ? Colors.grey.shade100
                                                : AppColors.warningSoft,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        active
                                            ? 'Đang diễn ra'
                                            : pastEnd
                                                ? 'Hết hạn'
                                                : 'Không hoạt động',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AppColors.success
                                              : pastEnd
                                                  ? Colors.black54
                                                  : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${formatDate(item.startDate)} - ${formatDate(item.endDate)}',
                                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Switch(
                                      value: item.isActive,
                                      activeTrackColor: AppColors.tealDeep.withValues(alpha: 0.5),
                                      activeColor: AppColors.tealDeep,
                                      onChanged: (v) async {
                                        try {
                                          await _service.updateEvent(
                                            eventId: item.id,
                                            name: item.name,
                                            startDate: item.startDate,
                                            endDate: item.endDate,
                                            isActive: v,
                                          );
                                          _load(showLoader: false);
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Lỗi toggle: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    const Text(
                                      'Kích hoạt',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                                      onPressed: () => _openEventDialog(existing: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteEvent(item),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
