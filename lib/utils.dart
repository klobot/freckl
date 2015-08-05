library utils;

import 'dart:async';
import 'dart:html';

/// The index file is a list of maps with the following structure:
/// [
///   ...
///   {
///     "id": <data entry ID>,
///     "img": <absolute URL to the data entry image>,
///     "freckl": <absolute URL to the data entry freckl file>,
///   }
///   ...
/// }
void validateIndexFileContents(indexContents) {
  assert(indexContents is List);
  for (var element in indexContents) {
    assert(element is Map);
    Map map = element;
    assert(map.containsKey('id'));
    assert(map.containsKey('img'));
    assert(map.containsKey('freckl'));
  }
}

/// A freckl file is a list of maps with the following structure:
/// [
///   ...
///   {
///     'point': [<num x>, <num y>],
///     'value': <data point value>,
///     'color': <color as an int or string>,
///     'uri': <optional uri to more data point information>
///   }
///   ...
/// ]
void validateFrecklFileContents(frecklContents) {
  assert(frecklContents is List);
  for (var element in frecklContents) {
    assert(element is Map);
    Map map = element;
    // Check for point
    assert(map.containsKey('point'));
    assert(map['point'] is List);
    assert(map['point'].length == 2);
    // Check for value
    assert(map.containsKey('value'));
    assert(map.containsKey('color'));
  }
}

/// Color can be an int (the format of the image package for Dart)
/// or a (hex) string.
String readColor(color) {
  String returnColor;
  if (color is int) {
    int c = color;
    int r = c & 0xff;
    int g = (c >> 8) & 0xff;
    int b = (c >> 16) & 0xff;
    int a = (c >> 24) & 0xff;
    returnColor = 'rgba($r, $g, $b, $a)';
  } else {
    returnColor = color;
  }
  return returnColor;
}

/// Turns a freckl data point map to a string.
Future stringifyFreckl(Map frecklData) async {
  StringBuffer result = new StringBuffer();
  for (String key in frecklData.keys) {
    result.writeln('$key : ${frecklData[key]}');
  }
  if (frecklData.containsKey('uri')) {
    String response = await HttpRequest.getString(frecklData['uri']);
    result.writeln(response);
  }
  return new Future.value(result.toString());
}
