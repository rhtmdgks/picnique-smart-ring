import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/data/tab_item.dart';

class BottomNavBar extends StatelessWidget {
  final int index;
  final Function(int) onTap;

  const BottomNavBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomNavigationBar(
        selectedItemColor: AppColors.lightPurple,
        unselectedItemColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 14,
          fontVariations: AppFontVariations.medium,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontVariations: AppFontVariations.light,
        ),
        backgroundColor: Colors.transparent,
        currentIndex: index,
        onTap: (index) {
          onTap(index);
        },
        items: <BottomNavigationBarItem>[
          for (var tabItem in tabItems)
            BottomNavigationBarItem(
              icon: Container(
                width: 24,
                height: 24,
                margin: EdgeInsets.only(bottom: 8),
                child: Center(
                  child: SvgPicture.asset(
                    tabItem.iconSvgPath,
                    colorFilter: ColorFilter.mode(
                        tabItem == tabItems[index]
                            ? AppColors.lightPurple
                            : Colors.white,
                        BlendMode.srcIn),
                  ),
                ),
              ),
              label: tabItem.title,
            ),
        ],
      ),
    );
  }
}
