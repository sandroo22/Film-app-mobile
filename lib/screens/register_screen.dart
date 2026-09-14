import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
// IMPORTAZIONI FONDAMENTALI PER IL WEB
import 'package:google_sign_in_web/web_only.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confermaPasswordController = TextEditingController();
  
  bool _isLoading = false;
  
  // Variabili per la visibilità delle password
  bool _isPasswordVisible = false;
  bool _isConfermaPasswordVisible = false;

  // VARIABILI PER GOOGLE
  bool _isGoogleReady = false; 
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _accendiMotoreGoogle(); // Inizializza Google all'avvio della pagina
  }

  // --- FUNZIONE: AVVIO DI GOOGLE (Identica al Login) ---
  Future<void> _accendiMotoreGoogle() async {
    try {
      await _googleSignIn.initialize(
        clientId: '499726248211-ufrhid1p5eg6qkifjmu868q7hv5mhmme.apps.googleusercontent.com',
      );

      // Pulisce la memoria web per evitare blocchi
      if (kIsWeb) {
        try { await _googleSignIn.signOut(); } catch (_) {}
      }
      
      // Si mette in ascolto degli eventi di autenticazione
      _googleSignIn.authenticationEvents.listen((GoogleSignInAuthenticationEvent event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn(:final user):
            _inviaTokenGoogleAlServer(user);
          case GoogleSignInAuthenticationEventSignOut():
            break;
        }
      });
      
      // Mostra il bottone
      if (mounted) setState(() => _isGoogleReady = true);
      
    } catch (e) {
      // ignore: avoid_print
      print("Errore Google Init: $e");
    }
  }

  // --- FUNZIONE: INVIA TOKEN AL SERVER ---
  Future<void> _inviaTokenGoogleAlServer(GoogleSignInAccount googleUser) async {
    setState(() => _isLoading = true);

    try {
      // ignore: await_only_futures
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final response = await http.post(
          Uri.parse('http://localhost:5000/api/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);

          if (data['refreshToken'] != null) {
            await _storage.write(
              key: 'refresh_token_${googleUser.email}',
              value: data['refreshToken'],
            );
          }

          List<String> emails = prefs.getStringList('saved_emails_list') ?? [];
          if (!emails.contains(googleUser.email)) {
            emails.add(googleUser.email);
            await prefs.setStringList('saved_emails_list', emails);
          }

          if (mounted) {
            // Entra in dashboard e cancella la cronologia di navigazione
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorData['errore'] ?? 'Errore dal server'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la registrazione con Google'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNZIONE: REGISTRAZIONE CLASSICA (Il tuo codice originale intatto) ---
  Future<void> _registrati() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confermaPassword = _confermaPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compila tutti i campi'), backgroundColor: Colors.redAccent));
      return;
    }

    if (password != confermaPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le password non coincidono!'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrazione completata! Ora puoi accedere.'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['errore'] ?? 'Errore durante la registrazione'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile connettersi al server.'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNZIONE: REGISTRAZIONE CON GOOGLE DA MOBILE ---
  Future<void> _registratiConGoogle() async {
    setState(() => _isLoading = true);
    try {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      await _inviaTokenGoogleAlServer(googleUser);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante la registrazione con Google'), backgroundColor: Colors.redAccent));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_add, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                "Crea un Account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Unisciti alla Piattaforma Film",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // CAMPO EMAIL
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.grey),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // CAMPO PASSWORD
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CAMPO CONFERMA PASSWORD
              TextField(
                controller: _confermaPasswordController,
                obscureText: !_isConfermaPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Conferma Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfermaPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfermaPasswordVisible = !_isConfermaPasswordVisible;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // BOTTONE REGISTRATI
              ElevatedButton(
                onPressed: _isLoading ? null : _registrati,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Registrati",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text("OPPURE", style: TextStyle(color: Colors.grey, fontSize: 12))),
                  Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),

              // ==========================================
              // BOTTONE GOOGLE (Gestisce Web e Mobile in automatico)
              // ==========================================
              kIsWeb
                  ? SizedBox(
                      height: 44, 
                      child: _isGoogleReady 
                          ? web.renderButton() 
                          : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                    )
                  : OutlinedButton.icon(
                      onPressed: _isLoading ? null : _registratiConGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                      label: const Text("Registrati con Google", style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),

              const SizedBox(height: 16),
              
              // LINK TORNA AL LOGIN
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Hai già un account? Accedi",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}