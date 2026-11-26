/// Disease classification options for field labeling.
///
/// These are provisional field choices. The final disease classes should be
/// confirmed by the supervisor and qualified plant-disease reviewer.
enum DiseaseClass {
  healthy('healthy', 'Healthy'),
  algalLeafSpot('algal_leaf_spot', 'Suspected algal leaf spot'),
  grayBlight('gray_blight', 'Suspected gray blight'),
  blisterBlight('blister_blight', 'Suspected blister blight'),
  otherUnknown('other_unknown', 'Other / unknown symptoms'),
  mixedSymptoms('mixed_symptoms', 'Mixed symptoms'),
  notSure('not_sure', 'Not sure — needs expert review');

  const DiseaseClass(this.databaseKey, this.displayName);

  /// The value stored in the database.
  final String databaseKey;

  /// The human-readable label shown in the UI.
  final String displayName;

  /// The default list of field labels available to collectors.
  static List<DiseaseClass> get defaultFieldLabels => DiseaseClass.values;

  /// Look up a [DiseaseClass] by its database key, or return [notSure].
  static DiseaseClass fromDatabaseKey(String? key) {
    if (key == null) return DiseaseClass.notSure;
    return DiseaseClass.values.firstWhere(
      (e) => e.databaseKey == key,
      orElse: () => DiseaseClass.notSure,
    );
  }
}
