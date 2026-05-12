import '../models/jellyfin_models.dart';

/// Represents a folder with its items and subfolders
class FolderItem {
  final String path;
  final String name;
  final List<BaseItemDto> items;
  final List<FolderItem> subfolders;

  FolderItem({
    required this.path,
    required this.name,
    required this.items,
    this.subfolders = const [],
  });
}

/// Helper class to handle folder grouping based on item paths
class FolderHelper {
  /// Groups items by their paths into a folder structure
  static List<FolderItem> groupItemsByPath(List<BaseItemDto> items) {
    // Filter out items without paths
    final validItems = items.where((item) => item.path != null && item.path!.isNotEmpty).toList();

    if (validItems.isEmpty) {
      return [];
    }

    final separator = RegExp(r'[\/\\]');
    
    // First, build a map of all directories and their items
    final directoryMap = <String, List<BaseItemDto>>{};
    
    // Add all items to their respective directories
    for (final item in validItems) {
      var path = item.path!;
      // Remove leading separators
      path = path.replaceFirst(RegExp(r'^[\/\\]+'), '');
      final parts = path.split(separator);
      
      // For each item, add it to all its parent directories
      for (int i = 1; i < parts.length; i++) {
        final dirPath = parts.sublist(0, i).join('/');
        if (!directoryMap.containsKey(dirPath)) {
          directoryMap[dirPath] = [];
        }
        // Only add the item to its immediate parent directory
        if (i == parts.length - 1) {
          directoryMap[dirPath]!.add(item);
        }
      }
    }

    // Build the folder tree starting from root
    List<FolderItem> folders = _buildFolderTree(directoryMap, separator);
    
    return folders;
  }

  /// Simplifies folder path by skipping single-child directories
  static List<FolderItem> _simplifySinglePath(List<FolderItem> folders) {
    if (folders.length != 1) return folders;
    
    var currentFolder = folders.first;
    var simplifiedPath = currentFolder;
    bool changed;
    
    do {
      changed = false;
      if (simplifiedPath.items.isEmpty && simplifiedPath.subfolders.length == 1) {
        simplifiedPath = simplifiedPath.subfolders.first;
        changed = true;
      }
    } while (changed);
    
    return [simplifiedPath];
  }

  /// Builds a complete folder tree from a directory map
  static List<FolderItem> _buildFolderTree(Map<String, List<BaseItemDto>> directoryMap, RegExp separator) {
    final rootFolders = <FolderItem>[];
    
    // Find all root directories (those with no parent in the map)
    for (final dirPath in directoryMap.keys) {
      final parts = dirPath.split(separator);
      if (parts.length == 1) {
        // Root directory
        final folder = _buildFolderRecursive(dirPath, directoryMap, separator);
        if (folder != null) {
          rootFolders.add(folder);
        }
      }
    }
    
    // Check for any orphaned directories and add them
    for (final dirPath in directoryMap.keys) {
      final parts = dirPath.split(separator);
      if (parts.length > 1) {
        final parentPath = parts.sublist(0, parts.length - 1).join('/');
        if (!directoryMap.containsKey(parentPath)) {
          // This is a root-level orphan directory
          final folder = _buildFolderRecursive(dirPath, directoryMap, separator);
          if (folder != null) {
            rootFolders.add(folder);
          }
        }
      }
    }

    // Sort folders alphabetically
    rootFolders.sort((a, b) => a.name.compareTo(b.name));
    return rootFolders;
  }

  /// Recursively builds a folder and its subfolders
  static FolderItem? _buildFolderRecursive(String path, Map<String, List<BaseItemDto>> directoryMap, RegExp separator) {
    final parts = path.split(separator);
    final name = parts.isNotEmpty ? parts.last : path;
    
    // Check if this directory has direct items
    final directItems = directoryMap[path] ?? [];
    
    // Find all subdirectories
    final subfolders = <FolderItem>[];
    
    for (final dirPath in directoryMap.keys) {
      if (dirPath.startsWith('$path/') && dirPath != path) {
        final subParts = dirPath.split(separator);
        if (subParts.length == parts.length + 1) {
          // Direct child directory
          final subfolder = _buildFolderRecursive(dirPath, directoryMap, separator);
          if (subfolder != null) {
            subfolders.add(subfolder);
          }
        }
      }
    }
    
    // Sort subfolders alphabetically
    subfolders.sort((a, b) => a.name.compareTo(b.name));
    
    // Only create folder if it has items or subfolders
    if (directItems.isEmpty && subfolders.isEmpty) {
      return null;
    }

    return FolderItem(
      path: path,
      name: name,
      items: directItems,
      subfolders: subfolders,
    );
  }
}
