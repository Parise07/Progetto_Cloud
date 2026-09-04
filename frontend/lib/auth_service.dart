import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'shared_preferences.dart';

/// Codici applicativi restituiti dal backend insieme al 401/503.
///
/// Rispecchiano `AuthErrorCode` in `Backend/autentication/keycloack_service.py`
/// e servono a distinguere "rinnova il token" da "la sessione e' persa".
class AuthErrorCode {
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const tokenInvalid = 'TOKEN_INVALID';
  static const refreshExpired = 'REFRESH_EXPIRED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const authUnavailable = 'AUTH_UNAVAILABLE';

  /// Estrae il codice dal corpo della risposta, se presente.
  static String? fromResponse(http.Response response) {
    try {
      final detail = jsonDecode(response.body)['detail'];
      if (detail is Map && detail['code'] is String) return detail['code'];
    } catch (_) {
      // Corpo non JSON o forma inattesa: nessun codice da estrarre.
    }
    return null;
  }
}

/// Gestisce la sessione dell'utente: memorizza i token, li rinnova prima che
/// scadano e chiude la sessione quando il refresh non e' piu' utilizzabile.
///
/// Il rinnovo e' *single-flight*: piu' richieste che scoprono insieme il token
/// scaduto attendono tutte lo stesso refresh invece di lanciarne uno ciascuna.
/// Serve gia' oggi per non moltiplicare le chiamate a Keycloak, e diventera'
/// indispensabile quando sul realm verra' attivato `Revoke Refresh Token`:
/// con la rotazione stretta due refresh paralleli si invaliderebbero a vicenda,
/// buttando fuori l'utente.
class AuthService {
  static const _kAccess = 'access';
  static const _kRefresh = 'refresh';
  static const _kAccessExpiresAt = 'access_expires_at';
  static const _kRefreshExpiresAt = 'refresh_expires_at';

  /// Quanto prima della scadenza conviene rinnovare, per non far partire
  /// richieste con un token che scade mentre sono in volo.
  static const Duration _margine = Duration(seconds: 60);

  /// Refresh in corso, condiviso da tutti i chiamanti concorrenti.
  static Future<bool>? _refreshInCorso;

  /// Client HTTP condiviso con [ApiClient]. Sostituibile nei test.
  static http.Client httpClient = http.Client();

  /// Notifica alla UI i cambi di stato della sessione, cosi' le pagine possono
  /// aggiornarsi anche quando la sessione cade durante una richiesta.
  static final ValueNotifier<bool> sessioneAttiva = ValueNotifier<bool>(false);

  // --------------------------------------------------------------------- //
  // Stato
  // --------------------------------------------------------------------- //

  static String? get accessToken =>
      SharedPreferenceManager.instance.getString(_kAccess);

  static String? get refreshToken =>
      SharedPreferenceManager.instance.getString(_kRefresh);

  /// True se esiste un refresh token ancora spendibile.
  ///
  /// Si basa sul refresh e non sull'access token: quest'ultimo puo' essere
  /// scaduto senza che la sessione lo sia, ed e' esattamente il caso che il
  /// rinnovo automatico deve rendere invisibile all'utente.
  static bool get isLoggedIn {
    if (refreshToken == null) return false;
    final scadenza =
        SharedPreferenceManager.instance.getInt(_kRefreshExpiresAt);
    if (scadenza == null) return true; // sessione salvata da una versione precedente
    return DateTime.now().millisecondsSinceEpoch < scadenza;
  }

  /// Allinea il notifier allo stato salvato. Da chiamare all'avvio dell'app.
  static void init() {
    sessioneAttiva.value = isLoggedIn;
  }

  // --------------------------------------------------------------------- //
  // Persistenza dei token
  // --------------------------------------------------------------------- //

  /// Salva la coppia di token e le rispettive scadenze.
  ///
  /// Va usata sia dopo il login sia dopo ogni refresh: Keycloak emette sempre
  /// un refresh token nuovo, quindi sovrascrivere solo l'access token
  /// significherebbe conservare un refresh destinato a diventare inutilizzabile.
  static Future<void> salvaSessione(Map<String, dynamic> body) async {
    final prefs = SharedPreferenceManager.instance;
    final ora = DateTime.now().millisecondsSinceEpoch;

    final access = body['access_token'] as String?;
    final refresh = body['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw const FormatException('Risposta di autenticazione senza token');
    }

    final expiresIn = (body['expires_in'] as num?)?.toInt();
    final refreshExpiresIn = (body['refresh_expires_in'] as num?)?.toInt();

    // Le scadenze sono calcolate sull'orologio locale a partire dalle durate
    // restituite dal server: evita di dipendere dalla sincronizzazione fra
    // l'ora del dispositivo e quella di Keycloak.
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
    if (expiresIn != null) {
      await prefs.setInt(_kAccessExpiresAt, ora + expiresIn * 1000);
    }
    if (refreshExpiresIn != null) {
      await prefs.setInt(_kRefreshExpiresAt, ora + refreshExpiresIn * 1000);
    }

    sessioneAttiva.value = true;
  }

  /// Cancella la sessione locale, lasciando intatte le altre preferenze.
  static Future<void> _pulisciSessione() async {
    final prefs = SharedPreferenceManager.instance;
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kAccessExpiresAt);
    await prefs.remove(_kRefreshExpiresAt);
    sessioneAttiva.value = false;
  }

  // --------------------------------------------------------------------- //
  // Rinnovo
  // --------------------------------------------------------------------- //

  static bool get _accessInScadenza {
    final scadenza = SharedPreferenceManager.instance.getInt(_kAccessExpiresAt);
    if (scadenza == null) return true; // scadenza ignota: meglio rinnovare
    final limite = DateTime.now().add(_margine).millisecondsSinceEpoch;
    return limite >= scadenza;
  }

  /// Restituisce un access token utilizzabile, rinnovandolo se sta per scadere.
  ///
  /// E' il rinnovo *proattivo*: l'utente non incontra mai il 401, perche' il
  /// token viene sostituito prima che il server lo rifiuti.
  static Future<String?> accessTokenValido() async {
    if (refreshToken == null) return accessToken;
    if (accessToken != null && !_accessInScadenza) return accessToken;

    await rinnova();
    return accessToken;
  }

  /// Rinnova la coppia di token. Piu' chiamate concorrenti condividono
  /// lo stesso rinnovo e ne attendono l'esito.
  ///
  /// :return: true se al termine esiste un access token valido
  static Future<bool> rinnova() {
    // Se un rinnovo e' gia' partito, ci si accoda invece di lanciarne un altro.
    final inCorso = _refreshInCorso;
    if (inCorso != null) return inCorso;

    final futuro = _eseguiRinnovo();
    _refreshInCorso = futuro;
    // Il "lucchetto" va rilasciato in ogni caso, anche in caso di errore, ma
    // solo se nel frattempo non e' gia' partito un rinnovo successivo: azzerarlo
    // alla cieca lascerebbe quel rinnovo senza protezione.
    return futuro.whenComplete(() {
      if (identical(_refreshInCorso, futuro)) _refreshInCorso = null;
    });
  }

  static Future<bool> _eseguiRinnovo() async {
    final refresh = refreshToken;
    if (refresh == null) return false;

    try {
      final response = await httpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/utente/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );

      if (response.statusCode == 200) {
        await salvaSessione(jsonDecode(response.body) as Map<String, dynamic>);
        return true;
      }

      final codice = AuthErrorCode.fromResponse(response);
      if (codice == AuthErrorCode.authUnavailable || response.statusCode >= 500) {
        // Problema temporaneo del server di autenticazione: la sessione e'
        // probabilmente ancora valida, quindi non si slogga l'utente.
        debugPrint('Refresh non riuscito, server non disponibile: riprovare.');
        return false;
      }

      // REFRESH_EXPIRED o token non piu' accettato: la sessione e' finita.
      debugPrint('Sessione scaduta ($codice): necessario un nuovo login.');
      await _pulisciSessione();
      return false;
    } catch (e) {
      // Errore di rete: come sopra, non e' un motivo per chiudere la sessione.
      debugPrint('Errore di rete durante il refresh: $e');
      return false;
    }
  }

  // --------------------------------------------------------------------- //
  // Login / logout
  // --------------------------------------------------------------------- //

  /// Chiude la sessione revocando il refresh token su Keycloak.
  ///
  /// La pulizia locale avviene comunque, anche se la chiamata di revoca
  /// fallisce: dal punto di vista dell'utente il logout non deve mai fallire.
  static Future<void> logout() async {
    final refresh = refreshToken;
    if (refresh != null) {
      try {
        await httpClient.post(
          Uri.parse('${ApiConfig.baseUrl}/utente/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refresh}),
        );
      } catch (e) {
        debugPrint('Revoca del token non riuscita: $e');
      }
    }
    await _pulisciSessione();
  }

  /// Invalida la sessione locale senza contattare il server.
  ///
  /// Usata da [ApiClient] quando il backend segnala che il token non e' piu'
  /// accettabile: a quel punto la revoca sarebbe inutile.
  static Future<void> invalidaSessione() => _pulisciSessione();
}
