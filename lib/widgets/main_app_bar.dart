import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Future<void> Function()? onSignOut;

  const MainAppBar({
    super.key,
    required this.title,
    this.onSignOut,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            debugPrint("뒤로가기 버튼 눌림");
          },
          icon: SvgPicture.asset(
            'assets/icons/cross.svg',
            width: 20,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: AppFontWeight.bold,
          ),
        ),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: '로그아웃',
              onPressed: () async => onSignOut?.call(),
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
