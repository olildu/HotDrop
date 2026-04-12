class FileModel {
  final String name;
  final String? location;
  final String? url;
  final int? size;

  FileModel({
    required this.name,
    this.location,
    this.url,
    this.size,
  });

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      name: map['name'] ?? '',
      location: map['location'],
      url: map['url'],
      size: map['size'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'url': url,
      'size': size,
    };
  }
}