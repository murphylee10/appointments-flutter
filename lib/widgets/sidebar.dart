import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const Sidebar({
    required this.selectedIndex,
    required this.onItemTapped,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.blue[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Patients'),
            selected: selectedIndex == 0,
            onTap: () => onItemTapped(0),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Appointments'),
            selected: selectedIndex == 1,
            onTap: () => onItemTapped(1),
          ),
        ],
      ),
    );
  }
}
