import 'package:flutter/material.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: runStore,
        builder: (context, _) => PageBody(title: 'المتجر', children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF22335A), Brand.navy], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(children: [
              const CircleAvatar(radius: 26, backgroundColor: Brand.sun, child: Icon(Icons.toll, color: Brand.navy, size: 28)),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('رصيد النقاط', style: TextStyle(color: Color(0xFFA9B3C7), fontSize: 12.5)),
                  Text('${runStore.points}',
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1)),
                  const Text('$pointsPerKm نقاط لكل كيلومتر تجريه',
                      style: TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'العروض توصل قريباً',
            hint: 'نجهز أول المتاجر الشريكة في جدة. نقاطك محفوظة وتقدر تستبدلها أول ما تفتح العروض.',
          ),
        ]),
      );
}
