import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/film_detail_screen.dart';

class FilmListItem extends StatefulWidget {
  final dynamic film;
  final String apiKey;
  final VoidCallback onToggleVisto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FilmListItem({
    super.key,
    required this.film,
    required this.apiKey,
    required this.onToggleVisto,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<FilmListItem> createState() => _FilmListItemState();
}

class _FilmListItemState extends State<FilmListItem> {
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
            if (mounted) setState(() => _posterUrl = 'https://image.tmdb.org/t/p/w92$path'); 
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

    return Dismissible(
      key: Key(widget.film['id'].toString()), 
      direction: DismissDirection.endToStart, 
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF27272A),
              title: const Text("Conferma eliminazione"),
              content: Text("Vuoi davvero eliminare '$titolo'?"),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Annulla", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("Elimina", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        widget.onDelete(); 
      },
      child: Card(
        color: const Color(0xFF27272A),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 50,
              height: 75,
              child: _posterUrl != null
                  ? Image.network(_posterUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[900],
                      child: _isSearching
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)))
                          : const Icon(Icons.movie, color: Colors.grey),
                    ),
            ),
          ),
          title: Text(
            titolo,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isVisto ? Colors.grey : Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color.fromARGB(255, 255, 7, 7)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FilmDetailScreen(film: widget.film))),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: Icon(isVisto ? Icons.visibility : Icons.visibility_off, color: isVisto ? Colors.green : Colors.grey),
                onPressed: widget.onToggleVisto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}