class Invoice {
  final String id;
  final String clientId;
  final String period;
  final double amount;
  final DateTime dueDate;
  final String status;
  final DateTime? paidDate;

  Invoice({
    required this.id,
    required this.clientId,
    required this.period,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidDate,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
        id: map['id'] as String,
        clientId: map['client_id'] as String,
        period: map['period'] as String,
        amount: (map['amount'] as num).toDouble(),
        dueDate: DateTime.parse(map['due_date'] as String),
        status: map['status'] as String,
        paidDate: map['paid_date'] == null
            ? null
            : DateTime.parse(map['paid_date'] as String),
      );

  bool get isPaid => status == 'paid';
  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());
}
