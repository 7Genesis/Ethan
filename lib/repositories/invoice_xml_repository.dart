import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:xml/xml.dart';

import 'package:projeto_ethan/models/invoice_xml_record.dart';

class InvoiceXmlRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Stream<List<InvoiceXmlRecord>> getQuotationInvoices(String quotationId) {
    return firestore
        .collection('quotations')
        .doc(quotationId)
        .collection('invoiceXmls')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(InvoiceXmlRecord.fromFirestore).toList(),
        );
  }

  Stream<InvoiceXmlRecord?> getProposalInvoice(
    String quotationId,
    String proposalId,
  ) {
    return firestore
        .collection('quotations')
        .doc(quotationId)
        .collection('invoiceXmls')
        .doc(proposalId)
        .snapshots()
        .map((doc) => doc.exists ? InvoiceXmlRecord.fromFirestore(doc) : null);
  }

  Future<bool> uploadInvoiceXml({
    required String quotationId,
    required String proposalId,
    required String supplierName,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xml'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return false;
    }

    final file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Nao foi possivel ler o XML selecionado.');
    }

    final xmlContent = utf8.decode(bytes, allowMalformed: true);
    final metadata = _parseInvoiceMetadata(xmlContent);
    final buyerContext = await _loadBuyerContext(quotationId);
    final proposalContext = await _loadProposalContext(proposalId);
    final safeFileName = _sanitizeFileName(file.name);
    final storagePath =
        'quotation_invoices/$quotationId/$proposalId/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    final reference = storage.ref(storagePath);
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/xml',
        customMetadata: {
          'quotationId': quotationId,
          'proposalId': proposalId,
          'supplierId': user.uid,
        },
      ),
    );

    final downloadUrl = await reference.getDownloadURL();
    final matchStatus = _recipientMatchStatus(
      buyerTaxId: buyerContext.companyTaxId,
      recipientTaxId: metadata.recipientTaxId,
    );
    final consistency = _buildConsistencyReport(
      metadata: metadata,
      buyerContext: buyerContext,
      proposalContext: proposalContext,
      recipientMatchStatus: matchStatus,
    );

    await firestore
        .collection('quotations')
        .doc(quotationId)
        .collection('invoiceXmls')
        .doc(proposalId)
        .set({
          'quotationId': quotationId,
          'proposalId': proposalId,
          'supplierId': user.uid,
          'supplierName': supplierName,
          'fileName': file.name,
          'storagePath': storagePath,
          'downloadUrl': downloadUrl,
          'invoiceKey': metadata.invoiceKey,
          'issuerName': metadata.issuerName,
          'issuerTaxId': metadata.issuerTaxId,
          'recipientName': metadata.recipientName,
          'recipientTaxId': metadata.recipientTaxId,
          'buyerCompanyName': buyerContext.companyName,
          'buyerCompanyTaxId': buyerContext.companyTaxId,
          'recipientMatchStatus': matchStatus,
          'totalAmount': metadata.totalAmount,
          'proposalAmount': proposalContext.price,
          'consistencyStatus': consistency.status,
          'consistencyIssues': consistency.issues,
          'issueDate': metadata.issueDate == null
              ? null
              : Timestamp.fromDate(metadata.issueDate!),
          'uploadedAt': Timestamp.now(),
          'reviewStatus': 'pending_review',
          'reviewNote': '',
          'reviewedAt': null,
        });

    await firestore.collection('quotations').doc(quotationId).set({
      'workflowStage': 'invoice_under_review',
    }, SetOptions(merge: true));

    return true;
  }

  Future<void> reviewInvoiceXml({
    required String quotationId,
    required String proposalId,
    required String reviewStatus,
    String reviewNote = '',
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    if (reviewStatus != 'verified' && reviewStatus != 'rejected') {
      throw Exception('Status de revisao invalido.');
    }

    if (reviewStatus == 'verified') {
      final invoiceDoc = await firestore
          .collection('quotations')
          .doc(quotationId)
          .collection('invoiceXmls')
          .doc(proposalId)
          .get();
      final invoiceData = invoiceDoc.data() ?? {};
      final consistencyStatus = (invoiceData['consistencyStatus'] ?? '')
          .toString();
      if (consistencyStatus == 'fail') {
        throw Exception(
          'XML com inconsistencias criticas nao pode ser validado. Revise ou rejeite.',
        );
      }
    }

    await firestore
        .collection('quotations')
        .doc(quotationId)
        .collection('invoiceXmls')
        .doc(proposalId)
        .set({
          'reviewStatus': reviewStatus,
          'reviewNote': reviewNote,
          'reviewedAt': Timestamp.now(),
          'reviewedBy': user.uid,
        }, SetOptions(merge: true));

    await firestore.collection('quotations').doc(quotationId).set({
      'workflowStage': reviewStatus == 'verified'
          ? 'purchase_completed'
          : 'invoice_rejected',
    }, SetOptions(merge: true));
  }

  Future<_BuyerContext> _loadBuyerContext(String quotationId) async {
    final quotationDoc = await firestore
        .collection('quotations')
        .doc(quotationId)
        .get();
    final quotationData = quotationDoc.data() ?? {};
    final buyerId = (quotationData['buyerId'] ?? '').toString();

    if (buyerId.isEmpty) {
      return const _BuyerContext(companyName: '', companyTaxId: '');
    }

    final buyerDoc = await firestore.collection('users').doc(buyerId).get();
    final buyerData = buyerDoc.data() ?? {};

    return _BuyerContext(
      companyName: (buyerData['companyName'] ?? '').toString(),
      companyTaxId: (buyerData['companyTaxId'] ?? '').toString(),
    );
  }

  Future<_ProposalContext> _loadProposalContext(String proposalId) async {
    final proposalDoc = await firestore
        .collection('proposals')
        .doc(proposalId)
        .get();
    final proposalData = proposalDoc.data() ?? {};
    final supplierId = (proposalData['supplierId'] ?? '').toString();
    var supplierTaxId = '';
    if (supplierId.isNotEmpty) {
      final supplierDoc = await firestore
          .collection('users')
          .doc(supplierId)
          .get();
      supplierTaxId = (supplierDoc.data()?['companyTaxId'] ?? '').toString();
    }

    return _ProposalContext(
      supplierId: supplierId,
      supplierName: (proposalData['supplier'] ?? '').toString(),
      supplierTaxId: supplierTaxId,
      price: _parseAmount((proposalData['price'] ?? '').toString()),
    );
  }

  _InvoiceXmlMetadata _parseInvoiceMetadata(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final infNFe = _firstDescendant(document, 'infNFe');
    final emit = _firstDescendant(infNFe ?? document, 'emit');
    final dest = _firstDescendant(infNFe ?? document, 'dest');
    final ide = _firstDescendant(infNFe ?? document, 'ide');
    final icmsTot = _firstDescendant(infNFe ?? document, 'ICMSTot');
    final prot = _firstDescendant(document, 'protNFe');
    final infProt = _firstDescendant(prot ?? document, 'infProt');

    final rawInvoiceKey =
        (infNFe?.getAttribute('Id') ?? _textOf(infProt, 'chNFe'))
            .replaceFirst('NFe', '')
            .trim();
    final issueDateText = _textOf(ide, 'dhEmi').isNotEmpty
        ? _textOf(ide, 'dhEmi')
        : _textOf(ide, 'dEmi');

    return _InvoiceXmlMetadata(
      invoiceKey: rawInvoiceKey,
      issuerName: _textOf(emit, 'xNome').isNotEmpty
          ? _textOf(emit, 'xNome')
          : _textOf(emit, 'xFant'),
      issuerTaxId: _digitsOnly(
        _textOf(emit, 'CNPJ').isNotEmpty
            ? _textOf(emit, 'CNPJ')
            : _textOf(emit, 'CPF'),
      ),
      recipientName: _textOf(dest, 'xNome'),
      recipientTaxId: _digitsOnly(
        _textOf(dest, 'CNPJ').isNotEmpty
            ? _textOf(dest, 'CNPJ')
            : _textOf(dest, 'CPF'),
      ),
      totalAmount: _parseAmount(_textOf(icmsTot, 'vNF')),
      issueDate: DateTime.tryParse(issueDateText),
    );
  }

  XmlElement? _firstDescendant(XmlNode? node, String localName) {
    if (node == null) {
      return null;
    }

    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        return element;
      }
    }

    return null;
  }

  String _textOf(XmlNode? node, String localName) {
    final element = _firstDescendant(node, localName);
    return element?.innerText.trim() ?? '';
  }

  double _parseAmount(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  String _recipientMatchStatus({
    required String buyerTaxId,
    required String recipientTaxId,
  }) {
    final buyerDigits = _digitsOnly(buyerTaxId);
    final recipientDigits = _digitsOnly(recipientTaxId);

    if (buyerDigits.isEmpty || recipientDigits.isEmpty) {
      return 'unknown';
    }

    return buyerDigits == recipientDigits ? 'matched' : 'mismatch';
  }

  String _sanitizeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.toLowerCase().endsWith('.xml')) {
      final base = sanitized.substring(0, sanitized.length - 4);
      return '$base.xml';
    }
    return '$sanitized.xml';
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  _ConsistencyReport _buildConsistencyReport({
    required _InvoiceXmlMetadata metadata,
    required _BuyerContext buyerContext,
    required _ProposalContext proposalContext,
    required String recipientMatchStatus,
  }) {
    final failIssues = <String>[];
    final warningIssues = <String>[];

    if (metadata.invoiceKey.isEmpty || metadata.invoiceKey.length < 44) {
      failIssues.add('Chave da NF-e ausente ou incompleta.');
    }

    if (metadata.totalAmount <= 0) {
      failIssues.add('Valor total da NF-e invalido.');
    }

    if (recipientMatchStatus == 'mismatch') {
      failIssues.add(
        'Documento do destinatario no XML diverge do cadastro do comprador.',
      );
    }

    final issuerTaxId = _digitsOnly(metadata.issuerTaxId);
    final supplierTaxId = _digitsOnly(proposalContext.supplierTaxId);
    if (issuerTaxId.isNotEmpty &&
        supplierTaxId.isNotEmpty &&
        issuerTaxId != supplierTaxId) {
      failIssues.add(
        'Documento do emitente diverge do cadastro fiscal do fornecedor.',
      );
    }

    final proposalAmount = proposalContext.price;
    if (proposalAmount > 0 && metadata.totalAmount > 0) {
      final diffRatio =
          ((metadata.totalAmount - proposalAmount).abs() / proposalAmount);
      if (diffRatio > 0.5) {
        failIssues.add(
          'Valor da NF-e diverge acima de 50% da proposta selecionada.',
        );
      } else if (diffRatio > 0.2) {
        warningIssues.add(
          'Valor da NF-e diverge mais de 20% da proposta selecionada.',
        );
      }
    }

    if (_digitsOnly(buyerContext.companyTaxId).isEmpty) {
      warningIssues.add('Comprador sem documento fiscal cadastrado.');
    }

    if (failIssues.isNotEmpty) {
      return _ConsistencyReport(status: 'fail', issues: failIssues);
    }
    if (warningIssues.isNotEmpty) {
      return _ConsistencyReport(status: 'warning', issues: warningIssues);
    }
    return const _ConsistencyReport(status: 'pass', issues: <String>[]);
  }
}

class _InvoiceXmlMetadata {
  final String invoiceKey;
  final String issuerName;
  final String issuerTaxId;
  final String recipientName;
  final String recipientTaxId;
  final double totalAmount;
  final DateTime? issueDate;

  const _InvoiceXmlMetadata({
    required this.invoiceKey,
    required this.issuerName,
    required this.issuerTaxId,
    required this.recipientName,
    required this.recipientTaxId,
    required this.totalAmount,
    required this.issueDate,
  });
}

class _BuyerContext {
  final String companyName;
  final String companyTaxId;

  const _BuyerContext({required this.companyName, required this.companyTaxId});
}

class _ProposalContext {
  final String supplierId;
  final String supplierName;
  final String supplierTaxId;
  final double price;

  const _ProposalContext({
    required this.supplierId,
    required this.supplierName,
    required this.supplierTaxId,
    required this.price,
  });
}

class _ConsistencyReport {
  final String status;
  final List<String> issues;

  const _ConsistencyReport({required this.status, required this.issues});
}
