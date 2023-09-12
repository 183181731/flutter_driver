// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';

import 'deserialization_factory.dart';
import 'error.dart';
import 'message.dart';

const List<Type> _supportedKeyValueTypes = <Type>[String, int];

DriverError _createInvalidKeyValueTypeError(String invalidType) {
  return DriverError(
      'Unsupported key value type $invalidType. Flutter Driver only supports ${_supportedKeyValueTypes.join(", ")}');
}

/// A Flutter Driver command aimed at an object to be located by [finder].
///
/// Implementations must provide a concrete [kind]. If additional data is
/// required beyond the [finder] the implementation may override [serialize]
/// and add more keys to the returned map.
abstract class CommandWithTarget extends Command {
  /// Constructs this command given a [finder].
  CommandWithTarget(this.finder, {super.timeout});

  /// Deserializes this command from the value generated by [serialize].
  CommandWithTarget.deserialize(
      super.json, DeserializeFinderFactory finderFactory)
      : finder = finderFactory.deserializeFinder(json),
        super.deserialize();

  /// Locates the object or objects targeted by this command.
  final SerializableFinder finder;

  /// This method is meant to be overridden if data in addition to [finder]
  /// is serialized to JSON.
  ///
  /// Example:
  ///
  ///     Map<String, String> toJson() => super.toJson()..addAll({
  ///       'foo': this.foo,
  ///     });
  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll(finder.serialize());
}

/// A Flutter Driver command that waits until [finder] can locate the target.
class WaitFor extends CommandWithTarget {
  /// Creates a command that waits for the widget identified by [finder] to
  /// appear within the [timeout] amount of time.
  ///
  /// If [timeout] is not specified, the command defaults to no timeout.
  WaitFor(super.finder, {super.timeout});

  /// Deserializes this command from the value generated by [serialize].
  WaitFor.deserialize(super.json, super.finderFactory) : super.deserialize();

  @override
  String get kind => 'waitFor';
}

/// A Flutter Driver command that waits until [finder] can no longer locate the target.
class WaitForAbsent extends CommandWithTarget {
  /// Creates a command that waits for the widget identified by [finder] to
  /// disappear within the [timeout] amount of time.
  ///
  /// If [timeout] is not specified, the command defaults to no timeout.
  WaitForAbsent(super.finder, {super.timeout});

  /// Deserializes this command from the value generated by [serialize].
  WaitForAbsent.deserialize(super.json, super.finderFactory)
      : super.deserialize();

  @override
  String get kind => 'waitForAbsent';
}

/// A Flutter Driver command that waits until [finder] can be tapped.
class WaitForTappable extends CommandWithTarget {
  /// Creates a command that waits for the widget identified by [finder] to
  /// be tappable within the [timeout] amount of time.
  ///
  /// If [timeout] is not specified, the command defaults to no timeout.
  WaitForTappable(super.finder, {super.timeout});

  /// Deserialized this command from the value generated by [serialize].
  WaitForTappable.deserialize(super.json, super.finderFactory)
      : super.deserialize();

  @override
  String get kind => 'waitForTappable';
}

/// Base class for Flutter Driver finders, objects that describe how the driver
/// should search for elements.
abstract class SerializableFinder {
  /// A const constructor to allow subclasses to be const.
  const SerializableFinder();

  /// Identifies the type of finder to be used by the driver extension.
  String get finderType;

  /// Serializes common fields to JSON.
  ///
  /// Methods that override [serialize] are expected to call `super.serialize`
  /// and add more fields to the returned [Map].
  @mustCallSuper
  Map<String, String> serialize() => <String, String>{'finderType': finderType};
}

/// A Flutter Driver finder that finds widgets by tooltip text.
class ByTooltipMessage extends SerializableFinder {
  /// Creates a tooltip finder given the tooltip's message [text].
  const ByTooltipMessage(this.text, this.index);

  /// Tooltip message text.
  final String text;
  final String index;

  @override
  String get finderType => 'ByTooltipMessage';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'text': text,
    });

  /// Deserializes the finder from JSON generated by [serialize].
  static ByTooltipMessage deserialize(Map<String, String> json) {
    return ByTooltipMessage(
        json['text']!, json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter Driver finder that finds widgets by semantic label.
///
/// If the [label] property is a [String], the finder will try to find an exact
/// match. If it is a [RegExp], it will return true for [RegExp.hasMatch].
class BySemanticsLabel extends SerializableFinder {
  /// Creates a semantic label finder given the [label].
  const BySemanticsLabel(this.label, this.index);

  /// A [Pattern] matching the label of a [SemanticsNode].
  ///
  /// If this is a [String], it will be treated as an exact match.
  final Pattern label;
  final String index;

  @override
  String get finderType => 'BySemanticsLabel';

  @override
  Map<String, String> serialize() {
    if (label is RegExp) {
      final RegExp regExp = label as RegExp;
      return super.serialize()
        ..addAll(<String, String>{
          'label': regExp.pattern,
          'isRegExp': 'true',
        });
    } else {
      return super.serialize()
        ..addAll(<String, String>{
          'label': label as String,
        });
    }
  }

  /// Deserializes the finder from JSON generated by [serialize].
  static BySemanticsLabel deserialize(Map<String, String> json) {
    final bool isRegExp = json['isRegExp'] == 'true';
    return BySemanticsLabel(isRegExp ? RegExp(json['label']!) : json['label']!,
        json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter Driver finder that finds widgets by [text] inside a
/// [widgets.Text] or [widgets.EditableText] widget.
class ByText extends SerializableFinder {
  /// Creates a text finder given the text.
  const ByText(this.text, this.index);

  /// The text that appears inside the [widgets.Text] or [widgets.EditableText]
  /// widget.
  final String text;
  final String index;

  @override
  String get finderType => 'ByText';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'text': text,
    });

  /// Deserializes the finder from JSON generated by [serialize].
  static ByText deserialize(Map<String, String> json) {
    return ByText(
        json['text']!, json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter Driver finder that finds widgets by `ValueKey`.
class ByValueKey extends SerializableFinder {
  /// Creates a finder given the key value.
  ByValueKey(this.keyValue, this.index)
      : keyValueString = '$keyValue',
        keyValueType = '${keyValue.runtimeType}' {
    if (!_supportedKeyValueTypes.contains(keyValue.runtimeType)) {
      throw _createInvalidKeyValueTypeError('$keyValue.runtimeType');
    }
  }

  /// The true value of the key.
  final dynamic keyValue;

  /// Stringified value of the key (we can only send strings to the VM service)
  final String keyValueString;

  /// The type name of the key.
  ///
  /// May be one of "String", "int". The list of supported types may change.
  final String keyValueType;
  final String index;

  @override
  String get finderType => 'ByValueKey';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'keyValueString': keyValueString,
      'keyValueType': keyValueType,
    });

  /// Deserializes the finder from JSON generated by [serialize].
  static ByValueKey deserialize(Map<String, String> json) {
    final String keyValueString = json['keyValueString']!;
    final String keyValueType = json['keyValueType']!;
    switch (keyValueType) {
      case 'int':
        return ByValueKey(int.parse(keyValueString),
            json.containsKey('index') ? json['index']! : "0");
      case 'String':
        return ByValueKey(
            keyValueString, json.containsKey('index') ? json['index']! : "0");
      default:
        throw _createInvalidKeyValueTypeError(keyValueType);
    }
  }
}

/// A Flutter Driver finder that finds widgets by their [runtimeType].
class ByType extends SerializableFinder {
  /// Creates a finder given the runtime type in string form.
  const ByType(this.type, this.index);

  /// The widget's [runtimeType], in string form.
  final String type;
  final String index;

  @override
  String get finderType => 'ByType';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'type': type,
    });

  /// Deserializes the finder from JSON generated by [serialize].
  static ByType deserialize(Map<String, String> json) {
    return ByType(
        json['type']!, json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter Driver finder that finds the back button on the page's Material
/// or Cupertino scaffold.
///
/// See also:
///
///  * [WidgetTester.pageBack], for a similar functionality in widget tests.
class PageBack extends SerializableFinder {
  /// Creates a [PageBack].
  const PageBack();

  @override
  String get finderType => 'PageBack';
}

/// A Flutter Driver finder that finds a descendant of [of] that matches
/// [matching].
///
/// If the `matchRoot` argument is true, then the widget specified by [of] will
/// be considered for a match. The argument defaults to false.
class Descendant extends SerializableFinder {
  /// Creates a descendant finder.
  const Descendant(
      {required this.of,
      required this.matching,
      this.matchRoot = false,
      this.firstMatchOnly = false,
      required this.index});

  final String index;

  /// The finder specifying the widget of which the descendant is to be found.
  final SerializableFinder of;

  /// Only a descendant of [of] matching this finder will be found.
  final SerializableFinder matching;

  /// Whether the widget matching [of] will be considered for a match.
  final bool matchRoot;

  /// If true then only the first descendant matching `matching` will be returned.
  final bool firstMatchOnly;

  @override
  String get finderType => 'Descendant';

  @override
  Map<String, String> serialize() {
    return super.serialize()
      ..addAll(<String, String>{
        'of': jsonEncode(of.serialize()),
        'matching': jsonEncode(matching.serialize()),
        'matchRoot': matchRoot ? 'true' : 'false',
        'firstMatchOnly': firstMatchOnly ? 'true' : 'false',
      });
  }

  /// Deserializes the finder from JSON generated by [serialize].
  static Descendant deserialize(
      Map<String, String> json, DeserializeFinderFactory finderFactory) {
    final Map<String, String> jsonOfMatcher = Map<String, String>.from(
        jsonDecode(json['of']!) as Map<String, dynamic>);
    final Map<String, String> jsonMatchingMatcher = Map<String, String>.from(
        jsonDecode(json['matching']!) as Map<String, dynamic>);
    return Descendant(
        of: finderFactory.deserializeFinder(jsonOfMatcher),
        matching: finderFactory.deserializeFinder(jsonMatchingMatcher),
        matchRoot: json['matchRoot'] == 'true',
        firstMatchOnly: json['firstMatchOnly'] == 'true',
        index: json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter Driver finder that finds an ancestor of [of] that matches
/// [matching].
///
/// If the `matchRoot` argument is true, then the widget specified by [of] will
/// be considered for a match. The argument defaults to false.
class Ancestor extends SerializableFinder {
  /// Creates an ancestor finder.
  const Ancestor(
      {required this.of,
      required this.matching,
      this.matchRoot = false,
      this.firstMatchOnly = false,
      this.index = '0'});

  final String index;

  /// The finder specifying the widget of which the ancestor is to be found.
  final SerializableFinder of;

  /// Only an ancestor of [of] matching this finder will be found.
  final SerializableFinder matching;

  /// Whether the widget matching [of] will be considered for a match.
  final bool matchRoot;

  /// If true then only the first ancestor matching `matching` will be returned.
  final bool firstMatchOnly;

  @override
  String get finderType => 'Ancestor';

  @override
  Map<String, String> serialize() {
    return super.serialize()
      ..addAll(<String, String>{
        'of': jsonEncode(of.serialize()),
        'matching': jsonEncode(matching.serialize()),
        'matchRoot': matchRoot ? 'true' : 'false',
        'firstMatchOnly': firstMatchOnly ? 'true' : 'false',
      });
  }

  /// Deserializes the finder from JSON generated by [serialize].
  static Ancestor deserialize(
      Map<String, String> json, DeserializeFinderFactory finderFactory) {
    final Map<String, String> jsonOfMatcher = Map<String, String>.from(
        jsonDecode(json['of']!) as Map<String, dynamic>);
    final Map<String, String> jsonMatchingMatcher = Map<String, String>.from(
        jsonDecode(json['matching']!) as Map<String, dynamic>);
    return Ancestor(
        of: finderFactory.deserializeFinder(jsonOfMatcher),
        matching: finderFactory.deserializeFinder(jsonMatchingMatcher),
        matchRoot: json['matchRoot'] == 'true',
        firstMatchOnly: json['firstMatchOnly'] == 'true',
        index: json.containsKey('index') ? json['index']! : "0");
  }
}

/// A Flutter driver command that retrieves a semantics id using a specified finder.
///
/// This command requires assertions to be enabled on the device.
///
/// If the object returned by the finder does not have its own semantics node,
/// then the semantics node of the first ancestor is returned instead.
///
/// Throws an error if a finder returns multiple objects or if there are no
/// semantics nodes.
///
/// Semantics must be enabled to use this method, either using a platform
/// specific shell command or [FlutterDriver.setSemantics].
class GetSemanticsId extends CommandWithTarget {
  /// Creates a command which finds a Widget and then looks up the semantic id.
  GetSemanticsId(super.finder, {super.timeout});

  /// Creates a command from a JSON map.
  GetSemanticsId.deserialize(super.json, super.finderFactory)
      : super.deserialize();

  @override
  String get kind => 'get_semantics_id';
}

/// The result of a [GetSemanticsId] command.
class GetSemanticsIdResult extends Result {
  /// Creates a new [GetSemanticsId] result.
  const GetSemanticsIdResult(this.id);

  /// The semantics id of the node.
  final int id;

  /// Deserializes this result from JSON.
  static GetSemanticsIdResult fromJson(Map<String, dynamic> json) {
    return GetSemanticsIdResult(json['id'] as int);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}
