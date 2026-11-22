import 'package:printing/printing.dart';
import '../../core/api_client.dart';

abstract interface class QuotePdfActions {
  Future<bool> preview(QuotePdfDownload file);
  Future<bool> download(QuotePdfDownload file);
}

class SystemQuotePdfActions implements QuotePdfActions {
  const SystemQuotePdfActions();
  @override
  Future<bool> preview(QuotePdfDownload file) => Printing.layoutPdf(
    name: file.filename,
    dynamicLayout: false,
    onLayout: (_) async => file.bytes,
  );
  @override
  Future<bool> download(QuotePdfDownload file) =>
      Printing.sharePdf(bytes: file.bytes, filename: file.filename);
}
