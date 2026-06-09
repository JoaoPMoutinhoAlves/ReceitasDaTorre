import 'dart:async';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../widgets/recipe_card.dart';
import '../theme/app_theme.dart';
import 'recipe_detail_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Recipe> _recipes = [];
  List<String> _categories = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _reloadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _load();
    });
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.listRecipes(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          category: _selectedCategory,
        ),
        ApiService.listCategories(),
      ]);
      setState(() {
        _recipes = results[0] as List<Recipe>;
        _categories = results[1] as List<String>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String value) {
    setState(() => _searchQuery = value);
    _load();
  }

  void _onCategorySelected(String? cat) {
    setState(() => _selectedCategory = cat);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receitas', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search recipes…',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _selectedCategory == null,
                    onSelected: (_) => _onCategorySelected(null),
                  ),
                  ..._categories.map(
                    (cat) => _CategoryChip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      onSelected: (_) => _onCategorySelected(
                        _selectedCategory == cat ? null : cat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ImportScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Could not connect to backend', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'No recipes found'
                  : 'No recipes yet.\nShare a link from Instagram or TikTok!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // When a specific category is selected or searching: flat grid
    if (_selectedCategory != null || _searchQuery.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: _recipes.length,
          itemBuilder: (context, i) => _recipeCard(_recipes[i]),
        ),
      );
    }

    // Default: grouped by category
    return RefreshIndicator(
      onRefresh: _load,
      child: _buildGroupedView(),
    );
  }

  Widget _buildGroupedView() {
    // Group recipes by category
    final Map<String, List<Recipe>> grouped = {};
    for (final recipe in _recipes) {
      final cat = recipe.category ?? '';
      grouped.putIfAbsent(cat, () => []).add(recipe);
    }

    // Order: known categories first (in API order), uncategorized last
    final sections = <String>[
      ..._categories.where(grouped.containsKey),
      if (grouped.containsKey('')) '',
    ];

    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final cat = sections[i];
        final recipes = grouped[cat]!;
        return _buildCategorySection(cat.isEmpty ? 'Other' : cat, recipes);
      },
    );
  }

  Widget _buildCategorySection(String title, List<Recipe> recipes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recipes.length,
            itemBuilder: (context, i) => SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _recipeCard(recipes[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recipeCard(Recipe recipe) => RecipeCard(
        recipe: recipe,
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
          );
          if (changed == true) _load();
        },
      );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: AppTheme.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
