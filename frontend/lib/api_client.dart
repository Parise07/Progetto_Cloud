import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

/// Unico punto di uscita HTTP verso il backend.
///
/// Si occupa da solo dell'autenticazione: allega il token, lo rinnova prima
/// che scada e, se una richiesta viene comunque rifiutata perche' scaduto,
/// la ripete una volta con il token nuovo. Le pagine non devono piu' leggere
/// i token ne' costruire l'header `Authorization` a mano.
class ApiClient {
  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  // --------------------------------------------------------------------- //
  // Verbi HTTP
  // --------------------------------------------------------------------- //

  static Future<http.Response> get(String path, {bool autenticata = true}) {
    return _invia(
      (headers) => AuthService.httpClient.get(_uri(path), headers: headers),
      autenticata: autenticata,
    );
  }

  static Future<http.Response> post(String path,
      {Object? body, bool autenticata = true}) {
    return _invia(
      (headers) => AuthService.httpClient.post(
        _uri(path),
        headers: {'Content-Type': 'application/json', ...headers},
        body: body == null ? null : jsonEncode(body),
      ),
      autenticata: autenticata,
    );
  }

  static Future<http.Response> put(String path,
      {Object? body, bool autenticata = true}) {
    return _invia(
      (headers) => AuthService.httpClient.put(
        _uri(path),
        headers: {'Content-Type': 'application/json', ...headers},
        body: body == null ? null : jsonEncode(body),
      ),
      autenticata: autenticata,
    );
  }

  static Future<http.Response> delete(String path, {bool autenticata = true}) {
    return _invia(
      (headers) => AuthService.httpClient.delete(_uri(path), headers: headers),
      autenticata: autenticata,
    );
  }

  /// Invia una richiesta multipart (upload di file).
  ///
  /// Richiede una *funzione* che costruisca la richiesta, non la richiesta
  /// stessa: una `MultipartRequest` gia' inviata non e' riutilizzabile, quindi
  /// per l'eventuale secondo tentativo va ricostruita da zero.
  static Future<http.Response> multipart(
    http.MultipartRequest Function() costruisci, {
    bool autenticata = true,
  }) {
    return _invia(
      (headers) async {
        final richiesta = costruisci();
        richiesta.headers.addAll(headers);
        final streamed = await AuthService.httpClient.send(richiesta);
        return http.Response.fromStream(streamed);
      },
      autenticata: autenticata,
    );
  }

  // --------------------------------------------------------------------- //
  // Motore
  // --------------------------------------------------------------------- //

  /// Esegue la richiesta gestendo token, rinnovo e singolo nuovo tentativo.
  static Future<http.Response> _invia(
    Future<http.Response> Function(Map<String, String> headers) esegui, {
    required bool autenticata,
  }) async {
    if (!autenticata) return esegui(const {});

    // Rinnovo proattivo: se il token sta per scadere viene sostituito prima
    // ancora di partire, cosi' il 401 non si verifica affatto.
    String? token = await AuthService.accessTokenValido();
    var risposta = await esegui(_headerAuth(token));

    if (risposta.statusCode != 401) return risposta;

    final codice = AuthErrorCode.fromResponse(risposta);

    if (codice == AuthErrorCode.refreshExpired) {
      // Il backend ha gia' stabilito che la sessione non e' recuperabile.
      await AuthService.invalidaSessione();
      return risposta;
    }

    // Reattivo: il token era scaduto (o il server non ha specificato il
    // motivo). Si tenta un rinnovo e si ripete la richiesta una volta sola,
    // per non innescare cicli in caso di 401 permanente.
    final rinnovato = await AuthService.rinnova();
    if (!rinnovato) {
      if (!AuthService.isLoggedIn) {
        debugPrint('Sessione terminata: e\' necessario un nuovo login.');
      }
      return risposta;
    }

    token = AuthService.accessToken;
    risposta = await esegui(_headerAuth(token));

    if (risposta.statusCode == 401 &&
        AuthErrorCode.fromResponse(risposta) == AuthErrorCode.tokenInvalid) {
      // Token rifiutato anche subito dopo il rinnovo: sessione non valida.
      await AuthService.invalidaSessione();
    }
    return risposta;
  }

  static Map<String, String> _headerAuth(String? token) =>
      token == null ? const {} : {'Authorization': 'Bearer $token'};
}
