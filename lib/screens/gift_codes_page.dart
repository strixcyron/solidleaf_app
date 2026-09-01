import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GiftCodesPage extends StatefulWidget {
  const GiftCodesPage({super.key});

  @override
  State<GiftCodesPage> createState() => _GiftCodesPageState();
}

class _GiftCodesPageState extends State<GiftCodesPage> {
  static const List<_GiftCodeEntry> _giftCodes = [
    _GiftCodeEntry(code: '5YRBRF9', status: 'Активен', permanent: true),
    _GiftCodeEntry(code: '1999GIFT', status: 'Активен', permanent: true),
    _GiftCodeEntry(code: 'GachaGaming1999', status: 'Активен', permanent: true),
    _GiftCodeEntry(
      code: 'MainStoryChapt12',
      status: 'Закончен',
      permanent: false,
    ),
    _GiftCodeEntry(code: 'KnightsDuty', status: 'Закончен', permanent: false),
    _GiftCodeEntry(code: 'RestlessSouls', status: 'Закончен', permanent: false),
    _GiftCodeEntry(
      code: 'Halfannivlive0404',
      status: 'Закончен',
      permanent: false,
    ),
    _GiftCodeEntry(code: 'PastShadows', status: 'Закончен', permanent: false),
    _GiftCodeEntry(code: 'DeadSilence', status: 'Закончен', permanent: false),
    _GiftCodeEntry(
      code: 'PaperHeronLiveHost0404',
      status: 'Закончен',
      permanent: false,
    ),
    _GiftCodeEntry(code: 'UndyingLight', status: 'Закончен', permanent: false),
    _GiftCodeEntry(code: 'LastDefence', status: 'Закончен', permanent: false),
    _GiftCodeEntry(code: 'NoMercy', status: 'Закончен', permanent: false),
  ];

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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
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
                  'Копируйте коды и вставляйте их в игру. Периодически проверяйте обновления.',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                ..._giftCodes.map((entry) {
                  final active = entry.permanent;
                  final accent = active
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE53935);
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      entry.status,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (entry.permanent)
                                    Text(
                                      'Без срока годности',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _copyCode(entry.code),
                          tooltip: 'Копировать код',
                          style: IconButton.styleFrom(
                            backgroundColor: accent.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.copy_all_rounded, color: accent),
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
  final String status;
  final bool permanent;

  const _GiftCodeEntry({
    required this.code,
    required this.status,
    required this.permanent,
  });
}
