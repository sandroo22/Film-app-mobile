import 'package:flutter/material.dart';

class ReviewModal extends StatefulWidget {
  // Questa funzione ci permette di "passare" i dati (voto e testo)
  // alla schermata principale una volta che l'utente clicca Salva.
  final Function(int voto, String testo) onSave;

  const ReviewModal({super.key, required this.onSave});

  @override
  State<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends State<ReviewModal> {
  int _votoSelezionato = 0;
  final TextEditingController _testoController = TextEditingController();

  @override
  void dispose() {
    _testoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Il viewInsets.bottom serve a spingere in alto il popup quando si apre la tastiera!
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "La tua Recensione",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // SEZIONE STELLINE
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _votoSelezionato ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                ),
                onPressed: () {
                  setState(() {
                    _votoSelezionato = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          
          // CAMPO DI TESTO
          TextField(
            controller: _testoController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Scrivi cosa ne pensi del film...",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // BOTTONE SALVA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // Quando clicchi salva, passa i dati al componente padre e chiude il popup
                widget.onSave(_votoSelezionato, _testoController.text);
                Navigator.pop(context);
              },
              child: const Text(
                "Salva Recensione",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}