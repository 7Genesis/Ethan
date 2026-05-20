import 'package:flutter/material.dart';
import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/repositories/quotation_repository.dart';

class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key});

  @override
  State<CreateQuotationPage> createState() =>
      _CreateQuotationPageState();
}

class _CreateQuotationPageState
    extends State<CreateQuotationPage> {

  final productController = TextEditingController();
  final quantityController = TextEditingController();
  final notesController = TextEditingController();

  final repository = QuotationRepository();

  Future<void> submitQuotation() async {

    final quotation = Quotation(
      product: productController.text,
      quantity: quantityController.text,
      notes: notesController.text,
      createdAt: DateTime.now(),
    );

    await repository.createQuotation(
      quotation,
    );

    Navigator.pop(
      context,
      quotation,
    );
  }

  @override
  void dispose() {
    productController.dispose();
    quantityController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: const Text('Nova Cotação'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            TextField(
              controller: productController,
              decoration: InputDecoration(
                labelText: 'Produto ou material',
                hintText: 'Ex: Copo descartável 300ml',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantidade',
                hintText: 'Ex: 10 caixas',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Observações',
                hintText: 'Marca, prazo, entrega...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: submitQuotation,
                child: const Text('Enviar Cotação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}