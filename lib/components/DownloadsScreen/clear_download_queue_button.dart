import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class ClearDownloadQueueButton extends ConsumerStatefulWidget {
  const ClearDownloadQueueButton({super.key});

  @override
  ConsumerState<ClearDownloadQueueButton> createState() => _ClearDownloadQueueButtonState();
}

class _ClearDownloadQueueButtonState extends ConsumerState<ClearDownloadQueueButton> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _enabled
          ? () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.clearDownloadQueue),
                  content: Text(AppLocalizations.of(context)!.clearDownloadQueueConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(AppLocalizations.of(context)!.clear),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              setState(() {
                _enabled = false;
              });

              await GetIt.instance<DownloadsService>().clearDownloadQueue();

              if (!mounted) return;
              GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.downloadQueueCleared);
              setState(() {
                _enabled = true;
              });
            }
          : null,
      icon: const Icon(Icons.clear_all),
      tooltip: AppLocalizations.of(context)!.clearDownloadQueue,
    );
  }
}