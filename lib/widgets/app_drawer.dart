import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final List<String> cartelle;
  final String cartellaAttuale;
  final Function(String) onCartellaSelezionata;
  final VoidCallback onNuovaCartellaRichiesta;
  // --- NUOVE CALLBACK PER MODIFICA E ELIMINAZIONE ---
  final Function(String) onModificaCartellaRichiesta;
  final Function(String) onEliminaCartellaRichiesta;

  const AppDrawer({
    super.key,
    required this.cartelle,
    required this.cartellaAttuale,
    required this.onCartellaSelezionata,
    required this.onNuovaCartellaRichiesta,
    required this.onModificaCartellaRichiesta,
    required this.onEliminaCartellaRichiesta,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF18181B),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF27272A)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.movie, size: 48, color: Colors.redAccent),
                  SizedBox(height: 8),
                  Text('PIATTAFORMA FILM', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.white),
            title: const Text('Tutti i Film', style: TextStyle(color: Colors.white, fontSize: 16)),
            selected: cartellaAttuale == 'Tutti',
            // ignore: deprecated_member_use
            selectedTileColor: Colors.redAccent.withOpacity(0.2),
            onTap: () {
              onCartellaSelezionata('Tutti');
              Navigator.pop(context);
            },
          ),
          const Divider(color: Colors.grey),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('LE TUE LISTE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: cartelle.length,
              itemBuilder: (context, index) {
                final nomeCartella = cartelle[index];
                return ListTile(
                  leading: const Icon(Icons.folder, color: Colors.grey),
                  title: Text(nomeCartella, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                  selected: cartellaAttuale == nomeCartella,
                  // ignore: deprecated_member_use
                  selectedTileColor: Colors.redAccent.withOpacity(0.2),
                  onTap: () {
                    onCartellaSelezionata(nomeCartella);
                    Navigator.pop(context);
                  },
                  // --- ICONE DI MODIFICA E ELIMINAZIONE ---
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                        onPressed: () {
                          Navigator.pop(context); // Chiudiamo il drawer
                          onModificaCartellaRichiesta(nomeCartella); // Apriamo il popup
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          Navigator.pop(context); 
                          onEliminaCartellaRichiesta(nomeCartella);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.redAccent),
            title: const Text('Nuova cartella...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              onNuovaCartellaRichiesta();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}