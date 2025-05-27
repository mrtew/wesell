import 'package:flutter/material.dart';

Future<void> showCustomDialog({
  required BuildContext context,
  required String title,
  required String content,
  String buttonText1 = '',
  String buttonText2 = '',
  VoidCallback? onPressed1,
  VoidCallback? onPressed2,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (buttonText1 != '')
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onPressed1 != null) {
                onPressed1();
              }
            },
            child: Text(buttonText1),
          ),
          if (buttonText2 != '') 
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              if (onPressed2 != null) {
                onPressed2(); // Execute the callback if provided
              }
            },
            child: Text(buttonText2),
          ),
        ],
      );
    },
  );
}

// to use it
// ElevatedButton(
//   onPressed: () {
//     showCustomDialog(
//       context: context,
//       title: "Warning",
//       content: "Are you sure you want to continue?",
//       buttonText: "Proceed",
//       onPressed: () {
//         print("User clicked Proceed!");
//       },
//     );
//   },
//   child: Text("Show Dialog"),
// );