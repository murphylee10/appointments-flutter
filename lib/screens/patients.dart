import 'package:flutter/material.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Patients Screen',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
