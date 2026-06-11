import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_theme.dart';
import 'recipe_scale_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Are you sure you want to delete "${_recipe.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ApiService.deleteRecipe(_recipe.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _deleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      await PdfExportService.exportRecipes([_recipe]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _openSource() async {
    if (_recipe.sourceUrl == null) return;
    final uri = Uri.parse(_recipe.sourceUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _recipe.imageUrl != null ? 260 : 0,
            pinned: true,
            flexibleSpace: _recipe.imageUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: _recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFFFCEEE4)),
                    ),
                  )
                : null,
            actions: [
              if (_recipe.ingredients.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.scale_outlined),
                  tooltip: 'Adjust servings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeScaleScreen(recipe: _recipe),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'Export as PDF',
                onPressed: _exportPdf,
              ),
              if (_recipe.sourceUrl != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open source',
                  onPressed: _openSource,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _deleting ? null : _delete,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _recipe.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 10),
                  // Meta row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (_recipe.category != null) _metaChip(_recipe.category!),
                      if (_recipe.timeDisplay.isNotEmpty) _metaChip('⏱ ${_recipe.timeDisplay}'),
                      if (_recipe.servings != null) _metaChip('🍽 ${_recipe.servings} servings'),
                      if (_recipe.sourcePlatform != null) _metaChip(_recipe.sourcePlatform!),
                    ],
                  ),
                  if (_recipe.description != null && _recipe.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _recipe.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B4C3B),
                            height: 1.5,
                          ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Timing breakdown
                  if (_recipe.prepTimeMinutes != null || _recipe.cookTimeMinutes != null)
                    _timingRow(context),
                  // Ingredients
                  if (_recipe.ingredients.isNotEmpty) ...[
                    _sectionTitle(context, 'Ingredients'),
                    ..._recipe.ingredients.map((ing) => _ingredientRow(context, ing)),
                    const SizedBox(height: 24),
                  ],
                  // Steps
                  if (_recipe.steps.isNotEmpty) ...[
                    _sectionTitle(context, 'Steps'),
                    ..._recipe.steps.asMap().entries.map(
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

  Widget _metaChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEEE4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
        ),
      );

  Widget _timingRow(BuildContext context) {
    final items = <String, String?>{
      'Prep': _recipe.prepTimeMinutes != null ? '${_recipe.prepTimeMinutes}min' : null,
      'Cook': _recipe.cookTimeMinutes != null ? '${_recipe.cookTimeMinutes}min' : null,
      'Total': _recipe.timeDisplay.isNotEmpty ? _recipe.timeDisplay : null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: items.entries
            .where((e) => e.value != null)
            .map(
              (e) => Expanded(
                child: Column(
                  children: [
                    Text(e.value!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(e.key, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
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

  Widget _ingredientRow(BuildContext context, Ingredient ing) => Padding(
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
              child: Text(ing.display, style: Theme.of(context).textTheme.bodyMedium),
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
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
              ),
            ),
          ],
        ),
      );
}
