import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:MazeRunner/channels.dart';

import 'packages.dart';
import 'scenarios/scenario.dart';
import 'scenarios/scenarios.dart';

void log(String message) {
  print('[MazeRunner] $message');
}

void main() {
  runApp(const MazeRunnerFlutterApp());
}

/// Represents a MazeRunner command
class Command {
  final String action;
  final String scenarioName;
  final String extraConfig;

  const Command({
    required this.action,
    required this.scenarioName,
    required this.extraConfig,
  });

  factory Command.fromJsonString(String jsonString) {
    final map = json.decode(jsonString) as Map<String, String>;
    if (map['action'] == null) {
      throw new Exception('MazeRunner commands must have an action');
    }
    return Command(
      action: map['action']!,
      scenarioName: map['scenario_name'] ?? '',
      extraConfig: map['extra_config'] ?? ''
    );
  }
}

class MazeRunnerFlutterApp extends StatelessWidget {
  const MazeRunnerFlutterApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bugsnag Test',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 73, 73, 227),
      ),
      home: const MazeRunnerHomePage(),
    );
  }
}

class MazeRunnerHomePage extends StatefulWidget {
  const MazeRunnerHomePage({Key? key}) : super(key: key);

  @override
  State<MazeRunnerHomePage> createState() => _HomePageState();
}

class _HomePageState extends State<MazeRunnerHomePage> {
  late TextEditingController _scenarioNameController;
  late TextEditingController _extraConfigController;
  late TextEditingController _notifyEndpointController;
  late TextEditingController _sessionEndpointController;

  static const platform = MethodChannel('com.bugsnag.mazeRunner/platform');

  List<String> _packages = const [];

  @override
  void initState() {
    super.initState();
    _scenarioNameController = TextEditingController();
    _extraConfigController = TextEditingController();
    _notifyEndpointController = TextEditingController(
      text: const String.fromEnvironment(
        'bsg.endpoint.notify',
        defaultValue: 'http://bs-local.com:9339/notify',
      ),
    );
    _sessionEndpointController = TextEditingController(
      text: const String.fromEnvironment(
        'bsg.endpoint.session',
        defaultValue: 'http://bs-local.com:9339/session',
      ),
    );

    listPackages().then((value) {
      setState(() {
        _packages = value;
      });
    });
  }

  @override
  void dispose() {
    _scenarioNameController.dispose();
    _extraConfigController.dispose();
    _notifyEndpointController.dispose();
    _sessionEndpointController.dispose();

    super.dispose();
  }

  /// Fetches the next command
  void _onRunCommand(BuildContext context) async {
    log('Fetching the next command');
    final commandStr = await MazeRunnerChannels.getCommand();
    log('The command is: ${commandStr}');

    final command = Command.fromJsonString(commandStr);
    _scenarioNameController.text = command.scenarioName;
    _extraConfigController.text = command.extraConfig;

    switch(command.action) {
      case 'start_bugsnag': {
        _onStartBugsnag();
      }
      break;

      case 'run_scenario': {
        _onRunScenario(context);
      }
      break;
    }
  }

  /// Starts Bugsnag
  Future<void> _onStartBugsnag() async {
    log('Starting Bugsnag');
    final notifyEndpoint = _notifyEndpointController.value.text;
    final sessionEndpoint = _sessionEndpointController.value.text;

    await MazeRunnerChannels.startBugsnag(
      notifyEndpoint: notifyEndpoint,
      sessionEndpoint: sessionEndpoint,
    );
  }

  /// Runs a scenario, starting bugsnag first
  void _onRunScenario(BuildContext context) async {
    final scenario = _initScenario(context);
    if (scenario == null) {
      return;
    }

    final extraConfig = _extraConfigController.value.text;
    scenario.extraConfig = extraConfig;
    scenario.startBugsnag = _onStartBugsnag;
    log('Running scenario');
    await scenario.run();
  }

  /// Initializes a scenario
  Scenario? _initScenario(BuildContext context) {
    final name = _scenarioNameController.value.text;
    log('Initializing scenario: $name');
    final scenarioIndex =
        scenarios.indexWhere((element) => element.name == name);

    if (scenarioIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot find Scenario $name. "
              "Has it been added to scenario.dart?"),
        ),
      );

      return null;
    }

    return scenarios[scenarioIndex].init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 400.0,
              width: double.infinity,
              child: TextButton(
                child: const Text("Run Command"),
                onPressed: () => _onRunCommand(context),
                key: const Key("runCommand"),
              )
            ),
            TextField(
              controller: _scenarioNameController,
              key: const Key("scenarioName"),
              decoration: const InputDecoration(
                label: Text("Scenario Name"),
              ),
            ),
            TextField(
              controller: _extraConfigController,
              key: const Key("extraConfig"),
              decoration: const InputDecoration(
                label: Text("Extra Config"),
              ),
            ),
            TextField(
              controller: _notifyEndpointController,
              key: const Key("notifyEndpoint"),
              decoration: const InputDecoration(
                label: Text("Notify Endpoint"),
              ),
            ),
            TextField(
              controller: _sessionEndpointController,
              key: const Key("sessionEndpoint"),
              decoration: const InputDecoration(
                label: Text("Session Endpoint"),
              ),
            ),
            TextButton(
              child: const Text("Start Bugsnag"),
              onPressed: _onStartBugsnag,
              key: const Key("startBugsnag"),
            ),
            TextButton(
              child: const Text("Run Scenario"),
              onPressed: () => _onRunScenario(context),
              key: const Key("startScenario"),
            ),
            ListView(
              children: _packages.map((e) => Text("package: $e")).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
