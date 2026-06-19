import 'package:flutter/material.dart';

class ModeTabItem {
  const ModeTabItem({
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final Widget screen;
}

class ModeShellScreen extends StatefulWidget {
  const ModeShellScreen({
    super.key,
    required this.title,
    required this.tabs,
    this.onSignOut,
  });

  final String title;
  final List<ModeTabItem> tabs;
  final Future<void> Function()? onSignOut;

  @override
  State<ModeShellScreen> createState() => _ModeShellScreenState();
}

class _ModeShellScreenState extends State<ModeShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tabs[_index];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1028),
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              tooltip: '로그아웃',
              onPressed: () async => widget.onSignOut?.call(),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1D1B29),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.tabs.length,
                  itemBuilder: (context, i) {
                    final item = widget.tabs[i];
                    final selected = i == _index;
                    return ListTile(
                      leading: Icon(
                        item.icon,
                        color: selected ? const Color(0xFFBEA9FF) : Colors.white70,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? const Color(0xFFBEA9FF) : Colors.white,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      selected: selected,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: tab.screen,
    );
  }
}
