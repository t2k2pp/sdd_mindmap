import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class ImportPayload {
  ImportPayload({required this.data, required this.detectedFormat});

  final AppData data;
  final String detectedFormat;
}

class ExportImportService {
  Future<File> exportJson(AppData data) async {
    final dir = await _exportDir();
    final file = File('${dir.path}/mindmap_backup_${_stamp()}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data.toJson()));
    return file;
  }

  Future<File> exportCsvZip(AppData data) async {
    final archive = Archive();
    archive.add(ArchiveFile.string('nodes.csv', _nodesCsv(data.nodes)));
    archive.add(ArchiveFile.string('tasks.csv', _tasksCsv(data.tasks)));
    archive.add(ArchiveFile.string('links.csv', _linksCsv(data.links)));

    final bytes = ZipEncoder().encode(archive);
    final dir = await _exportDir();
    final out = File('${dir.path}/mindmap_export_${_stamp()}.zip');
    await out.writeAsBytes(bytes);
    return out;
  }

  Future<File> exportFullZip(AppData data) async {
    final archive = Archive();
    archive.add(ArchiveFile.string('data.json', const JsonEncoder.withIndent('  ').convert(data.toJson())));
    archive.add(ArchiveFile.string('export_info.txt', _exportInfo(data)));
    archive.add(ArchiveFile('attachments/.keep', 0, <int>[]));

    final bytes = ZipEncoder().encode(archive);
    final dir = await _exportDir();
    final out = File('${dir.path}/mindmap_backup_full_${_stampDateOnly()}.zip');
    await out.writeAsBytes(bytes);
    return out;
  }

  Future<ImportPayload> importFromFile(String path) async {
    final file = File(path);
    final ext = path.toLowerCase();

    if (ext.endsWith('.json')) {
      final raw = await file.readAsString();
      final data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return ImportPayload(data: data, detectedFormat: 'json');
    }

    if (ext.endsWith('.zip')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final jsonFile = archive.firstWhere(
        (item) => item.isFile && (item.name == 'data.json' || item.name.toLowerCase().endsWith('.json')),
        orElse: () => ArchiveFile('', 0, Uint8List(0)),
      );

      if (jsonFile.name.isNotEmpty) {
        final raw = utf8.decode(jsonFile.content as List<int>);
        return ImportPayload(
          data: AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          detectedFormat: 'zip-json',
        );
      }

      final nodes = _findFile(archive, 'nodes.csv');
      final tasks = _findFile(archive, 'tasks.csv');
      final links = _findFile(archive, 'links.csv');
      if (nodes != null || tasks != null || links != null) {
        return ImportPayload(
          data: AppData(
            version: '1.0.0',
            exportedAt: DateTime.now().millisecondsSinceEpoch,
            maps: <MindMap>[
              MindMap(
                id: 'map-import-${DateTime.now().millisecondsSinceEpoch}',
                title: 'CSV Imported',
                description: 'Imported from CSV zip',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                nodeIds: <String>[],
              ),
            ],
            nodes: nodes == null ? <MindNode>[] : _parseNodesCsv(nodes),
            tasks: tasks == null ? <MindTask>[] : _parseTasksCsv(tasks),
            links: links == null ? <MindLink>[] : _parseLinksCsv(links),
          ),
          detectedFormat: 'zip-csv',
        );
      }
    }

    if (ext.endsWith('.csv')) {
      throw const FormatException('単体CSVは非対応です。ZIP内に nodes/tasks/links.csv を入れてください。');
    }

    throw const FormatException('対応していないファイル形式です。');
  }

  Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  }

  String _stampDateOnly() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _exportInfo(AppData data) {
    final now = DateTime.now();
    return 'Export Date: ${now.toIso8601String()}\n'
        'App Version: 1.0.0\n'
        'Data Version: ${data.version}\n'
        'Platform: mobile\n'
        'Total Maps: ${data.maps.length}\n'
        'Total Nodes: ${data.nodes.length}\n'
        'Total Tasks: ${data.tasks.length}\n'
        'Total Links: ${data.links.length}\n';
  }

  String _nodesCsv(List<MindNode> nodes) {
    final buffer = StringBuffer();
    buffer.writeln(
      '\ufeffid,mapId,title,description,url,type,createdAt,updatedAt,parentNodeIds,childNodeIds,linkedTaskIds,color,icon',
    );
    for (final n in nodes) {
      buffer.writeln([
        _csv(n.id),
        _csv(n.mapId),
        _csv(n.title),
        _csv(n.description),
        _csv(n.url ?? ''),
        _csv(n.type.name),
        _csv(n.createdAt.toString()),
        _csv(n.updatedAt.toString()),
        _csv(n.parentNodeIds.join(',')),
        _csv(n.childNodeIds.join(',')),
        _csv(n.linkedTaskIds.join(',')),
        _csv(n.metadata.color ?? ''),
        _csv(n.metadata.icon ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  String _tasksCsv(List<MindTask> tasks) {
    final buffer = StringBuffer();
    buffer.writeln(
      '\ufeffid,title,description,status,priority,dueDate,linkedNodeIds,tags,createdAt,updatedAt,completedAt',
    );
    for (final t in tasks) {
      buffer.writeln([
        _csv(t.id),
        _csv(t.title),
        _csv(t.description ?? ''),
        _csv(_taskStatus(t.status)),
        _csv(t.priority.toString()),
        _csv((t.dueDate ?? '').toString()),
        _csv(t.linkedNodeIds.join(',')),
        _csv(t.tags.join(',')),
        _csv(t.createdAt.toString()),
        _csv(t.updatedAt.toString()),
        _csv((t.completedAt ?? '').toString()),
      ].join(','));
    }
    return buffer.toString();
  }

  String _linksCsv(List<MindLink> links) {
    final buffer = StringBuffer();
    buffer.writeln('\ufeffid,sourceId,targetId,type,weight,createdAt');
    for (final l in links) {
      buffer.writeln([
        _csv(l.id),
        _csv(l.sourceId),
        _csv(l.targetId),
        _csv(_linkType(l.type)),
        _csv((l.weight ?? '').toString()),
        _csv(l.createdAt.toString()),
      ].join(','));
    }
    return buffer.toString();
  }

  String _taskStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.done:
        return 'done';
      case TaskStatus.archived:
        return 'archived';
    }
  }

  String _linkType(LinkType type) {
    switch (type) {
      case LinkType.parentChild:
        return 'parent-child';
      case LinkType.reference:
        return 'reference';
      case LinkType.taskGoal:
        return 'task-goal';
    }
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String? _findFile(Archive archive, String fileName) {
    for (final item in archive) {
      if (item.isFile && item.name.toLowerCase().endsWith(fileName)) {
        return utf8.decode(item.content as List<int>);
      }
    }
    return null;
  }

  List<MindNode> _parseNodesCsv(String csv) {
    final rows = _parseRows(csv);
    if (rows.length <= 1) return <MindNode>[];

    final mapId = 'map-import-${DateTime.now().millisecondsSinceEpoch}';
    final nodes = <MindNode>[];
    for (final row in rows.skip(1)) {
      if (row.isEmpty || row.first.trim().isEmpty) continue;
      nodes.add(
        MindNode(
          id: row[0],
          mapId: row.length > 1 && row[1].isNotEmpty ? row[1] : mapId,
          title: row.length > 2 ? row[2] : 'Untitled',
          description: row.length > 3 ? row[3] : '',
          url: row.length > 4 && row[4].isNotEmpty ? row[4] : null,
          urlMetadata: null,
          type: NodeType.values.firstWhere(
            (e) => e.name == (row.length > 5 ? row[5] : 'concept'),
            orElse: () => NodeType.concept,
          ),
          createdAt: _toInt(row.length > 6 ? row[6] : null) ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: _toInt(row.length > 7 ? row[7] : null) ?? DateTime.now().millisecondsSinceEpoch,
          position: NodePosition(x: 60, y: 60),
          parentNodeIds: _splitList(row.length > 8 ? row[8] : ''),
          childNodeIds: _splitList(row.length > 9 ? row[9] : ''),
          linkedTaskIds: _splitList(row.length > 10 ? row[10] : ''),
          metadata: NodeMetadata(
            color: row.length > 11 && row[11].isNotEmpty ? row[11] : null,
            icon: row.length > 12 && row[12].isNotEmpty ? row[12] : null,
          ),
        ),
      );
    }
    return nodes;
  }

  List<MindTask> _parseTasksCsv(String csv) {
    final rows = _parseRows(csv);
    if (rows.length <= 1) return <MindTask>[];
    return rows.skip(1).where((row) => row.isNotEmpty && row.first.trim().isNotEmpty).map((row) {
      final raw = row.length > 3 ? row[3] : 'todo';
      final status = raw == 'in_progress'
          ? TaskStatus.inProgress
          : TaskStatus.values.firstWhere(
              (e) => e.name == raw,
              orElse: () => TaskStatus.todo,
            );
      return MindTask(
        id: row[0],
        title: row.length > 1 ? row[1] : 'Untitled',
        description: row.length > 2 ? row[2] : null,
        status: status,
        priority: _toInt(row.length > 4 ? row[4] : null) ?? 3,
        dueDate: _toInt(row.length > 5 ? row[5] : null),
        linkedNodeIds: _splitList(row.length > 6 ? row[6] : ''),
        tags: _splitList(row.length > 7 ? row[7] : ''),
        createdAt: _toInt(row.length > 8 ? row[8] : null) ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt: _toInt(row.length > 9 ? row[9] : null) ?? DateTime.now().millisecondsSinceEpoch,
        completedAt: _toInt(row.length > 10 ? row[10] : null),
      );
    }).toList();
  }

  List<MindLink> _parseLinksCsv(String csv) {
    final rows = _parseRows(csv);
    if (rows.length <= 1) return <MindLink>[];
    return rows.skip(1).where((row) => row.isNotEmpty && row.first.trim().isNotEmpty).map((row) {
      final raw = row.length > 3 ? row[3] : 'reference';
      final type = raw == 'parent-child'
          ? LinkType.parentChild
          : raw == 'task-goal'
              ? LinkType.taskGoal
              : LinkType.reference;
      return MindLink(
        id: row[0],
        sourceId: row.length > 1 ? row[1] : '',
        targetId: row.length > 2 ? row[2] : '',
        type: type,
        weight: row.length > 4 && row[4].isNotEmpty ? double.tryParse(row[4]) : null,
        createdAt: _toInt(row.length > 5 ? row[5] : null) ?? DateTime.now().millisecondsSinceEpoch,
      );
    }).toList();
  }

  int? _toInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }

  List<String> _splitList(String value) {
    if (value.trim().isEmpty) return <String>[];
    return value.split(',').where((v) => v.trim().isNotEmpty).map((v) => v.trim()).toList();
  }

  List<List<String>> _parseRows(String csv) {
    final lines = const LineSplitter().convert(csv.replaceAll('\r', ''));
    return lines.map(_parseCsvLine).toList();
  }

  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buffer.toString().replaceFirst('\ufeff', ''));
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    out.add(buffer.toString().replaceFirst('\ufeff', ''));
    return out;
  }
}
