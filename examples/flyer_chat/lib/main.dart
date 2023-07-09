import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'api_get_initial_messages.dart';
import 'gpt.dart';
import 'local.dart';

void main() {
  runApp(const FlyerChat());
}

class FlyerChat extends StatelessWidget {
  const FlyerChat({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flyer Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FlyerChatHomePage(),
    );
  }
}

class FlyerChatHomePage extends StatefulWidget {
  const FlyerChatHomePage({super.key});

  @override
  State<FlyerChatHomePage> createState() => _FlyerChatHomePageState();
}

class _FlyerChatHomePageState extends State<FlyerChatHomePage> {
  final _dio = Dio();
  String senderId = 'sender1';

  @override
  void dispose() {
    try {
      _dio.close(force: true);
    } catch (e) {
      debugPrint('Error closing Dio instance: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'sender1',
                  label: Text('sender1'),
                ),
                ButtonSegment<String>(
                  value: 'sender2',
                  label: Text('sender2'),
                ),
              ],
              selected: <String>{senderId},
              onSelectionChanged: (Set<String> newSender) {
                setState(() {
                  // By default there is only a single segment that can be
                  // selected at one time, so its value is always the first
                  // item in the selected set.
                  senderId = newSender.first;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () {
                  getInitialMessages(_dio).then((messages) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Api(
                          userId: senderId,
                          initialMessages: messages,
                          dio: _dio,
                        ),
                      ),
                    );
                  }).catchError((error) {
                    debugPrint('Error: $error');
                  });
                },
                child: const Text('api'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Local(userId: senderId, dio: _dio),
                    ),
                  );
                },
                child: const Text('local'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Gpt(dio: _dio),
                    ),
                  );
                },
                child: const Text('gpt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
