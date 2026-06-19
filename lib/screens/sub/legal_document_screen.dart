import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

/// assets/legal/ 아래 마크다운 법적 문서를 표시한다.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<String> _contentFuture = rootBundle.loadString(widget.assetPath);

  MarkdownStyleSheet get _styleSheet => MarkdownStyleSheet(
        p: TextStyle(
          color: AppColors.lightGray,
          fontSize: 14,
          height: 1.65,
          fontWeight: AppFontWeight.regular,
        ),
        h1: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: AppFontWeight.bold,
        ),
        h2: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: AppFontWeight.semiBold,
        ),
        h3: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: AppFontWeight.semiBold,
        ),
        strong: TextStyle(
          color: Colors.white,
          fontWeight: AppFontWeight.semiBold,
        ),
        blockquote: TextStyle(
          color: AppColors.lightGray,
          fontSize: 13,
          height: 1.5,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.mutePurple.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: AppColors.lightPurple, width: 3),
          ),
        ),
        listBullet: TextStyle(color: AppColors.lightGray, fontSize: 14),
        tableHead: TextStyle(
          color: Colors.white,
          fontWeight: AppFontWeight.semiBold,
          fontSize: 13,
        ),
        tableBody: TextStyle(
          color: AppColors.lightGray,
          fontSize: 13,
          height: 1.45,
        ),
        tableBorder: TableBorder.all(
          color: AppColors.darkGray.withValues(alpha: 0.8),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.darkGray.withValues(alpha: 0.7),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SubAppBar(title: widget.title),
        body: FutureBuilder<String>(
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  '문서를 불러오지 못했습니다.',
                  style: TextStyle(color: AppColors.lightGray),
                ),
              );
            }

            return Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: MarkdownBody(
                    data: snapshot.data!,
                    styleSheet: _styleSheet,
                    extensionSet: md.ExtensionSet.gitHubWeb,
                    selectable: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
