/// Configuration for the current research project.
class ProjectConfig {
  final String projectCode;
  final String collectorCode;
  final String deviceId;
  final List<String> estates;
  final List<String> regions;
  final List<String> districts;

  const ProjectConfig({
    this.projectCode = 'SL_TEA_RESEARCH',
    this.collectorCode = '',
    this.deviceId = '',
    this.estates = const [],
    this.regions = const [],
    this.districts = const [],
  });

  ProjectConfig copyWith({
    String? projectCode,
    String? collectorCode,
    String? deviceId,
    List<String>? estates,
    List<String>? regions,
    List<String>? districts,
  }) {
    return ProjectConfig(
      projectCode: projectCode ?? this.projectCode,
      collectorCode: collectorCode ?? this.collectorCode,
      deviceId: deviceId ?? this.deviceId,
      estates: estates ?? this.estates,
      regions: regions ?? this.regions,
      districts: districts ?? this.districts,
    );
  }
}
