import 'dart:convert';
import 'dart:io';

void main() {
  // 1. Chemin vers ton fichier JSON
  final file = File('assets/action_verite.json');

  if (!file.existsSync()) {
    print('❌ Erreur : Le fichier assets/questions.json est introuvable.');
    return;
  }

  // 2. Lire le contenu du fichier
  final String contents = file.readAsStringSync();
  final List<dynamic> data = json.decode(contents);

  // Convertir en liste typée pour faciliter le tri
  List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(data);

  // 3. Trier les questions
  questions.sort((a, b) {
    // Étape A : Trier par Catégorie (ordre alphabétique)
    String catA = a['category'] ?? '';
    String catB = b['category'] ?? '';
    int categoryComparison = catA.compareTo(catB);
    
    if (categoryComparison != 0) {
      return categoryComparison; // Si catégories différentes, on s'arrête là
    }

    // Étape B : Si c'est la même catégorie, on trie par Type (action ou verite)
    String typeA = a['type'] ?? '';
    String typeB = b['type'] ?? '';
    return typeA.compareTo(typeB);
  });

  // 4. Réécrire le fichier avec une belle indentation (formatage propre)
  final encoder = const JsonEncoder.withIndent('  ');
  final String prettyJson = encoder.convert(questions);
  
  file.writeAsStringSync(prettyJson);

  print('✅ Fichier trié avec succès ! Va vérifier ton questions.json.');
}