import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _film = [];
  bool _isLoading = true;

  // NUOVO: Variabili per gestire la ricerca
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
        setState(() {
          _film = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
    // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> _aggiungiFilm(String titolo) async {
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
        body: jsonEncode({'testo': titolo}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchFilm();
        // Svuotiamo la ricerca quando aggiungiamo un nuovo film
        _searchController.clear();
        setState(() => _searchQuery = '');
      }
    // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> _eliminaFilm(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/film/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 && response.statusCode != 204)
        // ignore: curly_braces_in_flow_control_structures
        _fetchFilm();
    } catch (e) {
      _fetchFilm();
    }
  }

  void _mostraDialogAggiunta() {
    final TextEditingController nuovoFilmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF27272A),
          title: const Text('Aggiungi un nuovo film'),
          content: TextField(
            controller: nuovoFilmController,
            decoration: const InputDecoration(hintText: 'Es. Interstellar'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annulla',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _aggiungiFilm(nuovoFilmController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Aggiungi',
                style: TextStyle(color: Colors.white),
              ),
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

  Widget _buildListaFilm(List<dynamic> listaFiltrata) {
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
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: listaFiltrata.length,
        itemBuilder: (context, index) {
          final film = listaFiltrata[index];
          final isVisto = film['visto'] != null && film['visto'] != false;

          return Dismissible(
            key: Key(film['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
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
                    content: Text("Vuoi davvero eliminare '${film['testo']}'?"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          "Annulla",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text(
                          "Elimina",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            onDismissed: (direction) {
              setState(() => _film.removeWhere((f) => f['id'] == film['id']));
              _eliminaFilm(film['id']);
            },
            child: Card(
              color: const Color(0xFF27272A),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  film['testo'] ?? 'Senza titolo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isVisto ? Colors.grey : Colors.white,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    isVisto ? Icons.visibility : Icons.visibility_off,
                    color: isVisto ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => _toggleVisto(film['id'], isVisto),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. PRIMO FILTRO: Ricerca testuale
    final filmFiltratiPerRicerca = _film.where((f) {
      final titolo = (f['testo'] ?? '').toString().toLowerCase();
      return titolo.contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. SECONDO FILTRO: Separiamo i film trovati tra Visti e Da Vedere per i Tab
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
            // NUOVO ELEMENTO: La barra di ricerca
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cerca un film...',
                  prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                  // Mostriamo la "X" per pulire la ricerca solo se c'è del testo scritto
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
            // La lista dei film occupa lo spazio rimanente
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    )
                  : TabBarView(
                      children: [
                        _buildListaFilm(filmFiltratiPerRicerca),
                        _buildListaFilm(filmDaVedere),
                        _buildListaFilm(filmVisti),
                      ],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostraDialogAggiunta,
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
