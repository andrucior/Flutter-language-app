import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class GoogleAuthService {
  final String clientId =
      '1058215519513-a553cccaeglmnv8p3kknh0g7magv7t3r.apps.googleusercontent.com';
  final String clientSecret = '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';
  final String redirectUri = 'http://localhost:8080';
  final String authEndpoint = 'https://accounts.google.com/o/oauth2/auth';
  final String tokenEndpoint = 'https://oauth2.googleapis.com/token';

  Future<String?> authenticate() async {
    final authUrl = Uri.parse(
      '$authEndpoint?client_id=$clientId&redirect_uri=$redirectUri&response_type=code&scope=https://www.googleapis.com/auth/youtube.force-ssl',
    );

    if (!await launchUrl(authUrl)) {
      throw Exception('Could not open authorization URL');
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    final request = await server.first;
    final authCode = request.uri.queryParameters['code'];

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('<h1>You can close this tab now.</h1>')
      ..close();

    await server.close();

    if (authCode == null) {
      throw Exception('Authorization failed');
    }

    final tokenResponse = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': authCode,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Failed to obtain access token');
    }

    final tokenData = jsonDecode(tokenResponse.body);
    return tokenData['access_token'];
  }
}
