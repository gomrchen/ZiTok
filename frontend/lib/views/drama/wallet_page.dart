import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drama_provider.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('我的钱包')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('金币余额'),
                  const SizedBox(height: 8),
                  Text(
                    '${dp.wallet?.balance ?? 0}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await dp.mockTopup(100);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已充值 100 金币')));
                      }
                    },
                    child: const Text('Mock 充值 +100'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('流水', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ...dp.ledger.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${e['reason'] ?? ''}'),
                subtitle: Text('${e['created_at'] ?? ''}'),
                trailing: Text(
                  '${(e['change_amount'] as num?)?.toInt() ?? 0}',
                  style: TextStyle(
                    color: ((e['change_amount'] as num?)?.toInt() ?? 0) >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
