String stressToLabel(double stress) {
  if (stress < 20) {
    return "안정";
  } else if (stress < 40) {
    return "주의";
  } else if (stress < 60) {
    return "경고";
  } else if (stress < 80) {
    return "위험";
  } else {
    return "심각";
  }
}

/// 스트레스 게이지(5단) 인덱스. 1=안정 … 5=심각
int stressLevelIndex(int stress) {
  final s = stress.clamp(0, 100);
  if (s < 20) return 1;
  if (s < 40) return 2;
  if (s < 60) return 3;
  if (s < 80) return 4;
  return 5;
}