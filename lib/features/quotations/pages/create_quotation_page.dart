import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/models/quotation_item.dart';
import 'package:cotahub/features/support/widgets/ai_assistant_fab.dart';
import 'package:cotahub/repositories/quotation_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:flutter/material.dart';

class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key});

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final notesController = TextEditingController();
  final itemForms = <_QuotationItemFormData>[];
  final repository = QuotationRepository();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() {
    setState(() {
      itemForms.add(_QuotationItemFormData.create());
    });
  }

  void _removeItem(_QuotationItemFormData form) {
    if (itemForms.length == 1) {
      return;
    }

    setState(() {
      itemForms.remove(form);
    });

    form.dispose();
  }

  Future<void> submitQuotation() async {
    final items = <QuotationItem>[];

    for (final form in itemForms) {
      final name = form.nameController.text.trim();
      final quantity = form.quantityController.text.trim();

      if (name.isEmpty || quantity.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cada item precisa ter nome e quantidade.'),
          ),
        );
        return;
      }

      items.add(
        QuotationItem(
          id: form.id,
          name: name,
          quantity: quantity,
          brand: form.brandController.text.trim(),
          model: form.modelController.text.trim(),
          notes: form.notesController.text.trim(),
          imageUrl: form.imageUrlController.text.trim(),
        ),
      );
    }

    final productSummary = items.length == 1
        ? items.first.name
        : '${items.length} itens';
    final quantitySummary = items.length == 1
        ? items.first.quantity
        : '${items.length} itens no lote';

    final quotation = Quotation(
      id: '',
      product: productSummary,
      quantity: quantitySummary,
      notes: notesController.text.trim(),
      createdAt: DateTime.now(),
      status: 'open',
      workflowStage: 'collecting_proposals',
      selectedProposalId: '',
      selectedSupplierId: '',
      items: items,
    );

    setState(() => isSaving = true);

    try {
      await repository.createQuotation(quotation);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar cotacao: $error')));
      return;
    } finally {
      if (mounted) setState(() => isSaving = false);
    }

    if (!mounted) return;

    Navigator.pop(context, quotation);
  }

  @override
  void dispose() {
    for (final itemForm in itemForms) {
      itemForm.dispose();
    }
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      floatingActionButton: const AiAssistantFab(),
      appBar: AppBar(title: const Text('Nova cotacao')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isSaving ? null : submitQuotation,
            child: Text(isSaving ? 'Publicando...' : 'Publicar cotacao'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        children: [
          _IntroSection(itemCount: itemForms.length, onAddItem: _addItem),
          const SizedBox(height: 20),
          ...itemForms.asMap().entries.map((entry) {
            final index = entry.key;
            final form = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuotationItemFormCard(
                index: index,
                form: form,
                canRemove: itemForms.length > 1,
                onChanged: () => setState(() {}),
                onRemove: () => _removeItem(form),
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CotahubTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CotahubTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observacoes gerais',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use este campo para informacoes do lote inteiro: entrega, janela de recebimento ou regras comuns a todos os itens.',
                  style: TextStyle(
                    color: CotahubTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes da cotacao',
                    hintText:
                        'Prazo, local de entrega, instrucoes ou restricoes...',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  final int itemCount;
  final VoidCallback onAddItem;

  const _IntroSection({required this.itemCount, required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CotahubTheme.surface,
            CotahubTheme.surfaceAlt,
            CotahubTheme.surfaceSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SignalPill(
                label: '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                color: CotahubTheme.blue,
              ),
              const _SignalPill(
                label: 'Imagem por item',
                color: CotahubTheme.accent,
              ),
              const _SignalPill(
                label: 'Marca e modelo',
                color: CotahubTheme.green,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Especificacao boa parece produto, nao formulario.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.03,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cada item pode carregar contexto visual, referencia de marca e observacoes especificas. Isso eleva a qualidade da proposta que volta.',
            style: TextStyle(
              color: CotahubTheme.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAddItem,
            style: OutlinedButton.styleFrom(
              backgroundColor: CotahubTheme.surfaceAlt,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar item'),
          ),
        ],
      ),
    );
  }
}

class _QuotationItemFormCard extends StatelessWidget {
  final int index;
  final _QuotationItemFormData form;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _QuotationItemFormCard({
    required this.index,
    required this.form,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: CotahubTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    color: CotahubTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: CotahubTheme.surfaceAlt,
                    foregroundColor: CotahubTheme.textSecondary,
                    side: const BorderSide(color: CotahubTheme.line),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ImagePreview(url: form.imageUrlController.text.trim()),
          const SizedBox(height: 16),
          TextField(
            controller: form.nameController,
            decoration: const InputDecoration(
              labelText: 'Nome do item',
              hintText: 'Ex: Parafusadeira',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: form.quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantidade',
              hintText: 'Ex: 10 unidades',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 560;

              final brandField = TextField(
                controller: form.brandController,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ex: Bosch',
                ),
              );

              final modelField = TextField(
                controller: form.modelController,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Ex: GSR 12V-30',
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    brandField,
                    const SizedBox(height: 12),
                    modelField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: brandField),
                  const SizedBox(width: 12),
                  Expanded(child: modelField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: form.imageUrlController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'URL da imagem',
              hintText: 'https://...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: form.notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observacoes do item',
              hintText: 'Cor, referencia, acabamento, compatibilidade...',
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String url;

  const _ImagePreview({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CotahubTheme.surfaceWarm, CotahubTheme.surfaceAlt],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CotahubTheme.line),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(18),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: CotahubTheme.accent,
              size: 28,
            ),
            SizedBox(height: 10),
            Text(
              'Adicione uma imagem para dar contexto visual ao item.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CotahubTheme.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Sem imagem, o pedido volta a depender demais de texto.',
              style: TextStyle(color: CotahubTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return Container(
              color: CotahubTheme.surfaceAlt,
              alignment: Alignment.center,
              child: const Text(
                'Imagem nao carregada',
                style: TextStyle(color: CotahubTheme.textSecondary),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SignalPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _QuotationItemFormData {
  final String id;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController notesController;
  final TextEditingController imageUrlController;

  _QuotationItemFormData({
    required this.id,
    required this.nameController,
    required this.quantityController,
    required this.brandController,
    required this.modelController,
    required this.notesController,
    required this.imageUrlController,
  });

  factory _QuotationItemFormData.create() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    return _QuotationItemFormData(
      id: id,
      nameController: TextEditingController(),
      quantityController: TextEditingController(),
      brandController: TextEditingController(),
      modelController: TextEditingController(),
      notesController: TextEditingController(),
      imageUrlController: TextEditingController(),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    brandController.dispose();
    modelController.dispose();
    notesController.dispose();
    imageUrlController.dispose();
  }
}
