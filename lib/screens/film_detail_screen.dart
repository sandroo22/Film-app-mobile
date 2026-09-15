import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/review_modal.dart';

class FilmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> film;

  const FilmDetailScreen({super.key, required this.film});

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  bool _isLoading = true;
  String _trama = "Trama non disponibile.";
  String? _backdropPath;
  String? _posterPath;
  List<dynamic> _cast = [];

  // Variabili per la recensione
  int? _votoSalvato;
  String? _testoSalvato;

  final String _tmdbApiKey = 'f54f39b5310035478bd10b4d1487458b';

  @override
  void initState() {
    super.initState();
    // FIX: Nel database MySQL la colonna si chiama 'rating', non 'voto'
    _votoSalvato = widget.film['rating'] ?? widget.film['voto'];
    _testoSalvato = widget.film['recensione'];

    _fetchTMDBData();
  }

  Future<void> _fetchTMDBData() async {
    final titolo = widget.film['testo'] ?? '';
    if (titolo.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final searchUrl = Uri.parse(
        'https://api.themoviedb.org/3/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(titolo)}&language=it-IT',
      );
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);

        if (searchData['results'] != null && searchData['results'].isNotEmpty) {
          final tmdbId = searchData['results'][0]['id'];

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
                _trama = detailsData['overview'] ?? 'Nessuna trama in italiano disponibile.';
                _cast = detailsData['credits']?['cast'] ?? [];
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      // Ignoriamo per brevità
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- FUNZIONE: SALVA RECENSIONE NEL DATABASE NODE.JS ---
  Future<void> _salvaRecensioneNelDatabase(int voto, String testo) async {
    // 1. Aggiorna SUBITO la grafica dell'app (fa comparire le stelline)
    setState(() {
      _votoSalvato = voto;
      _testoSalvato = testo;
    });

    try {
      // 2. Recupera il token di sicurezza
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // FIX: Cerchiamo in modo robusto sia 'id' che '_id'
      final filmId = widget.film['id'] ?? widget.film['_id'];

      if (filmId == null) {
        // Se non lo trova, stampiamo cosa c'è dentro il film per indagare
        // ignore: avoid_print
        print("Errore CRITICO: ID del film mancante! I dati ricevuti sono: ${widget.film}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore: impossibile identificare il film.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 3. Invia la richiesta PUT al tuo backend
      final response = await http.put(
        Uri.parse('http://localhost:5000/api/film/$filmId/recensione'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'voto': voto, 'recensione': testo}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recensione salvata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ignore: avoid_print
        print("Errore dal server: ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore durante il salvataggio sul server'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print("Errore di rete: $e");
    }
  }

  void _apriPopupRecensione(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF27272A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ReviewModal(
          onSave: (voto, testo) {
            _salvaRecensioneNelDatabase(voto, testo);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titolo = widget.film['testo'] ?? 'Senza titolo';
    final isVisto = widget.film['visto'] != null && widget.film['visto'] != false;

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
                        // Badge Visto/Da vedere
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
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

                        // LA TRAMA
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

                        // IL CAST
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
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _cast.length > 10 ? 10 : _cast.length,
                              itemBuilder: (context, index) {
                                final attore = _cast[index];
                                final profilePath = attore['profile_path'];

                                return Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
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

                        // --- MOSTRA LA RECENSIONE SE ESISTE ---
                        if (_votoSalvato != null && _votoSalvato! > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // ignore: deprecated_member_use
                                color: Colors.amber.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                    5,
                                    (index) => Icon(
                                      index < _votoSalvato!
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                if (_testoSalvato != null &&
                                    _testoSalvato!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _testoSalvato!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // BOTTONE PER AGGIUNGERE O MODIFICARE
                        OutlinedButton.icon(
                          onPressed: () => _apriPopupRecensione(context),
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: Text(
                            _votoSalvato != null && _votoSalvato! > 0
                                ? "Modifica recensione"
                                : "Scrivi una recensione",
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}