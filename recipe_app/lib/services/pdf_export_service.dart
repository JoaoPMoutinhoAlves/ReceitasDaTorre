import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/recipe.dart';
import 'api_service.dart';

class PdfExportService {
  // Monochrome palette — printer-friendly, no coloured ink wasted
  static const _ink = PdfColor(0.11, 0.07, 0.03); // deep brown-black
  static const _dark = PdfColor(0.27, 0.27, 0.27); // dark grey
  static const _mid = PdfColor(0.50, 0.50, 0.50); // mid grey
  static const _rule = PdfColor(0.82, 0.82, 0.82); // light grey rule
  static const _shade = PdfColor(0.96, 0.94, 0.92); // very faint warm tint

  static Future<void> exportRecipes(List<Recipe> recipes) async {
    final base = await ApiService.baseUrl;
    // Fetch all images in parallel before building the PDF
    final imageDataList = await Future.wait(
      recipes.map((r) =>
          r.imageUrl != null ? _fetchImage(r.imageUrl!, base) : Future<Uint8List?>.value(null)),
    );

    final pdf = pw.Document(
      creator: 'Receitas da Torre',
      title: recipes.length == 1 ? recipes.first.name : 'Receitas',
    );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 40),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Receitas da Torre',
          style: pw.TextStyle(fontSize: 7, color: _mid),
        ),
      ),
      build: (ctx) {
        final widgets = <pw.Widget>[];
        for (var i = 0; i < recipes.length; i++) {
          if (i > 0) widgets.add(pw.NewPage());
          final imgData = imageDataList[i];
          final img = imgData != null ? pw.MemoryImage(imgData) : null;
          widgets.addAll(_buildRecipeWidgets(recipes[i], img));
        }
        return widgets;
      },
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: recipes.length == 1 ? recipes.first.name : 'Receitas',
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<Uint8List?> _fetchImage(String url, String base) async {
    final proxyUrl = '$base/api/proxy-image?url=${Uri.encodeComponent(url)}';
    try {
      final res = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  static List<pw.Widget> _buildRecipeWidgets(Recipe recipe, pw.MemoryImage? image) {
    return [
      _recipeHeader(recipe),
      pw.SizedBox(height: 10),
      pw.Divider(color: _rule, thickness: 0.6),
      pw.SizedBox(height: 10),
      _imageAndIngredients(recipe, image),
      if (recipe.steps.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Divider(color: _rule, thickness: 0.6),
        pw.SizedBox(height: 10),
        _stepsSection(recipe),
      ],
    ];
  }

  // ── Header: title + meta ───────────────────────────────────────────────────

  static pw.Widget _recipeHeader(Recipe recipe) {
    final metaParts = <String>[
      if (recipe.category != null) recipe.category!,
      if (recipe.timeDisplay.isNotEmpty) recipe.timeDisplay,
      if (recipe.servings != null) '${recipe.servings} servings',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                recipe.name,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            if (metaParts.isNotEmpty)
              pw.Text(
                metaParts.join('  ·  '),
                style: pw.TextStyle(fontSize: 9, color: _mid),
              ),
          ],
        ),
        if (recipe.description != null && recipe.description!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            recipe.description!,
            style: pw.TextStyle(fontSize: 10, color: _dark, lineSpacing: 2),
          ),
        ],
      ],
    );
  }

  // ── Image + Ingredients side-by-side ──────────────────────────────────────

  static pw.Widget _imageAndIngredients(Recipe recipe, pw.MemoryImage? image) {
    final hasImage = image != null;
    final hasIngredients = recipe.ingredients.isNotEmpty;

    if (!hasImage && !hasIngredients) return pw.SizedBox(height: 0);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(image, width: 168, height: 150, fit: pw.BoxFit.cover),
          ),
          pw.SizedBox(width: 18),
        ],
        if (hasIngredients)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionLabel('Ingredients'),
                pw.SizedBox(height: 6),
                ...recipe.ingredients.map(_ingredientRow),
              ],
            ),
          ),
      ],
    );
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  static pw.Widget _stepsSection(Recipe recipe) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('Steps'),
        pw.SizedBox(height: 8),
        // Use a two-column layout for steps when there are many short ones
        if (recipe.steps.length > 6)
          _twoColumnSteps(recipe.steps)
        else
          pw.Column(
            children: recipe.steps
                .asMap()
                .entries
                .map((e) => _stepRow(e.key + 1, e.value))
                .toList(),
          ),
      ],
    );
  }

  static pw.Widget _twoColumnSteps(List<String> steps) {
    final mid = (steps.length / 2).ceil();
    final left = steps.sublist(0, mid);
    final right = steps.sublist(mid);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            children: left
                .asMap()
                .entries
                .map((e) => _stepRow(e.key + 1, e.value))
                .toList(),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            children: right
                .asMap()
                .entries
                .map((e) => _stepRow(mid + e.key + 1, e.value))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── Micro widgets ──────────────────────────────────────────────────────────

  static pw.Widget _sectionLabel(String text) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _dark,
            letterSpacing: 1.4,
          ),
        ),
      );

  static pw.Widget _ingredientRow(Ingredient ing) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, right: 6),
              child: pw.Container(
                width: 3,
                height: 3,
                decoration: const pw.BoxDecoration(
                  color: _dark,
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                ing.display,
                style: pw.TextStyle(fontSize: 10, color: _ink, lineSpacing: 1.5),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _stepRow(int number, String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 17,
              height: 17,
              decoration: pw.BoxDecoration(
                color: _shade,
                border: pw.Border.all(color: _rule, width: 0.6),
                shape: pw.BoxShape.circle,
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                '$number',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  text,
                  style: pw.TextStyle(fontSize: 10, color: _ink, lineSpacing: 2),
                ),
              ),
            ),
          ],
        ),
      );
}
