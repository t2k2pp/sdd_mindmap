import 'dart:convert';

class MindMap {
  MindMap({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    required this.nodeIds,
  });

  final String id;
  final String title;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final String? color;
  final List<String> nodeIds;

  MindMap copyWith({
    String? id,
    String? title,
    String? description,
    int? createdAt,
    int? updatedAt,
    String? color,
    List<String>? nodeIds,
  }) {
    return MindMap(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      nodeIds: nodeIds ?? List<String>.from(this.nodeIds),
    );
  }

  factory MindMap.fromJson(Map<String, dynamic> json) {
    return MindMap(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      color: json['color'] as String?,
      nodeIds: (json['nodeIds'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'color': color,
      'nodeIds': nodeIds,
    };
  }
}

class UrlMetadata {
  UrlMetadata({this.pageTitle, this.favicon, this.ogImage});

  final String? pageTitle;
  final String? favicon;
  final String? ogImage;

  factory UrlMetadata.fromJson(Map<String, dynamic> json) {
    return UrlMetadata(
      pageTitle: json['pageTitle'] as String?,
      favicon: json['favicon'] as String?,
      ogImage: json['ogImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageTitle': pageTitle,
      'favicon': favicon,
      'ogImage': ogImage,
    };
  }
}

enum NodeType { concept, goal, project, reference }

class NodePosition {
  NodePosition({required this.x, required this.y});

  final double x;
  final double y;

  factory NodePosition.fromJson(Map<String, dynamic> json) {
    return NodePosition(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class NodeMetadata {
  NodeMetadata({this.color, this.icon, this.collapsed = false});

  final String? color;
  final String? icon;
  final bool collapsed;

  factory NodeMetadata.fromJson(Map<String, dynamic> json) {
    return NodeMetadata(
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      collapsed: (json['collapsed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'color': color, 'icon': icon, 'collapsed': collapsed};
  }
}

class MindNode {
  MindNode({
    required this.id,
    required this.mapId,
    required this.title,
    required this.description,
    this.url,
    this.urlMetadata,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.position,
    required this.parentNodeIds,
    required this.childNodeIds,
    required this.linkedTaskIds,
    required this.metadata,
  });

  final String id;
  final String mapId;
  final String title;
  final String description;
  final String? url;
  final UrlMetadata? urlMetadata;
  final NodeType type;
  final int createdAt;
  final int updatedAt;
  final NodePosition position;
  final List<String> parentNodeIds;
  final List<String> childNodeIds;
  final List<String> linkedTaskIds;
  final NodeMetadata metadata;

  MindNode copyWith({
    String? id,
    String? mapId,
    String? title,
    String? description,
    String? url,
    UrlMetadata? urlMetadata,
    NodeType? type,
    int? createdAt,
    int? updatedAt,
    NodePosition? position,
    List<String>? parentNodeIds,
    List<String>? childNodeIds,
    List<String>? linkedTaskIds,
    NodeMetadata? metadata,
  }) {
    return MindNode(
      id: id ?? this.id,
      mapId: mapId ?? this.mapId,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      urlMetadata: urlMetadata ?? this.urlMetadata,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      position: position ?? this.position,
      parentNodeIds: parentNodeIds ?? List<String>.from(this.parentNodeIds),
      childNodeIds: childNodeIds ?? List<String>.from(this.childNodeIds),
      linkedTaskIds: linkedTaskIds ?? List<String>.from(this.linkedTaskIds),
      metadata: metadata ?? this.metadata,
    );
  }

  factory MindNode.fromJson(Map<String, dynamic> json) {
    return MindNode(
      id: json['id'] as String,
      mapId: json['mapId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      url: json['url'] as String?,
      urlMetadata: json['urlMetadata'] == null
          ? null
          : UrlMetadata.fromJson(json['urlMetadata'] as Map<String, dynamic>),
      type: NodeType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => NodeType.concept,
      ),
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      position: NodePosition.fromJson(json['position'] as Map<String, dynamic>? ?? {}),
      parentNodeIds: (json['parentNodeIds'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      childNodeIds: (json['childNodeIds'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      linkedTaskIds: (json['linkedTaskIds'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      metadata: NodeMetadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mapId': mapId,
      'title': title,
      'description': description,
      'url': url,
      'urlMetadata': urlMetadata?.toJson(),
      'type': type.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'position': position.toJson(),
      'parentNodeIds': parentNodeIds,
      'childNodeIds': childNodeIds,
      'linkedTaskIds': linkedTaskIds,
      'metadata': metadata.toJson(),
    };
  }
}

enum TaskStatus { todo, inProgress, done, archived }

class MindTask {
  MindTask({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.linkedNodeIds,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final int priority;
  final int? dueDate;
  final List<String> linkedNodeIds;
  final List<String> tags;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;

  MindTask copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    int? priority,
    int? dueDate,
    List<String>? linkedNodeIds,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    int? completedAt,
  }) {
    return MindTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      linkedNodeIds: linkedNodeIds ?? List<String>.from(this.linkedNodeIds),
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory MindTask.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? 'todo').replaceAll('_', '');
    return MindTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.values.firstWhere(
        (value) => value.name.toLowerCase() == rawStatus.toLowerCase(),
        orElse: () => TaskStatus.todo,
      ),
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      dueDate: (json['dueDate'] as num?)?.toInt(),
      linkedNodeIds: (json['linkedNodeIds'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      completedAt: (json['completedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': _statusToJson(status),
      'priority': priority,
      'dueDate': dueDate,
      'linkedNodeIds': linkedNodeIds,
      'tags': tags,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
    };
  }

  static String _statusToJson(TaskStatus status) {
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
}

enum LinkType { parentChild, reference, taskGoal }

class MindLink {
  MindLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.weight,
    required this.createdAt,
  });

  final String id;
  final String sourceId;
  final String targetId;
  final LinkType type;
  final double? weight;
  final int createdAt;

  factory MindLink.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'reference').replaceAll('-', '');
    return MindLink(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      targetId: json['targetId'] as String,
      type: LinkType.values.firstWhere(
        (value) => value.name.toLowerCase() == rawType.toLowerCase(),
        orElse: () => LinkType.reference,
      ),
      weight: (json['weight'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'targetId': targetId,
      'type': _typeToJson(type),
      'weight': weight,
      'createdAt': createdAt,
    };
  }

  static String _typeToJson(LinkType type) {
    switch (type) {
      case LinkType.parentChild:
        return 'parent-child';
      case LinkType.reference:
        return 'reference';
      case LinkType.taskGoal:
        return 'task-goal';
    }
  }
}

class AppData {
  AppData({
    required this.version,
    required this.exportedAt,
    required this.maps,
    required this.nodes,
    required this.tasks,
    required this.links,
  });

  final String version;
  final int exportedAt;
  final List<MindMap> maps;
  final List<MindNode> nodes;
  final List<MindTask> tasks;
  final List<MindLink> links;

  factory AppData.empty() {
    return AppData(
      version: '1.0.0',
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      maps: <MindMap>[],
      nodes: <MindNode>[],
      tasks: <MindTask>[],
      links: <MindLink>[],
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      version: json['version'] as String? ?? '1.0.0',
      exportedAt: (json['exportedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      maps: (json['maps'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MindMap.fromJson(item as Map<String, dynamic>))
          .toList(),
      nodes: (json['nodes'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MindNode.fromJson(item as Map<String, dynamic>))
          .toList(),
      tasks: (json['tasks'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MindTask.fromJson(item as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => MindLink.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt,
      'maps': maps.map((item) => item.toJson()).toList(),
      'nodes': nodes.map((item) => item.toJson()).toList(),
      'tasks': tasks.map((item) => item.toJson()).toList(),
      'links': links.map((item) => item.toJson()).toList(),
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
