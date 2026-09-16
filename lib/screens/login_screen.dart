import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:async';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  TextEditingController? _emailController;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  
  bool _isGoogleReady = false; 

  List<String> _emailSalvate = [];
  bool _mostraSelettoreAccount = true;
  final _storage = const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription? _googleAuthSubscription;

  @override
  void initState() {
    super.initState();
    _caricaEmailSalvate();
    _accendiMotoreGoogle(); 
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _accendiMotoreGoogle() async {
    try {
      try {
        await _googleSignIn.initialize(
          clientId: '499726248211-ufrhid1p5eg6qkifjmu868q7hv5mhmme.apps.googleusercontent.com',
        );
      } catch (e) {
        if (e.toString().contains('init() has already been called')) {
          // ignore: avoid_print
          print("🔄 Google già inizializzato nel browser (Hot Reload). Tutto ok!");
        } else {
          rethrow;
        }
      }

      if (kIsWeb) {
        try { await _googleSignIn.signOut(); } catch (_) {}
      }
      
      _googleAuthSubscription?.cancel();
      
      _googleAuthSubscription = _googleSignIn.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _inviaTokenGoogleAlServer(event.user);
        }
      });
      
      if (mounted) setState(() => _isGoogleReady = true);
      
    } catch (e) {
      // ignore: avoid_print
      print("Errore Google Init: $e");
    }
  }

  Future<void> _caricaEmailSalvate() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> emails = prefs.getStringList('saved_emails_list') ?? [];

    setState(() {
      _emailSalvate = emails;
      if (_emailSalvate.isEmpty) {
        _mostraSelettoreAccount = false;
      }
    });
  }

  Future<void> _inviaTokenGoogleAlServer(GoogleSignInAccount googleUser) async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
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

          if (!_emailSalvate.contains(googleUser.email)) {
            _emailSalvate.add(googleUser.email);
            await prefs.setStringList('saved_emails_list', _emailSalvate);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
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
          const SnackBar(content: Text('Errore di connessione al server Node.js'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_emailController == null || _emailController!.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un\'email valida'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController!.text, 'password': _passwordController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);

        final emailUsata = _emailController!.text.trim();
        if (data['refreshToken'] != null) {
          await _storage.write(key: 'refresh_token_$emailUsata', value: data['refreshToken']);
        }
        if (!_emailSalvate.contains(emailUsata)) {
          _emailSalvate.add(emailUsata);
          await prefs.setStringList('saved_emails_list', _emailSalvate);
        }
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['errore'] ?? 'Credenziali non valide'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile connettersi al server.'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accessoSilenzioso(String emailSelezionata) async {
    setState(() => _isLoading = true);
    try {
      final refreshToken = await _storage.read(key: 'refresh_token_$emailSelezionata');
      if (refreshToken == null) {
        _forzaLoginManuale(emailSelezionata);
        return;
      }
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
      } else {
        _forzaLoginManuale(emailSelezionata, messaggio: "Sessione scaduta. Inserisci la password.");
      }
    } catch (e) {
      _forzaLoginManuale(emailSelezionata, messaggio: "Errore di rete. Riprova.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginConGoogle() async {
    setState(() => _isLoading = true);
    try {
      // FIX LINTER: rimossa la dichiarazione di tipo esplicita
      final googleUser = await _googleSignIn.authenticate();
      // ignore: dead_code, unnecessary_null_comparison
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      await _inviaTokenGoogleAlServer(googleUser);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore durante il login con Google'), backgroundColor: Colors.redAccent));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forzaLoginManuale(String email, {String? messaggio}) {
    setState(() {
      _mostraSelettoreAccount = false;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_emailController != null) _emailController!.text = email;
      });
    });
    if (messaggio != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messaggio), backgroundColor: Colors.orange));
  }

  void _passwordDimenticata() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
  }

  Widget _buildSelettoreAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Scegli un account", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        ..._emailSalvate.map(
          (email) => Card(
            color: const Color(0xFF27272A),
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person, color: Colors.white)),
              title: Text(email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              trailing: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                  : const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: _isLoading ? null : () => _accessoSilenzioso(email),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mostraSelettoreAccount = false),
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text("Usa un altro account", style: TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildFormManuale() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return _emailSalvate;
            return _emailSalvate.where((email) => email.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _emailController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email, color: Colors.grey)),
              keyboardType: TextInputType.emailAddress,
              onTap: () {
                if (controller.text.isEmpty) {
                  controller.text = ' ';
                  controller.text = '';
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey, size: 20),
                        title: Text(option, style: const TextStyle(color: Colors.white)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _passwordDimenticata,
            child: const Text('Password dimenticata?', style: TextStyle(color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Accedi", style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        if (_emailSalvate.isNotEmpty) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _mostraSelettoreAccount = true),
            child: const Text("Torna alla lista account", style: TextStyle(color: Colors.grey)),
          ),
        ],
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.grey)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text("OPPURE", style: TextStyle(color: Colors.grey, fontSize: 12))),
            Expanded(child: Divider(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 24),

        kIsWeb
            ? SizedBox(
                height: 44, 
                child: _isGoogleReady 
                    ? web.renderButton() 
                    : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
              )
            : OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginConGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                label: const Text("Accedi con Google", style: TextStyle(color: Colors.white, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
          },
          child: const Text("Non hai un account? Registrati", style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  // ECCO IL PEZZO MANCANTE CHE HO RIPRISTINATO!
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.movie, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text("Piattaforma Film", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              if (_mostraSelettoreAccount && _emailSalvate.isNotEmpty)
                _buildSelettoreAccount()
              else
                _buildFormManuale(),
            ],
          ),
        ),
      ),
    );
  }
}