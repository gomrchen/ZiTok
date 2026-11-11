import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/drama_provider.dart';
import '../home/shell_surface.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DramaProvider>().refreshWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DramaProvider>();
    final ink = ShellSurface.inkOf(context);
    final card = ShellSurface.cardOf(context);
    final line = ShellSurface.lineOf(context);
    final bal = dp.wallet?.balance ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ShellSurface.systemUiOf(context),
      child: Scaffold(
        backgroundColor: ShellSurface.canvasOf(context),
        appBar: ShellSurface.appBar(
          title: '我的钱包',
          context: context,
          forceBack: true,
        ),
        body: RefreshIndicator(
          color: ShellSurface.coral,
          backgroundColor: card,
          onRefresh: () => dp.refreshWallet(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShellSurface.pagePad,
              8,
              ShellSurface.pagePad,
              24,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: Column(
                  children: [
                    Text(
                      '金币余额',
                      style: ShellSurface.captionOf(context).copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$bal',
                      style: TextStyle(
                        color: ink,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShellSurface.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await dp.mockTopup(100);
                          if (!context.mounted) return;
                          ShellSurface.showTip(context, '已充值 100 金币');
                        },
                        child: const Text('Mock 充值 +100'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ShellSurface.sectionGap),
              Text('流水', style: ShellSurface.sectionTitleOf(context)),
              const SizedBox(height: 10),
              if (dp.ledger.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Text(
                    '暂无流水',
                    textAlign: TextAlign.center,
                    style: ShellSurface.captionOf(context),
                  ),
                )
              else
                ...dp.ledger.map((e) {
                  final delta = (e['change_amount'] as num?)?.toInt() ?? 0;
                  final up = delta >= 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['reason'] ?? '变动'}',
                                style: ShellSurface.bodyStrongOf(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${e['created_at'] ?? ''}',
                                style: ShellSurface.captionOf(context),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          up ? '+$delta' : '$delta',
                          style: TextStyle(
                            color: up ? ShellSurface.accent : ShellSurface.coral,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
