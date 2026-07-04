class Service {
  final int? id;
  final String name;
  final double price;

  Service({this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }

  Service copyWith({int? id, String? name, double? price}) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}
