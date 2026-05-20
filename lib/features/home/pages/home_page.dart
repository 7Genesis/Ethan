import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cotahub/features/quotations/pages/create_quotation_page.dart';
import 'package:cotahub/features/quotations/pages/quotation_details_page.dart';
import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/repositories/quotation_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color background = Color(0xFFF7F3EC);
  static const Color primary = Color(0xFF7D8F69);
  static const Color secondary = Color(0xFFD8C8B6);
  static const Color accent = Color(0xFFE9B384);
  static const Color textDark = Color(0xFF263128);

  @override
  Widget build(BuildContext context) {
    final repository = QuotationRepository();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: StreamBuilder<List<Quotation>>(
          stream: repository.getQuotations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final quotations = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cotahub',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'Compras B2B inteligentes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7D8F69),
                        Color(0xFFA8B88C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare fornecedores com mais clareza',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Crie uma cotação, receba propostas e tome decisões por preço, prazo e disponibilidade.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Cotações',
                        value: '${quotations.length}',
                        subtitle: 'criadas',
                        color: Colors.white,
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: _MetricCard(
                        title: 'Economia',
                        value: 'R\$ 0',
                        subtitle: 'estimada',
                        color: Color(0xFFFFF7E8),
                        icon: Icons.savings_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateQuotationPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Criar nova cotação',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Cotações recentes',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),

                const SizedBox(height: 14),

                if (quotations.isEmpty)
                  const _EmptyState()
                else
                  ...quotations.map(
                        (quotation) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuotationDetailsPage(
                                quotation: quotation,
                              ),
                            ),
                          );
                        },
                        child: _QuotationCard(quotation: quotation),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HomePage.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: HomePage.textDark,
            ),
          ),
          Text(subtitle, style: const TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  final Quotation quotation;

  const _QuotationCard({
    required this.quotation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0DD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: HomePage.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quotation.product,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: HomePage.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quotation.quantity,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  quotation.notes.isEmpty
                      ? 'Aguardando propostas'
                      : quotation.notes,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.black38),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Nenhuma cotação criada ainda. Clique em “Criar nova cotação” para começar.',
        style: TextStyle(color: Colors.black54, height: 1.4),
      ),
    );
  }
}