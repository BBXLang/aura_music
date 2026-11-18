/// Represents a community music source plugin or OAuth-backed provider.
class SourcePlugin {
  /// Creates an immutable [SourcePlugin] instance.
  const SourcePlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.connected,
    required this.tierLabel,
    this.enabled = true,
    this.importUrl,
  });

  final String id;
  final String name;
  final String version;
  final bool connected;
  final String tierLabel;
  final bool enabled;
  final String? importUrl;

  /// Creates a [SourcePlugin] from a JSON map.
  factory SourcePlugin.fromJson(Map<String, dynamic> json) {
    return SourcePlugin(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? 'v1.0.0',
      connected: json['connected'] as bool? ?? false,
      tierLabel: json['tierLabel'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      importUrl: json['importUrl'] as String?,
    );
  }

  /// Serializes this [SourcePlugin] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'connected': connected,
      'tierLabel': tierLabel,
      'enabled': enabled,
      if (importUrl != null && importUrl!.isNotEmpty) 'importUrl': importUrl,
    };
  }

  /// Returns a copy of this plugin with the specified fields replaced.
  SourcePlugin copyWith({
    String? id,
    String? name,
    String? version,
    bool? connected,
    String? tierLabel,
    bool? enabled,
    String? importUrl,
  }) {
    return SourcePlugin(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      connected: connected ?? this.connected,
      tierLabel: tierLabel ?? this.tierLabel,
      enabled: enabled ?? this.enabled,
      importUrl: importUrl ?? this.importUrl,
    );
  }
}
