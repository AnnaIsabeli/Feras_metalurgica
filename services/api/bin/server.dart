import 'dart:io';
import 'package:fera_api/src/database/postgres_quote_document_repository.dart';
import 'package:fera_api/src/documents/quote_pdf_renderer.dart';
import 'package:fera_api/src/documents/quote_pdf_service.dart';
import 'package:fera_api/src/database/postgres_pricing_repository.dart';
import 'package:fera_api/src/quotes/pricing_service.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/config.dart';
import 'package:fera_api/src/database/postgres_quote_repository.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/quotes/quote_service.dart';

Future<void> main() async {
  final config = AppConfig.fromEnvironment(Platform.environment);
  final pool = Pool.withUrl(config.databaseUrl);
  final handler = buildHandler(
    quotes: QuoteService(PostgresQuoteRepository(pool)),
    pdfs: QuotePdfService(
      PostgresQuoteDocumentRepository(pool),
      await QuotePdfRenderer.load(),
    ),
    pricings: PricingService(PostgresPricingRepository(pool)),
    identity: config.devAuth
        ? DevelopmentIdentityVerifier()
        : DenyAllIdentityVerifier(),
    checkDatabase: () async {
      await pool.execute('SELECT 1 FROM quote_requests LIMIT 1');
    },
    allowedOrigin: config.allowedOrigin,
  );
  final server = await shelf_io.serve(handler, config.host, config.port);
  stdout.writeln('Fera API: http://${server.address.host}:${server.port}');
  if (config.devAuth) {
    stdout.writeln(
      'DEMONSTRAÇÃO LOCAL: autenticação Google ainda não implementada.',
    );
  }
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    await pool.close();
    exit(0);
  });
}
