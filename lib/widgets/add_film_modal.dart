import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AddFilmModal extends StatefulWidget {
  final Function(Map<String, dynamic> filmData) onFilmSelected;

  const AddFilmModal({super.key, required this.onFilmSelected});

  @override
  State<AddFilmModal> createState() => _AddFilmModalState();
}

class _AddFilmModalState extends State<AddFilmModal> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _risultati = [];
  bool _isSearching = false;
  Timer? _debounce;

  final String _tmdbApiKey = 'f54f39b5310035478bd10b4d1487458b';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _cercaFilm(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _risultati = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final url = Uri.parse(
          'https://api.themoviedb.org/3/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(query)}&language=it-IT',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _risultati = data['results'] ?? [];
          });
        }
      } catch (e) {
        // ignore: avoid_print
        print("Errore ricerca TMDB: $e");
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.7, 
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Aggiungi un nuovo film",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _cercaFilm,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Cerca titolo (es. Interstellar)...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _cercaFilm('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : _risultati.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? "Digita il titolo di un film per iniziare"
                              : "Nessun film trovato",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _risultati.length,
                        itemBuilder: (context, index) {
                          final film = _risultati[index];
                          final posterPath = film['poster_path'];
                          final anno = film['release_date'] != null && film['release_date'].toString().length >= 4
                              ? film['release_date'].toString().substring(0, 4)
                              : 'Anno sconosciuto';

                          return Card(
                            color: const Color(0xFF27272A),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: posterPath != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w92$posterPath',
                                        width: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 50,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.movie, color: Colors.white54),
                                      ),
                              ),
                              title: Text(film['title'] ?? 'Senza titolo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(anno, style: const TextStyle(color: Colors.grey)),
                              onTap: () {
                                final filmScelto = {
                                  'testo': film['title'],
                                  'copertina': posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null,
                                };
                                widget.onFilmSelected(filmScelto);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}