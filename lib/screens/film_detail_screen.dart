import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FilmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> film;

  const FilmDetailScreen({super.key, required this.film});

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  bool _isLoading = true;
  String _trama = "Trama non disponibile.";
  String? _backdropPath; // Immagine orizzontale di sfondo
  String? _posterPath; // Locandina verticale
  List<dynamic> _cast = [];

  final String _tmdbApiKey = 'f54f39b5310035478bd10b4d1487458b';

  @override
  void initState() {
    super.initState();
    _fetchTMDBData();
  }

  Future<void> _fetchTMDBData() async {
    final titolo = widget.film['testo'] ?? '';
    if (titolo.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Cerchiamo il film su TMDB partendo dal nostro titolo
      final searchUrl = Uri.parse(
        'https://api.themoviedb.org/3/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(titolo)}&language=it-IT',
      );
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);

        // Se TMDB ha trovato dei risultati...
        if (searchData['results'] != null && searchData['results'].isNotEmpty) {
          final tmdbId = searchData['results'][0]['id'];

          // 2. Chiediamo i dettagli completi del film E il cast in un colpo solo
          final detailsUrl = Uri.parse(
            'https://api.themoviedb.org/3/movie/$tmdbId?api_key=$_tmdbApiKey&language=it-IT&append_to_response=credits',
          );
          final detailsResponse = await http.get(detailsUrl);

          if (detailsResponse.statusCode == 200) {
            final detailsData = jsonDecode(detailsResponse.body);

            if (mounted) {
              setState(() {
                _posterPath = detailsData['poster_path'];
                _backdropPath = detailsData['backdrop_path'];
                _trama =
                    detailsData['overview'] ??
                    'Nessuna trama in italiano disponibile.';
                _cast = detailsData['credits']?['cast'] ?? [];
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      // Ignoriamo per brevità, mostrerà i dati di default
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final titolo = widget.film['testo'] ?? 'Senza titolo';
    final isVisto =
        widget.film['visto'] != null && widget.film['visto'] != false;

    // Scegliamo quale immagine mostrare nell'header
    final imageUrl = _backdropPath != null
        ? 'https://image.tmdb.org/t/p/w500$_backdropPath'
        : (_posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$_posterPath'
              : null);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: const Color(0xFF18181B),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                titolo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Mostriamo l'immagine di TMDB!
                  if (imageUrl != null)
                    Image.network(imageUrl, fit: BoxFit.cover)
                  else
                    Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.movie_creation,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                  // Sfumatura
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isLoading
                  // Rotellina mentre scarichiamo i dati da TMDB
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(50.0),
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: isVisto
                                // ignore: deprecated_member_use
                                ? Colors.green.withOpacity(0.2)
                                // ignore: deprecated_member_use
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isVisto ? Colors.green : Colors.orange,
                            ),
                          ),
                          child: Text(
                            isVisto
                                ? 'Occhiata data (Visto)'
                                : 'Nella lista desideri',
                            style: TextStyle(
                              color: isVisto ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // LA TRAMA (Scaricata da TMDB)
                        const Text(
                          'Trama',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trama,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // IL CAST (Scaricato da TMDB)
                        const Text(
                          'Cast Principale',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_cast.isEmpty)
                          const Text(
                            "Nessun attore trovato.",
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          SizedBox(
                            height: 120, // Spazio per le foto degli attori
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _cast.length > 10
                                  ? 10
                                  : _cast
                                        .length, // Mostriamo massimo i primi 10
                              itemBuilder: (context, index) {
                                final attore = _cast[index];
                                final profilePath = attore['profile_path'];

                                return Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      // Foto Attore
                                      CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.grey[800],
                                        backgroundImage: profilePath != null
                                            ? NetworkImage(
                                                'https://image.tmdb.org/t/p/w200$profilePath',
                                              )
                                            : null,
                                        child: profilePath == null
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.white54,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 8),
                                      // Nome Attore
                                      Text(
                                        attore['name'] ?? 'Sconosciuto',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 32),
                        const Text(
                          'Le tue recensioni',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27272A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.star, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Questa sezione la collegheremo al database Node.js in futuro!",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 100,
                        ), // Spazio per permettere lo scroll
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
