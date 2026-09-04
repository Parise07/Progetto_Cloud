import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/api_client.dart';
import 'package:frontend/auth_service.dart';
import 'package:frontend/shared_preferences.dart';

/// Corpo di una risposta di login/refresh, come la restituisce il backend.
String tokenBody(String suffisso,
        {int expiresIn = 1800, int refreshExpiresIn = 2400}) =>
    jsonEncode({
      'access_token': 'access-$suffisso',
      'refresh_token': 'refresh-$suffisso',
      'token_type': 'Bearer',
      'expires_in': expiresIn,
      'refresh_expires_in': refreshExpiresIn,
    });

String erroreAuth(String codice) =>
    jsonEncode({'detail': {'code': codice, 'message': 'test'}});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferenceManager.init();
  });

  tearDown(() {
    AuthService.httpClient = http.Client();
  });

  /// Prepara una sessione salvata con le scadenze indicate.
  Future<void> sessioneCon({required int expiresIn}) async {
    await AuthService.salvaSessione(
      jsonDecode(tokenBody('iniziale', expiresIn: expiresIn))
          as Map<String, dynamic>,
    );
  }

  group('salvataggio della sessione', () {
    test('salva entrambi i token e calcola le scadenze', () async {
      await sessioneCon(expiresIn: 1800);

      expect(AuthService.accessToken, 'access-iniziale');
      expect(AuthService.refreshToken, 'refresh-iniziale');
      expect(AuthService.isLoggedIn, isTrue);
    });

    test('il refresh token viene sovrascritto ad ogni rinnovo', () async {
      await sessioneCon(expiresIn: 1800);
      await AuthService.salvaSessione(
          jsonDecode(tokenBody('nuovo')) as Map<String, dynamic>);

      // Conservare il vecchio refresh e' l'errore che, con la rotazione
      // stretta attiva, farebbe cadere la sessione al rinnovo successivo.
      expect(AuthService.refreshToken, 'refresh-nuovo');
      expect(AuthService.accessToken, 'access-nuovo');
    });

    test('senza refresh token la sessione non e\' attiva', () async {
      expect(AuthService.isLoggedIn, isFalse);
    });
  });

  group('rinnovo proattivo', () {
    test('un access token in scadenza viene rinnovato prima della richiesta',
        () async {
      // Scade fra 10 s, sotto il margine di 60 s: va rinnovato subito.
      await sessioneCon(expiresIn: 10);

      var refreshChiamati = 0;
      final tokenUsati = <String?>[];

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          refreshChiamati++;
          return http.Response(tokenBody('rinnovato'), 200);
        }
        tokenUsati.add(request.headers['Authorization']);
        return http.Response('{"ok":true}', 200);
      });

      final risposta = await ApiClient.get('/articles/me');

      expect(risposta.statusCode, 200);
      expect(refreshChiamati, 1);
      // La richiesta non e' mai partita con il token vecchio: nessun 401.
      expect(tokenUsati, ['Bearer access-rinnovato']);
    });

    test('un access token ancora valido non provoca rinnovi', () async {
      await sessioneCon(expiresIn: 1800);

      var refreshChiamati = 0;
      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) refreshChiamati++;
        return http.Response('{"ok":true}', 200);
      });

      await ApiClient.get('/articles/me');
      expect(refreshChiamati, 0);
    });
  });

  group('mutex sul rinnovo', () {
    test('richieste concorrenti condividono un solo rinnovo', () async {
      await sessioneCon(expiresIn: 10); // tutte troveranno il token scaduto

      var refreshChiamati = 0;
      final sbloccaRefresh = Completer<void>();

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          refreshChiamati++;
          // Tiene il rinnovo "in volo" finche' tutte le richieste sono partite:
          // e' la finestra in cui una implementazione senza mutex ne
          // lancerebbe uno per ciascuna.
          await sbloccaRefresh.future;
          return http.Response(tokenBody('unico'), 200);
        }
        return http.Response('{"ok":true}', 200);
      });

      final richieste = List.generate(5, (_) => ApiClient.get('/articles/me'));
      await Future<void>.delayed(Duration.zero);
      sbloccaRefresh.complete();
      final risposte = await Future.wait(richieste);

      expect(refreshChiamati, 1,
          reason: 'cinque richieste devono provocare un solo refresh');
      expect(risposte.every((r) => r.statusCode == 200), isTrue);
      expect(AuthService.refreshToken, 'refresh-unico');
    });

    test('dopo il completamento un nuovo rinnovo e\' di nuovo possibile',
        () async {
      await sessioneCon(expiresIn: 10);

      var refreshChiamati = 0;
      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          refreshChiamati++;
          return http.Response(tokenBody('n$refreshChiamati', expiresIn: 10), 200);
        }
        return http.Response('{"ok":true}', 200);
      });

      await ApiClient.get('/articles/me');
      await ApiClient.get('/articles/me');

      // Il lucchetto viene rilasciato: la seconda richiesta rinnova di nuovo.
      expect(refreshChiamati, 2);
    });
  });

  group('reazione al 401', () {
    test('TOKEN_EXPIRED: rinnova e ripete la richiesta una sola volta',
        () async {
      await sessioneCon(expiresIn: 1800); // valido: nessun rinnovo proattivo

      var tentativi = 0;
      var refreshChiamati = 0;

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          refreshChiamati++;
          return http.Response(tokenBody('dopo401'), 200);
        }
        tentativi++;
        // Il server considera scaduto il token solo al primo tentativo.
        if (tentativi == 1) {
          return http.Response(erroreAuth(AuthErrorCode.tokenExpired), 401);
        }
        return http.Response('{"ok":true}', 200);
      });

      final risposta = await ApiClient.get('/articles/me');

      expect(risposta.statusCode, 200);
      expect(tentativi, 2, reason: 'un solo nuovo tentativo');
      expect(refreshChiamati, 1);
      expect(AuthService.isLoggedIn, isTrue);
    });

    test('401 permanente: non entra in ciclo', () async {
      await sessioneCon(expiresIn: 1800);

      var tentativi = 0;
      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          return http.Response(tokenBody('nuovo'), 200);
        }
        tentativi++;
        return http.Response(erroreAuth(AuthErrorCode.tokenInvalid), 401);
      });

      final risposta = await ApiClient.get('/articles/me');

      expect(risposta.statusCode, 401);
      expect(tentativi, 2, reason: 'al massimo due tentativi, poi si arrende');
      // Token rifiutato anche subito dopo il rinnovo: sessione chiusa.
      expect(AuthService.isLoggedIn, isFalse);
    });

    test('REFRESH_EXPIRED: chiude la sessione senza tentare il rinnovo',
        () async {
      await sessioneCon(expiresIn: 1800);

      var refreshChiamati = 0;
      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          refreshChiamati++;
          return http.Response(erroreAuth(AuthErrorCode.refreshExpired), 401);
        }
        return http.Response(erroreAuth(AuthErrorCode.refreshExpired), 401);
      });

      final risposta = await ApiClient.get('/articles/me');

      expect(risposta.statusCode, 401);
      expect(refreshChiamati, 0, reason: 'inutile rinnovare: sessione persa');
      expect(AuthService.isLoggedIn, isFalse);
      expect(AuthService.accessToken, isNull);
    });
  });

  group('server di autenticazione non disponibile', () {
    test('un 503 sul refresh NON slogga l\'utente', () async {
      await sessioneCon(expiresIn: 10);

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          return http.Response(erroreAuth(AuthErrorCode.authUnavailable), 503);
        }
        return http.Response('{"ok":true}', 200);
      });

      await ApiClient.get('/articles/me');

      // La sessione e' probabilmente ancora valida: buttare fuori l'utente
      // per un disservizio temporaneo sarebbe la reazione sbagliata.
      expect(AuthService.isLoggedIn, isTrue);
      expect(AuthService.refreshToken, 'refresh-iniziale');
    });

    test('un errore di rete sul refresh NON slogga l\'utente', () async {
      await sessioneCon(expiresIn: 10);

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) {
          throw const SocketExceptionFinta();
        }
        return http.Response('{"ok":true}', 200);
      });

      await ApiClient.get('/articles/me');

      expect(AuthService.isLoggedIn, isTrue);
    });
  });

  group('richieste pubbliche', () {
    test('non allegano il token e non innescano rinnovi', () async {
      await sessioneCon(expiresIn: 10); // scaduto: rinnoverebbe, se autenticata

      var refreshChiamati = 0;
      String? authHeader = 'non-impostato';

      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/refresh')) refreshChiamati++;
        authHeader = request.headers['Authorization'];
        return http.Response('{"articles":[]}', 200);
      });

      await ApiClient.get('/articles', autenticata: false);

      expect(refreshChiamati, 0);
      expect(authHeader, isNull);
    });
  });

  group('logout', () {
    test('revoca il refresh token e pulisce la sessione', () async {
      await sessioneCon(expiresIn: 1800);

      String? revocato;
      AuthService.httpClient = MockClient((request) async {
        if (request.url.path.endsWith('/utente/logout')) {
          revocato = jsonDecode(request.body)['refresh_token'] as String?;
          return http.Response('{"status":"success"}', 200);
        }
        return http.Response('{}', 200);
      });

      await AuthService.logout();

      expect(revocato, 'refresh-iniziale');
      expect(AuthService.isLoggedIn, isFalse);
      expect(AuthService.refreshToken, isNull);
    });

    test('pulisce la sessione anche se la revoca fallisce', () async {
      await sessioneCon(expiresIn: 1800);

      AuthService.httpClient = MockClient((request) async {
        throw const SocketExceptionFinta();
      });

      await AuthService.logout();

      // Dal punto di vista dell'utente il logout non deve mai fallire.
      expect(AuthService.isLoggedIn, isFalse);
    });
  });
}

/// Eccezione usata per simulare la caduta della rete.
class SocketExceptionFinta implements Exception {
  const SocketExceptionFinta();
  @override
  String toString() => 'rete non raggiungibile (simulata)';
}
