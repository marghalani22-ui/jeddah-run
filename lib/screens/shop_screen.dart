import 'package:flutter/material.dart';

import '../state/game.dart';
import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'points_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([runStore, game]),
        builder: (context, _) => PageBody(title: 'المتجر', children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PointsScreen())),
            child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: Grad.night,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(children: [
              const CircleAvatar(radius: 26, backgroundColor: Brand.sun, child: Icon(Icons.toll, color: Brand.navy, size: 28)),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('رصيد النقاط', style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                  Text('${game.balance}',
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1)),
                  const Text('$pointsPerKm نقاط لكل كيلو كامل · لين $dailyRunCap باليوم',
                      style: TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFFA9B3C7)),
            ]),
          ),
          ),
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'العروض توصل قريباً',
            hint: 'نجهز أول المتاجر الشريكة في جدة. نقاطك محفوظة وتقدر تستبدلها أول ما تفتح العروض.',
          ),
        ]),
      );
}
