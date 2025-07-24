import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_height_plugin_example/input_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    return Scaffold(
      resizeToAvoidBottomInset: false, // 重要：禁用自动调整
      appBar: AppBar(
        title: const Text('Input Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Input Page'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const InputPage()));
              },
              child: const Text('Click Me'),
            ),
          ],
        ),
      ),
    );
  }
}
