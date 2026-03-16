import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyGameApp());
}

class MyGameApp extends StatelessWidget {
  const MyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Star Fighter',
      debugShowCheckedModeBanner: false,
      home: GameWidget(game: MyGame()),
    );
  }
}

enum GameState { menu, playing, paused, gameOver }

class MyGame extends FlameGame with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  late Player player;
  late ScoreComponent score;
  late EnemySpawner spawner;
  late CollectibleSpawner collectibleSpawner;
  late Background background;
  late BulletSpawner bulletSpawner;
  late EffectsManager effectsManager;
  GameState gameState = GameState.menu;
  int difficultyLevel = 1;
  double gameTime = 0;
  double screenShake = 0;
  final Set<LogicalKeyboardKey> keysPressed = {};
  double lastShootTime = 0;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    background = Background();
    player = Player();
    score = ScoreComponent();
    spawner = EnemySpawner();
    collectibleSpawner = CollectibleSpawner();
    bulletSpawner = BulletSpawner();
    effectsManager = EffectsManager();
    
    await add(background);
    await add(effectsManager);
    await add(score);
    await add(player);
    await add(spawner);
    await add(collectibleSpawner);
    await add(bulletSpawner);
    await add(ScreenHitbox());
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      player.position = Vector2(size.x / 2, size.y - 80);
    }
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == GameState.menu) {
      startGame();
    } else if (gameState == GameState.gameOver) {
      restart();
    } else if (gameState == GameState.playing) {
      player.setTarget(event.localPosition);
      player.shoot();
    }
  }
  
  @override
  KeyEventResult handleKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      this.keysPressed.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      this.keysPressed.remove(event.logicalKey);
    }
    
    if (gameState == GameState.menu || gameState == GameState.gameOver) {
      if (keysPressed.contains(LogicalKeyboardKey.space) || keysPressed.contains(LogicalKeyboardKey.enter)) {
        if (gameState == GameState.menu) {
          startGame();
        } else if (gameState == GameState.gameOver) {
          restart();
        }
      }
      return KeyEventResult.handled;
    }
    
    if (gameState == GameState.playing) {
      if (keysPressed.contains(LogicalKeyboardKey.space)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastShootTime > 150) {
          player.shoot();
          lastShootTime = now.toDouble();
        }
      }
    }
    
    return KeyEventResult.handled;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameState == GameState.playing) {
      _handleKeyboardMovement(dt);
      
      gameTime += dt;
      if (gameTime > 10) {
        difficultyLevel++;
        gameTime = 0;
        spawner.increaseDifficulty(difficultyLevel);
        collectibleSpawner.increaseDifficulty(difficultyLevel);
      }
    }
    if (screenShake > 0) {
      screenShake -= dt * 10;
    }
  }
  
  void _handleKeyboardMovement(double dt) {
    const moveSpeed = 400.0;
    bool moved = false;
    
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || keysPressed.contains(LogicalKeyboardKey.keyA)) {
      player.position.x -= moveSpeed * dt;
      moved = true;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || keysPressed.contains(LogicalKeyboardKey.keyD)) {
      player.position.x += moveSpeed * dt;
      moved = true;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp) || keysPressed.contains(LogicalKeyboardKey.keyW)) {
      player.position.y -= moveSpeed * dt;
      moved = true;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown) || keysPressed.contains(LogicalKeyboardKey.keyS)) {
      player.position.y += moveSpeed * dt;
      moved = true;
    }
    
    player.position.x = player.position.x.clamp(player.size.x / 2, size.x - player.size.x / 2);
    player.position.y = player.position.y.clamp(player.size.y / 2, size.y - player.size.y / 2);
    
    if (moved) {
      player.thrustIntensity = min(1.0, player.thrustIntensity + dt * 3);
    } else {
      player.thrustIntensity = max(0.3, player.thrustIntensity - dt * 2);
    }
  }
  
  void startGame() {
    gameState = GameState.playing;
    player.position = Vector2(size.x / 2, size.y - 80);
    player.target = player.position;
    spawner.start();
    collectibleSpawner.start();
    bulletSpawner.start();
  }
  
  void playShootSound() {
    try {
      FlameAudio.play('shoot.mp3', volume: 0.3);
    } catch (_) {}
  }
  
  void playCollectSound() {
    try {
      FlameAudio.play('collect.mp3', volume: 0.5);
    } catch (_) {}
  }
  
  void playExplosionSound() {
    try {
      FlameAudio.play('explosion.mp3', volume: 0.6);
    } catch (_) {}
  }
  
  void playGameOverSound() {
    try {
      FlameAudio.play('gameover.mp3', volume: 0.7);
    } catch (_) {}
  }
  
  void playPowerUpSound() {
    try {
      FlameAudio.play('powerup.mp3', volume: 0.6);
    } catch (_) {}
  }
  
  void triggerScreenShake(double intensity) {
    screenShake = intensity;
  }
  
  void showExplosion(Vector2 position, {bool isBig = false}) {
    screenShake = isBig ? 15 : 8;
    for (int i = 0; i < (isBig ? 40 : 20); i++) {
      add(ExplosionParticle(position: position, isBig: isBig));
    }
    for (int i = 0; i < (isBig ? 15 : 8); i++) {
      add(SmokeParticle(position: position));
    }
  }
  
  void showParticles(Vector2 position, Color color) {
    for (int i = 0; i < 10; i++) {
      add(GameParticle(position: position, color: color));
    }
  }
  
  void gameOver() {
    gameState = GameState.gameOver;
    spawner.stop();
    collectibleSpawner.stop();
    bulletSpawner.stop();
    playGameOverSound();
  }
  
  void restart() {
    gameState = GameState.playing;
    difficultyLevel = 1;
    gameTime = 0;
    score.reset();
    player.reset();
    spawner.resetDifficulty();
    collectibleSpawner.resetDifficulty();
    children.whereType<Enemy>().forEach((e) => e.removeFromParent());
    children.whereType<Collectible>().forEach((c) => c.removeFromParent());
    children.whereType<PowerUp>().forEach((p) => p.removeFromParent());
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    spawner.start();
    collectibleSpawner.start();
    bulletSpawner.start();
  }
}

class EffectsManager extends Component with HasGameReference<MyGame> {
  @override
  void render(Canvas canvas) {
    if (game.screenShake > 0) {
      final shakeX = (Random().nextDouble() - 0.5) * game.screenShake;
      final shakeY = (Random().nextDouble() - 0.5) * game.screenShake;
      canvas.translate(shakeX, shakeY);
    }
  }
}

class Background extends Component with HasGameReference<MyGame> {
  final Random _random = Random();
  final List<Star> stars = [];
  final List<Nebula> nebulae = [];
  final List<Cloud> clouds = [];
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < 150; i++) {
      stars.add(Star(
        position: Vector2(_random.nextDouble() * 1200, _random.nextDouble() * 1200),
        size: 0.5 + _random.nextDouble() * 2.5,
        brightness: 0.3 + _random.nextDouble() * 0.7,
        twinkleSpeed: 0.5 + _random.nextDouble() * 2,
        twinkleOffset: _random.nextDouble() * pi * 2,
      ));
    }
    for (int i = 0; i < 8; i++) {
      nebulae.add(Nebula(
        position: Vector2(_random.nextDouble() * 800, _random.nextDouble() * 600),
        size: 100 + _random.nextDouble() * 250,
        color: Color.fromRGBO(
          80 + _random.nextInt(120),
          30 + _random.nextInt(80),
          120 + _random.nextInt(130),
          0.08,
        ),
      ));
    }
    for (int i = 0; i < 5; i++) {
      clouds.add(Cloud(
        position: Vector2(_random.nextDouble() * 800, _random.nextDouble() * 600),
        size: 80 + _random.nextDouble() * 100,
        speed: 10 + _random.nextDouble() * 20,
      ));
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState == GameState.playing) {
      for (final star in stars) {
        star.position.y += star.speed * dt;
        if (star.position.y > game.size.y) {
          star.position.y = 0;
          star.position.x = _random.nextDouble() * game.size.x;
        }
      }
      for (final cloud in clouds) {
        cloud.position.y += cloud.speed * dt;
        if (cloud.position.y > game.size.y + cloud.size) {
          cloud.position.y = -cloud.size;
          cloud.position.x = _random.nextDouble() * game.size.x;
        }
      }
    }
  }
  
  @override
  void render(Canvas canvas) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF000022),
        const Color(0xFF0a0a2e),
        const Color(0xFF150a35),
        const Color(0xFF000018),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, game.size.x, game.size.y),
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, game.size.x, game.size.y)),
    );
    
    for (final nebula in nebulae) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [nebula.color, nebula.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: nebula.position.toOffset(), radius: nebula.size));
      canvas.drawCircle(nebula.position.toOffset(), nebula.size, paint);
    }
    
    for (final cloud in clouds) {
      final cloudPaint = Paint()
        ..color = const Color(0xFF1a1a3a).withValues(alpha: 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: cloud.position.toOffset(), width: cloud.size * 2, height: cloud.size),
        cloudPaint,
      );
    }
    
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final star in stars) {
      final twinkle = sin(time * star.twinkleSpeed + star.twinkleOffset) * 0.3 + 0.7;
      canvas.drawCircle(
        star.position.toOffset(),
        star.size,
        Paint()..color = Colors.white.withValues(alpha: star.brightness * twinkle),
      );
    }
  }
}

class Star {
  Vector2 position;
  double size;
  double brightness;
  double speed = 15 + Random().nextDouble() * 35;
  double twinkleSpeed;
  double twinkleOffset;
  Star({required this.position, required this.size, required this.brightness, required this.twinkleSpeed, required this.twinkleOffset});
}

class Nebula {
  Vector2 position;
  double size;
  Color color;
  Nebula({required this.position, required this.size, required this.color});
}

class Cloud {
  Vector2 position;
  double size;
  double speed;
  Cloud({required this.position, required this.size, required this.speed});
}

class Player extends PositionComponent with HasGameReference<MyGame>, CollisionCallbacks {
  static const double speed = 350;
  Vector2 target = Vector2.zero();
  bool isInvincible = false;
  double invincibilityTimer = 0;
  bool isShielded = false;
  double shootCooldown = 0;
  bool isTripleShot = false;
  double tripleShotTimer = 0;
  double thrustIntensity = 0;
  
  Player() : super(
    size: Vector2(80, 50),
    anchor: Anchor.center,
    position: Vector2(200, 500),
  ) {
    add(RectangleHitbox(size: Vector2(60, 30)));
  }
  
  void setTarget(Vector2 newTarget) {
    target = newTarget;
  }
  
  void shoot() {
    if (game.gameState != GameState.playing) return;
    if (shootCooldown > 0) return;
    
    shootCooldown = 0.15;
    game.playShootSound();
    
    if (isTripleShot) {
      game.add(Bullet(Vector2(position.x, position.y - 20), Vector2(0, -650)));
      game.add(Bullet(Vector2(position.x - 15, position.y - 10), Vector2(-50, -620)));
      game.add(Bullet(Vector2(position.x + 15, position.y - 10), Vector2(50, -620)));
    } else {
      game.add(Bullet(Vector2(position.x, position.y - 20), Vector2(0, -650)));
    }
  }
  
  void activateShield(double duration) {
    isShielded = true;
    isInvincible = true;
    invincibilityTimer = duration;
  }
  
  void activateTripleShot(double duration) {
    isTripleShot = true;
    tripleShotTimer = duration;
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (game.gameState != GameState.playing) return;
    
    if (other is Enemy) {
      if (!isInvincible) {
        if (isShielded) {
          other.removeFromParent();
          game.score.addScore(5);
          game.showExplosion(other.position.clone());
          isShielded = false;
        } else {
          game.showExplosion(position.clone(), isBig: true);
          game.gameOver();
        }
      }
    } else if (other is Collectible) {
      other.removeFromParent();
      game.score.addScore(10);
      game.playCollectSound();
      game.showParticles(other.position.clone(), Colors.green);
    } else if (other is PowerUp) {
      other.applyEffect(game);
      other.removeFromParent();
      game.playPowerUpSound();
      game.showParticles(other.position.clone(), Colors.yellow);
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    if (shootCooldown > 0) shootCooldown -= dt;
    if (isInvincible) {
      invincibilityTimer -= dt;
      if (invincibilityTimer <= 0) {
        isInvincible = false;
      }
    }
    if (isTripleShot) {
      tripleShotTimer -= dt;
      if (tripleShotTimer <= 0) {
        isTripleShot = false;
      }
    }
    
    final diff = target - position;
    if (diff.length > 5) {
      final dir = diff.normalized();
      position += dir * speed * dt;
      thrustIntensity = min(1.0, thrustIntensity + dt * 3);
    } else {
      thrustIntensity = max(0.3, thrustIntensity - dt * 2);
    }
    
    game.add(EngineExhaust(position: Vector2(position.x - 10, position.y + 25), intensity: thrustIntensity));
    game.add(EngineExhaust(position: Vector2(position.x + 10, position.y + 25), intensity: thrustIntensity));
    
    final gameSize = game.size;
    position.x = position.x.clamp(size.x / 2, gameSize.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, gameSize.y - size.y / 2);
  }
  
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    
    final bodyPaint = Paint()..color = const Color(0xFF2C3E50);
    final cockpitPaint = Paint()..color = const Color(0xFF5DADE2);
    final wingPaint = Paint()..color = const Color(0xFF34495E);
    final enginePaint = Paint()..color = const Color(0xFF7F8C8D);
    final accentPaint = Paint()..color = const Color(0xFF3498DB);
    
    canvas.drawPath(
      Path()..moveTo(0, -28)
            ..lineTo(10, -18)
            ..lineTo(10, 0)
            ..lineTo(38, 18)
            ..lineTo(38, 24)
            ..lineTo(10, 24)
            ..lineTo(10, 30)
            ..lineTo(-10, 30)
            ..lineTo(-10, 24)
            ..lineTo(-38, 24)
            ..lineTo(-38, 18)
            ..lineTo(-10, 0)
            ..lineTo(-10, -18)
            ..close(),
      bodyPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, -18)
            ..lineTo(6, -10)
            ..lineTo(0, -2)
            ..lineTo(-6, -10)
            ..close(),
      cockpitPaint,
    );
    
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, -25), const Offset(0, -5), highlightPaint);
    
    canvas.drawPath(
      Path()..moveTo(-10, 8)
            ..lineTo(-32, 20)
            ..lineTo(-28, 25)
            ..lineTo(-10, 14)
            ..close(),
      wingPaint,
    );
    canvas.drawPath(
      Path()..moveTo(10, 8)
            ..lineTo(32, 20)
            ..lineTo(28, 25)
            ..lineTo(10, 14)
            ..close(),
      wingPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(-18, 25)
            ..lineTo(-18, 32)
            ..lineTo(-10, 32)
            ..lineTo(-10, 25)
            ..close(),
      enginePaint,
    );
    canvas.drawPath(
      Path()..moveTo(18, 25)
            ..lineTo(18, 32)
            ..lineTo(10, 32)
            ..lineTo(10, 25)
            ..close(),
      enginePaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, -28)
            ..lineTo(4, -22)
            ..lineTo(0, -20)
            ..lineTo(-4, -22)
            ..close(),
      accentPaint,
    );
    
    if (isShielded) {
      final shieldPaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      final shieldStrokePaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 75, height: 55), shieldPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 75, height: 55), shieldStrokePaint);
    }
    
    if (isInvincible && !isShielded) {
      final alpha = 0.3 + 0.4 * sin(DateTime.now().millisecondsSinceEpoch / 100);
      final glowPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset.zero, 35, glowPaint);
    }
    
    canvas.restore();
  }
  
  void reset() {
    position = Vector2(game.size.x / 2, game.size.y - 80);
    target = position;
    isInvincible = false;
    isShielded = false;
    isTripleShot = false;
    invincibilityTimer = 0;
    tripleShotTimer = 0;
    shootCooldown = 0;
    thrustIntensity = 0.3;
  }
}

class EngineExhaust extends CircleComponent with HasGameReference<MyGame> {
  double lifetime = 0.3;
  double age = 0;
  double intensity;
  
  EngineExhaust({required Vector2 position, required this.intensity}) : super(
    position: position,
    radius: 3 + intensity * 4,
    paint: Paint()..color = Color.lerp(Colors.orange, Colors.yellow, intensity)!,
    anchor: Anchor.center,
  ) {
    lifetime = 0.2 + intensity * 0.15;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState != GameState.playing) return;
    
    age += dt;
    radius *= 1.08;
    paint.color = Color.lerp(Colors.orange, Colors.red, age / lifetime)!.withValues(alpha: 1 - age / lifetime);
    
    if (age >= lifetime) {
      removeFromParent();
    }
  }
}

class Bullet extends PositionComponent with HasGameReference<MyGame>, CollisionCallbacks {
  late Vector2 velocity;
  final List<Vector2> trail = [];
  
  Bullet(Vector2 position, this.velocity) : super(
    position: position,
    size: Vector2(6, 20),
    anchor: Anchor.center,
  ) {
    add(RectangleHitbox(size: Vector2(4, 16)));
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    trail.add(position.clone());
    if (trail.length > 8) trail.removeAt(0);
    position += velocity * dt;
    
    if (position.y < -20 || position.x < -20 || position.x > game.size.x + 20) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    for (int i = 0; i < trail.length; i++) {
      final alpha = i / trail.length * 0.5;
      final trailRadius = 2.0 + (i / trail.length) * 2;
      canvas.drawCircle(
        trail[i].toOffset(),
        trailRadius,
        Paint()..color = Colors.orange.withValues(alpha: alpha),
      );
    }
    
    final gradient = RadialGradient(
      colors: [Colors.white, Colors.yellow, Colors.orange],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 5, height: 20),
        const Radius.circular(2.5),
      ),
      Paint()..shader = gradient.createShader(Rect.fromCenter(center: Offset.zero, width: 5, height: 20)),
    );
    
    final glowPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 24),
        const Radius.circular(4),
      ),
      glowPaint,
    );
  }
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Enemy) {
      other.removeFromParent();
      removeFromParent();
      game.score.addScore(20);
      game.playExplosionSound();
      game.showExplosion(other.position.clone());
    }
  }
}

class BulletSpawner extends Component with HasGameReference<MyGame> {
  void start() {}
  void stop() {}
}

class Enemy extends PositionComponent with HasGameReference<MyGame> {
  late double speed;
  bool isDestroyed = false;
  double wobble = 0;
  double wobbleSpeed;
  
  Enemy(Vector2 position, this.speed, {this.wobbleSpeed = 1.0}) : super(
    position: position,
    size: Vector2(50, 50),
    anchor: Anchor.center,
  );
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position.y += speed * dt;
    wobble += dt * wobbleSpeed;
    position.x += sin(wobble) * 0.8;
    
    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    
    final bodyPaint = Paint()..color = const Color(0xFF8B0000);
    final cockpitPaint = Paint()..color = const Color(0xFFFF4500);
    final wingPaint = Paint()..color = const Color(0xFF5C0000);
    final glowPaint = Paint()..color = const Color(0xFFFF6600);
    
    canvas.drawPath(
      Path()..moveTo(0, 22)
            ..lineTo(8, 12)
            ..lineTo(8, 0)
            ..lineTo(30, -14)
            ..lineTo(30, -20)
            ..lineTo(8, -10)
            ..lineTo(8, -22)
            ..lineTo(-8, -22)
            ..lineTo(-8, -10)
            ..lineTo(-30, -20)
            ..lineTo(-30, -14)
            ..lineTo(-8, 0)
            ..lineTo(-8, 12)
            ..close(),
      bodyPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, 10)
            ..lineTo(5, 3)
            ..lineTo(0, -2)
            ..lineTo(-5, 3)
            ..close(),
      cockpitPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(-8, 8)
            ..lineTo(-28, 20)
            ..lineTo(-22, 24)
            ..lineTo(-8, 14)
            ..close(),
      wingPaint,
    );
    canvas.drawPath(
      Path()..moveTo(8, 8)
            ..lineTo(28, 20)
            ..lineTo(22, 24)
            ..lineTo(8, 14)
            ..close(),
      wingPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(-12, 18)
            ..lineTo(-12, 24)
            ..lineTo(-6, 24)
            ..lineTo(-6, 18)
            ..close(),
      glowPaint,
    );
    canvas.drawPath(
      Path()..moveTo(12, 18)
            ..lineTo(12, 24)
            ..lineTo(6, 24)
            ..lineTo(6, 18)
            ..close(),
      glowPaint,
    );
    
    canvas.restore();
  }
}

class Collectible extends CircleComponent with HasGameReference<MyGame> {
  Collectible(Vector2 position, double speed) : super(
    radius: 15,
    position: position,
    paint: Paint()..color = Colors.green,
    anchor: Anchor.center,
  ) {
    add(CircleHitbox());
    this.speed = speed;
  }
  
  late double speed;
  double rotation = 0;
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position.y += speed * dt;
    rotation += dt * 3;
    
    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(rotation);
    
    final glowPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, radius + 4, glowPaint);
    
    final gradient = RadialGradient(
      colors: [Colors.lightGreen, Colors.green, Color(0xFF006400)],
    );
    canvas.drawCircle(Offset.zero, radius, Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset.zero, radius: radius)));
    
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * pi / 180;
      final outerX = cos(angle) * radius * 0.7;
      final outerY = sin(angle) * radius * 0.7;
      final innerAngle = ((i * 72 + 36) - 90) * pi / 180;
      final innerX = cos(innerAngle) * radius * 0.3;
      final innerY = sin(innerAngle) * radius * 0.3;
      if (i == 0) {
        starPath.moveTo(outerX, outerY);
      } else {
        starPath.lineTo(outerX, outerY);
      }
      starPath.lineTo(innerX, innerY);
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = Colors.white);
    
    canvas.restore();
  }
}

enum PowerUpType { shield, points, triple, slow }
extension PowerUpTypeExt on PowerUpType {
  Color get color {
    switch (this) {
      case PowerUpType.shield:
        return Colors.cyan;
      case PowerUpType.points:
        return Colors.yellow;
      case PowerUpType.triple:
        return Colors.orange;
      case PowerUpType.slow:
        return Colors.purple;
    }
  }
  
  String get label {
    switch (this) {
      case PowerUpType.shield:
        return '🛡';
      case PowerUpType.points:
        return '⭐';
      case PowerUpType.triple:
        return '🔥';
      case PowerUpType.slow:
        return '❄';
    }
  }
}

class PowerUp extends CircleComponent with HasGameReference<MyGame> {
  final PowerUpType type;
  double rotation = 0;
  
  PowerUp(Vector2 position, this.type) : super(
    radius: 22,
    position: position,
    paint: Paint()..color = type.color,
    anchor: Anchor.center,
  ) {
    add(CircleHitbox());
  }
  
  void applyEffect(MyGame game) {
    switch (type) {
      case PowerUpType.shield:
        game.player.activateShield(5.0);
        break;
      case PowerUpType.points:
        game.score.addScore(50);
        break;
      case PowerUpType.triple:
        game.player.activateTripleShot(8.0);
        break;
      case PowerUpType.slow:
        game.spawner.slowDown(3.0);
        break;
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position.y += 80 * dt;
    rotation += dt * 2;
    
    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(rotation);
    
    final glowPaint = Paint()
      ..color = type.color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, radius + 6, glowPaint);
    
    final gradient = RadialGradient(
      colors: [type.color.withValues(alpha: 0.8), type.color],
    );
    canvas.drawCircle(Offset.zero, radius, Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset.zero, radius: radius)));
    
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, radius, borderPaint);
    
    canvas.restore();
  }
}

class ExplosionParticle extends CircleComponent with HasGameReference<MyGame> {
  final Random random = Random();
  late Vector2 velocity;
  double lifetime = 0.6;
  double age = 0;
  bool isBig;
  
  ExplosionParticle({required Vector2 position, this.isBig = false}) : super(
    radius: isBig ? 5.0 : 3.0,
    position: position,
    paint: Paint()..color = Colors.orange,
    anchor: Anchor.center,
  ) {
    final angle = random.nextDouble() * 2 * pi;
    final speed = (isBig ? 150 : 100) + random.nextDouble() * (isBig ? 250 : 200);
    velocity = Vector2(cos(angle) * speed, sin(angle) * speed);
    lifetime = isBig ? 0.8 : 0.5;
    radius = (isBig ? 4 : 2) + random.nextDouble() * (isBig ? 6 : 4);
    paint.color = Color.lerp(Colors.orange, Colors.red, random.nextDouble())!;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position += velocity * dt;
    velocity *= 0.94;
    age += dt;
    
    paint.color = Color.lerp(
      Color.lerp(Colors.orange, Colors.red, age / lifetime)!,
      Colors.black,
      age / lifetime,
    )!.withValues(alpha: 1 - age / lifetime);
    
    if (age >= lifetime) {
      removeFromParent();
    }
  }
}

class SmokeParticle extends CircleComponent with HasGameReference<MyGame> {
  final Random random = Random();
  late Vector2 velocity;
  double lifetime = 0.8;
  double age = 0;
  
  SmokeParticle({required Vector2 position}) : super(
    radius: 2,
    position: position,
    paint: Paint()..color = Colors.grey.withValues(alpha: 0.5),
    anchor: Anchor.center,
  ) {
    final angle = random.nextDouble() * 2 * pi;
    final speed = 20 + random.nextDouble() * 40;
    velocity = Vector2(cos(angle) * speed, sin(angle) * speed - 20);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position += velocity * dt;
    velocity *= 0.98;
    age += dt;
    radius += dt * 15;
    paint.color = Colors.grey.withValues(alpha: max(0, 0.5 - age / lifetime));
    
    if (age >= lifetime) {
      removeFromParent();
    }
  }
}

class GameParticle extends CircleComponent with HasGameReference<MyGame> {
  final Random random = Random();
  late Vector2 velocity;
  double lifetime = 0.5;
  double age = 0;
  
  GameParticle({required Vector2 position, required Color color}) : super(
    radius: 3,
    position: position,
    paint: Paint()..color = color,
    anchor: Anchor.center,
  ) {
    final angle = random.nextDouble() * 2 * pi;
    final speed = 50 + random.nextDouble() * 100;
    velocity = Vector2(cos(angle) * speed, sin(angle) * speed);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position += velocity * dt;
    age += dt;
    
    if (age >= lifetime) {
      removeFromParent();
    }
  }
}

class EnemySpawner extends Component with HasGameReference<MyGame> {
  final Random _random = Random();
  double _timer = 0;
  final double _baseInterval = 1.2;
  double _interval = 1.2;
  final double _baseEnemySpeed = 180;
  double _enemySpeed = 180;
  double _slowTimer = 0;
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    if (_slowTimer > 0) {
      _slowTimer -= dt;
    }
    
    _timer += dt;
    if (_timer >= _interval) {
      _timer = 0;
      spawnEnemy();
    }
  }
  
  void spawnEnemy() {
    final gameWidth = game.size.x;
    final x = _random.nextDouble() * (gameWidth - 60) + 30;
    final speed = _slowTimer > 0 ? _enemySpeed * 0.5 : _enemySpeed;
    final wobbleSpeed = 0.5 + _random.nextDouble() * 1.5;
    game.add(Enemy(Vector2(x, -30), speed, wobbleSpeed: wobbleSpeed));
  }
  
  void increaseDifficulty(int level) {
    _interval = (_baseInterval * (1 - (level - 1) * 0.08)).clamp(0.4, 1.2);
    _enemySpeed = _baseEnemySpeed + (level - 1) * 25;
  }
  
  void slowDown(double duration) {
    _slowTimer = duration;
  }
  
  void resetDifficulty() {
    _interval = _baseInterval;
    _enemySpeed = _baseEnemySpeed;
    _slowTimer = 0;
  }
  
  void start() {
    _timer = 0;
  }
  
  void stop() {
    _timer = 0;
  }
}

class CollectibleSpawner extends Component with HasGameReference<MyGame> {
  final Random _random = Random();
  double _timer = 0;
  double _powerUpTimer = 0;
  final double _baseInterval = 1.5;
  double _interval = 1.5;
  final double _baseSpeed = 120;
  double _speed = 120;
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    _timer += dt;
    if (_timer >= _interval) {
      _timer = 0;
      spawnCollectible();
    }
    
    _powerUpTimer += dt;
    if (_powerUpTimer >= 7.0) {
      _powerUpTimer = 0;
      spawnPowerUp();
    }
  }
  
  void spawnCollectible() {
    final gameWidth = game.size.x;
    final x = _random.nextDouble() * (gameWidth - 40) + 20;
    game.add(Collectible(Vector2(x, -30), _speed));
  }
  
  void spawnPowerUp() {
    final gameWidth = game.size.x;
    final x = _random.nextDouble() * (gameWidth - 40) + 20;
    final types = PowerUpType.values;
    final type = types[_random.nextInt(types.length)];
    game.add(PowerUp(Vector2(x, -30), type));
  }
  
  void increaseDifficulty(int level) {
    _interval = (_baseInterval * (1 - (level - 1) * 0.05)).clamp(0.8, 1.5);
    _speed = _baseSpeed + (level - 1) * 15;
  }
  
  void resetDifficulty() {
    _interval = _baseInterval;
    _speed = _baseSpeed;
    _powerUpTimer = 0;
  }
  
  void start() {
    _timer = 0;
  }
  
  void stop() {
    _timer = 0;
  }
}

class ScoreComponent extends Component with HasGameReference<MyGame> {
  int score = 0;
  int highScore = 0;
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    if (game.gameState == GameState.menu) {
      _drawMenu(canvas);
    } else if (game.gameState == GameState.gameOver) {
      _drawGameOver(canvas);
    } else if (game.gameState == GameState.playing) {
      _drawScore(canvas);
    }
  }
  
  void _drawMenu(Canvas canvas) {
    final titleGradient = LinearGradient(
      colors: [Colors.cyan, Colors.blue, Colors.purple],
    );
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'STAR FIGHTER',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 52,
          fontWeight: FontWeight.bold,
          letterSpacing: 6,
          shadows: [
            Shadow(color: Colors.cyan, blurRadius: 20),
            Shadow(color: Colors.blue, blurRadius: 30),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, Vector2(
      game.size.x / 2 - titlePainter.width / 2,
      game.size.y / 4,
    ).toOffset());
    
    final startPainter = TextPainter(
      text: const TextSpan(
        text: '▶ TAP TO START',
        style: TextStyle(
          color: Colors.cyan,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    startPainter.layout();
    startPainter.paint(canvas, Vector2(
      game.size.x / 2 - startPainter.width / 2,
      game.size.y / 2,
    ).toOffset());
    
    if (highScore > 0) {
      final highScorePainter = TextPainter(
        text: TextSpan(
          text: '★ HIGH SCORE: $highScore',
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      highScorePainter.layout();
      highScorePainter.paint(canvas, Vector2(
        game.size.x / 2 - highScorePainter.width / 2,
        game.size.y / 2 + 55,
      ).toOffset());
    }
  }
  
  void _drawGameOver(Canvas canvas) {
    final gameOverPainter = TextPainter(
      text: const TextSpan(
        text: 'GAME OVER',
        style: TextStyle(
          color: Colors.red,
          fontSize: 56,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.red, blurRadius: 30),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    gameOverPainter.layout();
    gameOverPainter.paint(canvas, Vector2(
      game.size.x / 2 - gameOverPainter.width / 2,
      game.size.y / 3,
    ).toOffset());
    
    final scorePainter = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(canvas, Vector2(
      game.size.x / 2 - scorePainter.width / 2,
      game.size.y / 2,
    ).toOffset());
    
    final highScorePainter = TextPainter(
      text: TextSpan(
        text: '★ HIGH SCORE: $highScore',
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    highScorePainter.layout();
    highScorePainter.paint(canvas, Vector2(
      game.size.x / 2 - highScorePainter.width / 2,
      game.size.y / 2 + 50,
    ).toOffset());
    
    final restartPainter = TextPainter(
      text: const TextSpan(
        text: '▶ TAP TO RESTART',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 22,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    restartPainter.layout();
    restartPainter.paint(canvas, Vector2(
      game.size.x / 2 - restartPainter.width / 2,
      game.size.y / 2 + 110,
    ).toOffset());
  }
  
  void _drawScore(Canvas canvas) {
    final scoreShadow = Paint()..color = Colors.black54;
    final scorePainter = TextPainter(
      text: TextSpan(
        text: '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(canvas, const Offset(20, 20));
    
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'SCORE',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(canvas, const Offset(20, 52));
    
    final levelPainter = TextPainter(
      text: TextSpan(
        text: 'LV ${game.difficultyLevel}',
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    levelPainter.layout();
    levelPainter.paint(canvas, Offset(game.size.x - levelPainter.width - 20, 20));
    
    if (game.player.isShielded) {
      final shieldPainter = TextPainter(
        text: const TextSpan(
          text: '🛡 SHIELD',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      shieldPainter.layout();
      shieldPainter.paint(canvas, Offset(game.size.x - shieldPainter.width - 20, 50));
    }
    
    if (game.player.isTripleShot) {
      final triplePainter = TextPainter(
        text: const TextSpan(
          text: '🔥 TRIPLE',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      triplePainter.layout();
      triplePainter.paint(canvas, Offset(game.size.x - triplePainter.width - 20, 75));
    }
  }
  
  void addScore(int points) {
    score += points;
    if (score > highScore) {
      highScore = score;
    }
  }
  
  void reset() {
    score = 0;
  }
}
