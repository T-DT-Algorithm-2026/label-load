import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/keybindings_provider.dart';
import 'package:label_load/services/input/side_button_service.dart';

Future<void> _dispatch(MethodCall call) async {
  const channel = MethodChannel('side_buttons');
  const codec = StandardMethodCodec();
  final binding = TestDefaultBinaryMessengerBinding.instance;
  final data = codec.encodeMethodCall(call);
  final completer = Completer<void>();

  binding.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    data,
    (_) => completer.complete(),
  );

  await completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SideButtonService emits events for string payloads', () async {
    final service = SideButtonService.instance;
    final eventsFuture = service.stream.take(2).toList();

    await _dispatch(const MethodCall('sideButton', 'back'));
    await _dispatch(const MethodCall('sideButton', 'forward'));

    final events = await eventsFuture;
    expect(events.length, 2);
    expect(events[0].button, MouseButton.back);
    expect(events[0].isDown, isTrue);
    expect(events[1].button, MouseButton.forward);
    expect(events[1].isDown, isTrue);
  });

  test('SideButtonService emits events for map payloads', () async {
    final service = SideButtonService.instance;
    final eventsFuture = service.stream.take(2).toList();

    await _dispatch(const MethodCall(
      'sideButton',
      {'button': 'back', 'state': 'up'},
    ));
    await _dispatch(const MethodCall(
      'sideButton',
      {'button': 'forward', 'state': 'down'},
    ));

    final events = await eventsFuture;
    expect(events.length, 2);
    expect(events[0].button, MouseButton.back);
    expect(events[0].isDown, isFalse);
    expect(events[1].button, MouseButton.forward);
    expect(events[1].isDown, isTrue);
  });

  test('SideButtonService ignores invalid payloads', () async {
    final service = SideButtonService.instance;
    final events = <SideButtonEvent>[];
    final sub = service.stream.listen(events.add);

    await _dispatch(const MethodCall('notSideButton', 'back'));
    await _dispatch(const MethodCall(
      'sideButton',
      {'button': 'unknown', 'state': 'down'},
    ));
    await _dispatch(const MethodCall(
      'sideButton',
      {'button': 123, 'state': 'down'},
    ));

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, isEmpty);
  });
}
