import 'dart:async';
import 'dart:io';

import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

/// Paint a real first frame while the OHOS core and persisted state initialize.
/// The old startup path awaited both before calling runApp, which left the
/// native white start window visible for several seconds on a cold launch.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  Object? _error;
  StackTrace? _stack;
  ProviderContainer? _container;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (system.isDesktop) {
        await RustLib.init();
      }
      await CoreController.initOhosCoreBinary();
      final version = await system.version;
      final container = await globalState.init(version);
      HttpOverrides.global = FlClashHttpOverrides();
      if (!mounted) return;
      setState(() {
        _container = container;
        _ready = true;
      });
    } catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _stack = stack;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: InitErrorScreen(
          error: _error!,
          stack: _stack ?? StackTrace.current,
        ),
      );
    }
    if (_ready && _container != null) {
      return UncontrolledProviderScope(
        container: _container!,
        child: const Application(),
      );
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _StartupSplash(),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/icon.png',
          width: 128,
          height: 128,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
