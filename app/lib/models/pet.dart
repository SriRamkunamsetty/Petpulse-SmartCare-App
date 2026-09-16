class Pet {
  final String name;
  final String breed;
  final int ageValue;
  final String ageUnit; // 'yrs' | 'mos'
  final int weightValue;
  final String weightUnit; // 'kg' | 'lb'
  final List<String> healthConditions;
  final String notes;

  const Pet({
    required this.name,
    required this.breed,
    required this.ageValue,
    required this.ageUnit,
    required this.weightValue,
    required this.weightUnit,
    required this.healthConditions,
    required this.notes,
  });

  static const empty = Pet(
    name: '',
    breed: '',
    ageValue: 2,
    ageUnit: 'yrs',
    weightValue: 12,
    weightUnit: 'kg',
    healthConditions: [],
    notes: '',
  );

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  String get breedWeightLine => '$breed · $weightValue$weightUnit';

  String get healthSummary =>
      healthConditions.isEmpty ? 'None reported' : healthConditions.join(', ');

  Pet copyWith({
    String? name,
    String? breed,
    int? ageValue,
    String? ageUnit,
    int? weightValue,
    String? weightUnit,
    List<String>? healthConditions,
    String? notes,
  }) {
    return Pet(
      name: name ?? this.name,
      breed: breed ?? this.breed,
      ageValue: ageValue ?? this.ageValue,
      ageUnit: ageUnit ?? this.ageUnit,
      weightValue: weightValue ?? this.weightValue,
      weightUnit: weightUnit ?? this.weightUnit,
      healthConditions: healthConditions ?? this.healthConditions,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'breed': breed,
        'age_value': ageValue,
        'age_unit': ageUnit,
        'weight_value': weightValue,
        'weight_unit': weightUnit,
        'health_conditions': healthConditions,
        'notes': notes,
      };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        name: json['name'] as String? ?? '',
        breed: json['breed'] as String? ?? '',
        ageValue: (json['age_value'] as num?)?.toInt() ?? 2,
        ageUnit: json['age_unit'] as String? ?? 'yrs',
        weightValue: (json['weight_value'] as num?)?.toInt() ?? 12,
        weightUnit: json['weight_unit'] as String? ?? 'kg',
        healthConditions:
            (json['health_conditions'] as List?)?.cast<String>() ?? [],
        notes: json['notes'] as String? ?? '',
      );
}
