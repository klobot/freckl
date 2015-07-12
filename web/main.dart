import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;
import 'dart:convert' show JSON;

import 'package:svg_pan_zoom/svg_pan_zoom.dart' as panzoom;

void main() {
  querySelector('#path-button').onMouseUp.listen(buttonPressHandler);

  var panZoom = new panzoom.SvgPanZoom.selector('.inner');
  panZoom
    ..zoomEnabled = true
    ..panEnabled = true
    ..zoomSensitivity = 0.02;
}

void buttonPressHandler(MouseEvent event) {
  InputElement input = querySelector('#path-to-json');
  String pathToJson = input.value;
  HttpRequest.getString(pathToJson).then((String response) {
    List data = JSON.decode(response);
    displayData(data);
  });
}

void displayData(List data) {
  svg.SvgSvgElement innerSvg = querySelector('.inner');
  svg.GElement group = innerSvg.querySelector('#viewport');
  group.nodes.clear();

  // Record maximum values of x and y which represent the width and height for
  // background necessary for zooming and panning.
  num maxX, maxY;
  maxX = maxY = double.NEGATIVE_INFINITY;

  for (Map dataPoint in data) {
    // [dataPoint] looks like:
    // {'point': [x, y],
    //  'value': v,
    //  'color': c,
    //  ...
    // }
    assert(dataPoint.containsKey('point'));
    assert(dataPoint['point'] is List);
    assert(dataPoint['point'].length == 2);
    assert(dataPoint.containsKey('value'));
    assert(dataPoint.containsKey('color'));
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
    // Update maximum values.
    maxX = dataPoint['point'][0] > maxX ? dataPoint['point'][0] : maxX;
    maxY = dataPoint['point'][1] > maxY ? dataPoint['point'][1] : maxY;

    // Create the circle element
    svg.CircleElement point = new svg.CircleElement();
    point.attributes = {
      'cx': '${dataPoint['point'][0]}',
      'cy': '${dataPoint['point'][1]}',
      'r': '2',
      'fill': color,
    };

    point.onMouseOver.listen((MouseEvent event) {
      DivElement tooltip = querySelector('.tooltip');
      PreElement preElement = tooltip.querySelector('pre');
      preElement.text = prettyString(dataPoint);
    });

    point.onMouseLeave.listen((MouseEvent event) {
      DivElement tooltip = querySelector('.tooltip');
      PreElement preElement = tooltip.querySelector('pre');
      preElement.text = '';
    });
    group.append(point);
  }

  // Create a background rect and insert it before the points.
  svg.RectElement rect = new svg.RectElement();
  rect.attributes = {
    'x': '0',
    'y': '0',
    'width': '${maxX.toInt()}',
    'height': '${maxY.toInt()}',
  };
  rect.classes.add('background');
  group.nodes.insert(0, rect);

  // Adjust the viewport on the parent svg element.
  innerSvg.viewport.width = maxX.toInt();
  innerSvg.viewport.height = maxY.toInt();
}

String prettyString(Map map) {
  StringBuffer result = new StringBuffer();
  for (String key in map.keys) {
    result.writeln('$key : ${map[key]}');
  }
  return result.toString();
}
