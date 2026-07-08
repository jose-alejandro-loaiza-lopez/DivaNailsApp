class Client {
  final int? id;
  final String phone;
  final String name;
  final String lastName;
  final int? birthDay;
  final int? birthMonth;
  final String location;

  Client({
    this.id,
    this.phone = '',
    required this.name,
    this.lastName = '',
    this.birthDay,
    this.birthMonth,
    this.location = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'phone': phone,
      'name': name,
      'last_name': lastName,
      'birth_day': birthDay,
      'birth_month': birthMonth,
      'location': location,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      phone: (map['phone'] as String?) ?? '',
      name: map['name'] as String,
      lastName: map['last_name'] as String? ?? '',
      birthDay: map['birth_day'] as int?,
      birthMonth: map['birth_month'] as int?,
      location: map['location'] as String? ?? '',
    );
  }

  Client copyWith({
    int? id,
    String? phone,
    String? name,
    String? lastName,
    int? birthDay,
    int? birthMonth,
    String? location,
  }) {
    return Client(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      birthDay: birthDay ?? this.birthDay,
      birthMonth: birthMonth ?? this.birthMonth,
      location: location ?? this.location,
    );
  }

  String get fullName => lastName.isNotEmpty ? '$name $lastName' : name;

  String get birthDisplay {
    if (birthDay == null || birthMonth == null) return '';
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final m = birthMonth! >= 1 && birthMonth! <= 12 ? months[birthMonth! - 1] : '?';
    return '$birthDay $m';
  }
}
