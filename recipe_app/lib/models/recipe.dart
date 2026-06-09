class Ingredient {
  final String? amount;
  final String? unit;
  final String item;
  final String? note;

  const Ingredient({
    this.amount,
    this.unit,
    required this.item,
    this.note,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        amount: json['amount'] as String?,
        unit: json['unit'] as String?,
        item: json['item'] as String? ?? '',
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (unit != null) 'unit': unit,
        'item': item,
        if (note != null) 'note': note,
      };

  String get display {
    final parts = <String>[
      if (amount != null) amount!,
      if (unit != null) unit!,
      item,
      if (note != null) '(${note!})',
    ];
    return parts.join(' ');
  }
}

class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? category;
  final List<String> tags;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? totalTimeMinutes;
  final int? servings;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.name,
    this.description,
    this.sourceUrl,
    this.sourcePlatform,
    this.category,
    this.tags = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.servings,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sourceUrl: json['source_url'] as String?,
        sourcePlatform: json['source_platform'] as String?,
        category: json['category'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? [],
        prepTimeMinutes: json['prep_time_minutes'] as int?,
        cookTimeMinutes: json['cook_time_minutes'] as int?,
        totalTimeMinutes: json['total_time_minutes'] as int?,
        servings: json['servings'] as int?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (sourcePlatform != null) 'source_platform': sourcePlatform,
        if (category != null) 'category': category,
        'tags': tags,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
        if (cookTimeMinutes != null) 'cook_time_minutes': cookTimeMinutes,
        if (totalTimeMinutes != null) 'total_time_minutes': totalTimeMinutes,
        if (servings != null) 'servings': servings,
        if (imageUrl != null) 'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get timeDisplay {
    final total = totalTimeMinutes ?? (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);
    if (total == 0) return '';
    if (total < 60) return '${total}min';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}

// Used for creating/editing — no id/timestamps
class RecipeInput {
  String name;
  String? description;
  String? sourceUrl;
  String? sourcePlatform;
  String? category;
  List<String> tags;
  List<Ingredient> ingredients;
  List<String> steps;
  int? prepTimeMinutes;
  int? cookTimeMinutes;
  int? totalTimeMinutes;
  int? servings;
  String? imageUrl;

  RecipeInput({
    required this.name,
    this.description,
    this.sourceUrl,
    this.sourcePlatform,
    this.category,
    this.tags = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.totalTimeMinutes,
    this.servings,
    this.imageUrl,
  });

  factory RecipeInput.fromJson(Map<String, dynamic> json) => RecipeInput(
        name: json['name'] as String? ?? 'Untitled',
        description: json['description'] as String?,
        sourceUrl: json['source_url'] as String?,
        sourcePlatform: json['source_platform'] as String?,
        category: json['category'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? [],
        prepTimeMinutes: json['prep_time_minutes'] as int?,
        cookTimeMinutes: json['cook_time_minutes'] as int?,
        totalTimeMinutes: json['total_time_minutes'] as int?,
        servings: json['servings'] as int?,
        imageUrl: json['image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (sourcePlatform != null) 'source_platform': sourcePlatform,
        if (category != null) 'category': category,
        'tags': tags,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
        if (cookTimeMinutes != null) 'cook_time_minutes': cookTimeMinutes,
        if (totalTimeMinutes != null) 'total_time_minutes': totalTimeMinutes,
        if (servings != null) 'servings': servings,
        if (imageUrl != null) 'image_url': imageUrl,
      };
}
