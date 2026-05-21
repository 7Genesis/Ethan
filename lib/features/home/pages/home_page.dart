import 'package:cotahub/features/quotations/pages/create_quotation_page.dart';
import 'package:cotahub/features/quotations/pages/quotation_details_page.dart';
import 'package:cotahub/features/profile/pages/company_profile_page.dart';
import 'package:cotahub/features/support/pages/support_page.dart';
import 'package:cotahub/features/support/widgets/ai_assistant_fab.dart';
import 'package:cotahub/models/app_notification.dart';
import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/models/quotation_item.dart';
import 'package:cotahub/repositories/notification_repository.dart';
import 'package:cotahub/repositories/quotation_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _QuotationFilter { all, open, closed }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _QuotationFilter selectedFilter = _QuotationFilter.all;

  @override
  Widget build(BuildContext context) {
    final repository = QuotationRepository();
    final notificationRepository = NotificationRepository();

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      floatingActionButton: const AiAssistantFab(),
      body: SafeArea(
        child: StreamBuilder<List<Quotation>>(
          stream: repository.getMyQuotations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final quotations = snapshot.data ?? [];
            final openQuotations = quotations
                .where((quotation) => !quotation.isClosed)
                .toList();
            final closedQuotations = quotations
                .where((quotation) => quotation.isClosed)
                .toList();
            final totalItems = quotations.fold<int>(
              0,
              (sum, quotation) => sum + quotation.itemCount,
            );

            final visibleQuotations = switch (selectedFilter) {
              _QuotationFilter.open => openQuotations,
              _QuotationFilter.closed => closedQuotations,
              _ => quotations,
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                _TopBar(
                  onLogout: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  onCreate: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateQuotationPage(),
                      ),
                    );
                  },
                  onProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompanyProfilePage(),
                      ),
                    );
                  },
                  onSupport: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportPage()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<AppNotification>>(
                  stream: notificationRepository.currentUserNotifications(
                    limit: 6,
                  ),
                  builder: (context, notificationSnapshot) {
                    final notifications = notificationSnapshot.data ?? const [];
                    return _NotificationPanel(
                      notifications: notifications,
                      onMarkAsRead: (id) =>
                          notificationRepository.markAsRead(id),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Cotações',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${openQuotations.length} abertas • ${closedQuotations.length} concluidas • $totalItems itens',
                  style: const TextStyle(
                    color: CotahubTheme.textSecondary,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: CupertinoSlidingSegmentedControl<_QuotationFilter>(
                    groupValue: selectedFilter,
                    backgroundColor: CotahubTheme.surfaceAlt,
                    thumbColor: CotahubTheme.surfaceSoft,
                    padding: const EdgeInsets.all(4),
                    children: const {
                      _QuotationFilter.all: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          'Todas',
                          style: TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _QuotationFilter.open: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          'Abertas',
                          style: TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _QuotationFilter.closed: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          'Concluidas',
                          style: TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => selectedFilter = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _SummaryBand(
                  quotations: quotations,
                  openCount: openQuotations.length,
                  closedCount: closedQuotations.length,
                  totalItems: totalItems,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Lista',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (visibleQuotations.isEmpty)
                  const _EmptyState(
                    title: 'Nada para mostrar aqui',
                    message:
                        'Ajuste o filtro ou crie uma nova cotacao para começar.',
                  )
                else
                  ...visibleQuotations.map(
                    (quotation) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _QuotationCard(
                        quotation: quotation,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QuotationDetailsPage(quotation: quotation),
                            ),
                          );
                        },
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

class _TopBar extends StatelessWidget {
  final Future<void> Function() onLogout;
  final VoidCallback onCreate;
  final VoidCallback onProfile;
  final VoidCallback onSupport;

  const _TopBar({
    required this.onLogout,
    required this.onCreate,
    required this.onProfile,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: CotahubTheme.textPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.hub_rounded, color: CotahubTheme.background),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Cotahub',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: onCreate,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onProfile,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.apartment_rounded),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onSupport,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.support_agent_rounded),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onLogout,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final List<Quotation> quotations;
  final int openCount;
  final int closedCount;
  final int totalItems;

  const _SummaryBand({
    required this.quotations,
    required this.openCount,
    required this.closedCount,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final previewItems = quotations
        .expand((quotation) => quotation.items)
        .take(2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tudo que importa, em uma passada.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  color: CotahubTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Itens, status e decisao final organizados com a mesma calma visual de um app nativo.',
                style: TextStyle(
                  color: CotahubTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DataChip(
                    label: 'Abertas',
                    value: '$openCount',
                    color: CotahubTheme.blue,
                  ),
                  _DataChip(
                    label: 'Concluidas',
                    value: '$closedCount',
                    color: CotahubTheme.green,
                  ),
                  _DataChip(
                    label: 'Itens',
                    value: '$totalItems',
                    color: CotahubTheme.accent,
                  ),
                ],
              ),
            ],
          );

          final preview = Column(
            children: [
              for (final item in previewItems)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: item == previewItems.last ? 0 : 12,
                  ),
                  child: _PreviewTile(item: item),
                ),
              if (previewItems.isEmpty) const _InlineEmptyPreview(),
            ],
          );

          return isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: copy),
                    const SizedBox(width: 18),
                    Expanded(flex: 8, child: preview),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 18), preview],
                );
        },
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function(String notificationId) onMarkAsRead;

  const _NotificationPanel({
    required this.notifications,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notifications.take(3).map((notification) {
          return InkWell(
            onTap: () => onMarkAsRead(notification.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    notification.isUnread
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                    size: 18,
                    color: notification.isUnread
                        ? CotahubTheme.blue
                        : CotahubTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: notification.isUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          style: const TextStyle(
                            color: CotahubTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final QuotationItem item;

  const _PreviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.hasImage
            ? CotahubTheme.surfaceWarm
            : CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        children: [
          _Thumbnail(item: item, size: 66),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.quantity,
                  style: const TextStyle(color: CotahubTheme.textSecondary),
                ),
                if (item.brandModelLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.brandModelLabel,
                    style: const TextStyle(
                      color: CotahubTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;

  const _QuotationCard({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstItem = quotation.firstItem;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CotahubTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CotahubTheme.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(item: firstItem, size: 88),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            quotation.summaryTitle,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: CotahubTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(quotation: quotation),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quotation.summaryQuantity,
                      style: const TextStyle(color: CotahubTheme.textSecondary),
                    ),
                    if (firstItem != null &&
                        firstItem.brandModelLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        firstItem.brandModelLabel,
                        style: const TextStyle(
                          color: CotahubTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      quotation.notes.isNotEmpty
                          ? quotation.notes
                          : quotation.isClosed
                          ? quotation.purchaseCompleted
                                ? 'Compra encerrada com XML validado.'
                                : quotation.invoiceUnderReview
                                ? 'Fornecedor enviou XML. Falta conferencia final.'
                                : quotation.awaitingInvoice
                                ? 'Proposta escolhida. Aguardando XML fiscal do fornecedor.'
                                : 'Cotacao encerrada com proposta escolhida.'
                          : 'Aguardando retorno dos fornecedores.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CotahubTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: CotahubTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final QuotationItem? item;
  final double size;

  const _Thumbnail({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    if (item != null && item!.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            item!.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CotahubTheme.line),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_rounded, color: CotahubTheme.accent),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DataChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Quotation quotation;

  const _StatusChip({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final color = quotation.purchaseCompleted
        ? CotahubTheme.green
        : quotation.invoiceUnderReview
        ? CotahubTheme.accent
        : quotation.awaitingInvoice
        ? CotahubTheme.blue
        : quotation.isClosed
        ? CotahubTheme.green
        : CotahubTheme.blue;
    final label = quotation.isClosed ? quotation.workflowStageLabel : 'Aberta';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineEmptyPreview extends StatelessWidget {
  const _InlineEmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: const Text(
        'Quando voce publicar a primeira cotacao, os itens aparecem aqui como preview.',
        style: TextStyle(color: CotahubTheme.textSecondary, height: 1.4),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
