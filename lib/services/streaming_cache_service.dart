import 'dart:io';

import 'package:isar/isar.dart';
import 'package:logging/logging.dart';

import '../models/finamp_models.dart';

/// Service for managing streaming cache metadata using Isar database.
/// Tracks cache entries, file sizes, and access times for efficient cache management.
class StreamingCacheService {
  static final _log = Logger('StreamingCacheService');
  static StreamingCacheService? _instance;
  late final Isar _isar;

  StreamingCacheService._();

  /// Initialize the service with an Isar instance
  static Future<void> init(Isar isar) async {
    _instance = StreamingCacheService._();
    _instance!._isar = isar;
    _log.info('StreamingCacheService initialized');
  }

  /// Get the singleton instance
  static StreamingCacheService get instance {
    if (_instance == null) {
      throw StateError('StreamingCacheService not initialized. Call init() first.');
    }
    return _instance!;
  }

  /// Record a newly cached URL in the database
  Future<void> recordCachedUrl({
    required String urlHash,
    required String fileUrl,
    required int fileSizeMB,
  }) async {
    try {
      final now = DateTime.now();
      final entry = StreamingCacheEntry(
        urlHash: urlHash,
        fileUrl: fileUrl,
        fileSizeMB: fileSizeMB,
        createdAt: now,
        lastAccessedAt: now,
        lastModifiedAt: now,
      );

      await _isar.writeTxn(() async {
        await _isar.streamingCacheEntrys.put(entry);
      });

      _log.info('Recorded cache entry: $urlHash ($fileSizeMB MB)');
    } catch (e) {
      _log.severe('Error recording cache entry', e);
      rethrow;
    }
  }

  /// Get a cache entry by URL hash
  Future<StreamingCacheEntry?> getCacheEntry(String urlHash) async {
    try {
      return await _isar.streamingCacheEntrys.where().urlHashEqualTo(urlHash).findFirst();
    } catch (e) {
      _log.severe('Error getting cache entry', e);
      rethrow;
    }
  }

  /// Get all cache entries
  Future<List<StreamingCacheEntry>> getAllCacheEntries() async {
    try {
      return await _isar.streamingCacheEntrys.where().findAll();
    } catch (e) {
      _log.severe('Error getting all cache entries', e);
      rethrow;
    }
  }

  /// Get total size of all cached files in MB
  Future<int> getTotalCacheSize() async {
    try {
      final entries = await getAllCacheEntries();
      return entries.fold<int>(0, (sum, entry) => sum + entry.fileSizeMB);
    } catch (e) {
      _log.severe('Error calculating total cache size', e);
      rethrow;
    }
  }

  /// Get number of cached entries
  Future<int> getCacheEntryCount() async {
    try {
      return await _isar.streamingCacheEntrys.count();
    } catch (e) {
      _log.severe('Error getting cache entry count', e);
      rethrow;
    }
  }

  /// Update the last accessed time for a cache entry (mark as recently used)
  Future<void> updateAccessTime(String urlHash) async {
    try {
      final entry = await getCacheEntry(urlHash);
      if (entry == null) {
        _log.warning('Cache entry not found for update: $urlHash');
        return;
      }

      entry.lastAccessedAt = DateTime.now();

      await _isar.writeTxn(() async {
        await _isar.streamingCacheEntrys.put(entry);
      });

      _log.finest('Updated access time for cache entry: $urlHash');
    } catch (e) {
      _log.severe('Error updating cache entry access time', e);
      rethrow;
    }
  }

  /// Delete a cache entry from the database
  Future<void> deleteCacheEntry(String urlHash) async {
    try {
      final entry = await getCacheEntry(urlHash);
      if (entry == null) {
        _log.warning('Cache entry not found for deletion: $urlHash');
        return;
      }

      await _isar.writeTxn(() async {
        await _isar.streamingCacheEntrys.delete(entry.isarId);
      });

      _log.info('Deleted cache entry: $urlHash');
    } catch (e) {
      _log.severe('Error deleting cache entry', e);
      rethrow;
    }
  }

  /// Get the oldest cache entries (for LRU cleanup)
  /// Returns entries sorted by lastAccessedAt (oldest first)
  Future<List<StreamingCacheEntry>> getOldestEntries(int count) async {
    try {
      return await _isar.streamingCacheEntrys
          .where()
          .sortByLastAccessedAt()
          .limit(count)
          .findAll();
    } catch (e) {
      _log.severe('Error getting oldest cache entries', e);
      rethrow;
    }
  }

  /// Get cache entries that should be deleted to stay under maxSizeMB
  /// Returns entries sorted by access time (oldest first)
  Future<List<StreamingCacheEntry>> getEntriesToDelete(int currentSizeMB, int maxSizeMB) async {
    try {
      if (currentSizeMB <= maxSizeMB) {
        return [];
      }

      final entriesToDelete = <StreamingCacheEntry>[];
      var sizeToFree = currentSizeMB - maxSizeMB;
      
      final allEntries = await _isar.streamingCacheEntrys
          .where()
          .sortByLastAccessedAt()
          .findAll();

      for (final entry in allEntries) {
        if (sizeToFree <= 0) break;
        entriesToDelete.add(entry);
        sizeToFree -= entry.fileSizeMB;
      }

      return entriesToDelete;
    } catch (e) {
      _log.severe('Error getting entries to delete', e);
      rethrow;
    }
  }

  /// Clean up cache entries for files that no longer exist
  /// Also removes entries that reference non-existent files
  Future<int> cleanupMissingFiles(String cacheDirectory) async {
    try {
      final entries = await getAllCacheEntries();
      var deletedCount = 0;

      for (final entry in entries) {
        final cacheFile = File('$cacheDirectory/${entry.cacheFileName}');
        if (!cacheFile.existsSync()) {
          await deleteCacheEntry(entry.urlHash);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        _log.info('Cleaned up $deletedCount cache entries for missing files');
      }

      return deletedCount;
    } catch (e) {
      _log.severe('Error cleaning up missing files', e);
      rethrow;
    }
  }

  /// Delete all cache entries
  Future<void> clearAllEntries() async {
    try {
      await _isar.writeTxn(() async {
        await _isar.streamingCacheEntrys.clear();
      });

      _log.info('Cleared all cache entries from database');
    } catch (e) {
      _log.severe('Error clearing all cache entries', e);
      rethrow;
    }
  }
}
