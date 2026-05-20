import 'package:flutter/material.dart';
import 'package:cotahub/models/quotation.dart';

class QuotationDetailsPage extends StatelessWidget {
  final Quotation quotation;

  const QuotationDetailsPage({
    super.key,
    required this.quotation,
  });

  static const Color background = Color(0xFFF7F3EC);
  static const Color primary = Color(0xFF7D8F69);
  static const Color textDark = Color(0xFF263128);

  @override
  Widget build(BuildContext context) {
    final offers = [
      {
        'supplier': 'Distribuidora Brasil',
        'price': 'R\$ 110,00',
        'delivery': '3 dias',
        'highlight': 'Menor preço',
      },
      {
        'supplier': 'Fornecedor Alpha',
        'price': 'R\$ 120,00',
        'delivery': '2 dias',
        'highlight': 'Melhor equilíbrio',
      },
      {
        'supplier': 'Atacado Forte',
        'price': 'R\$ 135,00',
        'delivery': '1 dia',
        'highlight': 'Entrega rápida',
      },
    ];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Propostas recebidas',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cotação em análise',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    quotation.product,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quotation.quantity,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Comparativo inteligente',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: textDark,
            ),
          ),

          const SizedBox(height: 14),

          ...offers.asMap().entries.map(
                (entry) {
              final index = entry.key;
              final offer = entry.value;

              return _AnimatedOfferCard(
                delay: index * 180,
                supplier: offer['supplier']!,
                price: offer['price']!,
                delivery: offer['delivery']!,
                highlight: offer['highlight']!,
                isBest: index == 0,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedOfferCard extends StatelessWidget {
  final int delay;
  final String supplier;
  final String price;
  final String delivery;
  final String highlight;
  final bool isBest;

  const _AnimatedOfferCard({
    required this.delay,
    required this.supplier,
    required this.price,
    required this.delivery,
    required this.highlight,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 32 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isBest ? const Color(0xFFFFF7E8) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isBest
                ? const Color(0xFFE9B384)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBest)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9B384),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'Melhor opção',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263128),
                  ),
                ),
              ),

            Text(
              supplier,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF263128),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF263128),
                    ),
                  ),
                ),
                const Icon(
                  Icons.trending_down_rounded,
                  color: Color(0xFF7D8F69),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  size: 20,
                  color: Colors.black45,
                ),
                const SizedBox(width: 8),
                Text(
                  'Entrega em $delivery',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Color(0xFF7D8F69),
                ),
                const SizedBox(width: 8),
                Text(
                  highlight,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}