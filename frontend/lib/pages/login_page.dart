import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import '../api_config.dart';
import '../shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

class LoginScreen extends StatefulWidget {
  final bool popAfterLogin;

  const LoginScreen({super.key, this.popAfterLogin = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final loginUsername = TextEditingController();
  final loginPassword = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final email = TextEditingController();

  bool _nascondiPasswordLogin = true;
  bool _nascondiPasswordRegistrazione = true;

  @override
  void initState(){
    super.initState();
  }



  //funzione per il login
  Future<void> Login() async{
      String usernametxt = loginUsername.text;
      String passwordtxt = loginPassword.text;

      if (usernametxt.isEmpty || passwordtxt.isEmpty) {
        showErrorDialog('Compila tutti i campi per effettuare il login.');
        return;
      }

      Map<String, dynamic> loginData = {
        'username': usernametxt,
        'password': passwordtxt,
      };

      String formData = loginData.entries
          .map<String>((e) =>
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      try {
        final responseLogin = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/utente/login'), // L'URL della tua nuova rotta!
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(loginData),
        );

        if (responseLogin.statusCode == 200) {
          var responseBody = jsonDecode(responseLogin.body);
          String accessToken = responseBody['access_token'];
          String refreshToken = responseBody['refresh_token'];

          SharedPreferences storage = await SharedPreferences.getInstance();
          await storage.setString('access', accessToken);
          await storage.setString('refresh', refreshToken);

          if (!mounted) return;
          showSuccessDialog("Accesso effettuato con successo bentornato user : $usernametxt");

        } else {
          if (!mounted) return; // Protezione anche per il dialog!
          showErrorDialog('Username o password non corretta: ${responseLogin.body}');
        }
      } catch (e) {
        print('Eccezione durante il login: $e');
        showErrorDialog('Errore di rete durante il login');
      }
  }



  //funzione per il signin
  Future<void> SignIn() async{
    String usernametext = username.text;
    String passwordtext = password.text;
    String emailtext = email.text;


    if (usernametext.isEmpty || passwordtext.isEmpty || emailtext.isEmpty ) {
      showErrorDialog('Compila tutti i campi per effettuare la registrazione.');
      return;
    }

    Map<String, dynamic> utenteData = {
      'username': usernametext,
      'email': emailtext,
      'password': passwordtext,
    };

    String url = '${ApiConfig.baseUrl}/utente/addUtente';
    try {
      final responseSignin = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(utenteData),
      );

      if (responseSignin.statusCode == 200) {
        await Login();
        showSuccessDialog('Utente registrato con successo');
      } else {
        showErrorDialog('Impossibile registrarsi: ${responseSignin.body}');
      }
    } catch (e) {
      print('Eccezione durante la registrazione: $e');
      showErrorDialog('Errore di rete durante la registrazione');
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Errore'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Successo'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.popAfterLogin) {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    const double width = 850;
    const double height = 500;

    // APP BAR
    return Scaffold(
      backgroundColor: coloreSfondo,
      body: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorePrincipale,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorePrincipale.withAlpha(80),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [

              // Forma animata

              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: -200,
                bottom: -200,

                left: _isLogin ? width * 0.48 : -width * 0.28,
                child: Transform.rotate(
                  angle: 0.12, // Inclinazione della diagonale
                  child: Container(
                    width: width * 0.8, // Larghezza della banda arancione
                    color: coloreAccento,
                  ),
                ),
              ),


              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: _isLogin ? width / 2 : width, // Scivola fuori a destra
                width: width / 2,
                child: _buildInfoText(
                  title: 'BENTORNATO!',
                  subtitle: 'Siamo felici di riaverti con noi.\nAccedi per esplorare l\'archivio.',
                  isRightSide: true,
                  isVisible: _isLogin,
                ),
              ),


              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: !_isLogin ? 0 : -width / 2,
                width: width / 2,
                child: _buildInfoText(
                  title: 'BENVENUTO!',
                  subtitle: 'Unisciti a noi per archiviare e cercare\nnotizie con la potenza dell\'IA.',
                  isRightSide: false,
                  isVisible: !_isLogin,
                ),
              ),

              //  Schermata login grafica

              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: _isLogin ? 0 : -width / 2,
                width: width / 2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _isLogin ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isLogin,
                    child: Stack(
                      children: [
                        // --- TASTO "X" IN ALTO A SINISTRA ---
                        Positioned(
                          top: 16,
                          left: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Login', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 30),
                              _buildTextField('Username', Icons.person, loginUsername),
                              const SizedBox(height: 20),
                              _buildTextField('Password', Icons.lock, loginPassword, isPassword: true, obscureText: _nascondiPasswordLogin,
                                onToggleVisibility: () {
                                  setState(() {
                                    _nascondiPasswordLogin = !_nascondiPasswordLogin;
                                  });
                                },),
                              const SizedBox(height: 24),
                              _buildSubmitButton('Accedi', () => Login()),
                              const SizedBox(height: 20),
                              _buildToggleText("Non hai un account? ", "Registrati", () => setState(() => _isLogin = false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),


              // Registrazione schermata grafica

              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: !_isLogin ? width / 2 : width,
                width: width / 2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: !_isLogin ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: _isLogin,
                    child: Stack(
                      children: [
                        // --- TASTO "X" IN ALTO A DESTRA ---
                        Positioned(
                          top: 16,
                          right: 16, // <-- Posizionato a destra!
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                            onPressed: () => Navigator.pop(context), // Chiude il form
                          ),
                        ),
                        // --- CONTENUTO DEL FORM ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Registrati', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 30),
                              _buildTextField('Username', Icons.person, username),
                              const SizedBox(height: 20),
                              _buildTextField('Email', Icons.email, email),
                              const SizedBox(height: 20),
                              _buildTextField('Password', Icons.lock, password, isPassword: true,
                                obscureText: _nascondiPasswordLogin,
                                onToggleVisibility: () {
                                  setState(() {
                                    _nascondiPasswordLogin = !_nascondiPasswordLogin;
                                  });
                                },),
                              const SizedBox(height: 30),
                              _buildSubmitButton('Registrati', () => SignIn()),
                              const SizedBox(height: 20),
                              _buildToggleText("Hai già un account? ", "Accedi", () => setState(() => _isLogin = true)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildInfoText({required String title, required String subtitle, required bool isRightSide, required bool isVisible}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isVisible ? 1.0 : 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isRightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
              textAlign: isRightSide ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
              textAlign: isRightSide ? TextAlign.right : TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildTextField(String label, IconData icon, TextEditingController controller,{bool isPassword = false , bool? obscureText, VoidCallback? onToggleVisibility,}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? (obscureText ?? true) : false,
      style: const TextStyle(color: Colors.white),
      cursorColor: coloreAccento,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            (obscureText ?? true) ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: onToggleVisibility,
          splashColor: Colors.transparent,
        )
            : null,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white30, width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: coloreAccento, width: 2),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: coloreAccento, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildToggleText(String normalText, String clickableText, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.white70),
          children: [
            TextSpan(text: normalText),
            TextSpan(text: clickableText, style: const TextStyle(color: coloreAccento, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }


}