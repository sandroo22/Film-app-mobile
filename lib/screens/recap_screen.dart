import 'package:flutter/material.dart';

class RecapScreen extends StatelessWidget {
  final List<dynamic> filmList;

  const RecapScreen({super.key, required this.filmList});

  @override
  Widget build(BuildContext context) {
    // 1. Calcoli per le statistiche principali
    final int totaleFilm = filmList.length;
    final int visti = filmList.where((f) => f['visto'] != null && f['visto'] != false).length;
    final int daVedere = totaleFilm - visti;
    
    // 2. Calcolo Tempo Speso (Formattato in Ore e Minuti come su React)
    final int minutiTotali = visti * 120;
    final int oreSpese = minutiTotali ~/ 60;
    final int minutiSpesi = minutiTotali % 60;

    // 3. Ultimi 5 film aggiunti (in ordine cronologico inverso)
    final ultimiAggiunti = filmList.reversed.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF27272A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Benvenuto nella tua Dashboard",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),

            // GRIGLIA 2x2 PER LE STATISTICHE
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  titolo: "Totale Film",
                  valore: "$totaleFilm",
                  icona: Icons.movie_filter,
                  colore: Colors.blueAccent,
                ),
                _buildStatCard(
                  titolo: "Già Visti",
                  valore: "$visti",
                  icona: Icons.check_circle,
                  colore: Colors.green,
                ),
                _buildStatCard(
                  titolo: "Da Vedere",
                  valore: "$daVedere",
                  icona: Icons.watch_later,
                  colore: Colors.orangeAccent,
                ),
                _buildStatCard(
                  titolo: "Tempo Speso",
                  valore: "${oreSpese}h ${minutiSpesi}m",
                  icona: Icons.timer,
                  colore: Colors.purpleAccent,
                ),
              ],
            ),
            
            const SizedBox(height: 40),

            // SEZIONE ULTIMI AGGIUNTI (Ora con le locandine)
            const Text(
              "Ultimi aggiunti",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            if (ultimiAggiunti.isEmpty)
              const Text("Nessun film presente.", style: TextStyle(color: Colors.grey))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), 
                itemCount: ultimiAggiunti.length,
                itemBuilder: (context, index) {
                  final film = ultimiAggiunti[index];
                  final isVisto = film['visto'] != null && film['visto'] != false;
                  
                  return Card(
                    color: const Color(0xFF27272A),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      // Mini-locandina allineata al lato sinistro
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: film['copertina'] != null
                            ? Image.network(
                                film['copertina'], 
                                width: 45, 
                                height: 65, 
                                fit: BoxFit.cover, 
                                errorBuilder: (c, e, s) => Container(width: 45, color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54))
                              )
                            : Container(width: 45, color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54)),
                      ),
                      title: Text(film['testo'] ?? 'Senza titolo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        isVisto ? 'Già visto' : 'Da vedere',
                        style: TextStyle(color: isVisto ? Colors.green : Colors.orangeAccent),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // WIDGET CARD RIUTILIZZABILE (Design aggiornato)
  Widget _buildStatCard({required String titolo, required String valore, required IconData icona, required Color colore}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: colore.withOpacity(0.3), width: 2),
        boxShadow: [
          // ignore: deprecated_member_use
          BoxShadow(color: colore.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, color: colore, size: 30),
          const Spacer(),
          Text(valore, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(titolo, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}