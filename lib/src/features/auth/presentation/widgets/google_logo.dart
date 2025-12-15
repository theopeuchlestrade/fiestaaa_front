import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scaling based on 24x24 standard size
    final double scale = size.width / 24.0;

    // Shift/Translate to center or align if needed, but here we draw at 0,0 scaled.
    canvas.scale(scale, scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Blue Path
    Path bluePath = Path();
    bluePath.moveTo(23.49, 12.27);
    bluePath.cubicTo(23.49, 11.48, 23.42, 10.73, 23.3, 10.02);
    bluePath.lineTo(12.0, 10.02);
    bluePath.lineTo(12.0, 14.51);
    bluePath.lineTo(18.47, 14.51);
    bluePath.cubicTo(18.18, 15.99, 17.25, 17.24, 15.94, 18.1);
    bluePath.lineTo(15.94, 21.1);
    bluePath.lineTo(19.82, 21.1);
    bluePath.cubicTo(22.09, 19.01, 23.49, 15.92, 23.49, 12.27);
    bluePath.close();
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(bluePath, paint);

    // Green Path
    Path greenPath = Path();
    greenPath.moveTo(12.0, 24.0);
    greenPath.cubicTo(15.15, 24.0, 17.81, 22.95, 19.82, 21.1);
    greenPath.lineTo(15.94, 18.1);
    greenPath.cubicTo(14.88, 18.82, 13.56, 19.23, 12.0, 19.23);
    greenPath.cubicTo(8.93, 19.23, 6.33, 17.15, 5.4, 14.35);
    greenPath.lineTo(1.47, 14.35);
    greenPath.lineTo(1.47, 17.39);
    greenPath.cubicTo(3.47, 21.36, 7.55, 24, 12.0, 24.0);
    greenPath.close();
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(greenPath, paint);

    // Yellow Path
    Path yellowPath = Path();
    yellowPath.moveTo(5.4, 14.35);
    yellowPath.cubicTo(5.17, 13.62, 5.04, 12.86, 5.04, 12.08);
    yellowPath.cubicTo(5.04, 11.3, 5.17, 10.53, 5.4, 9.8);
    yellowPath.lineTo(5.4, 6.76);
    yellowPath.lineTo(1.47, 6.76);
    yellowPath.cubicTo(0.53, 8.64, 0, 10.82, 0, 12.08);
    yellowPath.cubicTo(0, 13.33, 0.53, 15.51, 1.47, 17.39);
    yellowPath.lineTo(5.4, 14.35);
    yellowPath.close();
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(yellowPath, paint);

    // Red Path
    Path redPath = Path();
    redPath.moveTo(12.0, 4.9);
    redPath.cubicTo(13.67, 4.9, 15.19, 5.48, 16.39, 6.63);
    redPath.lineTo(19.89, 3.14);
    redPath.cubicTo(17.8, 1.19, 15.15, 0, 12.0, 0);
    redPath.cubicTo(7.55, 0, 3.47, 2.64, 1.47, 6.76);
    redPath.lineTo(5.4, 9.8);
    redPath.cubicTo(6.33, 7.0, 8.93, 4.9, 12.0, 4.9);
    redPath.close();
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
