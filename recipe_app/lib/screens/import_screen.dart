import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Shown when a link is shared from Instagram/TikTok, or when the user taps "Add Recipe".
/// 1. If sharedText/sharedUrl is provided → automatically calls the /parse endpoint.
/// 2. Otherwise → shows a manual input form.
/// After parsing, the user reviews and can edit before saving.
class ImportScreen extends StatefulWidget {
  final String? sharedText;
  final String? sharedUrl;
  final String? platform;

  const ImportScreen({
    super.key,
    this.sharedText,
    this.sharedUrl,
    this.platform,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  // State
  _ImportStep _step = _ImportStep.input;
  String? _error;
  RecipeInput? _parsed;

  // Input form
  final _urlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  String? _manualPlatform;

  // Edit form controllers (populated after parsing)
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _cookCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-trigger only when we have actual text content (not just a social URL)
    final hasCaptionText = widget.sharedText != null && widget.sharedText!.isNotEmpty;
    final isSocialUrl = widget.platform == 'instagram' || widget.platform == 'tiktok';
    if (hasCaptionText || (widget.sharedUrl != null && !isSocialUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerParse());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _urlCtrl, _textCtrl, _nameCtrl, _descCtrl, _categoryCtrl,
      _servingsCtrl, _prepCtrl, _cookCtrl, _ingredientsCtrl, _stepsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _triggerParse() async {
    final url = widget.sharedUrl ?? _urlCtrl.text.trim();
    // Prefer manually typed caption over auto-detected text (user can correct it)
    final text = _textCtrl.text.trim().isNotEmpty
        ? _textCtrl.text.trim()
        : (widget.sharedText ?? '');
    final platform = widget.platform ?? _manualPlatform;

    if (url.isEmpty && text.isEmpty) {
      setState(() => _error = 'Please enter a URL or paste the recipe text.');
      return;
    }

    setState(() {
      _step = _ImportStep.parsing;
      _error = null;
    });

    try {
      final recipe = await ApiService.parseSharedContent(
        text: text.isNotEmpty ? text : null,
        url: url.isNotEmpty ? url : null,
        platform: platform,
      );
      _populateEditForm(recipe);
      setState(() {
        _parsed = recipe;
        _step = _ImportStep.review;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _step = _ImportStep.input;
      });
    }
  }

  void _populateEditForm(RecipeInput r) {
    _nameCtrl.text = r.name;
    _descCtrl.text = r.description ?? '';
    _categoryCtrl.text = r.category ?? '';
    _servingsCtrl.text = r.servings?.toString() ?? '';
    _prepCtrl.text = r.prepTimeMinutes?.toString() ?? '';
    _cookCtrl.text = r.cookTimeMinutes?.toString() ?? '';
    _ingredientsCtrl.text = r.ingredients.map((i) => i.display).join('\n');
    _stepsCtrl.text = r.steps.join('\n\n');
  }

  RecipeInput _buildFromForm() {
    // Parse ingredients back from text (one per line)
    final ingredientLines = _ingredientsCtrl.text.trim().split('\n').where((l) => l.trim().isNotEmpty);
    final ingredients = ingredientLines.map((line) => Ingredient(item: line.trim())).toList();

    // Parse steps (separated by blank lines or newlines)
    final steps = _stepsCtrl.text
        .trim()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return RecipeInput(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      category: _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : null,
      servings: int.tryParse(_servingsCtrl.text.trim()),
      prepTimeMinutes: int.tryParse(_prepCtrl.text.trim()),
      cookTimeMinutes: int.tryParse(_cookCtrl.text.trim()),
      ingredients: ingredients,
      steps: steps,
      sourceUrl: _parsed?.sourceUrl ?? widget.sharedUrl ?? (_urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null),
      sourcePlatform: _parsed?.sourcePlatform ?? widget.platform ?? _manualPlatform,
      tags: _parsed?.tags ?? [],
      imageUrl: _parsed?.imageUrl,
    );
  }

  Future<void> _save() async {
    final input = _buildFromForm();
    if (input.name.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Missing name'),
          content: const Text('Please enter a recipe name before saving.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    setState(() => _step = _ImportStep.saving);
    try {
      await ApiService.createRecipe(input);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _step = _ImportStep.review);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Save failed'),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          _ImportStep.input => 'Add Recipe',
          _ImportStep.parsing => 'Parsing…',
          _ImportStep.review => 'Review Recipe',
          _ImportStep.saving => 'Saving…',
        }),
      ),
      body: switch (_step) {
        _ImportStep.input => _buildInputForm(),
        _ImportStep.parsing => _buildLoading('Asking Claude to extract the recipe…'),
        _ImportStep.review => _buildReviewForm(),
        _ImportStep.saving => _buildLoading('Saving recipe…'),
      },
    );
  }

  // ─── Input form ──────────────────────────────────────────────────────────

  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.sharedUrl == null && widget.sharedText == null) ...[
            Text(
              'Paste a link or text',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Share a link from Instagram or TikTok, paste a recipe URL, or paste the full recipe text.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL (Instagram, TikTok, recipe site…)',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                labelText: 'Or paste caption / recipe text',
                prefixIcon: Icon(Icons.text_snippet_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
          ] else ...[
            // Auto-share: show what was captured
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEEE4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.sharedUrl != null)
                    Text('URL: ${widget.sharedUrl}',
                        style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (widget.sharedText != null) ...[
                    if (widget.sharedUrl != null) const SizedBox(height: 4),
                    Text(widget.sharedText!, style: const TextStyle(fontSize: 12), maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Instagram and TikTok don\'t share captions automatically. If the result is empty, paste the caption below:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                labelText: 'Caption / recipe text (optional)',
                prefixIcon: Icon(Icons.text_snippet_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _triggerParse,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Extract Recipe with AI'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading ─────────────────────────────────────────────────────────────

  Widget _buildLoading(String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      );

  // ─── Review / Edit form ──────────────────────────────────────────────────

  Widget _buildReviewForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review and edit before saving',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _field(_nameCtrl, 'Name', required: true),
          const SizedBox(height: 12),
          _field(_categoryCtrl, 'Category', hint: 'e.g. Breakfast, Dinner, Dessert'),
          const SizedBox(height: 12),
          _field(_descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_servingsCtrl, 'Servings', keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _field(_prepCtrl, 'Prep (min)', keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _field(_cookCtrl, 'Cook (min)', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Ingredients'),
          const SizedBox(height: 4),
          Text('One per line', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          _field(_ingredientsCtrl, 'Ingredients', maxLines: 8, hint: '2 cups flour\n1 tsp salt\n…'),
          const SizedBox(height: 20),
          _sectionLabel('Steps'),
          const SizedBox(height: 4),
          Text('One step per line', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          _field(_stepsCtrl, 'Steps', maxLines: 10),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Recipe'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    bool required = false,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.onSurface),
      );
}

enum _ImportStep { input, parsing, review, saving }
