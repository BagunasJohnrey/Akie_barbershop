class Expense {
  final String id;
  final int amount;
  final String category;
  final String description;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: map['amount'],
      category: map['category'],
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}