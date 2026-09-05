import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../telegram_auth_config.dart';

class GiftCodesPage extends StatefulWidget {
  const GiftCodesPage({super.key});

  @override
  State<GiftCodesPage> createState() => _GiftCodesPageState();
}

class _GiftCodesPageState extends State<GiftCodesPage> {
  List<_GiftCodeEntry> _giftCodes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final res = await dio.get<List<dynamic>>(
        '${TelegramAuthConfig.baseUrl}/api/promos',
      );
      final items = (res.data ?? [])
          .whereType<Map>()
          .map((e) {
            final code = (e['code'] as String?)?.trim() ?? '';
            final reward = (e['reward'] as String?)?.trim() ?? '';
            if (code.isEmpty) return null;
            return _GiftCodeEntry(code: code, reward: reward);
          })
          .whereType<_GiftCodeEntry>()
          .toList();
      if (!mounted) return;
      setState(() {
        _giftCodes = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _giftCodes = const [];
        _loading = false;
        _error = 'Не удалось загрузить промокоды. Попробуйте позже.';
      });
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Код скопирован: $code')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
        elevation: 0,
        title: const Text('Подарочные коды'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _loadPromos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Подарочные коды',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Копируйте коды и вставляйте их в игру.',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.5,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (_giftCodes.isEmpty && _error == null)
                        Text(
                          'Активных промокодов пока нет.',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ..._giftCodes.map((entry) {
                        const accent = Color(0xFF2E7D32);
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.code,
                                      style: TextStyle(
                                        fontFamily: 'Consolas',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        letterSpacing: 0.5,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                      ),
                                    ),
                                    if (entry.reward.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        entry.reward,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => _copyCode(entry.code),
                                tooltip: 'Копировать код',
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      accent.withValues(alpha: 0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.copy_all_rounded,
                                  color: accent,
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
      ),
    );
  }
}

class _GiftCodeEntry {
  final String code;
  final String reward;

  const _GiftCodeEntry({
    required this.code,
    required this.reward,
  });
}
