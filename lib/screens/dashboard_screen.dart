import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';
import '../widgets/film_list_item.dart';
import '../widgets/film_grid_item.dart';
import '../widgets/add_film_modal.dart';
import 'recap_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _film = [];
  bool _isLoading = true;
  bool _isGridView = false;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final String _tmdbApiKey = 'f54f39b5310035478bd10b4d1487458b';

  @override
  void initState() {
    super.initState();
    _fetchFilm();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/film'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _film = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleVisto(int id, bool isVistoAttuale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.patch(
        Uri.parse('http://localhost:5000/api/film/$id/visto'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'visto': !isVistoAttuale}),
      );
      if (response.statusCode == 200) _fetchFilm();
    } catch (e) {}
  }

  Future<void> _aggiornaTitoloFilm(int id, String nuovoTitolo) async {
    if (nuovoTitolo.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('http://localhost:5000/api/film/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'testo': nuovoTitolo}),
      );
      if (response.statusCode == 200) {
        _fetchFilm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Titolo aggiornato con successo!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la modifica'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _aggiungiFilm(String titolo, String? copertina) async {
    if (titolo.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/film'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'testo': titolo,
          'copertina': copertina,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchFilm();
        _searchController.clear();
        setState(() => _searchQuery = '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$titolo" aggiunto alla lista!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {}
  }

  Future<void> _eliminaFilm(int id) async {
    setState(() {
      _film.removeWhere((f) => f['id'] == id);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/film/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Film eliminato correttamente.'), backgroundColor: Colors.green),
          );
        }
      } else {
        _fetchFilm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile eliminare il film.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      _fetchFilm();
    }
  }

  void _confermaEliminazione(int id, String titolo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF27272A),
          title: const Text('Elimina Film', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Sei sicuro di voler eliminare "$titolo" dalla tua lista?\nQuesta azione non può essere annullata.',
            style: const TextStyle(color: Colors.grey, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _eliminaFilm(id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sì, elimina'),
            ),
          ],
        );
      },
    );
  }

  void _mostraModaleRicercaIntelligente() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF27272A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddFilmModal(
          onFilmSelected: (filmData) {
            _aggiungiFilm(filmData['testo'], filmData['copertina']);
          },
        );
      },
    );
  }

  void _mostraDialogModifica(int id, String titoloCorrente) {
    final TextEditingController modificaController = TextEditingController(
      text: titoloCorrente,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF27272A),
          title: const Text('Modifica film', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: modificaController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Nuovo titolo',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _aggiornaTitoloFilm(id, modificaController.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Salva', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildContenutoFilm(List<dynamic> listaFiltrata) {
    if (listaFiltrata.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: _fetchFilm,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                "Nessun film trovato.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _fetchFilm,
      child: _isGridView
          ? _buildGriglia(listaFiltrata)
          : _buildLista(listaFiltrata),
    );
  }

  // --- LISTA CON SWIPE TO DELETE (DISMISSIBLE) ---
  Widget _buildLista(List<dynamic> listaFiltrata) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: listaFiltrata.length,
      itemBuilder: (context, index) {
        final film = listaFiltrata[index];
        
        return Dismissible(
          key: Key('film_${film['id']}'),
          direction: DismissDirection.endToStart, 
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF27272A),
                  title: const Text('Elimina Film', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                    'Vuoi davvero rimuovere "${film['testo']}"?\nQuesta azione non può essere annullata.',
                    style: const TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text('Sì, elimina', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            _eliminaFilm(film['id']);
          },
          child: FilmListItem(
            film: film,
            apiKey: _tmdbApiKey,
            onToggleVisto: () => _toggleVisto(
              film['id'],
              film['visto'] != null && film['visto'] != false,
            ),
            onEdit: () => _mostraDialogModifica(film['id'], film['testo'] ?? ''),
            onDelete: () => _confermaEliminazione(film['id'], film['testo'] ?? 'questo film'),
          ),
        );
      },
    );
  }

  Widget _buildGriglia(List<dynamic> listaFiltrata) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: listaFiltrata.length,
      itemBuilder: (context, index) {
        final film = listaFiltrata[index];
        return FilmGridItem(
          film: film,
          apiKey: _tmdbApiKey,
          onToggleVisto: () => _toggleVisto(
            film['id'],
            film['visto'] != null && film['visto'] != false,
          ),
          onEdit: () => _mostraDialogModifica(film['id'], film['testo'] ?? ''),
          onDelete: () => _confermaEliminazione(film['id'], film['testo'] ?? 'questo film'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filmFiltratiPerRicerca = _film.where((f) {
      final titolo = (f['testo'] ?? '').toString().toLowerCase();
      return titolo.contains(_searchQuery.toLowerCase());
    }).toList();

    final filmDaVedere = filmFiltratiPerRicerca
        .where((f) => f['visto'] == null || f['visto'] == false)
        .toList();
    final filmVisti = filmFiltratiPerRicerca
        .where((f) => f['visto'] != null && f['visto'] != false)
        .toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('I Miei Film'),
          backgroundColor: const Color(0xFF27272A),
          actions: [
            IconButton(
              icon: const Icon(Icons.pie_chart, color: Colors.blueAccent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecapScreen(filmList: _film),
                ),
              ),
              tooltip: 'Statistiche',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
              tooltip: 'Esci',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Tutti'),
              Tab(text: 'Da Vedere'),
              Tab(text: 'Visti'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Cerca tra i tuoi film...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                        filled: true,
                        fillColor: const Color(0xFF27272A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                      tooltip: _isGridView ? 'Passa alla Lista' : 'Passa alla Griglia',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                  : TabBarView(
                      children: [
                        _buildContenutoFilm(filmFiltratiPerRicerca),
                        _buildContenutoFilm(filmDaVedere),
                        _buildContenutoFilm(filmVisti),
                      ],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostraModaleRicercaIntelligente,
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}