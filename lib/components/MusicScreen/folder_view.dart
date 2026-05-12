import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/folder_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../../services/item_helper.dart';
import '../../services/queue_service.dart';
import '../../menus/components/playbackActions/playback_actions.dart';
import '../AlbumScreen/track_list_tile.dart';
import 'item_collection_wrapper.dart';
import 'music_screen_tab_view.dart';

class FolderView extends ConsumerStatefulWidget {
  const FolderView({
    super.key,
    this.view,
    this.genreFilter,
    this.sortByOverride,
    this.sortOrderOverride,
    this.isFavoriteOverride,
  });

  final BaseItemDto? view;
  final BaseItemDto? genreFilter;
  final SortBy? sortByOverride;
  final SortOrder? sortOrderOverride;
  final bool? isFavoriteOverride;

  @override
  ConsumerState<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends ConsumerState<FolderView> {
  final ValueNotifier<List<FolderItem>> _folders = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final List<BaseItemDto> _allTracks = [];
  bool _isOffline = false;

  // Store the full navigation path as a list of FolderItem
  List<FolderItem> _navigationPath = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void didUpdateWidget(FolderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.view?.id != oldWidget.view?.id ||
        widget.genreFilter?.id != oldWidget.genreFilter?.id ||
        widget.isFavoriteOverride != oldWidget.isFavoriteOverride) {
      _loadFolders();
    }
  }

  Future<void> _loadFolders() async {
    _isLoading.value = true;
    try {
      final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
      final isarDownloader = GetIt.instance<DownloadsService>();
      final settings = FinampSettingsHelper.finampSettings;
      _isOffline = settings.isOffline;

      List<BaseItemDto>? tracks;
      if (_isOffline) {
        final offlineItems = await isarDownloader.getAllTracks(
          nameFilter: null,
          viewFilter: widget.view?.id,
          nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
          onlyFavorites: (widget.isFavoriteOverride == true ||
                  (widget.isFavoriteOverride == null && settings.onlyShowFavorites)) &&
              settings.trackOfflineFavorites,
          genreFilter: widget.genreFilter,
        );
        tracks = offlineItems.map((e) => e.baseItem).nonNulls.toList();
      } else {
        tracks = await jellyfinApiHelper.getItems(
          parentItem: widget.view,
          includeItemTypes: BaseItemDtoType.track.jellyfinName,
          filters: (widget.isFavoriteOverride == true ||
                  (widget.isFavoriteOverride == null && settings.onlyShowFavorites))
              ? "IsFavorite"
              : null,
          genreFilter: widget.genreFilter,
          limit: 10000,
        );
      }

      _allTracks.clear();
      _allTracks.addAll(tracks ?? []);

      final folders = FolderHelper.groupItemsByPath(_allTracks);
      _folders.value = folders;

      _navigationPath.clear();
    } catch (e) {
      debugPrint('Error loading folders: $e');
      _folders.value = [];
    } finally {
      _isLoading.value = false;
    }
  }

  void _navigateToFolder(FolderItem folder) {
    setState(() {
      _navigationPath.add(folder);
    });
  }

  void _navigateBack() {
    if (_navigationPath.isNotEmpty) {
      setState(() {
        _navigationPath.removeLast();
      });
    }
  }

  void _navigateToPathIndex(int index, List<FolderItem> allFolders) {
    setState(() {
      if (index == 0) {
        // Go to root
        _navigationPath.clear();
      } else {
        // Go to the specified index in the path
        _navigationPath = _navigationPath.sublist(0, index);
      }
    });
  }

  /// Get the current folder at the end of the navigation path
  FolderItem? get _currentFolder {
    return _navigationPath.isEmpty ? null : _navigationPath.last;
  }

  /// Get the list of folders to display at the current navigation level
  List<FolderItem> _getCurrentFolders(List<FolderItem> allFolders) {
    if (_navigationPath.isEmpty) {
      return allFolders;
    }
    
    FolderItem current = _navigationPath.first;
    for (int i = 1; i < _navigationPath.length; i++) {
      // Find the corresponding folder in the current level's subfolders
      final nextFolder = current.subfolders.firstWhere(
        (f) => f.path == _navigationPath[i].path,
        orElse: () => _navigationPath[i],
      );
      current = nextFolder;
    }
    return current.subfolders;
  }

  /// Get the list of tracks to display at the current navigation level
  List<BaseItemDto> _getCurrentTracks(List<FolderItem> allFolders) {
    if (_navigationPath.isEmpty) {
      return [];
    }
    
    FolderItem current = _navigationPath.first;
    for (int i = 1; i < _navigationPath.length; i++) {
      final nextFolder = current.subfolders.firstWhere(
        (f) => f.path == _navigationPath[i].path,
        orElse: () => _navigationPath[i],
      );
      current = nextFolder;
    }
    return current.items;
  }

  @override
  Widget build(BuildContext context) {
    final isGridView = ref.watch(finampSettingsProvider.contentViewType) == ContentViewType.grid;

    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<List<FolderItem>>(
          valueListenable: _folders,
          builder: (context, folders, _) {
            if (folders.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildFolderContent(context, folders, isGridView);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.folder_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No folders found',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your library may not have folder information available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<BaseItemDto> _getAllTracksInFolder(List<FolderItem> allFolders) {
    final tracks = <BaseItemDto>[];
    
    void addTracksFromFolders(List<FolderItem> folders) {
      for (final folder in folders) {
        tracks.addAll(folder.items);
        addTracksFromFolders(folder.subfolders);
      }
    }
    
    if (_navigationPath.isEmpty) {
      // Add all tracks from all root folders
      addTracksFromFolders(allFolders);
    } else {
      // Add all tracks from the current folder and its subfolders
      // First, find the current folder in the tree
      FolderItem? currentFolder;
      List<FolderItem> currentLevel = allFolders;
      
      for (final pathFolder in _navigationPath) {
        currentFolder = currentLevel.firstWhere(
          (f) => f.path == pathFolder.path,
          orElse: () => pathFolder,
        );
        currentLevel = currentFolder.subfolders;
      }
      
      if (currentFolder != null) {
        void addFromFolder(FolderItem folder) {
          tracks.addAll(folder.items);
          for (final subfolder in folder.subfolders) {
            addFromFolder(subfolder);
          }
        }
        addFromFolder(currentFolder);
      }
    }
    
    return tracks;
  }

  BaseItemDto _createFolderPlayableItem(FolderItem? folder, List<FolderItem> allFolders) {
    return BaseItemDto(
      id: BaseItemId(Random().nextInt(999999999).toString()),
      name: folder?.name ?? 'All Music',
      type: BaseItemDtoType.folder.jellyfinName,
    );
  }

  Widget _buildPlaybackActions(BuildContext context, List<FolderItem> allFolders) {
    final tracks = _getAllTracksInFolder(allFolders);
    if (tracks.isEmpty) return const SizedBox.shrink();
    
    final queueService = GetIt.instance<QueueService>();
    final folderName = _navigationPath.isEmpty ? 'All Music' : _navigationPath.last.name;
    final fakeBaseItem = BaseItemDto(
      id: BaseItemId(Random().nextInt(999999999).toString()),
      name: folderName,
      type: BaseItemDtoType.folder.jellyfinName,
    );
    final source = QueueItemSource.fromBaseItem(fakeBaseItem);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Play Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await queueService.startPlayback(
                  items: tracks,
                  source: source,
                  order: FinampPlaybackOrder.linear,
                );
              },
              icon: const Icon(TablerIcons.player_play),
              label: const Text('Play'),
            ),
          ),
          const SizedBox(width: 8.0),
          // Shuffle Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await queueService.startPlayback(
                  items: tracks,
                  source: source,
                  order: FinampPlaybackOrder.shuffled,
                );
              },
              icon: const Icon(TablerIcons.arrows_shuffle),
              label: const Text('Shuffle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderContent(BuildContext context, List<FolderItem> folders, bool isGridView) {
    final displayFolders = _getCurrentFolders(folders);
    final displayTracks = _getCurrentTracks(folders);

    return Column(
      children: [
        _buildPathBreadcrumb(context, folders),
        _buildPlaybackActions(context, folders),
        Expanded(
          child: isGridView
              ? _buildGridView(context, displayFolders, displayTracks)
              : _buildListView(context, displayFolders, displayTracks),
        ),
      ],
    );
  }

  Widget _buildPathBreadcrumb(BuildContext context, List<FolderItem> allFolders) {
    final breadcrumbChildren = <Widget>[];

    // Add Root
    breadcrumbChildren.add(
      InkWell(
        onTap: _navigationPath.isEmpty
            ? null
            : () => _navigateToPathIndex(0, allFolders),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: _navigationPath.isEmpty
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            'Root',
            style: TextStyle(
              color: _navigationPath.isEmpty
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );

    // Add each folder in the navigation path
    for (int i = 0; i < _navigationPath.length; i++) {
      final folder = _navigationPath[i];
      final isLast = i == _navigationPath.length - 1;
      
      breadcrumbChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(
            Icons.chevron_right,
            size: 16.0,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );

      breadcrumbChildren.add(
        InkWell(
          onTap: isLast
              ? null
              : () => _navigateToPathIndex(i + 1, allFolders),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: isLast
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              folder.name,
              style: TextStyle(
                color: isLast
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
      );
    }

    // Add back button if not at root
    if (_navigationPath.isNotEmpty) {
      breadcrumbChildren.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: InkWell(
            onTap: _navigateBack,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                size: 18.0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: breadcrumbChildren,
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<FolderItem> folders, List<BaseItemDto> tracks) {
    final allItems = [...folders, ...tracks];

    if (allItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];

        if (item is FolderItem) {
          return FolderTile(
            folder: item,
            isGrid: false,
            onTap: () => _navigateToFolder(item),
          );
        } else if (item is BaseItemDto) {
          return TrackListTile(
            item: item,
            isTrack: true,
            index: index,
            isShownInSearchOrHistory: false,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGridView(BuildContext context, List<FolderItem> folders, List<BaseItemDto> tracks) {
    final allItems = [...folders, ...tracks];

    if (allItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: FinampSettingsHelper.finampSettings.useFixedSizeGridTiles
          ? SliverGridDelegateWithFixedSizeTiles(
              gridTileSize: FinampSettingsHelper.finampSettings.fixedGridTileSize.toDouble(),
            )
          : SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.orientationOf(context) == Orientation.landscape
                  ? FinampSettingsHelper.finampSettings.contentGridViewCrossAxisCountLandscape
                  : FinampSettingsHelper.finampSettings.contentGridViewCrossAxisCountPortrait,
            ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];

        if (item is FolderItem) {
          return FolderTile(
            folder: item,
            isGrid: true,
            onTap: () => _navigateToFolder(item),
          );
        } else if (item is BaseItemDto) {
          return ItemCollectionWrapper(
            item: item,
            isPlaylist: false,
            isGrid: true,
            genreFilter: widget.genreFilter,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    this.onTap,
    this.isGrid = false,
  });

  final FolderItem folder;
  final VoidCallback? onTap;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (isGrid) {
      return GestureDetector(
        onTap: onTap,
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Icon(
                  TablerIcons.folder,
                  size: 64,
                  color: primaryColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  folder.name,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (folder.items.isNotEmpty || folder.subfolders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                  child: Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                TablerIcons.folder,
                color: primaryColor,
                size: 24.0,
              ),
            ),
            title: Text(
              folder.name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15.0,
              ),
            ),
            subtitle: folder.subfolders.isNotEmpty || folder.items.isNotEmpty
                ? Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  )
                : null,
            trailing: folder.subfolders.isNotEmpty
                ? Icon(
                    Icons.chevron_right,
                    color: primaryColor.withOpacity(0.7),
                  )
                : null,
          ),
        ),
      );
    }
  }

  String _getSubtitle() {
    final parts = <String>[];
    if (folder.items.isNotEmpty) {
      parts.add('${folder.items.length} ${folder.items.length == 1 ? 'song' : 'songs'}');
    }
    if (folder.subfolders.isNotEmpty) {
      parts.add('${folder.subfolders.length} ${folder.subfolders.length == 1 ? 'subfolder' : 'subfolders'}');
    }
    return parts.join(' · ');
  }
}
