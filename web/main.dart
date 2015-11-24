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
int maxAllowedDistance = 500;

void main() {
  querySelector('#path-to-json').onKeyUp.listen(pathToJsonHander);
  querySelector('#path-button').onMouseUp.listen(buttonPressHandler);

  querySelectorAll('.splitter').forEach((Element element) {
    bool vertical = element.classes.contains('vertical');
    bool horizontal = element.classes.contains('horizontal');

    element.onMouseDown.listen((MouseEvent e) {
      if (e.which != 1) {
        return;
      }

      e.preventDefault();
      Point offset = e.offset;

      StreamSubscription moveSubscription, upSubscription;
      Function cancel = () {
        if (moveSubscription != null) {
          moveSubscription.cancel();
        }
        if (upSubscription != null) {
          upSubscription.cancel();
        }
      };

      moveSubscription = document.onMouseMove.listen((e) {
        List neighbors = element.parent.children;
        Element target = neighbors[neighbors.indexOf(element) - 1];

        if (e.which != 1) {
          cancel();
        } else {
          Point current = e.client - element.parent.client.topLeft - offset;
          current -= target.marginEdge.topLeft;
          if (vertical) {
            target.style.width = '${current.x}px';
          } else if (horizontal) {
            target.style.height = '${current.y}px';
          }
        }
      });

      upSubscription = document.onMouseUp.listen((e) {
        cancel();
      });
    });
  });

  panZoom = new panzoom.SvgPanZoom.selector('.inner-svg');
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
  svg.SvgSvgElement innerSvg = querySelector('.inner-svg');
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

  // Sort data ascending, so that we can compress the horizontal whitespace.
  data.sort((p1, p2) => p1['point'][0] - p2['point'][0]);
  num compressedWhitespace = 0;

  svg.CircleElement _createDataCircle(Map dataPoint, num radius, String colour,
      [num opacityOverride]) {
    svg.CircleElement point = new svg.CircleElement();
    point.attributes = {
      'cx': '${dataPoint['point'][0] - minX.toInt() - compressedWhitespace}',
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
    // The distance between this point and the previous one
    Map previousDataPoint = data[math.max(0, data.indexOf(dataPoint) - 1)];
    num distance = dataPoint['point'][0] - previousDataPoint['point'][0];
    if (distance > maxAllowedDistance) {
      var separatorWidth = 3;
      var spaceAroundRect = 100;
      var separatorHeight = maxY - minY;
      var separatorXOffset = previousDataPoint['point'][0] + spaceAroundRect - minX.toInt() - compressedWhitespace;

      var separator = new svg.GElement();
      separator
        ..attributes['width'] = '$separatorWidth'
        ..attributes['height'] = '${separatorHeight}'
        ..attributes['x'] = '${separatorXOffset}'
        ..attributes['y'] = '0';
      separator.style
        ..setProperty('fill', '#666666')
        ..setProperty('stroke', 'none');
      group.append(separator);

      separator.append(new svg.LineElement()
        ..attributes['x1'] = '${separatorXOffset}'
        ..attributes['y1'] = '${separatorHeight / 4}'
        ..attributes['x2'] = '${separatorXOffset}'
        ..attributes['y2'] = '${separatorHeight * 3/ 4}'
        ..attributes['stroke'] = '#666666'
        ..attributes['stroke-width'] = '${separatorWidth}');

      compressedWhitespace = compressedWhitespace + distance - separatorWidth - 2 * spaceAroundRect;
    }

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
      DivElement tooltip = querySelector('#info-left');
      PreElement preElement = tooltip.querySelector('pre');
      prettyString(dataPoint).then((String text) => preElement.text = text);
    });

    group.append(point);
  }

  // Create a background rect and insert it before the points.
  svg.RectElement rect = new svg.RectElement();
  rect.attributes = {
    'x': '-25',
    'y': '-25',
    'width': '${(maxX - minX - compressedWhitespace).toInt() + 50}',
    'height': '${(maxY - minY).toInt() + 50}',
  };
  rect.classes.add('background');
  group.nodes.insert(0, rect);

  // Adjust the viewport on the parent svg element.
  centerAndFitVisualisation((maxX - minX - compressedWhitespace).toInt(), (maxY - minY).toInt());
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
      panZoom.minZoom, new math.Point(visWidth * 0.5, visHeight * 0.5));
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
