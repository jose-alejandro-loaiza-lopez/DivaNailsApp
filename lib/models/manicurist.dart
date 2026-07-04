class Manicurist {
  final int? id;
  final String name;
  final double profitPercentage;

  Manicurist({
    this.id,
    required this.name,
    this.profitPercentage = 40.0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'profit_percentage': profitPercentage,
    };
  }

  factory Manicurist.fromMap(Map<String, dynamic> map) {
    return Manicurist(
      id: map['id'] as int?,
      name: map['name'] as String,
      profitPercentage: (map['profit_percentage'] as num?)?.toDouble() ?? 40.0,
    );
  }

  Manicurist copyWith({int? id, String? name, double? profitPercentage}) {
    return Manicurist(
      id: id ?? this.id,
      name: name ?? this.name,
      profitPercentage: profitPercentage ?? this.profitPercentage,
    );
  }
}
