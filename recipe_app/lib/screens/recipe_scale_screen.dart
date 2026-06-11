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
  static const _multipliers = [0.25, 0.5, 1.0, 2.0, 4.0];
  static const _labels = ['¼×', '½×', '1×', '2×', '4×'];

  double _multiplier = 1.0;

  // ── Scaling helpers ──────────────────────────────────────────────────────

  String _scaleAmount(String? amount) {
    if (amount == null || amount.isEmpty) return '';
    final parsed = _parseAmount(amount);
    if (parsed == null) return amount;
    return _formatAmount(parsed * _multiplier);
  }

  double? _parseAmount(String s) {
    s = s.trim();
    const unicodeMap = {
      '½': 0.5,  '⅓': 0.3333, '⅔': 0.6667, '¼': 0.25,  '¾': 0.75,
      '⅕': 0.2,  '⅖': 0.4,    '⅗': 0.6,    '⅘': 0.8,
      '⅙': 0.1667,'⅚': 0.8333,'⅛': 0.125,  '⅜': 0.375, '⅝': 0.625,'⅞': 0.875,
    };
    for (final entry in unicodeMap.entries) {
      if (s == entry.key) return entry.value;
      if (s.endsWith(entry.key)) {
        final prefix = s.substring(0, s.length - entry.key.length).trim();
        final whole = double.tryParse(prefix);
        if (whole != null) return whole + entry.value;
      }
    }
    // Mixed: "2 1/2"
    final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
    if (mixed != null) {
      final w = double.parse(mixed.group(1)!);
      final n = double.parse(mixed.group(2)!);
      final d = double.parse(mixed.group(3)!);
      if (d != 0) return w + n / d;
    }
    // Fraction: "1/2"
    final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (frac != null) {
      final n = double.parse(frac.group(1)!);
      final d = double.parse(frac.group(2)!);
      if (d != 0) return n / d;
    }
    return double.tryParse(s);
  }

  String _formatAmount(double value) {
    if (value <= 0) return '0';
    const tol = 0.04;
    const fractions = [
      (0.125, '1/8'), (0.25, '1/4'), (0.3333, '1/3'), (0.375, '3/8'),
      (0.5,   '1/2'), (0.625, '5/8'), (0.6667, '2/3'), (0.75,  '3/4'),
      (0.875, '7/8'),
    ];
    final whole = value.floor();
    final frac  = value - whole;

    if (frac < tol)       return '$whole';
    if (frac > 1 - tol)   return '${whole + 1}';

    for (final (fv, fs) in fractions) {
      if ((frac - fv).abs() < tol) {
        return whole == 0 ? fs : '$whole $fs';
      }
    }
    return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  String _scaledDisplay(Ingredient ing) {
    final parts = <String>[
      if (_scaleAmount(ing.amount).isNotEmpty) _scaleAmount(ing.amount),
      if (ing.unit != null) ing.unit!,
      ing.item,
      if (ing.note != null) '(${ing.note!})',
    ];
    return parts.join(' ');
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: recipe.imageUrl != null ? 260 : 0,
            pinned: true,
            title: const Text('Ajustar Receita'),
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
                  _multiplierPicker(context),
                  const SizedBox(height: 28),

                  // Keyed so Flutter fully recreates the subtree on multiplier change
                  if (recipe.ingredients.isNotEmpty)
                    _IngredientsSection(
                      key: ValueKey(_multiplier),
                      context: context,
                      ingredients: recipe.ingredients
                          .map((ing) => _scaledDisplay(ing))
                          .toList(),
                    ),

                  if (recipe.steps.isNotEmpty) ...[
                    _sectionTitle(context, 'Passos'),
                    for (int i = 0; i < recipe.steps.length; i++)
                      _stepRow(context, i + 1, recipe.steps[i]),
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

  // ── Multiplier picker ────────────────────────────────────────────────────

  Widget _multiplierPicker(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEEE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Multiplicador',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
              ),
              if (widget.recipe.servings != null) ...[
                const Spacer(),
                Text(
                  '${(widget.recipe.servings! * _multiplier).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} porções',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E7B6B)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < _multipliers.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _multiplierChip(i)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _multiplierChip(int index) {
    final selected = _multipliers[index] == _multiplier;
    return GestureDetector(
      onTap: () => setState(() => _multiplier = _multipliers[index]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.25),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _labels[index],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }

  // ── Row helpers ──────────────────────────────────────────────────────────

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

// Separate StatelessWidget so the ValueKey on it causes full recreation
class _IngredientsSection extends StatelessWidget {
  final BuildContext context;
  final List<String> ingredients;

  const _IngredientsSection({
    super.key,
    required this.context,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Ingredientes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
          ),
        ),
        for (final display in ingredients)
          Padding(
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
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
