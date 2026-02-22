class Barber {
  final String id;
  final String name;
  final String dayOff;
  final bool isActive;
  final bool isAbsent;

  Barber({
    required this.id, 
    required this.name, 
    required this.dayOff, 
    this.isActive = true,
    this.isAbsent = false,
  });

  factory Barber.fromMap(Map<String, dynamic> map) {
    return Barber(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      dayOff: map['day_off'] ?? 'Monday',
      isActive: map['is_active'] ?? true,
      isAbsent: map['is_absent'] ?? false,
    );
  }
}