import 'dart:async';
import 'dart:html';
import 'dart:math' as math;
import 'dart:svg' as svg;
import 'dart:convert' show JSON;

import 'package:svg_pan_zoom/svg_pan_zoom.dart' as panzoom;

panzoom.SvgPanZoom panZoom;
String visSelector = '.inner';
int visWidth = 1000;
int visHeight = 500;

void main() {
  querySelector('#path-to-json').onKeyUp.listen(pathToJsonHander);
  querySelector('#path-button').onMouseUp.listen(buttonPressHandler);

  panZoom = new panzoom.SvgPanZoom.selector(visSelector);
  panZoom
    ..zoomEnabled = true
    ..panEnabled = true
    ..zoomSensitivity = 0.02;
}

void pathToJsonHander(KeyboardEvent event) {
  if (event.keyCode == 13) _loadData();
}

void buttonPressHandler(MouseEvent event) {
  _loadData();
}

void _loadData() {
  InputElement input = querySelector('#path-to-json');
  String pathToJson = input.value;
  HttpRequest.getString(pathToJson).then((String response) {
    List data = JSON.decode(response);
    displayData(data);
  });
}

void displayData(List data) {
  // Before doing anything else, reset the viewport of the visualisation.
  resetVisualisation();

  svg.SvgSvgElement innerSvg = querySelector(visSelector);
  svg.GElement group = innerSvg.querySelector('#viewport');
  group.nodes.clear();

  // Record maximum values of x and y which represent the width and height for
  // background necessary for zooming and panning.
  num minX, maxX, minY, maxY;
  minX = minY = double.INFINITY;
  maxX = maxY = double.NEGATIVE_INFINITY;

  for (Map dataPoint in data) {
    // [dataPoint] looks like:
    // {'point': [x, y],
    //  'value': v,
    //  'color': c,
    //  'uri': path,
    //  ...
    // }
    assert(dataPoint.containsKey('point'));
    assert(dataPoint['point'] is List);
    assert(dataPoint['point'].length == 2);
    assert(dataPoint.containsKey('value'));
    assert(dataPoint.containsKey('color'));

    minX = dataPoint['point'][0] < minX ? dataPoint['point'][0] : minX;
    minY = dataPoint['point'][1] < minY ? dataPoint['point'][1] : minY;
    maxX = dataPoint['point'][0] > maxX ? dataPoint['point'][0] : maxX;
    maxY = dataPoint['point'][1] > maxY ? dataPoint['point'][1] : maxY;
  }

  svg.CircleElement _createDataCircle(Map dataPoint, num radius, String colour,
      [num opacityOverride]) {
    svg.CircleElement point = new svg.CircleElement();
    point.attributes = {
      'cx': '${dataPoint['point'][0] - minX.toInt()}',
      'cy': '${dataPoint['point'][1] - minY.toInt()}',
      'r': '$radius',
      'fill': colour,
    };

    if (opacityOverride != null) {
      point.attributes['opacity'] = '$opacityOverride';
    }
    return point;
  }

  for (Map dataPoint in data) {
    // Color can be an int (the format of the image package for Dart)
    // or a (hex) string.
    String color;
    if (dataPoint['color'] is int) {
      int c = dataPoint['color'];
      int r = c & 0xff;
      int g = (c >> 8) & 0xff;
      int b = (c >> 16) & 0xff;
      int a = (c >> 24) & 0xff;
      color = 'rgba($r, $g, $b, $a)';
    } else {
      color = dataPoint['color'];
    }

    // Add an area aura
    var aura = _createDataCircle(dataPoint, 25, color, 0.01);
    aura.style.pointerEvents = "None";
    group.append(aura);

    // Create the circle element
    var point = _createDataCircle(dataPoint, 1, color);

    point.onMouseOver.listen((MouseEvent event) {
      DivElement tooltip = querySelector('.tooltip');
      PreElement preElement = tooltip.querySelector('pre');
      prettyString(dataPoint).then((String text) => preElement.text = text);
    });

    group.append(point);
  }

  // Create a background rect and insert it before the points.
  svg.RectElement rect = new svg.RectElement();
  rect.attributes = {
    'x': '0',
    'y': '0',
    'width': '${(maxX - minX).toInt()}',
    'height': '${(maxY - minY).toInt()}',
  };
  rect.classes.add('background');
  group.nodes.insert(0, rect);

  // Adjust the viewport on the parent svg element.
  centerAndFitVisualisation((maxX - minX).toInt(), (maxY - minY).toInt());
}

void centerAndFitVisualisation(int width, int height) {
  // Center the visualisation
  num offsetX = (visWidth - width * panZoom.realZoom) * 0.5;
  num offsetY = (visHeight - height * panZoom.realZoom) * 0.5;
  panZoom.panTo(offsetX, offsetY);

  // Scale it so it fits in the container
  num newScale = math.min(visWidth / width, visHeight / height);
  var centre = new math.Point(visWidth * 0.5, visHeight * 0.5);
  panZoom.zoomAtPoint(newScale, centre, true);
}

void resetVisualisation() {
  panZoom.zoomAtPoint(
      panZoom.minZoom, new math.Point(visWidth * 0.5, visHeight * 0.5), true);
}

Future prettyString(Map map) async {
  StringBuffer result = new StringBuffer();
  for (String key in map.keys) {
    result.writeln('$key : ${map[key]}');
  }
  if (map.containsKey('uri')) {
    String response = await HttpRequest.getString(map['uri']);
    result.writeln(response);
  }
  return new Future.value(result.toString());
}
