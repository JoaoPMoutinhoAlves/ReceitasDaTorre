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
  static const _multiplierValues = [0.25, 0.5, 1.0, 2.0, 4.0];
  static const _multiplierLabels = ['¼×', '½×', '1×', '2×', '4×'];

  double _multiplier = 1.0;

  // Pre-computed ingredient display strings stored as STATE.
  // Updated explicitly on every multiplier change so Flutter has no
  // opportunity to skip re-rendering them.
  late List<String> _ingredientLines;

  @override
  void initState() {
    super.initState();
    _ingredientLines = _buildIngredientLines(1.0);
  }

  // ── Core computation ─────────────────────────────────────────────────────

  List<String> _buildIngredientLines(double multiplier) {
    return widget.recipe.ingredients.map((ing) {
      final scaledAmount = _scaleAmount(ing.amount, multiplier);
      final parts = <String>[
        if (scaledAmount.isNotEmpty) scaledAmount,
        if (ing.unit != null) ing.unit!,
        ing.item,
        if (ing.note != null) '(${ing.note!})',
      ];
      return parts.join(' ');
    }).toList();
  }

  String _scaleAmount(String? raw, double multiplier) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = _parse(raw.trim());
    if (parsed == null) return raw.trim();
    return _format(parsed * multiplier);
  }

  double? _parse(String s) {
    // Unicode vulgar fractions
    const unicode = {
      '½': 0.5,   '⅓': 1/3,   '⅔': 2/3,   '¼': 0.25,  '¾': 0.75,
      '⅕': 0.2,   '⅖': 0.4,   '⅗': 0.6,   '⅘': 0.8,
      '⅙': 1/6,   '⅚': 5/6,   '⅛': 0.125, '⅜': 0.375,
      '⅝': 0.625, '⅞': 0.875,
    };
    for (final e in unicode.entries) {
      if (s == e.key) return e.value;
      if (s.endsWith(e.key)) {
        final w = double.tryParse(s.substring(0, s.length - e.key.length).trim());
        if (w != null) return w + e.value;
      }
    }
    // Mixed number "2 1/2"
    final mixed = RegExp(r'^(\d+(?:[.,]\d+)?)\s+(\d+)/(\d+)$').firstMatch(s);
    if (mixed != null) {
      final w = _parseNum(mixed.group(1)!);
      final n = double.parse(mixed.group(2)!);
      final d = double.parse(mixed.group(3)!);
      if (w != null && d != 0) return w + n / d;
    }
    // Fraction "1/2"
    final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (frac != null) {
      final n = double.parse(frac.group(1)!);
      final d = double.parse(frac.group(2)!);
      if (d != 0) return n / d;
    }
    return _parseNum(s);
  }

  // Handles both "." and "," as decimal separator
  double? _parseNum(String s) =>
      double.tryParse(s) ?? double.tryParse(s.replaceAll(',', '.'));

  String _format(double v) {
    if (v <= 0) return '0';
    const tol = 0.04;
    const knownFracs = [
      (0.125, '1/8'), (0.25, '1/4'), (1/3, '1/3'), (0.375, '3/8'),
      (0.5,   '1/2'), (0.625, '5/8'), (2/3, '2/3'), (0.75,  '3/4'),
      (0.875, '7/8'),
    ];
    final whole = v.floor();
    final frac  = v - whole;

    if (frac < tol)     return '$whole';
    if (frac > 1 - tol) return '${whole + 1}';

    for (final (fv, fs) in knownFracs) {
      if ((frac - fv).abs() < tol) return whole == 0 ? fs : '$whole $fs';
    }
    // Two significant digits, strip trailing zeros
    final s = v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  // ── Multiplier selection ─────────────────────────────────────────────────

  void _selectMultiplier(double m) {
    // Recompute ingredient lines and store them in state atomically.
    final lines = _buildIngredientLines(m);
    setState(() {
      _multiplier = m;
      _ingredientLines = lines;
    });
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
                  // Title
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Multiplier picker
                  _buildMultiplierPicker(context),
                  const SizedBox(height: 28),

                  // Ingredients — read straight from _ingredientLines (state)
                  if (_ingredientLines.isNotEmpty) ...[
                    _sectionTitle(context, 'Ingredientes'),
                    for (int i = 0; i < _ingredientLines.length; i++)
                      _ingredientRow(context, i, _ingredientLines[i]),
                    const SizedBox(height: 24),
                  ],

                  // Steps — unchanged
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

  Widget _buildMultiplierPicker(BuildContext context) {
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
                  '${_format(widget.recipe.servings! * _multiplier)} porções',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E7B6B)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < _multiplierValues.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _multiplierChip(
                    label: _multiplierLabels[i],
                    value: _multiplierValues[i],
                    selected: _multiplierValues[i] == _multiplier,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _multiplierChip({
    required String label,
    required double value,
    required bool selected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectMultiplier(value),
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
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }

  // ── Row widgets ──────────────────────────────────────────────────────────

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

  // Key on ingredient rows forces Flutter to treat each as a fresh widget
  // when _ingredientLines changes.
  Widget _ingredientRow(BuildContext context, int index, String display) => Padding(
        key: ValueKey('ing_${_multiplier}_$index'),
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
              child: Text(
                display,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
}
