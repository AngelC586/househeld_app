import 'package:flutter/material.dart';

//import 'package:flutter/services.dart';

//import '../models.dart';
//import '../services/pantry_service.dart';
//import '../theme/app_theme.dart';
//import '../widgets/househeld_bottom_nav.dart';
//import '../widgets/pantry_row_card.dart';
//import 'pantry_form_screen.dart';

// Code for the Pantry Screen UI! Yippee!!!

// Placeholder for navigation:
// Don't forget to add householdID clause to homescreen navigation!
class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Placeholder Pantry Screen')),
      body: const Center(
        child: Text(
          'Not finished yet... Leave NOW!',
          style: TextStyle(fontSize: 20, color: Colors.red),
        ),
      ),
    );
  }
}
