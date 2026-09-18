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
  
  // NUOVA VARIABILE: Memorizza il tipo di ordinamento attuale
  String _ordinamento = 'aggiunta';

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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titolo aggiornato!'), backgroundColor: Colors.green));
      }
    } catch (e) {}
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
        body: jsonEncode({'testo': titolo, 'copertina': copertina}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchFilm();
        _searchController.clear();
        setState(() => _searchQuery = '');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$titolo" aggiunto!'), backgroundColor: Colors.green));
      }
    } catch (e) {}
  }

  Future<void> _eliminaFilm(int id) async {
    setState(() => _film.removeWhere((f) => f['id'] == id));
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/film/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) _fetchFilm();
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
          title: const Text('Elimina Film', style: TextStyle(color: Colors.white)),
          content: Text('Sicuro di voler eliminare "$titolo"?', style: const TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _eliminaFilm(id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Elimina', style: TextStyle(color: Colors.white)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return AddFilmModal(onFilmSelected: (filmData) => _aggiungiFilm(filmData['testo'], filmData['copertina']));
      },
    );
  }

  void _mostraDialogModifica(int id, String titoloCorrente) {
    final TextEditingController modificaController = TextEditingController(text: titoloCorrente);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF27272A),
          title: const Text('Modifica film', style: TextStyle(color: Colors.white)),
          content: TextField(controller: modificaController, style: const TextStyle(color: Colors.white), autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
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
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Widget _buildContenutoFilm(List<dynamic> listaFiltrata) {
    if (listaFiltrata.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: _fetchFilm,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 150), Center(child: Text("Nessun film trovato.", style: TextStyle(fontSize: 18, color: Colors.grey)))],
        ),
      );
    }
    return RefreshIndicator(color: Colors.redAccent, onRefresh: _fetchFilm, child: _isGridView ? _buildGriglia(listaFiltrata) : _buildLista(listaFiltrata));
  }

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
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF27272A),
                title: const Text('Elimina', style: TextStyle(color: Colors.white)),
                content: Text('Vuoi rimuovere "${film['testo']}"?', style: const TextStyle(color: Colors.grey)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Elimina')),
                ],
              ),
            );
          },
          onDismissed: (direction) => _eliminaFilm(film['id']),
          child: FilmListItem(
            film: film,
            apiKey: _tmdbApiKey,
            onToggleVisto: () => _toggleVisto(film['id'], film['visto'] != null && film['visto'] != false),
            onEdit: () => _mostraDialogModifica(film['id'], film['testo'] ?? ''),
            onDelete: () => _confermaEliminazione(film['id'], film['testo'] ?? ''),
          ),
        );
      },
    );
  }

  Widget _buildGriglia(List<dynamic> listaFiltrata) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: listaFiltrata.length,
      itemBuilder: (context, index) {
        final film = listaFiltrata[index];
        return FilmGridItem(
          film: film,
          apiKey: _tmdbApiKey,
          onToggleVisto: () => _toggleVisto(film['id'], film['visto'] != null && film['visto'] != false),
          onEdit: () => _mostraDialogModifica(film['id'], film['testo'] ?? ''),
          onDelete: () => _confermaEliminazione(film['id'], film['testo'] ?? ''),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Applichiamo la ricerca
    var filmFiltrati = _film.where((f) => (f['testo'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    // 2. APPLICHIAMO L'ORDINAMENTO SCELTO
    if (_ordinamento == 'az') {
      filmFiltrati.sort((a, b) => (a['testo'] ?? '').toString().toLowerCase().compareTo((b['testo'] ?? '').toString().toLowerCase()));
    } else if (_ordinamento == 'za') {
      filmFiltrati.sort((a, b) => (b['testo'] ?? '').toString().toLowerCase().compareTo((a['testo'] ?? '').toString().toLowerCase()));
    } else {
      // Ordine di aggiunta (dal più recente al più vecchio basandosi sull'ID del DB)
      filmFiltrati.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    }

    // 3. Dividiamo le liste per i Tab
    final filmDaVedere = filmFiltrati.where((f) => f['visto'] == null || f['visto'] == false).toList();
    final filmVisti = filmFiltrati.where((f) => f['visto'] != null && f['visto'] != false).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('I Miei Film'),
          backgroundColor: const Color(0xFF27272A),
          actions: [
            IconButton(
              icon: const Icon(Icons.pie_chart, color: Colors.blueAccent),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecapScreen(filmList: _film))),
            ),
            IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _logout),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'Tutti'), Tab(text: 'Da Vedere'), Tab(text: 'Visti')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // BARRA DI RICERCA
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Cerca...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                        filled: true,
                        fillColor: const Color(0xFF27272A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // MENU A TENDINA PER L'ORDINAMENTO
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _ordinamento,
                        dropdownColor: const Color(0xFF27272A),
                        icon: const Icon(Icons.sort, color: Colors.white),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _ordinamento = newValue);
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'aggiunta', child: Text(' Recenti')),
                          DropdownMenuItem(value: 'az', child: Text(' A - Z')),
                          DropdownMenuItem(value: 'za', child: Text(' Z - A')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // TASTO LISTA/GRIGLIA
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white), onPressed: () => setState(() => _isGridView = !_isGridView)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.redAccent)) : TabBarView(children: [_buildContenutoFilm(filmFiltrati), _buildContenutoFilm(filmDaVedere), _buildContenutoFilm(filmVisti)]),
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