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
/// - [selectFolder] == true  → pick one folder; the whole folder is sent.
/// - [selectFolder] == false → multi-select individual files.
class FileBrowserPage extends StatefulWidget {
  final bool selectFolder;

  const FileBrowserPage({required this.selectFolder, super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> with Refena {
  // Common external-storage roots on KitKat. The first existing one is used.
  // On many real KitKat devices /storage/emulated/0 does NOT exist and the
  // filesystem is rooted at /sdcard (a symlink) or /storage/sdcard0.
  static const _roots = ['/storage/emulated/0', '/sdcard', '/storage/sdcard0', '/storage'];

  // The resolved root for this session. Navigation is pinned to it: the user
  // can descend and come back up, but never above it.
  late final String _rootPath;

  late Directory _current;
  List<Directory> _dirs = [];
  List<File> _files = [];
  // file path -> size in bytes, statted once per listing (-1 when unknown).
  final Map<String, int> _sizes = {};
  final Set<String> _selectedFiles = {};
  // Monotonic token so a slow listing that is superseded by a newer navigation
  // does not clobber the current view (re-entrancy guard).
  int _loadId = 0;
  bool _loading = true;
  bool _hasError = false;

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
    int byName(FileSystemEntity a, FileSystemEntity b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
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

  // Navigation is pinned to the resolved root, so we only allow going up while
  // we are below it. This avoids the brittle path-length heuristic and the
  // dead-ends it caused when the root is /sdcard or /storage/sdcard0.
  bool get _canGoUp => _current.path != _rootPath;

  void _goUp() {
    if (!_canGoUp) {
      return;
    }
    _current = _current.parent;
    _load();
  }

  void _confirmFolder() {
    // ignore: discarded_futures
    ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(_current.path));
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
    final loc = LocaleSettings.currentLocale;
    final isZh = loc == AppLocale.zhCn || loc == AppLocale.zhTw || loc == AppLocale.zhHk;
    String tr(String en, String zh) => isZh ? zh : en;

    final atRoot = _current.path == _rootPath;
    final base = p.basename(_current.path);
    final title = atRoot ? tr('Internal storage', '内部存储') : (base.isEmpty ? _current.path : base);
    final isEmpty = _dirs.isEmpty && _files.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.fade, softWrap: false),
        actions: [
          if (_canGoUp)
            IconButton(
              onPressed: _goUp,
              icon: const Icon(Icons.arrow_upward),
              tooltip: tr('Up one level', '上一级'),
            ),
        ],
      ),
      body: Column(
        children: [
          // current path breadcrumb
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _current.path,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Partial-listing error strip: shown when some entries loaded but the
          // listing also threw (e.g. an unreadable sub-entry on KitKat).
          if (_hasError && !isEmpty && !_loading)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                tr('Some items could not be read', '部分内容无法读取'),
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
                            _hasError ? tr('Cannot open this folder', '无法打开此文件夹') : tr('Empty folder', '空文件夹'),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _dirs.length + _files.length,
                        itemBuilder: (context, index) {
                          if (index < _dirs.length) {
                            final dir = _dirs[index];
                            return ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(p.basename(dir.path)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _current = dir;
                                _load();
                              },
                            );
                          }

                          final file = _files[index - _dirs.length];
                          final size = _sizes[file.path] ?? -1;
                          final subtitle = size >= 0 ? size.asReadableFileSize : null;

                          if (widget.selectFolder) {
                            // Folder mode: files are shown for context only.
                            return ListTile(
                              enabled: false,
                              leading: const Icon(Icons.insert_drive_file_outlined),
                              title: Text(p.basename(file.path)),
                              subtitle: subtitle == null ? null : Text(subtitle),
                            );
                          }

                          // File mode: tap to (de)select.
                          final selected = _selectedFiles.contains(file.path);
                          return CheckboxListTile(
                            secondary: const Icon(Icons.insert_drive_file_outlined),
                            title: Text(p.basename(file.path)),
                            subtitle: subtitle == null ? null : Text(subtitle),
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
      floatingActionButton: widget.selectFolder
          ? FloatingActionButton.extended(
              onPressed: _confirmFolder,
              icon: const Icon(Icons.send),
              label: Text(tr('Send this folder', '发送此文件夹')),
            )
          : (_selectedFiles.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _confirmFiles,
                  icon: const Icon(Icons.send),
                  label: Text('${tr('Send', '发送')} (${_selectedFiles.length})'),
                )),
    );
  }
}
