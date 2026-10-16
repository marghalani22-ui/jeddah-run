import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PageBody(children: [
      Text('المتجر', style: Theme.of(context).textTheme.headlineMedium),
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
              const Text('${Demo.balance}', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1)),
              Text('+${Demo.pending} قيد الاعتماد', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHead('العروض'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.m,
          crossAxisSpacing: Gap.m,
          childAspectRatio: .92,
          children: [
            for (final (title, deal, cost, store) in Demo.offers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.m),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(backgroundColor: p.sunSoft, child: Icon(Icons.local_offer_outlined, color: p.goldInk)),
                    const Spacer(),
                    Text(deal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Brand.coral)),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(store, style: TextStyle(fontSize: 12, color: p.muted)),
                    const SizedBox(height: Gap.s),
                    Text('$cost نقطة', style: TextStyle(fontWeight: FontWeight.w700, color: Demo.balance >= cost ? p.good : p.muted)),
                  ]),
                ),
              ),
          ],
        ),
      ]),
    ]);
  }
}
