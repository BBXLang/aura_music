/// Represents a community music source plugin or OAuth-backed provider.
class SourcePlugin {
  /// Creates an immutable [SourcePlugin] instance.
  const SourcePlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.connected,
    required this.tierLabel,
  });

  final String id;
  final String name;
  final String version;
  final bool connected;
  final String tierLabel;

  /// Returns a copy of this plugin with the specified fields replaced.
  SourcePlugin copyWith({
    String? id,
    String? name,
    String? version,
    bool? connected,
    String? tierLabel,
  }) {
    return SourcePlugin(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      connected: connected ?? this.connected,
      tierLabel: tierLabel ?? this.tierLabel,
    );
  }
}
