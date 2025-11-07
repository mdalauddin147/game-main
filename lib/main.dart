import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart'; // ✅ Needed for Ticker

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(),
      child: const FloppyBikeApp(),
    ),
  );
}

class FloppyBikeApp extends StatelessWidget {
  const FloppyBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floppy Bike',
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// GameController: manages game logic and state
class GameController extends ChangeNotifier {
  double screenWidth = 0;
  double screenHeight = 0;

  // Bike
  double bikeX = 100;
  double bikeY = 200;
  double bikeWidth = 60;
  double bikeHeight = 40;
  double velocityY = 0;

  // Physics
  static const double gravity = 900.0;
  static const double flapImpulse = -360.0;

  // Obstacles
  final List<Obstacle> obstacles = [];
  double obstacleSpawnTimer = 0;
  final Random _rand = Random();

  // State
  bool isRunning = false;
  bool isGameOver = false;
  int score = 0;

  // Animation
  double flapPhase = 0;
  static const double maxDt = 1 / 30;

  void startNewGame({required double screenW, required double screenH}) {
    screenWidth = screenW;
    screenHeight = screenH;
    reset();
    isRunning = true;
    isGameOver = false;
    notifyListeners();
  }

  void reset() {
    bikeX = 100;
    bikeY = screenHeight * 0.4;
    velocityY = 0;
    obstacles.clear();
    obstacleSpawnTimer = 0;
    score = 0;
    flapPhase = 0;
    isGameOver = false;
    isRunning = false;
    notifyListeners();
  }

  void flap() {
    if (isGameOver) return;
    velocityY = flapImpulse;
    flapPhase = 1.0;
    notifyListeners();
  }

  void update(double dt) {
    if (!isRunning || isGameOver) return;
    dt = dt.clamp(0, maxDt);

    // Physics
    velocityY += gravity * dt;
    bikeY += velocityY * dt;

    // Animate flap
    flapPhase = max(0, flapPhase - dt * 3.5);

    // Ground collision
    final groundY = screenHeight - 20.0;
    if (bikeY + bikeHeight >= groundY) {
      bikeY = groundY - bikeHeight;
      gameOver();
    }
    if (bikeY < 0) {
      bikeY = 0;
      velocityY = 0;
    }

    // Obstacles update
    obstacleSpawnTimer -= dt;
    if (obstacleSpawnTimer <= 0) {
      spawnObstacle();
      obstacleSpawnTimer = 1.1 + _rand.nextDouble() * 0.9;
    }

    final List<Obstacle> toRemove = [];
    for (final ob in obstacles) {
      ob.x -= ob.speed * dt;

      if (!ob.passed && ob.x + ob.width < bikeX) {
        ob.passed = true;
        score++;
      }

      if (ob.x + ob.width < -50) toRemove.add(ob);

      // Collision
      final bikeRect = Rect.fromLTWH(bikeX, bikeY, bikeWidth, bikeHeight);
      final topRect = Rect.fromLTWH(ob.x, 0, ob.width, ob.gapTop);
      final bottomRect = Rect.fromLTWH(
        ob.x,
        ob.gapBottom,
        ob.width,
        screenHeight - ob.gapBottom,
      );

      if (bikeRect.overlaps(topRect) || bikeRect.overlaps(bottomRect)) {
        gameOver();
      }
    }
    obstacles.removeWhere((o) => toRemove.contains(o));

    // Increase difficulty gradually
    for (final ob in obstacles) {
      ob.speed = (180 + min(130, score * 6)).toDouble();
    }

    notifyListeners();
  }

  void spawnObstacle() {
    final gapSize = max(110.0, 180.0 - min(70, score * 3.0));
    final minTop = 50.0;
    final maxTop = screenHeight - gapSize - 120.0;
    final gapTop = minTop + _rand.nextDouble() * max(1, (maxTop - minTop));
    final gapBottom = gapTop + gapSize;
    final width = 62.0;
    final startX = screenWidth + 30;
    final speed = (180 + min(130, score * 6)).toDouble(); // ✅ fixed
    obstacles.add(
      Obstacle(
        x: startX,
        width: width,
        gapTop: gapTop,
        gapBottom: gapBottom,
        speed: speed,
      ),
    );
  }

  void gameOver() {
    isGameOver = true;
    isRunning = false;
    notifyListeners();
  }

  void restart() {
    reset();
    isRunning = true;
    isGameOver = false;
    notifyListeners();
  }
}

class Obstacle {
  double x;
  final double width;
  final double gapTop;
  final double gapBottom;
  double speed;
  bool passed = false;

  Obstacle({
    required this.x,
    required this.width,
    required this.gapTop,
    required this.gapBottom,
    required this.speed,
  });
}

/// GameScreen: manages input + ticker loop
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final controller = Provider.of<GameController>(context, listen: false);
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    controller.update(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final game = Provider.of<GameController>(context, listen: false);
      if (game.screenWidth == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          game.startNewGame(
            screenW: constraints.maxWidth,
            screenH: constraints.maxHeight,
          );
        });
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final ctrl = Provider.of<GameController>(context, listen: false);
          if (ctrl.isGameOver) {
            ctrl.restart();
            return;
          }
          if (!ctrl.isRunning) {
            ctrl.startNewGame(
              screenW: constraints.maxWidth,
              screenH: constraints.maxHeight,
            );
          }
          ctrl.flap();
        },
        child: Stack(
          children: const [
            GamePainterWidget(),
            HudOverlay(),
          ],
        ),
      );
    });
  }
}

class GamePainterWidget extends StatelessWidget {
  const GamePainterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, game, child) {
        return CustomPaint(
          size: Size(game.screenWidth, game.screenHeight),
          painter: _GamePainter(game),
        );
      },
    );
  }
}

class _GamePainter extends CustomPainter {
  final GameController game;
  _GamePainter(this.game) : super(repaint: game);

  @override
  void paint(Canvas canvas, Size size) {
    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF87CEEB),
    );

    // Ground
    final groundY = size.height - 20.0;
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, 20),
      Paint()..color = const Color(0xFF553311),
    );

    // Obstacles
    final Paint obsPaint = Paint()..color = const Color(0xFF2E7D32);
    final Paint capPaint = Paint()..color = const Color(0xFF1B5E20);
    for (final o in game.obstacles) {
      canvas.drawRect(Rect.fromLTWH(o.x, 0, o.width, o.gapTop), obsPaint);
      canvas.drawRect(
          Rect.fromLTWH(o.x, o.gapBottom, o.width, size.height - o.gapBottom),
          obsPaint);
      canvas.drawRect(Rect.fromLTWH(o.x - 6, o.gapTop - 16, o.width + 12, 16),
          capPaint);
      canvas.drawRect(Rect.fromLTWH(o.x - 6, o.gapBottom, o.width + 12, 16),
          capPaint);
    }

    // Bike
    final bikeRect =
    Rect.fromLTWH(game.bikeX, game.bikeY, game.bikeWidth, game.bikeHeight);
    final bikePaint = Paint()..color = const Color(0xFFFFC107);
    final RRect bikeR = RRect.fromRectAndRadius(bikeRect, const Radius.circular(8));

    canvas.save();
    final center = bikeRect.center;
    final tilt =
        (game.velocityY / 600).clamp(-0.7, 0.7) + (game.flapPhase * -0.15);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawRRect(bikeR, bikePaint);

    // Seat and wheels
    final seat = Rect.fromLTWH(game.bikeX + 8, game.bikeY + 8, 28, 10);
    canvas.drawRRect(
        RRect.fromRectAndRadius(seat, const Radius.circular(4)),
        Paint()..color = Colors.orangeAccent);
    final wheelY = game.bikeY + game.bikeHeight - 6;
    canvas.drawCircle(Offset(game.bikeX + 14, wheelY), 8,
        Paint()..color = Colors.black);
    canvas.drawCircle(Offset(game.bikeX + game.bikeWidth - 12, wheelY), 8,
        Paint()..color = Colors.black);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, game, child) {
        return Positioned.fill(
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'Score: ${game.score}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 3,
                            color: Colors.black54,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!game.isRunning && !game.isGameOver)
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Floppy Bike',
                            style: TextStyle(
                                fontSize: 34, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Tap to flap and avoid obstacles',
                            style: TextStyle(fontSize: 16)),
                        SizedBox(height: 16),
                        Icon(Icons.touch_app, size: 36),
                      ],
                    ),
                  ),
                if (game.isGameOver)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Game Over',
                              style: TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Score: ${game.score}',
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: game.restart,
                            child: const Text('Restart'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      game.isRunning
                          ? 'Tap anywhere to flap'
                          : (game.isGameOver
                          ? 'Tap Restart to try again'
                          : 'Tap to start'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
