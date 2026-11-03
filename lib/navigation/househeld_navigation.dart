import 'package:flutter/material.dart';

import '../screens/tasks_screen.dart';
import '../screens/pantry_screen.dart';
import '../screens/stuff_screen.dart';
import '../screens/grocery_screen.dart';
import '../screens/menu_screen.dart';

/*
The following code handles navigation between the app's main screens
To add navigation to a new screen, simply call `HouseheldNavigation`

Current Navigation Indices:
  0 = Home
  1 = Tasks
  2 = Pantry
  3 = Stuff
  4 = Grocery
  5 = Menu/Settings
*/

class HouseheldNavigation {
  const HouseheldNavigation._();

  static void navigate({
    required BuildContext context,
    required String householdID,
    required int currentIndex,
    required int destinationIndex,
  }) {
    // Already displaying selected destination:
    if (currentIndex == destinationIndex) {
      return;
    }

    // Blocks any other indeces (change if we add more):
    if (destinationIndex < 0 || destinationIndex > 5) {
      return;
    }

    final navigator = Navigator.of(context);

    // Return home
    if (destinationIndex == 0) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    final Widget destination;

    // Switch statement to set the destination variable:
    // Each case number is the index number for a given screen
    // If adding a new screen, another case here for it
    switch (destinationIndex) {
      case 1:
        destination = TasksScreen(householdID: householdID);
        break;

      case 2:
        destination = PantryScreen(householdID: householdID);
        break;

      case 3:
        destination = StuffScreen(householdID: householdID);
        break;

      case 4:
        destination = GroceryScreen(householdID: householdID);
        break;

      case 5:
        destination = MenuScreen(householdID: householdID);
        break;

      default:
        return;
    }

    // Open the selected screen:
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => route.isFirst,
    );
  }
}
