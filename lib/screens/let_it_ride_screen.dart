import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glassmorphic_card.dart';

class GameCandle {
  final double open;
  final double close;
  final double high;
  final double low;
  final double x;

  GameCandle({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.x,
  });
}

class GameObstacle {
  final double x;
  final double width;
  final double yTop;
  final double yBottom;
  final bool isCeiling;
  final bool isSpike;

  GameObstacle({
    required this.x,
    required this.width,
    required this.yTop,
    required this.yBottom,
    required this.isCeiling,
    required this.isSpike,
  });
}

class LetItRideScreen extends StatefulWidget {
  const LetItRideScreen({super.key});

  @override
  State<LetItRideScreen> createState() => _LetItRideScreenState();
}

class _LetItRideScreenState extends State<LetItRideScreen> with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  final Random _rng = Random();
  
  // Game state
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isHolding = false;
  bool _isSensorMode = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  
  double _yPos = 0.0;
  double _velocity = 0.0;
  
  // Physics constants
  final double _gravity = 15.0; 
  final double _thrust = -20.0; 
  final double _dampening = 0.95; 
  
  double _scrollOffset = 0.0;
  double _score = 1000.0; 
  double _maxScore = 1000.0;

  double _screenHeight = 0;
  double _screenWidth = 0;

  // Candlestick state
  List<GameCandle> _candles = [];
  double _currentCandleOpen = 0.0;
  double _currentCandleHigh = 0.0;
  double _currentCandleLow = 0.0;
  double _distanceSinceLastCandle = 0.0;
  final double _candleWidth = 8.0;
  final double _candleSpacing = 8.0;

  // Obstacles
  List<GameObstacle> _obstacles = [];
  double _distanceSinceLastObstacle = 0.0;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 365), 
    );
    _gameLoop.addListener(_updateGame);

    _accelSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.game).listen((event) {
      if (!_isPlaying || _isGameOver || !_isSensorMode) return;
      // In portrait mode, Y axis gravity is positive when phone is upright.
      // If Y > 5.0, user is holding phone vertically (tilt up).
      bool holding = event.y > 5.0;
      if (_isHolding != holding) {
        setState(() {
          _isHolding = holding;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gameLoop.dispose();
    super.dispose();
  }

  void _startGame(BoxConstraints constraints) {
    _screenHeight = constraints.maxHeight;
    _screenWidth = constraints.maxWidth;
    
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _yPos = _screenHeight / 2;
      _velocity = 0.0;
      _scrollOffset = 0.0;
      _score = 1000.0;
      if (_maxScore < 1000.0) _maxScore = 1000.0;
      
      _candles.clear();
      _obstacles.clear();
      
      _currentCandleOpen = _yPos;
      _currentCandleHigh = _yPos;
      _currentCandleLow = _yPos;
      _distanceSinceLastCandle = 0.0;
      _distanceSinceLastObstacle = 0.0;
    });
    
    _gameLoop.forward(from: 0);
  }

  void _gameOver() {
    _gameLoop.stop();
    setState(() {
      _isGameOver = true;
      _isPlaying = false;
      _isHolding = false;
    });
    HapticFeedback.heavyImpact();
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;

    if (_isHolding) {
      _velocity += _thrust * 0.016; 
    } else {
      _velocity += _gravity * 0.016;
    }
    
    _velocity *= _dampening;
    _yPos += _velocity;
    
    if (_yPos < 0 || _yPos > _screenHeight) {
      _gameOver();
      return;
    }

    const double speedX = 200.0 * 0.016;
    _scrollOffset += speedX;

    double heightRatio = 1.0 - (_yPos / _screenHeight); 
    double scoreChange = (heightRatio - 0.5) * 10; 
    _score += scoreChange;
    if (_score < 0) _score = 0; 
    if (_score > _maxScore) _maxScore = _score;
    
    if (_score == 0) {
      _gameOver();
      return;
    }

    // --- Candlestick Logic ---
    _distanceSinceLastCandle += speedX;
    
    if (_yPos < _currentCandleHigh) _currentCandleHigh = _yPos; // Y is inverted
    if (_yPos > _currentCandleLow) _currentCandleLow = _yPos;
    
    final double totalCandleSpace = _candleWidth + _candleSpacing;
    if (_distanceSinceLastCandle >= totalCandleSpace) {
      double playerXAbsolute = _screenWidth * 0.3 + _scrollOffset;
      double volatility = 6.0 + _rng.nextDouble() * 18.0;
      _candles.add(GameCandle(
        open: _currentCandleOpen,
        close: _yPos,
        high: _currentCandleHigh - volatility,
        low: _currentCandleLow + volatility,
        x: playerXAbsolute - _distanceSinceLastCandle,
      ));
      
      if (_candles.length > 50) _candles.removeAt(0);
      
      _currentCandleOpen = _yPos;
      _currentCandleHigh = _yPos;
      _currentCandleLow = _yPos;
      _distanceSinceLastCandle -= totalCandleSpace; 
    }

    // --- Obstacle Logic ---
    _distanceSinceLastObstacle += speedX;
    if (_distanceSinceLastObstacle > 200 + _rng.nextDouble() * 250) {
      _distanceSinceLastObstacle = 0.0;
      _spawnObstacle();
    }
    
    _obstacles.removeWhere((o) => (o.x - _scrollOffset + o.width) < 0);
    
    // Check collisions
    final Rect playerRect = Rect.fromCenter(
      center: Offset(_screenWidth * 0.3, _yPos), 
      width: 12, 
      height: 12
    );
    
    for (var o in _obstacles) {
      final double screenX = o.x - _scrollOffset;
      // Shrink hitbox slightly to be fair
      final Rect obsRect = Rect.fromLTRB(screenX + 4, o.yTop, screenX + o.width - 4, o.yBottom);
      
      if (playerRect.overlaps(obsRect)) {
        _gameOver();
        return;
      }
    }

    setState(() {}); 
  }

  void _spawnObstacle() {
    bool isCeiling = _rng.nextBool();
    bool isSpike = _rng.nextDouble() < 0.7;
    
    double height = isSpike 
        ? 100 + _rng.nextDouble() * (_screenHeight * 0.45) 
        : 80 + _rng.nextDouble() * (_screenHeight * 0.4); 
    double width = isSpike ? (60 + _rng.nextDouble() * 40) : (40 + _rng.nextDouble() * 60);
    double spawnX = _screenWidth + _scrollOffset + 50; 
    
    if (isCeiling) {
      _obstacles.add(GameObstacle(
        x: spawnX,
        width: width,
        yTop: 0,
        yBottom: height,
        isCeiling: true,
        isSpike: isSpike,
      ));
    } else {
      _obstacles.add(GameObstacle(
        x: spawnX,
        width: width,
        yTop: _screenHeight - height,
        yBottom: _screenHeight,
        isCeiling: false,
        isSpike: isSpike,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTapDown: (_) {
                if (_isSensorMode) return;
                if (_isPlaying && !_isGameOver) {
                  _isHolding = true;
                  HapticFeedback.selectionClick();
                }
              },
              onTapUp: (_) {
                if (!_isSensorMode) _isHolding = false;
              },
              onTapCancel: () {
                if (!_isSensorMode) _isHolding = false;
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    color: Colors.transparent,
                    child: _isPlaying || _isGameOver
                        ? CustomPaint(
                            painter: _ChartPainter(
                              candles: _candles,
                              obstacles: _obstacles,
                              currentCandleOpen: _currentCandleOpen,
                              currentCandleHigh: _currentCandleHigh,
                              currentCandleLow: _currentCandleLow,
                              distanceSinceLastCandle: _distanceSinceLastCandle,
                              scrollOffset: _scrollOffset,
                              playerX: constraints.maxWidth * 0.3,
                              playerY: _yPos,
                              isGameOver: _isGameOver,
                              isHolding: _isHolding,
                            ),
                          )
                        : const Center(),
                  );
                },
              ),
            ),
            
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Let It Ride 🚀',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Hold to pump, release to dump',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PORTFOLIO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '\$${_score.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _score >= 1000 ? AppColors.buyGreen : AppColors.sellRed,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            if (!_isPlaying)
              Center(
                child: SizedBox(
                  width: 300,
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isGameOver ? 'MARGIN CALL 📉' : 'READY TO RIDE?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _isGameOver ? AppColors.sellRed : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isGameOver 
                              ? 'Max Portfolio: \$${_maxScore.toStringAsFixed(2)}'
                              : 'Hold the screen (or tilt your phone up in Sensor Mode) to make the stock go up.\nRelease/tilt down to let it drop.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSensorMode ? Icons.screen_rotation_rounded : Icons.touch_app_rounded,
                              size: 16,
                              color: _isSensorMode ? AppColors.buyGreen : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sensor Controls',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isSensorMode ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isSensorMode,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _isSensorMode = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              final renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                _startGame(BoxConstraints(
                                  maxWidth: renderBox.size.width,
                                  maxHeight: renderBox.size.height,
                                ));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isGameOver ? 'TRADE AGAIN' : 'START TRADING',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<GameCandle> candles;
  final List<GameObstacle> obstacles;
  final double currentCandleOpen;
  final double currentCandleHigh;
  final double currentCandleLow;
  final double distanceSinceLastCandle;
  final double scrollOffset;
  final double playerX;
  final double playerY;
  final bool isGameOver;
  final bool isHolding;

  _ChartPainter({
    required this.candles,
    required this.obstacles,
    required this.currentCandleOpen,
    required this.currentCandleHigh,
    required this.currentCandleLow,
    required this.distanceSinceLastCandle,
    required this.scrollOffset,
    required this.playerX,
    required this.playerY,
    required this.isGameOver,
    required this.isHolding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw obstacles
    for (var o in obstacles) {
      final screenX = o.x - scrollOffset;
      final rect = Rect.fromLTRB(screenX, o.yTop, screenX + o.width, o.yBottom);
      
      final paint = Paint()
        ..color = AppColors.surfaceLight
        ..style = PaintingStyle.fill;
        
      final borderPaint = Paint()
        ..color = o.isCeiling ? AppColors.sellRed.withValues(alpha: 0.5) : AppColors.buyGreen.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
        
      if (o.isSpike) {
        final path = Path();
        if (o.isCeiling) {
          path.moveTo(screenX, o.yTop);
          path.lineTo(screenX + o.width, o.yTop);
          path.lineTo(screenX + o.width / 2, o.yBottom);
        } else {
          path.moveTo(screenX, o.yBottom);
          path.lineTo(screenX + o.width, o.yBottom);
          path.lineTo(screenX + o.width / 2, o.yTop);
        }
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, borderPaint);
      } else {
        canvas.drawRect(rect, paint);
        canvas.drawRect(rect, borderPaint);
        // Draw grid lines inside tower for techy look
        for (double dy = rect.top + 20; dy < rect.bottom; dy += 20) {
          canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), Paint()..color = borderPaint.color.withValues(alpha: 0.2));
        }
      }
    }

     // Draw previous candles
    for (var c in candles) {
      final screenX = c.x - scrollOffset;
      if (screenX > -20 && screenX < size.width) {
        _drawCandle(canvas, screenX, c.open, c.close, c.high, c.low);
      }
    }
    
    // Draw current forming candle (it moves left as distanceSinceLastCandle grows)
    final double currentCandleScreenX = playerX - distanceSinceLastCandle;
    _drawCandle(canvas, currentCandleScreenX, currentCandleOpen, playerY, currentCandleHigh, currentCandleLow);

    // Draw trailing line connecting the candle bases
    if (candles.isNotEmpty) {
      final linePath = Path();
      bool first = true;
      for (var c in candles) {
        final screenX = c.x - scrollOffset;
        if (screenX > -100 && screenX < size.width + 100) {
          final double lineY = c.open; 
          if (first) {
            linePath.moveTo(screenX, lineY);
            first = false;
          } else {
            linePath.lineTo(screenX, lineY);
          }
        }
      }
      if (!first) {
        linePath.lineTo(currentCandleScreenX, currentCandleOpen);
        linePath.lineTo(playerX, playerY);
      }
      
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.5;
        
      canvas.drawPath(linePath, linePaint);
    }

    // Draw the "Player" (the current price cursor)
    final cursorPaint = Paint()
      ..color = isGameOver ? Colors.grey : (isHolding ? AppColors.buyGreen : AppColors.sellRed)
      ..style = PaintingStyle.fill;
      
    // Draw cursor arrow 
    final path = Path();
    path.moveTo(playerX + 12, playerY);
    path.lineTo(playerX - 6, playerY - 8);
    path.lineTo(playerX - 2, playerY);
    path.lineTo(playerX - 6, playerY + 8);
    path.close();
    
    canvas.drawPath(path, cursorPaint);
    canvas.drawPath(
      path, 
      Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth=2
    );
    
    // Glow effect
    if (!isGameOver) {
      canvas.drawCircle(
        Offset(playerX, playerY), 
        15, 
        Paint()..color = cursorPaint.color.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      );
    }
  }

  void _drawCandle(Canvas canvas, double x, double open, double close, double high, double low) {
    final bool isBullish = close <= open; // Y is inverted
    final Color color = isBullish ? AppColors.buyGreen : AppColors.sellRed;
    final Paint paint = Paint()..color = color;
    
    double rawBodyHeight = (open - close).abs();
    double bodyHeight = rawBodyHeight.clamp(2.0, 24.0); // max 24 pixels
    
    // Base is at 'open'. Green grows UP (smaller Y), Red grows DOWN (larger Y).
    double topY = isBullish ? open - bodyHeight : open;
    double bottomY = isBullish ? open : open + bodyHeight;

    // Wick only protrudes in the direction of the movement with a stable length
    double extraWick = 4.0; 
    double wickTop = isBullish ? topY - extraWick : topY;
    double wickBottom = isBullish ? bottomY : bottomY + extraWick;

    // Draw Wick
    canvas.drawLine(
      Offset(x, wickTop), 
      Offset(x, wickBottom), 
      paint..strokeWidth = 2
    );
    
    // Draw Body
    final Rect bodyRect = Rect.fromLTRB(x - 4, topY, x + 4, bottomY);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(2)), 
      paint..style = PaintingStyle.fill
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return true; 
  }
}
