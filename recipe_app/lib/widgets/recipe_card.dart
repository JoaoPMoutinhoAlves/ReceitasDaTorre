import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (recipe.category != null) ...[
                        _chip(context, recipe.category!),
                        const SizedBox(width: 6),
                      ],
                      if (recipe.timeDisplay.isNotEmpty)
                        _timeChip(context, recipe.timeDisplay),
                    ],
                  ),
                  if (recipe.sourcePlatform != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _platformBadge(context, recipe.sourcePlatform!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: ApiService.displayImageUrl(recipe.imageUrl!),
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _imagePlaceholder(),
          placeholder: (_, __) => _imagePlaceholder(),
        ),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: const Color(0xFFFCEEE4),
          child: const Icon(Icons.restaurant, size: 40, color: AppTheme.primary),
        ),
      );

  Widget _chip(BuildContext context, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEEE4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      );

  Widget _timeChip(BuildContext context, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: Colors.grey),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ],
      );

  Widget _platformBadge(BuildContext context, String platform) {
    final icon = switch (platform) {
      'instagram' => Icons.camera_alt_outlined,
      'tiktok' => Icons.music_note_outlined,
      _ => Icons.link,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          platform,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
