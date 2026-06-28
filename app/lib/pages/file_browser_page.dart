import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:path/path.dart' as p;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// A Material 3, in-app file/folder browser.
///
/// It exists for **Android 4.4 KitKat**, where the system Storage Access
/// Framework directory-tree picker (`ACTION_OPEN_DOCUMENT_TREE`) is API 21+ and
/// therefore unavailable. On KitKat `READ_EXTERNAL_STORAGE` is granted at install
/// time and there is no scoped storage, so we can read the filesystem directly
/// via `dart:io` and let the user navigate it themselves.
///
/// Sized up for tablets: large touch targets, a prominent "up" button, and an
/// editable address bar so a path can be typed directly.
///
/// - [selectFolder] == true  → pick one folder.
/// - [selectFolder] == false → multi-select individual files.
/// - [returnPath] == true     → pop with the chosen folder path (a String)
///   instead of adding it to the send selection (used by the receive-destination
///   setting on Android 4.4).
class FileBrowserPage extends StatefulWidget {
  final bool selectFolder;
  final bool returnPath;

  const FileBrowserPage({
    required this.selectFolder,
    this.returnPath = false,
    super.key,
  });

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> with Refena {
  // Common external-storage roots on KitKat. The first existing one is used.
  // On many real KitKat devices /storage/emulated/0 does NOT exist and the
  // filesystem is rooted at /sdcard (a symlink) or /storage/sdcard0.
  static const _roots = [
    '/storage/emulated/0',
    '/sdcard',
    '/storage/sdcard0',
    '/storage'
  ];

  // The resolved storage root for this session. The "up" button is floored here
  // (you can descend and come back, but the button won't take you above it);
  // the editable address bar can still jump anywhere the app can read.
  late final String _rootPath;

  late Directory _current;
  // Backs the editable address bar; kept in sync with _current on every navigation.
  final TextEditingController _pathController = TextEditingController();
  List<Directory> _dirs = [];
  List<File> _files = [];
  // file path -> size in bytes, statted once per listing (-1 when unknown).
  final Map<String, int> _sizes = {};
  final Set<String> _selectedFiles = {};
  // Monotonic token so a slow listing superseded by a newer navigation cannot
  // clobber the current view (re-entrancy guard).
  int _loadId = 0;
  bool _loading = true;
  bool _hasError = false;

  bool get _isZh {
    final loc = LocaleSettings.currentLocale;
    return loc == AppLocale.zhCn ||
        loc == AppLocale.zhTw ||
        loc == AppLocale.zhHk;
  }

  String _t(String en, String zh) => _isZh ? zh : en;

  @override
  void initState() {
    super.initState();
    final root = _roots.firstWhere((path) {
      try {
        return Directory(path).existsSync();
      } catch (_) {
        return false;
      }
    }, orElse: () => '/storage/emulated/0');
    _rootPath = root;
    _current = Directory(root);
    _pathController.text = root;
    _load();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  /// Navigate to [dir] and keep the address bar in sync.
  void _navigateTo(Directory dir) {
    _current = dir;
    _pathController.text = dir.path;
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadId;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final dirs = <Directory>[];
    final files = <File>[];
    final sizes = <String, int>{};
    var hadError = false;
    try {
      await for (final entity in _current.list(followLinks: false)) {
        if (token != _loadId) return; // superseded by a newer navigation
        if (entity is Directory) {
          dirs.add(entity);
        } else if (entity is File) {
          files.add(entity);
          try {
            sizes[entity.path] = entity.lengthSync();
          } catch (_) {
            sizes[entity.path] = -1;
          }
        }
      }
    } catch (_) {
      hadError = true;
    }
    int byName(FileSystemEntity a, FileSystemEntity b) => p
        .basename(a.path)
        .toLowerCase()
        .compareTo(p.basename(b.path).toLowerCase());
    dirs.sort(byName);
    files.sort(byName);
    if (!mounted || token != _loadId) return;
    setState(() {
      _dirs = dirs;
      _files = files;
      _sizes
        ..clear()
        ..addAll(sizes);
      _hasError = hadError;
      _loading = false;
    });
  }

  bool get _canGoUp =>
      _current.path != _rootPath && _current.parent.path != _current.path;

  void _goUp() {
    if (_canGoUp) {
      _navigateTo(_current.parent);
    }
  }

  /// Jump to a path typed into the address bar.
  void _navigateToTyped(String value) {
    final path = value.trim();
    if (path.isEmpty) {
      return;
    }
    final dir = Directory(path);
    bool exists;
    try {
      exists = dir.existsSync();
    } catch (_) {
      exists = false;
    }
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Path not found or not readable', '路径不存在或无法读取')),
      ));
      _pathController.text = _current.path; // revert
      return;
    }
    FocusScope.of(context).unfocus();
    _navigateTo(dir);
  }

  void _confirmFolder() {
    if (widget.returnPath) {
      context.pop(_current.path);
      return;
    }
    // ignore: discarded_futures
    ref
        .redux(selectedSendingFilesProvider)
        .dispatchAsync(AddDirectoryAction(_current.path));
    context.pop();
  }

  void _confirmFiles() {
    if (_selectedFiles.isEmpty) {
      return;
    }
    // ignore: discarded_futures
    ref.redux(selectedSendingFilesProvider).dispatchAsync(AddFilesAction(
          files: _selectedFiles.map((path) => XFile(path)).toList(),
          converter: CrossFileConverters.convertXFile,
        ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atRoot = _current.path == _rootPath;
    final base = p.basename(_current.path);
    final title = atRoot
        ? _t('Internal storage', '内部存储')
        : (base.isEmpty ? _current.path : base);
    final isEmpty = _dirs.isEmpty && _files.isEmpty;

    // This page already uses explicit, tablet-friendly sizes, so opt it out of
    // the app-wide tablet text scaling (see main.dart) to avoid double-enlarging.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            // Prominent "up" button — large, labelled, only shown when we can go up.
            if (_canGoUp)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.tonalIcon(
                    onPressed: _goUp,
                    icon: const Icon(Icons.arrow_upward, size: 26),
                    label: Text(
                      _t('Up to previous folder', '返回上一个文件夹'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            // Editable address bar — type a path and tap Go (or the keyboard's Go).
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _pathController,
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  labelText: _t('Path (tap to edit)', '路径（点击可编辑）'),
                  prefixIcon: const Icon(Icons.folder_open),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: _t('Go', '前往'),
                    onPressed: () => _navigateToTyped(_pathController.text),
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                ),
                onSubmitted: _navigateToTyped,
              ),
            ),
            // Partial-listing error strip: some entries loaded but the listing threw.
            if (_hasError && !isEmpty && !_loading)
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  _t('Some items could not be read', '部分内容无法读取'),
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer, fontSize: 15),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _hasError
                                  ? _t('Cannot open this folder', '无法打开此文件夹')
                                  : _t('Empty folder', '空文件夹'),
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 17),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _dirs.length + _files.length,
                          itemBuilder: (context, index) {
                            if (index < _dirs.length) {
                              final dir = _dirs[index];
                              return ListTile(
                                visualDensity: const VisualDensity(vertical: 2),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: const Icon(Icons.folder, size: 36),
                                title: Text(p.basename(dir.path),
                                    style: const TextStyle(fontSize: 18)),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 28),
                                onTap: () => _navigateTo(dir),
                              );
                            }

                            final file = _files[index - _dirs.length];
                            final size = _sizes[file.path] ?? -1;
                            final subtitle =
                                size >= 0 ? size.asReadableFileSize : null;

                            if (widget.selectFolder) {
                              // Folder mode: files are shown for context only.
                              return ListTile(
                                enabled: false,
                                visualDensity: const VisualDensity(vertical: 2),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 34),
                                title: Text(p.basename(file.path),
                                    style: const TextStyle(fontSize: 17)),
                                subtitle: subtitle == null
                                    ? null
                                    : Text(subtitle,
                                        style: const TextStyle(fontSize: 14)),
                              );
                            }

                            // File mode: tap anywhere on the row to (de)select.
                            final selected = _selectedFiles.contains(file.path);
                            return CheckboxListTile(
                              visualDensity: const VisualDensity(vertical: 2),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              secondary: const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 34),
                              title: Text(p.basename(file.path),
                                  style: const TextStyle(fontSize: 17)),
                              subtitle: subtitle == null
                                  ? null
                                  : Text(subtitle,
                                      style: const TextStyle(fontSize: 14)),
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedFiles.add(file.path);
                                  } else {
                                    _selectedFiles.remove(file.path);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
        // Large, full-width confirm button at the bottom.
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: widget.selectFolder
                ? FilledButton.icon(
                    onPressed: _confirmFolder,
                    icon: const Icon(Icons.check, size: 26),
                    label: Text(
                      _t('Select current folder', '选择当前文件夹'),
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _selectedFiles.isEmpty ? null : _confirmFiles,
                    icon: const Icon(Icons.check, size: 26),
                    label: Text(
                      _selectedFiles.isEmpty
                          ? _t('Select files', '选择当前文件')
                          : '${_t('Select files', '选择当前文件')} (${_selectedFiles.length})',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
