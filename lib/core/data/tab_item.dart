import 'package:picnique_rosary_healthcare_smartring/core/models/tab_item_data.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/catholic_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/health_care_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/setting_screen.dart';

final List<TabItemData> tabItems = [
  TabItemData(
    title: "가톨릭",
    iconSvgPath: "assets/icons/catholic.svg",
    screen: CatholicScreen(),
  ),
  TabItemData(
    title: "헬스케어",
    iconSvgPath: "assets/icons/healthcare.svg",
    screen: HealthCareScreen(),
  ),
  TabItemData(
    title: "설정",
    iconSvgPath: "assets/icons/setting.svg",
    screen: SettingScreen(),
  ),
];
