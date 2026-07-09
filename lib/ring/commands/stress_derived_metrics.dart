// Derived stress/recovery metrics — raw data only per plan; scoring not implemented.
abstract class StressDerivedMetrics {
  Future<Map<String, dynamic>> computeRecoveryScore(List<int> rawSamples);
}
