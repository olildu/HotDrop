class FileModel {
  final String name;
  final int size;
  final DateTime timestamp;
  final double transferSpeed;
  final bool isSent;
  final String? path;

  FileModel({
    required this.name,
    required this.size,
    required this.timestamp,
    required this.transferSpeed,
    required this.isSent,
    this.path,
  });

  Map<String, dynamic> toJson() => {
        'file_name': name,
        'file_size': size,
        'timestamp': timestamp.toIso8601String(),
        'transfer_speed': transferSpeed,
        'is_sent': isSent,
        'file_path': path,
      };

  factory FileModel.fromJson(Map<String, dynamic> json) => FileModel(
        name: json['file_name'],
        size: json['file_size'],
        timestamp: DateTime.parse(json['timestamp']),
        transferSpeed: (json['transfer_speed'] as num).toDouble(),
        isSent: json['is_sent'],
        path: json['file_path'],
      );
}