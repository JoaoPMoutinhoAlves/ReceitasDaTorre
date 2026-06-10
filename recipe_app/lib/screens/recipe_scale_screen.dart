import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

class RecipeScaleScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeScaleScreen({super.key, required this.recipe});

  @override
  State<RecipeScaleScreen> createState() => _RecipeScaleScreenState();
}

class _RecipeScaleScreenState extends State<RecipeScaleScreen> {
  late int _targetServings;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetServings = widget.recipe.servings ?? 1;
    _controller.text = '$_targetServings';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _scaleFactor {
    final original = widget.recipe.servings ?? 1;
    if (original == 0) return 1;
    return _targetServings / original;
  }

  void _adjust(int delta) {
    final next = _targetServings + delta;
    if (next < 1) return;
    setState(() {
      _targetServings = next;
      _controller.text = '$next';
    });
  }

  void _onTextChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 1) {
      setState(() => _targetServings = parsed);
    }
  }

  String _scaleAmount(String? amount) {
    if (amount == null || amount.isEmpty) return '';
    final parsed = _parseAmount(amount);
    if (parsed == null) return amount;
    final scaled = parsed * _scaleFactor;
    return _formatAmount(scaled);
  }

  double? _parseAmount(String s) {
    s = s.trim();
    // Unicode fractions
    final unicodeMap = {
      '½': 0.5, '⅓': 1 / 3, '⅔': 2 / 3, '¼': 0.25, '¾': 0.75,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 1 / 6, '⅚': 5 / 6, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
    };
    for (final entry in unicodeMap.entries) {
      if (s == entry.key) return entry.value;
      // e.g. "2½"
      if (s.endsWith(entry.key)) {
        final prefix = s.substring(0, s.length - entry.key.length).trim();
        final whole = double.tryParse(prefix);
        if (whole != null) return whole + entry.value;
      }
    }
    // Mixed number: "2 1/2"
    final mixedMatch = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
    if (mixedMatch != null) {
      final whole = double.parse(mixedMatch.group(1)!);
      final num = double.parse(mixedMatch.group(2)!);
      final den = double.parse(mixedMatch.group(3)!);
      if (den != 0) return whole + num / den;
    }
    // Simple fraction: "1/2"
    final fracMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (fracMatch != null) {
      final num = double.parse(fracMatch.group(1)!);
      final den = double.parse(fracMatch.group(2)!);
      if (den != 0) return num / den;
    }
    // Plain number
    return double.tryParse(s);
  }

  String _formatAmount(double value) {
    if (value == 0) return '0';
    // Common fractions with tolerance
    final fractions = [
      (1 / 8, '1/8'), (1 / 4, '1/4'), (1 / 3, '1/3'), (3 / 8, '3/8'),
      (1 / 2, '1/2'), (5 / 8, '5/8'), (2 / 3, '2/3'), (3 / 4, '3/4'),
      (7 / 8, '7/8'),
    ];
    final whole = value.floor();
    final frac = value - whole;
    const tolerance = 0.04;

    if (frac < tolerance) {
      return '$whole' == '0' ? '0' : '$whole';
    }
    if (frac > 1 - tolerance) {
      return '${whole + 1}';
    }
    for (final (fracValue, fracStr) in fractions) {
      if ((frac - fracValue).abs() < tolerance) {
        return whole == 0 ? fracStr : '$whole $fracStr';
      }
    }
    // Fallback: 2 decimal places, strip trailing zeros
    final formatted = value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return formatted;
  }

  String _scaledIngredientDisplay(Ingredient ing) {
    final scaledAmount = _scaleAmount(ing.amount);
    final parts = <String>[
      if (scaledAmount.isNotEmpty) scaledAmount,
      if (ing.unit != null) ing.unit!,
      ing.item,
      if (ing.note != null) '(${ing.note!})',
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final originalServings = recipe.servings;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: recipe.imageUrl != null ? 260 : 0,
            pinned: true,
            title: const Text('Ajustar Porções'),
            flexibleSpace: recipe.imageUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFFFCEEE4)),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _servingsPicker(context, originalServings),
                  const SizedBox(height: 28),
                  if (recipe.ingredients.isNotEmpty) ...[
                    _sectionTitle(context, 'Ingredientes'),
                    ..._scaledIngredients(context),
                    const SizedBox(height: 24),
                  ],
                  if (recipe.steps.isNotEmpty) ...[
                    _sectionTitle(context, 'Passos'),
                    ...recipe.steps.asMap().entries.map(
                          (e) => _stepRow(context, e.key + 1, e.value),
                        ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _servingsPicker(BuildContext context, int? originalServings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEEE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Porções',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
              ),
              if (originalServings != null) ...[
                const Spacer(),
                Text(
                  'Original: $originalServings',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E7B6B)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pickerButton(Icons.remove, () => _adjust(-1)),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: _onTextChanged,
                ),
              ),
              const SizedBox(width: 12),
              _pickerButton(Icons.add, () => _adjust(1)),
              const Spacer(),
              if (originalServings != null && _targetServings != originalServings)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '× ${_scaleFactor.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickerButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primary),
        ),
      );

  List<Widget> _scaledIngredients(BuildContext context) {
    return widget.recipe.ingredients
        .map((ing) => _ingredientRow(context, _scaledIngredientDisplay(ing)))
        .toList();
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
        ),
      );

  Widget _ingredientRow(BuildContext context, String display) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.circle, size: 6, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(display,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );

  Widget _stepRow(BuildContext context, int number, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5)),
              ),
            ),
          ],
        ),
      );
}
