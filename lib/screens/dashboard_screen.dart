import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/invoice.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onAddClient;

  const DashboardScreen({super.key, this.onAddClient});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String get _currentPeriod => DateFormat('yyyy-MM').format(DateTime.now());

  Future<_DashboardData> _load() async {
    final invoiceRows = await supabase
        .from('invoices')
        .select('*, clients(name)')
        .eq('period', _currentPeriod)
        .order('due_date');
    final invoices = (invoiceRows as List)
        .map((row) => _InvoiceWithClient(
              invoice: Invoice.fromMap(row),
              clientName: row['clients']?['name'] as String? ?? 'Unknown',
            ))
        .toList();
    return _DashboardData(invoices: invoices);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _generateThisMonthInvoices() async {
    final clients = await supabase
        .from('clients')
        .select('id')
        .eq('status', 'active');
    final period = _currentPeriod;
    final now = DateTime.now();
    final dueDate = DateTime(now.year, now.month, 15);
    for (final client in clients as List) {
      await supabase.from('invoices').upsert({
        'client_id': client['id'],
        'period': period,
        'amount': 1000,
        'due_date': dueDate.toIso8601String().split('T').first,
        'status': 'unpaid',
      }, onConflict: 'client_id,period', ignoreDuplicates: true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invoices generated for this month.')));
    }
    _refresh();
  }

  Future<void> _markPaid(Invoice invoice) async {
    await supabase.from('invoices').update({
      'status': 'paid',
      'paid_date': DateTime.now().toIso8601String().split('T').first,
    }).eq('id', invoice.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Add client',
            onPressed: widget.onAddClient,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateThisMonthInvoices,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Generate this month'),
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoices = snapshot.data!.invoices;
          if (invoices.isEmpty) {
            return const Center(child: Text('No invoices for this month yet.'));
          }
          final overdue = invoices.where((i) => i.invoice.isOverdue).length;
          final unpaid = invoices.where((i) => !i.invoice.isPaid && !i.invoice.isOverdue).length;
          final paid = invoices.where((i) => i.invoice.isPaid).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _SummaryChip(label: 'Overdue', count: overdue, color: Colors.red),
                      const SizedBox(width: 8),
                      _SummaryChip(label: 'Due', count: unpaid, color: Colors.orange),
                      const SizedBox(width: 8),
                      _SummaryChip(label: 'Paid', count: paid, color: Colors.green),
                    ],
                  ),
                ),
                for (final item in invoices)
                  ListTile(
                    title: Text(item.clientName),
                    subtitle: Text(
                        'Due ${DateFormat.yMMMd().format(item.invoice.dueDate)} · ₱${item.invoice.amount.toStringAsFixed(0)}'),
                    trailing: item.invoice.isPaid
                        ? const Chip(label: Text('Paid'), backgroundColor: Color(0xFFDFF5E1))
                        : FilledButton(
                            onPressed: () => _markPaid(item.invoice),
                            child: const Text('Mark paid'),
                          ),
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color: item.invoice.isPaid
                          ? Colors.green
                          : (item.invoice.isOverdue ? Colors.red : Colors.orange),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _DashboardData {
  final List<_InvoiceWithClient> invoices;
  _DashboardData({required this.invoices});
}

class _InvoiceWithClient {
  final Invoice invoice;
  final String clientName;
  _InvoiceWithClient({required this.invoice, required this.clientName});
}
