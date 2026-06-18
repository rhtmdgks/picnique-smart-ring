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