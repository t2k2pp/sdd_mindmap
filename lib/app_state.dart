import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

enum ImportMode { merge, overwrite, asNewMap }

class ImportSummary {
  ImportSummary({
    required this.importedMaps,
    required this.importedNodes,
    required this.importedTasks,
    required this.importedLinks,
    required this.skipped,
  });

  final int importedMaps;
  final int importedNodes;
  final int importedTasks;
  final int importedLinks;
  final int skipped;
}

class AppState extends ChangeNotifier {
  AppState();

  final List<MindMap> _maps = <MindMap>[];
  final List<MindNode> _nodes = <MindNode>[];
  final List<MindTask> _tasks = <MindTask>[];
  final List<MindLink> _links = <MindLink>[];

  String? _selectedMapId;
  bool _ready = false;

  bool get isReady => _ready;
  List<MindMap> get maps => List.unmodifiable(_maps);
  List<MindNode> get nodes => List.unmodifiable(_nodes);
  List<MindTask> get tasks => List.unmodifiable(_tasks);
  List<MindLink> get links => List.unmodifiable(_links);
  String? get selectedMapId => _selectedMapId;

  MindMap? get selectedMap {
    if (_selectedMapId == null) return null;
    return _maps.cast<MindMap?>().firstWhere(
          (m) => m?.id == _selectedMapId,
          orElse: () => null,
        );
  }

  List<MindNode> get selectedMapNodes {
    if (_selectedMapId == null) return <MindNode>[];
    return _nodes.where((node) => node.mapId == _selectedMapId).toList();
  }

  Future<void> initialize() async {
    await _load();
    if (_maps.isEmpty) {
      await addMap(title: '最初のマップ', description: '思考整理の出発点');
    }
    _ready = true;
    notifyListeners();
  }

  void selectMap(String mapId) {
    _selectedMapId = mapId;
    notifyListeners();
  }

  Future<MindMap> addMap({required String title, String? description}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = MindMap(
      id: _newId('map'),
      title: title,
      description: description,
      createdAt: now,
      updatedAt: now,
      color: null,
      nodeIds: <String>[],
    );
    _maps.add(map);
    _selectedMapId ??= map.id;
    await _saveAndNotify();
    return map;
  }

  Future<void> deleteMap(String mapId) async {
    _maps.removeWhere((map) => map.id == mapId);
    final nodeIds = _nodes.where((node) => node.mapId == mapId).map((n) => n.id).toSet();
    _nodes.removeWhere((node) => nodeIds.contains(node.id));

    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      _tasks[i] = task.copyWith(
        linkedNodeIds: task.linkedNodeIds.where((id) => !nodeIds.contains(id)).toList(),
      );
    }

    _links.removeWhere((link) => nodeIds.contains(link.sourceId) || nodeIds.contains(link.targetId));

    if (_selectedMapId == mapId) {
      _selectedMapId = _maps.isEmpty ? null : _maps.first.id;
    }
    await _saveAndNotify();
  }

  Future<MindNode> addNode({
    required String title,
    required NodeType type,
    String description = '',
    String? url,
    String? mapId,
    String? parentNodeId,
  }) async {
    final targetMapId = mapId ?? _selectedMapId;
    if (targetMapId == null) {
      throw StateError('No map selected');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final node = MindNode(
      id: _newId('node'),
      mapId: targetMapId,
      title: title,
      description: description,
      url: url,
      urlMetadata: null,
      type: type,
      createdAt: now,
      updatedAt: now,
      position: NodePosition(x: 80 + (_nodes.length * 16) % 220, y: 90 + (_nodes.length * 20) % 300),
      parentNodeIds: parentNodeId == null ? <String>[] : <String>[parentNodeId],
      childNodeIds: <String>[],
      linkedTaskIds: <String>[],
      metadata: NodeMetadata(),
    );

    _nodes.add(node);
    final mapIndex = _maps.indexWhere((m) => m.id == targetMapId);
    if (mapIndex >= 0) {
      final map = _maps[mapIndex];
      _maps[mapIndex] = map.copyWith(
        updatedAt: now,
        nodeIds: <String>[...map.nodeIds, node.id],
      );
    }

    if (parentNodeId != null) {
      final parentIndex = _nodes.indexWhere((n) => n.id == parentNodeId);
      if (parentIndex >= 0) {
        final parent = _nodes[parentIndex];
        _nodes[parentIndex] = parent.copyWith(
          childNodeIds: <String>[...parent.childNodeIds, node.id],
          updatedAt: now,
        );
        _links.add(MindLink(
          id: _newId('link'),
          sourceId: parentNodeId,
          targetId: node.id,
          type: LinkType.parentChild,
          createdAt: now,
        ));
      }
    }

    await _saveAndNotify();
    return node;
  }

  Future<void> updateNode(MindNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    _nodes[index] = node.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    await _saveAndNotify();
  }

  Future<void> moveNode(String nodeId, double x, double y) async {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = _nodes[index];
    _nodes[index] = node.copyWith(
      position: NodePosition(x: x, y: y),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    await _save();
  }

  Future<void> deleteNode(String nodeId) async {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;

    final node = _nodes[index];
    _nodes.removeAt(index);

    for (var i = 0; i < _maps.length; i++) {
      final map = _maps[i];
      if (map.id == node.mapId) {
        _maps[i] = map.copyWith(nodeIds: map.nodeIds.where((id) => id != nodeId).toList());
      }
    }

    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      _nodes[i] = n.copyWith(
        parentNodeIds: n.parentNodeIds.where((id) => id != nodeId).toList(),
        childNodeIds: n.childNodeIds.where((id) => id != nodeId).toList(),
      );
    }

    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      _tasks[i] = task.copyWith(
        linkedNodeIds: task.linkedNodeIds.where((id) => id != nodeId).toList(),
      );
    }

    _links.removeWhere((link) => link.sourceId == nodeId || link.targetId == nodeId);
    await _saveAndNotify();
  }

  Future<MindTask> addTask({
    required String title,
    String? description,
    int priority = 3,
    int? dueDate,
    List<String>? linkedNodeIds,
    List<String>? tags,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = MindTask(
      id: _newId('task'),
      title: title,
      description: description,
      status: TaskStatus.todo,
      priority: priority,
      dueDate: dueDate,
      linkedNodeIds: linkedNodeIds ?? <String>[],
      tags: tags ?? <String>[],
      createdAt: now,
      updatedAt: now,
      completedAt: null,
    );
    _tasks.add(task);

    for (final nodeId in task.linkedNodeIds) {
      final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
      if (nodeIndex >= 0) {
        final node = _nodes[nodeIndex];
        _nodes[nodeIndex] = node.copyWith(linkedTaskIds: <String>[...node.linkedTaskIds, task.id]);
      }
      _links.add(MindLink(
        id: _newId('link'),
        sourceId: task.id,
        targetId: nodeId,
        type: LinkType.taskGoal,
        createdAt: now,
      ));
    }

    await _saveAndNotify();
    return task;
  }

  Future<void> updateTask(MindTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;

    final before = _tasks[index];
    final now = DateTime.now().millisecondsSinceEpoch;
    _tasks[index] = task.copyWith(
      updatedAt: now,
      completedAt: task.status == TaskStatus.done ? (task.completedAt ?? now) : null,
    );

    final removed = before.linkedNodeIds.where((id) => !task.linkedNodeIds.contains(id));
    final added = task.linkedNodeIds.where((id) => !before.linkedNodeIds.contains(id));

    for (final nodeId in removed) {
      final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
      if (nodeIndex >= 0) {
        final node = _nodes[nodeIndex];
        _nodes[nodeIndex] = node.copyWith(
          linkedTaskIds: node.linkedTaskIds.where((id) => id != task.id).toList(),
        );
      }
    }

    for (final nodeId in added) {
      final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
      if (nodeIndex >= 0) {
        final node = _nodes[nodeIndex];
        _nodes[nodeIndex] = node.copyWith(linkedTaskIds: <String>[...node.linkedTaskIds, task.id]);
      }
      _links.add(MindLink(
        id: _newId('link'),
        sourceId: task.id,
        targetId: nodeId,
        type: LinkType.taskGoal,
        createdAt: now,
      ));
    }

    _links.removeWhere(
      (link) => link.type == LinkType.taskGoal &&
          link.sourceId == task.id &&
          !task.linkedNodeIds.contains(link.targetId),
    );

    await _saveAndNotify();
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      _nodes[i] = node.copyWith(linkedTaskIds: node.linkedTaskIds.where((id) => id != taskId).toList());
    }
    _links.removeWhere((link) => link.sourceId == taskId || link.targetId == taskId);
    await _saveAndNotify();
  }

  AppData snapshot() {
    return AppData(
      version: '1.0.0',
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      maps: List<MindMap>.from(_maps),
      nodes: List<MindNode>.from(_nodes),
      tasks: List<MindTask>.from(_tasks),
      links: List<MindLink>.from(_links),
    );
  }

  Future<void> overwriteFrom(AppData incoming) async {
    _maps
      ..clear()
      ..addAll(incoming.maps);
    _nodes
      ..clear()
      ..addAll(incoming.nodes);
    _tasks
      ..clear()
      ..addAll(incoming.tasks);
    _links
      ..clear()
      ..addAll(incoming.links);
    _selectedMapId = _maps.isEmpty ? null : _maps.first.id;
    await _saveAndNotify();
  }

  Future<ImportSummary> mergeFrom(AppData incoming) async {
    var skipped = 0;

    for (final item in incoming.maps) {
      if (_maps.any((m) => m.id == item.id)) {
        skipped++;
      } else {
        _maps.add(item);
      }
    }

    for (final item in incoming.nodes) {
      if (_nodes.any((n) => n.id == item.id)) {
        skipped++;
      } else {
        _nodes.add(item);
      }
    }

    for (final item in incoming.tasks) {
      if (_tasks.any((t) => t.id == item.id)) {
        skipped++;
      } else {
        _tasks.add(item);
      }
    }

    for (final item in incoming.links) {
      if (_links.any((l) => l.id == item.id)) {
        skipped++;
      } else {
        _links.add(item);
      }
    }

    _selectedMapId ??= _maps.isEmpty ? null : _maps.first.id;
    await _saveAndNotify();

    return ImportSummary(
      importedMaps: incoming.maps.length,
      importedNodes: incoming.nodes.length,
      importedTasks: incoming.tasks.length,
      importedLinks: incoming.links.length,
      skipped: skipped,
    );
  }

  Future<ImportSummary> importAsNewMaps(AppData incoming) async {
    final mapIdMap = <String, String>{};
    final nodeIdMap = <String, String>{};
    final taskIdMap = <String, String>{};

    for (final m in incoming.maps) {
      mapIdMap[m.id] = _newId('map');
    }
    for (final n in incoming.nodes) {
      nodeIdMap[n.id] = _newId('node');
    }
    for (final t in incoming.tasks) {
      taskIdMap[t.id] = _newId('task');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newMaps = incoming.maps
        .map(
          (m) => m.copyWith(
            id: mapIdMap[m.id],
            title: '${m.title} (Imported)',
            nodeIds: m.nodeIds.map((id) => nodeIdMap[id] ?? id).toList(),
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final newNodes = incoming.nodes
        .map(
          (n) => n.copyWith(
            id: nodeIdMap[n.id],
            mapId: mapIdMap[n.mapId] ?? n.mapId,
            parentNodeIds: n.parentNodeIds.map((id) => nodeIdMap[id] ?? id).toList(),
            childNodeIds: n.childNodeIds.map((id) => nodeIdMap[id] ?? id).toList(),
            linkedTaskIds: n.linkedTaskIds.map((id) => taskIdMap[id] ?? id).toList(),
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final newTasks = incoming.tasks
        .map(
          (t) => t.copyWith(
            id: taskIdMap[t.id],
            linkedNodeIds: t.linkedNodeIds.map((id) => nodeIdMap[id] ?? id).toList(),
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final newLinks = incoming.links
        .map(
          (l) => MindLink(
            id: _newId('link'),
            sourceId: nodeIdMap[l.sourceId] ?? taskIdMap[l.sourceId] ?? l.sourceId,
            targetId: nodeIdMap[l.targetId] ?? taskIdMap[l.targetId] ?? l.targetId,
            type: l.type,
            weight: l.weight,
            createdAt: now,
          ),
        )
        .toList();

    _maps.addAll(newMaps);
    _nodes.addAll(newNodes);
    _tasks.addAll(newTasks);
    _links.addAll(newLinks);
    _selectedMapId = _selectedMapId ?? (newMaps.isEmpty ? null : newMaps.first.id);
    await _saveAndNotify();

    return ImportSummary(
      importedMaps: newMaps.length,
      importedNodes: newNodes.length,
      importedTasks: newTasks.length,
      importedLinks: newLinks.length,
      skipped: 0,
    );
  }

  Future<void> _saveAndNotify() async {
    await _save();
    notifyListeners();
  }

  Future<File> _storageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/mindmap_app_data.json');
  }

  Future<void> _load() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      final data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      _maps
        ..clear()
        ..addAll(data.maps);
      _nodes
        ..clear()
        ..addAll(data.nodes);
      _tasks
        ..clear()
        ..addAll(data.tasks);
      _links
        ..clear()
        ..addAll(data.links);
      _selectedMapId = _maps.isEmpty ? null : _maps.first.id;
    } catch (_) {
      _maps.clear();
      _nodes.clear();
      _tasks.clear();
      _links.clear();
      _selectedMapId = null;
    }
  }

  Future<void> _save() async {
    final file = await _storageFile();
    final data = snapshot();
    await file.writeAsString(data.toPrettyJson());
  }

  static final Random _random = Random();

  String _newId(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 24).toRadixString(16).padLeft(6, '0');
    return '$prefix-$millis-$randomPart';
  }
}
