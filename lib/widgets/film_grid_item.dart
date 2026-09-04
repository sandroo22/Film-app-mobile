import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/film_detail_screen.dart';

class FilmGridItem extends StatefulWidget {
  final dynamic film;
  final String apiKey;
  final VoidCallback onToggleVisto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FilmGridItem({
    super.key,
    required this.film,
    required this.apiKey,
    required this.onToggleVisto,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<FilmGridItem> createState() => _FilmGridItemState();
}

class _FilmGridItemState extends State<FilmGridItem> {
  String? _posterUrl;
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    _fetchPoster();
  }

  Future<void> _fetchPoster() async {
    final titolo = widget.film['testo'] ?? '';
    if (titolo.isEmpty || widget.apiKey.contains('INSERISCI_QUI')) {
      if (mounted) setState(() => _isSearching = false);
      return;
    }

    try {
      final searchUrl = Uri.parse('https://api.themoviedb.org/3/search/movie?api_key=${widget.apiKey}&query=${Uri.encodeComponent(titolo)}&language=it-IT');
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final path = data['results'][0]['poster_path'];
          if (path != null) {
            if (mounted) setState(() => _posterUrl = 'https://image.tmdb.org/t/p/w200$path');
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    final isVisto = widget.film['visto'] != null && widget.film['visto'] != false;
    final titolo = widget.film['testo'] ?? 'Senza titolo';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FilmDetailScreen(film: widget.film))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_posterUrl != null)
              Image.network(_posterUrl!, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[900],
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                    : const Icon(Icons.movie, size: 50, color: Colors.grey),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Colors.black87, Colors.transparent]),
              ),
            ),
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Text(titolo, style: TextStyle(fontWeight: FontWeight.bold, color: isVisto ? Colors.grey : Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Positioned(
              top: 4, left: 4,
              child: CircleAvatar(
                backgroundColor: Colors.black54, radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(isVisto ? Icons.visibility : Icons.visibility_off, color: isVisto ? Colors.green : Colors.white, size: 20),
                  onPressed: widget.onToggleVisto,
                ),
              ),
            ),
            Positioned(
              top: 4, right: 4,
              child: CircleAvatar(
                backgroundColor: Colors.black54, radius: 18,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  color: const Color(0xFF27272A),
                  onSelected: (value) {
                    if (value == 'edit') widget.onEdit();
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blueAccent), SizedBox(width: 8), Text('Modifica')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent), SizedBox(width: 8), Text('Elimina')])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}