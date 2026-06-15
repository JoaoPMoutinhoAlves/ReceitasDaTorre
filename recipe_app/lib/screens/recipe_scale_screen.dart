import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Per-ingredient base data computed once from the recipe at 1×.
/// [baseValue] is the numeric 1× amount (null when the ingredient has no
/// scalable quantity, e.g. "a gosto"); [rawAmount] holds the original amount
/// string for unscalable rows that still carry text.
class _IngredientBase {
  final double? baseValue;
  final String? rawAmount;
  final String? unit;
  final String item;
  final String? note;

  const _IngredientBase({
    this.baseValue,
    this.rawAmount,
    this.unit,
    required this.item,
    this.note,
  });

  bool get scalable => baseValue != null && baseValue! > 0;
}

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

  late List<_IngredientBase> _bases;

  // One controller per ingredient amount field (null for unscalable rows).
  late List<TextEditingController?> _amountControllers;
  // Controller for the custom "X" multiplier field.
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bases = _computeBases();
    _amountControllers = _bases
        .map((b) => b.scalable
            ? TextEditingController(text: _format(b.baseValue!))
            : null)
        .toList();
    _customController.text = _formatMultiplier(1.0);
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c?.dispose();
    }
    _customController.dispose();
    super.dispose();
  }

  // ── Base computation (once) ──────────────────────────────────────────────

  List<_IngredientBase> _computeBases() {
    return widget.recipe.ingredients.map((ing) {
      final rawAmount = ing.amount?.trim();
      final hasAmount = rawAmount != null && rawAmount.isNotEmpty;

      if (hasAmount) {
        final v = _parse(rawAmount);
        if (v != null) {
          return _IngredientBase(
            baseValue: v,
            unit: ing.unit,
            item: ing.item,
            note: ing.note,
          );
        }
        // Amount present but unparseable (e.g. "a gosto") — keep as text.
        return _IngredientBase(
          rawAmount: rawAmount,
          unit: ing.unit,
          item: ing.item,
          note: ing.note,
        );
      }

      // amount is null/empty — the number may be embedded in item ("6 ovos").
      final split = _extractLeadingNumber(ing.item);
      if (split != null) {
        return _IngredientBase(
          baseValue: split.$1,
          unit: ing.unit,
          item: split.$2,
          note: ing.note,
        );
      }
      return _IngredientBase(unit: ing.unit, item: ing.item, note: ing.note);
    }).toList();
  }

  // ── Multiplier application ────────────────────────────────────────────────

  /// Sets the multiplier from any source (chip, custom field, ingredient edit)
  /// and re-syncs every amount field + the custom field to match.
  void _applyMultiplier(double m) {
    if (m <= 0) return;
    setState(() => _multiplier = m);
    for (int i = 0; i < _bases.length; i++) {
      final b = _bases[i];
      if (b.scalable) {
        _amountControllers[i]!.text = _format(b.baseValue! * m);
      }
    }
    _customController.text = _formatMultiplier(m);
  }

  /// User edited an ingredient amount by hand — derive the multiplier from
  /// the ratio against its 1× base and rescale everything.
  void _onAmountEdited(int index, String text) {
    final base = _bases[index].baseValue;
    if (base == null || base <= 0) return;
    final v = _parse(text.trim());
    if (v == null || v <= 0) {
      // Invalid input — revert to the current scaled value.
      _amountControllers[index]!.text = _format(base * _multiplier);
      return;
    }
    _applyMultiplier(v / base);
  }

  void _onCustomEdited(String text) {
    final v = _parse(text.trim());
    if (v == null || v <= 0) {
      _customController.text = _formatMultiplier(_multiplier);
      return;
    }
    _applyMultiplier(v);
  }

  // ── Parsing & formatting ──────────────────────────────────────────────────

  /// If [item] begins with a recognisable quantity, returns (value, remainder).
  /// "6 ovos"       → (6.0,  "ovos")
  /// "1/2 colher"   → (0.5,  "colher")
  /// "2 1/2 chávenas" → (2.5, "chávenas")
  /// "a gosto"      → null
  (double, String)? _extractLeadingNumber(String item) {
    final s = item.trim();
    // Mixed number: "2 1/2 ..."
    final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)\s+(.+)$').firstMatch(s);
    if (mixed != null) {
      final w = double.parse(mixed.group(1)!);
      final n = double.parse(mixed.group(2)!);
      final d = double.parse(mixed.group(3)!);
      if (d != 0) return (w + n / d, mixed.group(4)!.trim());
    }
    // Fraction: "1/2 ..."
    final frac = RegExp(r'^(\d+)/(\d+)\s+(.+)$').firstMatch(s);
    if (frac != null) {
      final n = double.parse(frac.group(1)!);
      final d = double.parse(frac.group(2)!);
      if (d != 0) return (n / d, frac.group(3)!.trim());
    }
    // Integer or decimal: "6 ...", "2.5 ...", "2,5 ..."
    final num = RegExp(r'^(\d+(?:[.,]\d+)?)\s+(.+)$').firstMatch(s);
    if (num != null) {
      final v = _parseNum(num.group(1)!);
      if (v != null) return (v, num.group(2)!.trim());
    }
    return null;
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

  // Plain decimal formatting for the multiplier value (no fractions).
  String _formatMultiplier(double v) {
    final s = v
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return s.isEmpty ? '0' : s;
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
                  const SizedBox(height: 16),

                  // Ingredients
                  if (_bases.isNotEmpty) ...[
                    _sectionTitle(context, 'Ingredientes'),
                    for (int i = 0; i < _bases.length; i++)
                      _ingredientRow(context, i),
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
    final isCustom = !_multiplierValues.contains(_multiplier);

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
          const SizedBox(height: 10),
          // Custom "X" multiplier card
          _customMultiplierCard(context, isCustom),
        ],
      ),
    );
  }

  Widget _customMultiplierCard(BuildContext context, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.close, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            'Personalizado',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
          ),
          const Spacer(),
          SizedBox(
            width: 72,
            child: TextField(
              controller: _customController,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                suffixText: '×',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
              onSubmitted: _onCustomEdited,
              onEditingComplete: () =>
                  _onCustomEdited(_customController.text),
            ),
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
      onTap: () => _applyMultiplier(value),
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

  Widget _ingredientRow(BuildContext context, int index) {
    final base = _bases[index];

    // Trailing text: unit + item + note.
    final trailing = <String>[
      if (base.unit != null) base.unit!,
      base.item,
      if (base.note != null) '(${base.note!})',
    ].join(' ').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 6, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          if (base.scalable) ...[
            // Editable amount — scales every other ingredient when changed.
            SizedBox(
              width: 56,
              child: TextField(
                controller: _amountControllers[index],
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,/ ]')),
                ],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                ),
                onSubmitted: (t) => _onAmountEdited(index, t),
                onEditingComplete: () =>
                    _onAmountEdited(index, _amountControllers[index]!.text),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (base.rawAmount != null) ...[
            Text(
              base.rawAmount!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              trailing,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

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
