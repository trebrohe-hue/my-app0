import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const CubeDashApp());

class CubeDashApp extends StatelessWidget {
  const CubeDashApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cube Dash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

enum GameState { menu, playing, over }

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final Random _rand = Random();

  GameState _state = GameState.menu;

  // --- Player ---
  final double _playerSize = 38;
  final double _playerX = 90;
  double _playerY = 0;
  double _playerVel = 0;

  // --- World ---
  double _groundY = 0;
  Size _screenSize = Size.zero;
  bool _needsInit = true;

  // --- Obstacles ---
  final List<_Obstacle> _obstacles = [];
  double _spawnTimer = 0.9;
  double _speed = 260;

  // --- Score ---
  double _score = 0;
  int _best = 0;

  // --- Physics ---
  static const double _gravity   = 2000;
  static const double _jumpForce = -750;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    _update(dt);
    if (_state == GameState.playing && mounted) {
      setState(() {});
    }
  }

  void _update(double dt) {
    if (_state != GameState.playing) return;

    // Gravity
    _playerVel += _gravity * dt;
    _playerY   += _playerVel * dt;

    // Ground collision
    final restY = _groundY - _playerSize / 2;
    if (_playerY > restY) {
      _playerY   = restY;
      _playerVel = 0;
    }

    // Spawn
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnObstacle();
      _spawnTimer = (1.5 - _score * 0.005).clamp(0.55, 1.5);
    }

    // Move obstacles
    for (int i = _obstacles.length - 1; i >= 0; i--) {
      _obstacles[i].x -= _speed * dt;
      if (_obstacles[i].x + _obstacles[i].width < -20) {
        _obstacles.removeAt(i);
      }
    }

    // Ramp up speed
    _speed = (260 + _score * 1.1).clamp(260, 520);

    // Collision
    final playerRect = Rect.fromCenter(
      center: Offset(_playerX, _playerY),
      width: _playerSize,
      height: _playerSize,
    );
    for (final o in _obstacles) {
      final obsRect = Rect.fromLTWH(
        o.x, _groundY - o.height, o.width, o.height,
      );
      if (playerRect.overlaps(obsRect)) {
        _gameOver();
        return;
      }
    }

    _score += dt * 10;
  }

  void _spawnObstacle() {
    final h = 30.0 + _rand.nextDouble() * 50;
    final w = 28.0 + _rand.nextDouble() * 22;
    _obstacles.add(_Obstacle(
      x: _screenSize.width + 40,
      height: h,
      width: w,
    ));
  }

  void _gameOver() {
    final s = _score.floor();
    if (s > _best) _best = s;
    setState(() => _state = GameState.over);
  }

  void _onTap() {
    if (_state == GameState.menu || _state == GameState.over) {
      _startGame();
    } else {
      _jump();
    }
  }

  void _startGame() {
    _obstacles.clear();
    _spawnTimer = 0.9;
    _speed      = 260;
    _score      = 0;
    _playerVel  = 0;
    _needsInit  = true;
    setState(() => _state = GameState.playing);
  }

  void _jump() {
    final onGround = _playerY >= _groundY - _playerSize / 2 - 2;
    if (onGround) _playerVel = _jumpForce;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _groundY = _screenSize.height - 100;

          if (_needsInit && _screenSize.height > 0) {
            _playerY = _groundY - _playerSize / 2;
            _needsInit = false;
          }

          return GestureDetector(
            onTapDown: (_) => _onTap(),
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _GamePainter(
                playerX: _playerX,
                playerY: _playerY,
                playerSize: _playerSize,
                groundY: _groundY,
                obstacles: _obstacles,
                state: _state,
                score: _score.floor(),
                best: _best,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _Obstacle {
  double x;
  final double height;
  final double width;
  _Obstacle({required this.x, required this.height, required this.width});
}

class _GamePainter extends CustomPainter {
  final double playerX, playerY, playerSize, groundY;
  final List<_Obstacle> obstacles;
  final GameState state;
  final int score, best;

  _GamePainter({
    required this.playerX,
    required this.playerY,
    required this.playerSize,
    required this.groundY,
    required this.obstacles,
    required this.state,
    required this.score,
    required this.best,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF070B1A));
    _drawStars(canvas, size);
    _drawGround(canvas, size);
    _drawObstacles(canvas);
    _drawPlayer(canvas);
    _drawHud(canvas, size);
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint();
    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * (groundY - 10);
      final r = 0.7 + rng.nextDouble() * 1.5;
      paint.color = Colors.white.withOpacity(0.25 + rng.nextDouble() * 0.55);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = const Color(0xFF0F1830),
    );

    final glow = Paint()
      ..color = const Color(0xFF5AE5FF).withOpacity(0.35)
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), glow);

    final line = Paint()
      ..color = const Color(0xFF5AE5FF)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), line);
  }

  void _drawObstacles(Canvas canvas) {
    for (final o in obstacles) {
      final rect  = Rect.fromLTWH(o.x, groundY - o.height, o.width, o.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFFF5D7E).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFF5D7E));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.x + 3, groundY - o.height + 3, o.width - 6, 6),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withOpacity(0.35),
      );
    }
  }

  void _drawPlayer(Canvas canvas) {
    final rect  = Rect.fromCenter(
      center: Offset(playerX, playerY),
      width: playerSize, height: playerSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF7EF9FF).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF7EF9FF));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          playerX - playerSize / 2 + 5,
          playerY - playerSize / 2 + 5,
          playerSize - 10, 8,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withOpacity(0.5),
    );
  }

  void _drawHud(Canvas canvas, Size size) {
    _paintText(
      canvas, 'Score: $score', const Offset(24, 20),
      const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    );
    _paintText(
      canvas, 'Best: $best', Offset(size.width - 150, 20),
      const TextStyle(color: Color(0xFF7EF9FF), fontSize: 20, fontWeight: FontWeight.bold),
    );

    if (state == GameState.menu) {
      _paintCenter(canvas, size, 'CUBE DASH', 48, const Color(0xFF7EF9FF), -100);
      _paintCenter(canvas, size, 'Tap to jump', 22, Colors.white, 10);
      _paintCenter(canvas, size, 'Avoid the pink blocks', 16, Colors.white54, 50);
      _paintCenter(canvas, size, 'Tap anywhere to start', 16, Colors.white70, 130);
    } else if (state == GameState.over) {
      _paintCenter(canvas, size, 'GAME OVER', 44, const Color(0xFFFF5D7E), -80);
      _paintCenter(canvas, size, 'Score: $score', 28, Colors.white, 0);
      _paintCenter(canvas, size, 'Best: $best',   20, const Color(0xFF7EF9FF), 40);
      _paintCenter(canvas, size, 'Tap to restart', 18, Colors.white70, 110);
    }
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style) {
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout()
      ..paint(canvas, pos);
  }

  void _paintCenter(Canvas canvas, Size size, String text, double fontSize,
      Color color, double offsetY) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 + offsetY));
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}