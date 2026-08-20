class TreatmentItem {
  final String title;
  final String description;
  final String dosageOrFrequency;

  const TreatmentItem({
    required this.title,
    required this.description,
    required this.dosageOrFrequency,
  });
}

class TreatmentInfo {
  final String diseaseName;
  final List<TreatmentItem> culturalPractices;
  final List<TreatmentItem> organicTreatments;
  final List<TreatmentItem> chemicalTreatments;

  const TreatmentInfo({
    required this.diseaseName,
    required this.culturalPractices,
    required this.organicTreatments,
    required this.chemicalTreatments,
  });
}
