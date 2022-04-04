import 'package:bugsnag_flutter/bugsnag.dart';
import 'package:flutter/foundation.dart';

// This file is heavily based on:
// https://github.com/dart-lang/sdk/blob/main/pkg/native_stack_traces/lib/src/convert.dart
// the primary difference is that we're only interested in the virtual address

final _traceLineRE = RegExp(
    r'\s*#(\d+) abs [\da-f]+(?: virt (?<virtual>[\da-f]+))? (?<rest>.*)$');

final _buildIdRegExp = RegExp(r"build_id: \'([a-f0-9]+)\'");
final _baseAddressRegExp = RegExp(r"isolate_dso_base: ([a-f0-9]+),");

class _Frame {
  final int offset;
  final String? method;

  const _Frame(this.offset, this.method);

  static final _symbolOffsetRE =
      RegExp(r'(?<symbol>\w+)\+(?<offset>(?:0x)?[\da-f]+)');

  static _Frame? parse(String line) {
    final match = _traceLineRE.firstMatch(line);
    if (match == null) return null;
    // If all other cases failed, check for a virtual address. Until this package
    // depends on a version of Dart which only prints virtual addresses when the
    // virtual addresses in the snapshot are the same as in separately saved
    // debugging information, the other methods should be tried first.
    final virtualString = match.namedGroup('virtual');
    final rest = match.namedGroup('rest');

    final address =
        virtualString != null ? int.tryParse(virtualString, radix: 16) : null;

    if (address != null) {
      return _Frame(address, _extractMethodName(rest));
    }

    return null;
  }

  static String? _extractMethodName(String? symbolString) {
    if (symbolString == null) {
      return null;
    }

    final match = _symbolOffsetRE.firstMatch(symbolString);
    return match?.namedGroup('symbol');
  }
}

// Try to parse the build_id from the line, returning it's value if it existed
String? _parseBuildId(String line) {
  final match = _buildIdRegExp.firstMatch(line);
  return match?.group(1);
}

// Try to parse the Isolate base address from the line (isolate_dso_base)
int? _parseBaseAddress(String line) {
  final match = _baseAddressRegExp.firstMatch(line);
  final matchedAddressString = match?.group(1);

  if (matchedAddressString != null) {
    return int.tryParse(matchedAddressString, radix: 16);
  }

  return null;
}

Stacktrace? _parseStackTrace(String stackTraceString) {
  try {
    return StackFrame.fromStackTrace(StackTrace.fromString(stackTraceString))
        .map(Stackframe.fromStackFrame)
        .toList();
  } catch (e) {
    return null;
  }
}

/// If possible parse the given [stackTrace] as an obfuscated native stackTrace.
/// If the given `stackTrace` is not a valid native stack trace return `null`.
Stacktrace? parseNativeStackTrace(String stackTrace) {
  final stackTraceLines = stackTrace.split('\n');

  String? buildId;
  int? baseOffset;

  List<Stackframe> stacktrace = [];

  for (final line in stackTraceLines) {
    buildId ??= _parseBuildId(line);
    baseOffset ??= _parseBaseAddress(line);
    final frame = _Frame.parse(line);

    if (frame != null && baseOffset != null) {
      stacktrace.add(Stackframe(
        frameAddress: '0x' + (baseOffset + frame.offset).toRadixString(16),
        loadAddress: '0x' + baseOffset.toRadixString(16),
        codeIdentifier: buildId,
        method: frame.method,
      ));
    }
  }

  return buildId != null ? stacktrace : null;
}

Stacktrace? parseStackTraceString(String stackTrace) {
  return parseNativeStackTrace(stackTrace) ?? _parseStackTrace(stackTrace);
}
