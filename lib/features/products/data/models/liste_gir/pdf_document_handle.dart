/// `nicePdfLoad` köprü çağrısının sonucu — açık pdf.js belgesine referans.
class PdfDocumentHandle {
  final String docId;
  final int numPages;

  const PdfDocumentHandle({required this.docId, required this.numPages});

  factory PdfDocumentHandle.fromMap(Map<String, dynamic> map) {
    return PdfDocumentHandle(
      docId: map['docId'] as String,
      numPages: (map['numPages'] as num).toInt(),
    );
  }
}
