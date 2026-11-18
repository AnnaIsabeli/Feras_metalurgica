import 'dart:convert';
import 'package:jose/jose.dart';
import 'principal.dart';

abstract interface class GoogleAccountRepository {
  Future<Principal?> resolve({
    required String subject,
    required String email,
    required String name,
  });
}

/// Only Google's fixed JWKS endpoint is trusted; token-supplied key URLs are ignored.
class GoogleIdentityVerifier implements IdentityVerifier {
  GoogleIdentityVerifier({
    required this.clientIds,
    required this.accounts,
    JsonWebKeyStore? keyStore,
    DateTime Function()? now,
  }) : keys =
           keyStore ??
           (JsonWebKeyStore()..addKeySetUrl(
             Uri.parse('https://www.googleapis.com/oauth2/v3/certs'),
           )),
       now = now ?? DateTime.now {
    if (clientIds.isEmpty || clientIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Configure GOOGLE_CLIENT_IDS.');
    }
  }
  final Set<String> clientIds;
  final GoogleAccountRepository accounts;
  final JsonWebKeyStore keys;
  final DateTime Function() now;

  @override
  Future<Principal?> verify(String bearerToken) async {
    try {
      if (bearerToken.length > 16384) return null;
      final parts = bearerToken.split('.');
      if (parts.length != 3) return null;
      final header =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
              )
              as Map;
      if (header['alg'] != 'RS256' ||
          header.containsKey('jku') ||
          header.containsKey('jwk') ||
          header.containsKey('x5u'))
        return null;
      final jwt = JsonWebToken.unverified(bearerToken);
      if (!await jwt
          .verify(keys, allowedArguments: ['RS256'])
          .timeout(const Duration(seconds: 8)))
        return null;
      final claims = jwt.claims.toJson();
      final issuer = claims['iss'];
      final audience = claims['aud'];
      final expiry = claims['exp'];
      final issued = claims['iat'];
      final subject = claims['sub'];
      final email = claims['email'];
      final time = now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (issuer != 'https://accounts.google.com' &&
          issuer != 'accounts.google.com')
        return null;
      // Google ID tokens for this integration use one audience. Never trust client roles.
      if (audience is! String || !clientIds.contains(audience)) return null;
      if (claims['azp'] != null && !clientIds.contains(claims['azp']))
        return null;
      if (expiry is! int ||
          expiry <= time ||
          issued is! int ||
          issued > time + 60)
        return null;
      if (claims['nbf'] is num && (claims['nbf'] as num) > time + 60)
        return null;
      if (subject is! String ||
          subject.isEmpty ||
          subject.length > 255 ||
          email is! String ||
          email.isEmpty ||
          email.length > 320 ||
          claims['email_verified'] != true)
        return null;
      final displayName = claims['name'];
      return await accounts.resolve(
        subject: subject,
        email: email,
        name: displayName is String && displayName.trim().isNotEmpty
            ? displayName.trim()
            : email,
      );
    } catch (_) {
      // Do not leak credentials, JWT claims or database errors to the response/log.
      return null;
    }
  }
}
