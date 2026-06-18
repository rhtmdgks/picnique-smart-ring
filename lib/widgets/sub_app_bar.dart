import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class SubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const SubAppBar({super.key, required this.title});

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
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontVariations: AppFontVariations.semiBold,
          ),
        ),
      ),
    );
  }
}
