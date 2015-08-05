import 'dart:convert' show JSON;
import 'dart:html';
import 'dart:svg' as svg;

import 'package:svg_pan_zoom/svg_pan_zoom.dart' as panzoom;
import 'package:infinity_view/infinity_view.dart' as inf;
import 'package:freckl/utils.dart' as utils;

void main() {
  querySelector('#path-to-index-file').onKeyUp.listen(indexFileKeyHandler);
  querySelector('#path-button').onMouseUp.listen(indexFileButtonHandler);

  var panZoom = new panzoom.SvgPanZoom.selector('.inner');
  panZoom
    ..zoomEnabled = true
    ..panEnabled = true
    ..zoomSensitivity = 0.02;
}

void indexFileKeyHandler(KeyboardEvent event) {
  if (event.keyCode == 13) {
    _loadIndexFileFromUrl(
        (querySelector('#path-to-index-file') as InputElement).value);
  }
}

void indexFileButtonHandler(MouseEvent event) {
  _loadIndexFileFromUrl(
      (querySelector('#path-to-index-file') as InputElement).value);
}

void _loadIndexFileFromUrl(String fileURL) {
  HttpRequest.getString(fileURL).then((String response) {
    var fileContents = JSON.decode(response);
    utils.validateIndexFileContents(fileContents);
    displayImageList(fileContents);
  });
}

void _loadFrecklFileFromUrl(String fileURL) {
  HttpRequest.getString(fileURL).then((String response) {
    var fileContents = JSON.decode(response);
    utils.validateIndexFileContents(fileContents);
    displayData(fileContents);
  });
}

void displayImageList(List indexList) {
  DivElement selectorWindow = new DivElement();
  selectorWindow.id = 'data-selector-window';
  document.body.append(selectorWindow);

  DivElement selectorContainer = new DivElement();
  selectorContainer.id = 'selector-items-container';
  selectorWindow.append(selectorContainer);

  inf.InfinityView view;

  Function createItemElement = (Map dataEntryMap) {
    DivElement wrapper = new DivElement();
    wrapper.classes.add('item-selector');

    DivElement imgWrapper = new DivElement();
    imgWrapper.classes.add('image');
    wrapper.append(imgWrapper);

    ImageElement img = new ImageElement();
    img.src = dataEntryMap['img'];
    img.style
      ..maxWidth = '100%'
      ..maxHeight = '100%';
    imgWrapper.append(img);

    DivElement text = new DivElement();
    text.classes.add('text');
    text.text = dataEntryMap['id'];
    wrapper.append(text);

    wrapper.onClick.listen((MouseEvent event) {
      selectorWindow.remove();
      view = null;
      _loadFrecklFileFromUrl(dataEntryMap['freckl']);
    });
    return wrapper;
  };

  view = new inf.InfinityView(indexList, createItemElement);
  view.pageHorizontalItemCount = 5;
  view.pageVerticalItemCount = 7;
  view.attachToElement(selectorContainer);
}

void displayData(List data) {
  svg.SvgSvgElement innerSvg = querySelector('.inner');
  svg.GElement group = innerSvg.querySelector('#viewport');
  group.nodes.clear();

  // Record maximum values of x and y which represent the width and height for
  // background necessary for zooming and panning.
  num minX, maxX, minY, maxY;
  minX = minY = double.INFINITY;
  maxX = maxY = double.NEGATIVE_INFINITY;

  for (Map dataPoint in data) {
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
    String color = utils.readColor(dataPoint['color']);

    // Add an area aura
    var aura = _createDataCircle(dataPoint, 25, color, 0.01);
    aura.style.pointerEvents = "None";
    group.append(aura);

    // Create the circle element
    var point = _createDataCircle(dataPoint, 1, color);

    point.onMouseOver.listen((MouseEvent event) {
      DivElement tooltip = querySelector('.tooltip');
      PreElement preElement = tooltip.querySelector('pre');
      utils
          .stringifyFreckl(dataPoint)
          .then((String text) => preElement.text = text);
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
  innerSvg.viewport.width = (maxX - minX).toInt();
  innerSvg.viewport.height = (maxY - minY).toInt();
}
