import 'package:flutter/material.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Appointments Screen',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
