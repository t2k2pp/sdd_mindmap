import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'export_import_service.dart';
import 'models.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: const MindMapTaskApp(),
    ),
  );
}

class MindMapTaskApp extends StatelessWidget {
  const MindMapTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SDD MindMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF136F63)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tabs = const [
    Tab(icon: Icon(Icons.hub_outlined), text: 'マップ'),
    Tab(icon: Icon(Icons.checklist), text: 'タスク'),
    Tab(icon: Icon(Icons.settings_outlined), text: '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        if (!app.isReady) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(title: const Text('MindMap Task App'), bottom: TabBar(tabs: _tabs)),
            body: const TabBarView(
              children: [MapTab(), TaskTab(), SettingsTab()],
            ),
          ),
        );
      },
    );
  }
}

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final map = app.selectedMap;

    if (map == null) {
      return Center(
        child: FilledButton(
          onPressed: () async {
            final title = await _askText(context, title: 'マップ作成', hint: 'マップ名');
            if (title == null || title.trim().isEmpty) return;
            if (!context.mounted) return;
            await context.read<AppState>().addMap(title: title.trim());
          },
          child: const Text('最初のマップを作成'),
        ),
      );
    }

    final nodes = app.selectedMapNodes;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: map.id,
                  decoration: const InputDecoration(labelText: 'マップ選択', border: OutlineInputBorder()),
                  items: app.maps
                      .map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.title, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      context.read<AppState>().selectMap(id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '新規マップ',
                onPressed: () async {
                  final title = await _askText(context, title: '新規マップ', hint: 'マップ名');
                  if (title == null || title.trim().isEmpty) return;
                  if (!context.mounted) return;
                  await context.read<AppState>().addMap(title: title.trim());
                },
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'マップ削除',
                onPressed: () async {
                  final ok = await _confirm(context, 'マップ「${map.title}」を削除しますか？');
                  if (!ok) return;
                  if (!context.mounted) return;
                  await context.read<AppState>().deleteMap(map.id);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(500),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        backgroundBlendMode: BlendMode.softLight,
                      ),
                    ),
                  ),
                  for (final node in nodes)
                    Positioned(
                      left: node.position.x,
                      top: node.position.y,
                      child: _NodeCard(node: node),
                    ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final node = await _showNodeEditor(context, mapId: map.id);
                      if (node == null) return;
                      if (!context.mounted) return;
                      await context.read<AppState>().addNode(
                            mapId: map.id,
                            title: node.title,
                            description: node.description,
                            type: node.type,
                            url: node.url,
                          );
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('ノード追加'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node});

  final MindNode node;

  Color _typeColor(NodeType type) {
    switch (type) {
      case NodeType.goal:
        return Colors.orange;
      case NodeType.project:
        return Colors.blue;
      case NodeType.reference:
        return Colors.green;
      case NodeType.concept:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        context.read<AppState>().moveNode(node.id, node.position.x + details.delta.dx, node.position.y + details.delta.dy);
      },
      onDoubleTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(nodeId: node.id)));
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
        child: Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _typeColor(node.type), width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(node.type.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (node.linkedTaskIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(label: Text('+${node.linkedTaskIds.length} tasks')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskTab extends StatefulWidget {
  const TaskTab({super.key});

  @override
  State<TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends State<TaskTab> {
  TaskStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.tasks;
    final tasks = _statusFilter == null ? all : all.where((t) => t.status == _statusFilter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<TaskStatus?>(
                  segments: const [
                    ButtonSegment<TaskStatus?>(value: null, label: Text('全て')),
                    ButtonSegment<TaskStatus?>(value: TaskStatus.todo, label: Text('Todo')),
                    ButtonSegment<TaskStatus?>(value: TaskStatus.inProgress, label: Text('進行中')),
                    ButtonSegment<TaskStatus?>(value: TaskStatus.done, label: Text('完了')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (selected) {
                    setState(() => _statusFilter = selected.first);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Dismissible(
                key: ValueKey(task.id),
                background: Container(color: Colors.green.shade300, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16), child: const Icon(Icons.check)),
                secondaryBackground: Container(color: Colors.red.shade300, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 16), child: const Icon(Icons.delete)),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await context.read<AppState>().updateTask(task.copyWith(status: TaskStatus.done));
                    return false;
                  }
                  return _confirm(context, 'このタスクを削除しますか？');
                },
                onDismissed: (_) => context.read<AppState>().deleteTask(task.id),
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text('優先度 ${task.priority}  /  目的 +${task.linkedNodeIds.length}'),
                  trailing: task.status == TaskStatus.done ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)));
                  },
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FilledButton.icon(
              onPressed: () async {
                final draft = await _showTaskEditor(context, initialLinkedNodeIds: const <String>[]);
                if (draft == null) return;
                if (!context.mounted) return;
                await context.read<AppState>().addTask(
                      title: draft.title,
                      description: draft.description,
                      priority: draft.priority,
                      dueDate: draft.dueDate,
                      linkedNodeIds: draft.linkedNodeIds,
                      tags: draft.tags,
                    );
              },
              icon: const Icon(Icons.add_task),
              label: const Text('新規タスク追加'),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _service = ExportImportService();
  bool _busy = false;

  Future<void> _export(BuildContext context, Future<File> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await action();
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'MindMapデータをエクスポートしました'));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エクスポート完了: ${file.path}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エクスポート失敗: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'zip']);
      if (picked == null || picked.files.single.path == null) return;

      if (!context.mounted) return;
      final mode = await _pickImportMode(context);
      if (mode == null) return;

      final payload = await _service.importFromFile(picked.files.single.path!);
      if (!context.mounted) return;
      final app = context.read<AppState>();

      ImportSummary summary;
      switch (mode) {
        case ImportMode.overwrite:
          await app.overwriteFrom(payload.data);
          summary = ImportSummary(
            importedMaps: payload.data.maps.length,
            importedNodes: payload.data.nodes.length,
            importedTasks: payload.data.tasks.length,
            importedLinks: payload.data.links.length,
            skipped: 0,
          );
        case ImportMode.merge:
          summary = await app.mergeFrom(payload.data);
        case ImportMode.asNewMap:
          summary = await app.importAsNewMaps(payload.data);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'インポート完了 (${payload.detectedFormat}) maps:${summary.importedMaps} nodes:${summary.importedNodes} tasks:${summary.importedTasks} links:${summary.importedLinks} skip:${summary.skipped}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('インポート失敗: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final data = app.snapshot();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          title: const Text('データ概要'),
          subtitle: Text('maps:${data.maps.length} nodes:${data.nodes.length} tasks:${data.tasks.length} links:${data.links.length}'),
        ),
        const Divider(),
        FilledButton.icon(
          onPressed: _busy ? null : () => _export(context, () => _service.exportJson(data)),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('JSONエクスポート'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => _export(context, () => _service.exportCsvZip(data)),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('CSV(ZIP)エクスポート'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => _export(context, () => _service.exportFullZip(data)),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('完全バックアップZIP'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _import(context),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('インポート(JSON/ZIP)'),
        ),
      ],
    );
  }
}

class NodeDetailScreen extends StatelessWidget {
  const NodeDetailScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final node = app.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (node == null) {
      return const Scaffold(body: Center(child: Text('ノードが見つかりません')));
    }

    final linkedTasks = app.tasks.where((task) => node.linkedTaskIds.contains(task.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(node.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('種類', node.type.name),
          _kv('作成日', _time(node.createdAt)),
          const SizedBox(height: 16),
          Text(node.description.isEmpty ? '詳細なし' : node.description),
          const SizedBox(height: 16),
          if ((node.url ?? '').isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('参照URL'),
              subtitle: Text(node.url!),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final uri = Uri.tryParse(node.url!);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          const Divider(),
          const Text('紐づくタスク', style: TextStyle(fontWeight: FontWeight.w700)),
          ...linkedTasks.map(
            (task) => ListTile(
              leading: Icon(task.status == TaskStatus.done ? Icons.check_box : Icons.check_box_outline_blank),
              title: Text(task.title),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)));
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final edited = await _showNodeEditor(context, mapId: node.mapId, initial: node);
                    if (edited == null) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().updateNode(
                          node.copyWith(
                            title: edited.title,
                            description: edited.description,
                            type: edited.type,
                            url: edited.url,
                          ),
                        );
                  },
                  child: const Text('編集'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final ok = await _confirm(context, 'このノードを削除しますか？');
                    if (!ok) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().deleteNode(node.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('削除'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(key, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final task = app.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('タスクが見つかりません')));
    }

    final linkedNodes = app.nodes.where((node) => task.linkedNodeIds.contains(node.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('ステータス', _statusLabel(task.status)),
          _kv('優先度', '${task.priority}'),
          _kv('期限', task.dueDate == null ? '未設定' : _time(task.dueDate!)),
          const SizedBox(height: 16),
          Text(task.description ?? '詳細なし'),
          const Divider(height: 32),
          const Text('このタスクが貢献する目的', style: TextStyle(fontWeight: FontWeight.w700)),
          ...linkedNodes.map(
            (node) => ListTile(
              leading: const Icon(Icons.flag_circle_outlined),
              title: Text(node.title),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(nodeId: node.id)));
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: task.tags.map((tag) => Chip(label: Text('#$tag'))).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final draft = await _showTaskEditor(
                      context,
                      initial: task,
                      initialLinkedNodeIds: task.linkedNodeIds,
                    );
                    if (draft == null) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().updateTask(
                          task.copyWith(
                            title: draft.title,
                            description: draft.description,
                            status: draft.status,
                            priority: draft.priority,
                            dueDate: draft.dueDate,
                            linkedNodeIds: draft.linkedNodeIds,
                            tags: draft.tags,
                          ),
                        );
                  },
                  child: const Text('編集'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final ok = await _confirm(context, 'このタスクを削除しますか？');
                    if (!ok) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().deleteTask(task.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('削除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(key, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class NodeEditorDraft {
  NodeEditorDraft({required this.title, required this.description, required this.type, this.url});

  final String title;
  final String description;
  final NodeType type;
  final String? url;
}

Future<NodeEditorDraft?> _showNodeEditor(BuildContext context, {required String mapId, MindNode? initial}) {
  final titleCtrl = TextEditingController(text: initial?.title ?? '');
  final descCtrl = TextEditingController(text: initial?.description ?? '');
  final urlCtrl = TextEditingController(text: initial?.url ?? '');
  var type = initial?.type ?? NodeType.concept;

  return showModalBottomSheet<NodeEditorDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'タイトル')),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '説明'), maxLines: 3),
                  TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL(任意)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<NodeType>(
                    initialValue: type,
                    items: NodeType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        NodeEditorDraft(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          type: type,
                          url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class TaskEditorDraft {
  TaskEditorDraft({
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.linkedNodeIds,
    required this.tags,
  });

  final String title;
  final String? description;
  final TaskStatus status;
  final int priority;
  final int? dueDate;
  final List<String> linkedNodeIds;
  final List<String> tags;
}

Future<TaskEditorDraft?> _showTaskEditor(
  BuildContext context, {
  MindTask? initial,
  required List<String> initialLinkedNodeIds,
}) {
  final app = context.read<AppState>();
  final titleCtrl = TextEditingController(text: initial?.title ?? '');
  final descCtrl = TextEditingController(text: initial?.description ?? '');
  final dueCtrl = TextEditingController(
    text: initial?.dueDate == null ? '' : DateTime.fromMillisecondsSinceEpoch(initial!.dueDate!).toIso8601String().split('T').first,
  );
  final tagsCtrl = TextEditingController(text: initial?.tags.join(',') ?? '');
  var status = initial?.status ?? TaskStatus.todo;
  var priority = initial?.priority ?? 3;
  final linked = <String>{...initialLinkedNodeIds};

  return showModalBottomSheet<TaskEditorDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'タスク名')),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '説明'), maxLines: 3),
                  TextField(controller: dueCtrl, decoration: const InputDecoration(labelText: '期限 (YYYY-MM-DD)')),
                  TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'タグ (カンマ区切り)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'ステータス'),
                    items: TaskStatus.values
                        .map((value) => DropdownMenuItem(value: value, child: Text(_statusLabel(value))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: '優先度(1:高 - 5:低)'),
                    items: [1, 2, 3, 4, 5].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => priority = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('関連する目的(ノード)'),
                  const SizedBox(height: 4),
                  ...app.nodes.map((node) {
                    final selected = linked.contains(node.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      title: Text(node.title),
                      onChanged: (checked) {
                        setModalState(() {
                          if (checked ?? false) {
                            linked.add(node.id);
                          } else {
                            linked.remove(node.id);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final due = DateTime.tryParse(dueCtrl.text.trim());
                      Navigator.pop(
                        context,
                        TaskEditorDraft(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          status: status,
                          priority: priority,
                          dueDate: due?.millisecondsSinceEpoch,
                          linkedNodeIds: linked.toList(),
                          tags: tagsCtrl.text
                              .split(',')
                              .map((t) => t.trim())
                              .where((t) => t.isNotEmpty)
                              .toList(),
                        ),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> _askText(BuildContext context, {required String title, required String hint}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('保存')),
        ],
      );
    },
  );
}

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('いいえ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('はい')),
        ],
      );
    },
  );
  return result ?? false;
}

Future<ImportMode?> _pickImportMode(BuildContext context) {
  return showModalBottomSheet<ImportMode>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.merge_type_outlined),
              title: const Text('統合 (重複IDはスキップ)'),
              onTap: () => Navigator.pop(context, ImportMode.merge),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('上書き (既存データを置換)'),
              onTap: () => Navigator.pop(context, ImportMode.overwrite),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('新規マップとして追加'),
              onTap: () => Navigator.pop(context, ImportMode.asNewMap),
            ),
          ],
        ),
      );
    },
  );
}

String _time(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

String _statusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'Todo';
    case TaskStatus.inProgress:
      return '進行中';
    case TaskStatus.done:
      return '完了';
    case TaskStatus.archived:
      return 'アーカイブ';
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
