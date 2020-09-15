import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

/// signature canvas. Controller is required, other parameters are optional.
/// widget/canvas expands to maximum by default.
/// this behaviour can be overridden using width and/or height parameters.
class Signature extends StatefulWidget {
  /// constructor
  const Signature({
    @required this.controller,
    Key key,
    this.backgroundColor = Colors.grey,
    this.width,
    this.height,
  })  : assert(controller != null),
        super(key: key);

  /// signature widget controller
  final SignatureController controller;

  /// signature widget width
  final double width;

  /// signature widget height
  final double height;

  /// signature widget background color
  final Color backgroundColor;

  @override
  State createState() => SignatureState();
}

/// signature widget state
class SignatureState extends State<Signature> {
  @override
  Widget build(BuildContext context) {
    final double maxWidth = widget.width ?? double.infinity;
    final double maxHeight = widget.height ?? double.infinity;
    final GestureDetector signatureCanvas = GestureDetector(
      onPanUpdate: (DragUpdateDetails details) {
        setState(() {
          final RenderBox object = context.findRenderObject();
          final Offset _localPosition =
              object.globalToLocal(details.globalPosition);
          if ((widget.width == null ||
                  _localPosition.dx > 0 && _localPosition.dx < widget.width) &&
              (widget.height == null ||
                  _localPosition.dy > 0 && _localPosition.dy < widget.height)) {
            widget.controller.value = List<Offset>.from(widget.controller.value)
              ..add(_localPosition);
          }
        });
      },
      onPanEnd: (DragEndDetails details) => widget.controller.value.add(null),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SignaturePainter(controller: widget.controller),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: maxWidth,
                minHeight: maxHeight,
                maxWidth: maxWidth,
                maxHeight: maxHeight),
          ),
        ),
      ),
    );

    if (widget.width != null || widget.height != null) {
      //IF DOUNDARIES ARE DEFINED, USE LIMITED BOX
      return LimitedBox(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        child: signatureCanvas,
      );
    } else {
      //IF NO BOUNDARIES ARE DEFINED, USE EXPANDED
      return Expanded(child: signatureCanvas);
    }
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({this.controller}) : super(repaint: controller) {
    _penStyle = Paint()
      ..strokeCap = StrokeCap.round
      ..color = controller.penColor
      ..strokeWidth = controller.penStrokeWidth;
  }

  final SignatureController controller;
  Paint _penStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> points = controller.value;
    for (int i = 0; i < (points.length - 1); i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], _penStyle);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter other) => true;
}

/// class for interaction with signature widget
/// manages points representing signature on canvas
/// provides signature manipulation functions (export, clear)
class SignatureController extends ValueNotifier<List<Offset>> {
  /// constructor
  SignatureController(
      {List<Offset> points,
      this.penColor = Colors.black,
      this.penStrokeWidth = 3.0,
      this.exportBackgroundColor})
      : super(points ?? <Offset>[]);

  /// color of a signature line
  final Color penColor;

  /// boldness of a signature line
  final double penStrokeWidth;

  /// background color to be used in exported png image
  final Color exportBackgroundColor;

  /// getter for points representing signature on 2D canvas
  List<Offset> get points => value;

  /// setter for points representing signature on 2D canvas
  set points(List<Offset> points) {
    value = points.toList();
  }

  /// add point to point collection
  void addPoint(Offset point) {
    value.add(point);
    notifyListeners();
  }

  /// check if canvas is empty (opposite of isNotEmpty method for convenience)
  bool get isEmpty {
    return value.isEmpty;
  }

  /// check if canvas is not empty (opposite of isEmpty method for convenience)
  bool get isNotEmpty {
    return value.isNotEmpty;
  }

  /// clear the canvas
  void clear() {
    value = <Offset>[];
  }

  ///convert to
  Future<ui.Image> toImage() async {
    if (isEmpty) {
      return null;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (Offset point in points) {
      if (point != null) {
        if (point.dx < minX) {
          minX = point.dx;
        }
        if (point.dy < minY) {
          minY = point.dy;
        }
        if (point.dx > maxX) {
          maxX = point.dx;
        }
        if (point.dy > maxY) {
          maxY = point.dy;
        }
      }
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder)
      ..translate(-(minX - penStrokeWidth), -(minY - penStrokeWidth));
    if (exportBackgroundColor != null) {
      final ui.Paint paint = Paint()..color = exportBackgroundColor;
      canvas.drawPaint(paint);
    }
    _SignaturePainter(controller: this).paint(canvas, null);
    final ui.Picture picture = recorder.endRecording();
    return picture.toImage((maxX - minX + penStrokeWidth * 2).toInt(),
        (maxY - minY + penStrokeWidth * 2).toInt());
  }

  /// convert canvas to dart:ui Image and then to PNG represented in Uint8List
  Future<Uint8List> toPngBytes() async {
    if (!kIsWeb) {
      final ui.Image image = await toImage();
      if (image == null) {
        return null;
      }
      final ByteData bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes.buffer.asUint8List();
    } else {
      return _toPngBytesForWeb();
    }
  }

  // 'image.toByteData' is not available for web. So we are use the package
  // 'image' to create a image which works on web too
  Uint8List _toPngBytesForWeb() {
    if (isEmpty) {
      return null;
    }
    final int pColor =
        img.getColor(penColor.red, penColor.green, penColor.blue);

    final Color backgroundColor = exportBackgroundColor ?? Colors.transparent;
    final int bColor = img.getColor(backgroundColor.red, backgroundColor.green,
        backgroundColor.blue, backgroundColor.alpha.toInt());

    double minX = double.infinity;
    double maxX = 0;
    double minY = double.infinity;
    double maxY = 0;

    for (Offset point in points) {
      minX = min(point.dx, minX);
      maxX = max(point.dx, maxX);
      minY = min(point.dy, minY);
      maxY = max(point.dy, maxY);
    }

    //point translation
    final List<Offset> translatedPoints = <Offset>[];
    for (Offset point in points) {
      translatedPoints.add(Offset(
          point.dx - minX + penStrokeWidth, point.dy - minY + penStrokeWidth));
    }

    final int width = (maxX - minX + penStrokeWidth * 2).toInt();
    final int height = (maxY - minY + penStrokeWidth * 2).toInt();

    // create the image with the given size
    final img.Image signatureImage = img.Image(width, height);
    // set the image background color
    img.fill(signatureImage, bColor);

    // read the drawing points list and draw the image
    // it uses the same logic as the CustomPainter Paint function
    for (int i = 0; i < translatedPoints.length - 1; i++) {
      img.drawLine(
          signatureImage,
          translatedPoints[i].dx.toInt(),
          translatedPoints[i].dy.toInt(),
          translatedPoints[i + 1].dx.toInt(),
          translatedPoints[i + 1].dy.toInt(),
          pColor,
          thickness: penStrokeWidth);
    }
    // encode the image to PNG
    return Uint8List.fromList(img.encodePng(signatureImage));
  }
}
