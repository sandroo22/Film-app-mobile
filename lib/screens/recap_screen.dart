import 'package:flutter/material.dart';

class RecapScreen extends StatelessWidget {
  final List<dynamic> filmList;

  const RecapScreen({super.key, required this.filmList});

  @override
  Widget build(BuildContext context) {
    // Calcoliamo le statistiche
    final totaleFilm = filmList.length;
    final filmVisti = filmList.where((f) => f['visto'] != null && f['visto'] != false).toList();
    final numeroVisti = filmVisti.length;
    
    // Stima: calcoliamo circa 2 ore (120 minuti) per ogni film visto
    final oreTotali = numeroVisti * 2; 

    // Prendiamo gli ultimi 5 film aggiunti (invertiamo la lista per avere i più recenti in cima)
    final ultimiAggiunti = filmList.reversed.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie Statistiche'),
        backgroundColor: const Color(0xFF27272A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Il tuo Recap",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),

            // GRIGLIA DELLE STATISTICHE
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    titolo: "Film Visti",
                    valore: "$numeroVisti",
                    icona: Icons.remove_red_eye,
                    colore: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    titolo: "Ore Spese",
                    valore: "$oreTotali h",
                    icona: Icons.access_time_filled,
                    colore: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              titolo: "Film totali in libreria",
              valore: "$totaleFilm",
              icona: Icons.local_movies,
              colore: Colors.redAccent,
            ),
            
            const SizedBox(height: 40),

            // SEZIONE ULTIMI AGGIUNTI
            const Text(
              "Ultimi 5 film aggiunti",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            if (ultimiAggiunti.isEmpty)
              const Text("Non hai ancora aggiunto film.", style: TextStyle(color: Colors.grey))
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
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.movie, color: Colors.white, size: 20),
                      ),
                      title: Text(film['testo'] ?? 'Senza titolo', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        isVisto ? 'Già visto' : 'Da vedere',
                        style: TextStyle(color: isVisto ? Colors.green : Colors.orange),
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

  // Widget riutilizzabile per le Card delle statistiche
  Widget _buildStatCard({required String titolo, required String valore, required IconData icona, required Color colore}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: colore.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, color: colore, size: 32),
          const SizedBox(height: 12),
          Text(valore, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(titolo, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
