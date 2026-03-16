import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

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

class MyGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  late Player player;
  late ScoreComponent score;
  late EnemySpawner spawner;
  late CollectibleSpawner collectibleSpawner;
  late Background background;
  late BulletSpawner bulletSpawner;
  GameState gameState = GameState.menu;
  int difficultyLevel = 1;
  double gameTime = 0;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    background = Background();
    player = Player();
    score = ScoreComponent();
    spawner = EnemySpawner();
    collectibleSpawner = CollectibleSpawner();
    bulletSpawner = BulletSpawner();
    
    await add(background);
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
  void update(double dt) {
    super.update(dt);
    if (gameState == GameState.playing) {
      gameTime += dt;
      if (gameTime > 10) {
        difficultyLevel++;
        gameTime = 0;
        spawner.increaseDifficulty(difficultyLevel);
        collectibleSpawner.increaseDifficulty(difficultyLevel);
      }
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
  
  void showExplosion(Vector2 position) {
    for (int i = 0; i < 20; i++) {
      add(ExplosionParticle(position: position));
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

class Background extends Component with HasGameReference<MyGame> {
  final Random _random = Random();
  final List<Star> stars = [];
  final List<Nebula> nebulae = [];
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < 100; i++) {
      stars.add(Star(
        position: Vector2(_random.nextDouble() * 1200, _random.nextDouble() * 1200),
        size: 1 + _random.nextDouble() * 2,
        brightness: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
    for (int i = 0; i < 5; i++) {
      nebulae.add(Nebula(
        position: Vector2(_random.nextDouble() * 800, _random.nextDouble() * 600),
        size: 150 + _random.nextDouble() * 200,
        color: Color.fromRGBO(
          100 + _random.nextInt(100),
          50 + _random.nextInt(100),
          150 + _random.nextInt(100),
          0.1,
        ),
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
    }
  }
  
  @override
  void render(Canvas canvas) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF000033),
        const Color(0xFF0a0a2e),
        const Color(0xFF1a0a2e),
        const Color(0xFF000011),
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
    
    for (final star in stars) {
      canvas.drawCircle(
        star.position.toOffset(),
        star.size,
        Paint()..color = Colors.white.withValues(alpha: star.brightness),
      );
    }
  }
}

class Star {
  Vector2 position;
  double size;
  double brightness;
  double speed = 20 + Random().nextDouble() * 40;
  Star({required this.position, required this.size, required this.brightness});
}

class Nebula {
  Vector2 position;
  double size;
  Color color;
  Nebula({required this.position, required this.size, required this.color});
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
      game.add(Bullet(Vector2(position.x, position.y - 20), Vector2(0, -600)));
      game.add(Bullet(Vector2(position.x - 15, position.y - 10), Vector2(-50, -580)));
      game.add(Bullet(Vector2(position.x + 15, position.y - 10), Vector2(50, -580)));
    } else {
      game.add(Bullet(Vector2(position.x, position.y - 20), Vector2(0, -600)));
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
        if (!isShielded) {}
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
    }
    
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
    final enginePaint = Paint()..color = const Color(0xFFE74C3C);
    final glowPaint = Paint()..color = const Color(0xFF3498DB);
    
    canvas.drawPath(
      Path()..moveTo(0, -25)
            ..lineTo(8, -15)
            ..lineTo(8, 0)
            ..lineTo(35, 15)
            ..lineTo(35, 20)
            ..lineTo(8, 20)
            ..lineTo(8, 25)
            ..lineTo(-8, 25)
            ..lineTo(-8, 20)
            ..lineTo(-35, 20)
            ..lineTo(-35, 15)
            ..lineTo(-8, 0)
            ..lineTo(-8, -15)
            ..close(),
      bodyPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, -15)
            ..lineTo(5, -8)
            ..lineTo(0, 0)
            ..lineTo(-5, -8)
            ..close(),
      cockpitPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(-8, 5)
            ..lineTo(-30, 18)
            ..lineTo(-25, 22)
            ..lineTo(-8, 12)
            ..close(),
      wingPaint,
    );
    canvas.drawPath(
      Path()..moveTo(8, 5)
            ..lineTo(30, 18)
            ..lineTo(25, 22)
            ..lineTo(8, 12)
            ..close(),
      wingPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(-15, 22)
            ..lineTo(-15, 28)
            ..lineTo(-8, 28)
            ..lineTo(-8, 22)
            ..close(),
      enginePaint,
    );
    canvas.drawPath(
      Path()..moveTo(15, 22)
            ..lineTo(15, 28)
            ..lineTo(8, 28)
            ..lineTo(8, 22)
            ..close(),
      enginePaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, -25)
            ..lineTo(3, -20)
            ..lineTo(0, -18)
            ..lineTo(-3, -20)
            ..close(),
      glowPaint,
    );
    
    if (isShielded) {
      final shieldPaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 70, height: 50), shieldPaint);
    }
    
    if (isInvincible && !isShielded) {
      final alpha = 0.3 + 0.4 * sin(DateTime.now().millisecondsSinceEpoch / 100);
      final glowPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset.zero, 30, glowPaint);
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
  }
}

class Bullet extends PositionComponent with HasGameReference<MyGame>, CollisionCallbacks {
  late Vector2 velocity;
  
  Bullet(Vector2 position, this.velocity) : super(
    position: position,
    size: Vector2(6, 18),
    anchor: Anchor.center,
  ) {
    add(RectangleHitbox(size: Vector2(4, 14)));
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
  
  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    
    if (position.y < -20 || position.x < -20 || position.x > game.size.x + 20) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.yellow, Colors.orange],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 4, height: 15),
        const Radius.circular(2),
      ),
      Paint()..shader = gradient.createShader(Rect.fromCenter(center: Offset.zero, width: 4, height: 15)),
    );
  }
}

class BulletSpawner extends Component with HasGameReference<MyGame> {
  void start() {}
  void stop() {}
}

class Enemy extends PositionComponent with HasGameReference<MyGame> {
  late double speed;
  bool isDestroyed = false;
  
  Enemy(Vector2 position, this.speed) : super(
    position: position,
    size: Vector2(50, 50),
    anchor: Anchor.center,
  );
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position.y += speed * dt;
    position.x += sin(position.y / 50) * 1;
    
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
    
    canvas.drawPath(
      Path()..moveTo(0, 20)
            ..lineTo(6, 10)
            ..lineTo(6, 0)
            ..lineTo(28, -12)
            ..lineTo(28, -18)
            ..lineTo(6, -8)
            ..lineTo(6, -20)
            ..lineTo(-6, -20)
            ..lineTo(-6, -8)
            ..lineTo(-28, -18)
            ..lineTo(-28, -12)
            ..lineTo(-6, 0)
            ..lineTo(-6, 10)
            ..close(),
      bodyPaint,
    );
    
    canvas.drawPath(
      Path()..moveTo(0, 8)
            ..lineTo(4, 2)
            ..lineTo(0, -2)
            ..lineTo(-4, 2)
            ..close(),
      cockpitPaint,
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
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position.y += speed * dt;
    
    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
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
  
  PowerUp(Vector2 position, this.type) : super(
    radius: 18,
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
    
    if (position.y > game.size.y + 50) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, radius, Paint()..color = type.color.withValues(alpha: 0.3));
  }
}

class ExplosionParticle extends CircleComponent with HasGameReference<MyGame> {
  final Random random = Random();
  late Vector2 velocity;
  double lifetime = 0.6;
  double age = 0;
  
  ExplosionParticle({required Vector2 position}) : super(
    radius: 3.0,
    position: position,
    paint: Paint()..color = Colors.orange,
    anchor: Anchor.center,
  ) {
    final angle = random.nextDouble() * 2 * pi;
    final speed = 100 + random.nextDouble() * 200;
    velocity = Vector2(cos(angle) * speed, sin(angle) * speed);
    radius = 3 + random.nextDouble() * 4;
    paint.color = Color.lerp(Colors.orange, Colors.red, random.nextDouble())!;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.gameState != GameState.playing) return;
    
    position += velocity * dt;
    velocity *= 0.95;
    age += dt;
    
    if (age >= lifetime) {
      removeFromParent();
    }
  }
}

class GameParticle extends CircleComponent with HasGameReference<MyGame> {
  final Random _random = Random();
  late Vector2 velocity;
  double lifetime = 0.5;
  double age = 0;
  
  GameParticle({required Vector2 position, required Color color}) : super(
    radius: 3 + Random().nextDouble() * 3,
    position: position,
    paint: Paint()..color = color,
    anchor: Anchor.center,
  ) {
    final angle = _random.nextDouble() * 2 * pi;
    final speed = 50 + _random.nextDouble() * 100;
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
    game.add(Enemy(Vector2(x, -30), speed));
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
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'STAR FIGHTER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
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
        text: 'TAP TO START',
        style: TextStyle(
          color: Colors.cyan,
          fontSize: 24,
          fontWeight: FontWeight.bold,
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
          text: 'HIGH SCORE: $highScore',
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 20,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      highScorePainter.layout();
      highScorePainter.paint(canvas, Vector2(
        game.size.x / 2 - highScorePainter.width / 2,
        game.size.y / 2 + 50,
      ).toOffset());
    }
  }
  
  void _drawGameOver(Canvas canvas) {
    final gameOverPainter = TextPainter(
      text: const TextSpan(
        text: 'GAME OVER',
        style: TextStyle(
          color: Colors.red,
          fontSize: 52,
          fontWeight: FontWeight.bold,
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
          fontSize: 32,
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
        text: 'HIGH SCORE: $highScore',
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 24,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    highScorePainter.layout();
    highScorePainter.paint(canvas, Vector2(
      game.size.x / 2 - highScorePainter.width / 2,
      game.size.y / 2 + 45,
    ).toOffset());
    
    final restartPainter = TextPainter(
      text: const TextSpan(
        text: 'TAP TO RESTART',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    restartPainter.layout();
    restartPainter.paint(canvas, Vector2(
      game.size.x / 2 - restartPainter.width / 2,
      game.size.y / 2 + 100,
    ).toOffset());
  }
  
  void _drawScore(Canvas canvas) {
    final scorePainter = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(canvas, const Offset(16, 16));
    
    final levelPainter = TextPainter(
      text: TextSpan(
        text: 'LEVEL: ${game.difficultyLevel}',
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    levelPainter.layout();
    levelPainter.paint(canvas, const Offset(16, 44));
    
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
      shieldPainter.paint(canvas, Offset(game.size.x - shieldPainter.width - 16, 16));
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
      triplePainter.paint(canvas, Offset(game.size.x - triplePainter.width - 16, 40));
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
