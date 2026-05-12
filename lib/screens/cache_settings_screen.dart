import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/streaming_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class CacheSettingsScreen extends ConsumerStatefulWidget {
  const CacheSettingsScreen({super.key});
  static const routeName = "/settings/cache";

  @override
  ConsumerState<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends ConsumerState<CacheSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.streamingCache),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetCacheSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [
          _StreamingCacheEnabledToggle(),
          Divider(),
          _CacheStatisticsSection(),
          Divider(),
          _MaxCacheSizeSlider(),
          Divider(),
          _ClearCacheButton(),
        ],
      ),
    );
  }
}

/// Toggle to enable/disable streaming cache
class _StreamingCacheEnabledToggle extends ConsumerWidget {
  const _StreamingCacheEnabledToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.streamingCacheTitle),
      subtitle: Text(AppLocalizations.of(context)!.streamingCacheSubtitle),
      value: ref.watch(finampSettingsProvider.streamingCacheEnabled),
      onChanged: FinampSetters.setStreamingCacheEnabled,
    );
  }
}

/// Display cache size and entry count
class _CacheStatisticsSection extends ConsumerWidget {
  const _CacheStatisticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.streamingCacheStatistics,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12.0),
              FutureBuilder<int>(
                future: StreamingCacheService.instance.getTotalCacheSize(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text(
                      '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  final sizeMB = snapshot.data ?? 0;
                  return Text(
                    '${AppLocalizations.of(context)!.streamingCacheSize}: $sizeMB MB / ${FinampSettingsHelper.finampSettings.maxStreamingCacheSizeMB} MB',
                  );
                },
              ),
              const SizedBox(height: 8.0),
              FutureBuilder<int>(
                future: StreamingCacheService.instance.getCacheEntryCount(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text(
                      '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  final count = snapshot.data ?? 0;
                  return Text(
                    '${AppLocalizations.of(context)!.streamingCacheEntries}: $count',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slider to set max cache size
class _MaxCacheSizeSlider extends ConsumerWidget {
  const _MaxCacheSizeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxSizeMB = ref.watch(finampSettingsProvider.maxStreamingCacheSizeMB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.streamingCacheMaxSize,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12.0),
          Slider(
            value: maxSizeMB.toDouble(),
            min: 100,
            max: 5000,
            divisions: 98, // (5000 - 100) / 50 = 98
            label: '$maxSizeMB MB',
            onChanged: (value) {
              FinampSetters.setMaxStreamingCacheSizeMB(value.toInt());
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '100 MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '5000 MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            '${AppLocalizations.of(context)!.current}: $maxSizeMB MB',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to clear all cache with confirmation
class _ClearCacheButton extends ConsumerStatefulWidget {
  const _ClearCacheButton();

  @override
  ConsumerState<_ClearCacheButton> createState() => _ClearCacheButtonState();
}

class _ClearCacheButtonState extends ConsumerState<_ClearCacheButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.streamingCacheActions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12.0),
          ElevatedButton.icon(
            onPressed: () => _showClearCacheDialog(context),
            icon: const Icon(TablerIcons.trash),
            label: Text(AppLocalizations.of(context)!.clearStreamingCache),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            AppLocalizations.of(context)!.clearStreamingCacheDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.clearStreamingCacheConfirm),
        content: Text(AppLocalizations.of(context)!.clearStreamingCacheConfirmDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.noButtonLabel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.deleteDownloadsConfirmButtonText),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      // Clear database entries
      await StreamingCacheService.instance.clearAllEntries();

      // Clear cache files
      final cacheDir = await getApplicationCacheDirectory();
      final streamingCacheDir = Directory('${cacheDir.path}/finamp_streaming_cache');

      if (await streamingCacheDir.exists()) {
        streamingCacheDir.deleteSync(recursive: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.streamingCacheClearedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
