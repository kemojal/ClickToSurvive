import SwiftUI
import AVFoundation

// MARK: - Game Style Constants
struct GameColors {
    static let background = Color(red: 0.06, green: 0.06, blue: 0.12)
    static let accent = Color(red: 0.38, green: 0.71, blue: 0.91)
    static let danger = Color(red: 0.91, green: 0.3, blue: 0.38)
    static let success = Color(red: 0.3, green: 0.91, blue: 0.67)
    static let buttonGlow = Color(red: 0.38, green: 0.71, blue: 0.91, opacity: 0.3)
    static let gold = Color(red: 1, green: 0.84, blue: 0.0)
}

// MARK: - Particle Effect
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
    
    mutating func update() {
        position.x += velocity.x
        position.y += velocity.y
        opacity -= 0.05
        scale *= 0.95
        rotation += 5
    }
}

// MARK: - Wave System
struct Wave {
    var number: Int
    var enemiesRemaining: Int
    var enemySpeed: Double
    var spawnInterval: Double
    
    static func createWave(number: Int) -> Wave {
        let baseSpeed = 3.0
        let speedIncrease = Double(number) * 0.5
        let enemyCount = min(5 + number, 15)
        let interval = max(1.5 - (Double(number) * 0.1), 0.5)
        
        return Wave(
            number: number,
            enemiesRemaining: enemyCount,
            enemySpeed: baseSpeed + speedIncrease,
            spawnInterval: interval
        )
    }
}

// MARK: - Enemy Definition
struct Enemy: Identifiable {
    let id = UUID()
    var position: CGPoint
    var speed: Double
    var size: CGFloat = 30
    var rotation: Double = 0
    var opacity: Double = 1
    var health: Int = 1
    
    mutating func move(towards target: CGPoint) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        position.x += (dx / distance) * speed
        position.y += (dy / distance) * speed
        rotation += 2
    }
}

// MARK: - Game State
class GameState: ObservableObject {
    @Published var enemies: [Enemy] = []
    @Published var particles: [Particle] = []
    @Published var score = 0
    @Published var health = 100
    @Published var gameOver = false
    @Published var isPlaying = false
    @Published var comboMultiplier = 1
    @Published var currentWave: Wave?
    @Published var waveNumber = 0
    @Published var shockwave: CGFloat = 0
    @Published var isWaveComplete = false
    
    private var spawnTimer: Timer?
    private var particleTimer: Timer?
    private let maxParticles = 100
    
    func startGame() {
        isPlaying = true
        health = 100
        score = 0
        gameOver = false
        comboMultiplier = 1
        waveNumber = 0
        enemies.removeAll()
        particles.removeAll()
        startNewWave()
        
        // Start particle update timer
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateParticles()
        }
    }
    
    func startNewWave() {
        waveNumber += 1
        currentWave = Wave.createWave(number: waveNumber)
        isWaveComplete = false
        
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: currentWave?.spawnInterval ?? 1.5, repeats: true) { [weak self] _ in
            self?.spawnEnemy()
        }
    }
    
    func spawnEnemy() {
        guard let wave = currentWave, wave.enemiesRemaining > 0 else {
            spawnTimer?.invalidate()
            if enemies.isEmpty {
                isWaveComplete = true
            }
            return
        }
        
        guard enemies.isEmpty else { return } // Only spawn if no enemies present
        
        let screenSize = UIScreen.main.bounds
        let randomSide = Int.random(in: 0...3)
        var position: CGPoint
        
        switch randomSide {
        case 0:
            position = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: -50)
        case 1:
            position = CGPoint(x: screenSize.width + 50, y: CGFloat.random(in: 0...screenSize.height))
        case 2:
            position = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: screenSize.height + 50)
        default:
            position = CGPoint(x: -50, y: CGFloat.random(in: 0...screenSize.height))
        }
        
        let enemy = Enemy(
            position: position,
            speed: wave.enemySpeed,
            health: min(waveNumber, 3)
        )
        enemies.append(enemy)
        currentWave?.enemiesRemaining -= 1
    }
    
    func createExplosionParticles(at position: CGPoint) {
        let particleCount = 20
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 2...5)
            let particle = Particle(
                position: position,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                scale: CGFloat.random(in: 5...15),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)
            
            if particles.count > maxParticles {
                particles.removeFirst(particles.count - maxParticles)
            }
        }
    }
    
    func updateParticles() {
        particles = particles.compactMap { var particle = $0
            particle.update()
            return particle.opacity > 0 ? particle : nil
        }
    }
    
    func updateGame() {
        guard !gameOver else { return }
        
        let centerPoint = CGPoint(x: UIScreen.main.bounds.width / 2,
                                y: UIScreen.main.bounds.height / 2)
        
        if shockwave > 0 {
            shockwave -= 1
        }
        
        // Update enemies
        for (index, enemy) in enemies.enumerated() {
            var updatedEnemy = enemy
            updatedEnemy.move(towards: centerPoint)
            enemies[index] = updatedEnemy
            
            let distance = hypot(centerPoint.x - enemy.position.x,
                               centerPoint.y - enemy.position.y)
            if distance < 60 {
                health -= 10
                createExplosionParticles(at: enemy.position)
                _ = withAnimation(.easeOut(duration: 0.3)) {
    enemies.remove(at: index)
}
                // withAnimation(.easeOut(duration: 0.3)) {
                //     enemies.remove(at: index)
                // }
                if health <= 0 {
                    endGame()
                }
                break
            }
        }
        
        // Check for wave completion
        if currentWave?.enemiesRemaining == 0 && enemies.isEmpty && !isWaveComplete {
            isWaveComplete = true
        }
    }
    
    func defendAgainstEnemies() {
        guard !enemies.isEmpty else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            shockwave = 100
            
            // Create explosion particles for each enemy
            for enemy in enemies {
                createExplosionParticles(at: enemy.position)
            }
            
            // Calculate score based on wave and combo
            let baseScore = 100 * waveNumber
            score += baseScore * comboMultiplier
            
            enemies.removeAll()
            comboMultiplier = min(comboMultiplier + 1, 8)
            
            // Start next wave if current is complete
            if currentWave?.enemiesRemaining == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.startNewWave()
                }
            }
        }
    }
    
    func endGame() {
        gameOver = true
        isPlaying = false
        spawnTimer?.invalidate()
        particleTimer?.invalidate()
        spawnTimer = nil
        particleTimer = nil
    }
}

// MARK: - Game View
struct ContentView: View {
    @StateObject private var gameState = GameState()
    let gameTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            GameColors.background
                .edgesIgnoringSafeArea(.all)
            
            if !gameState.isPlaying {
                // Start Screen
                VStack(spacing: 30) {
                    Text("CLICK TO")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("SURVIVE")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(GameColors.accent)
                        .shadow(color: GameColors.accent.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    if gameState.gameOver {
                        VStack(spacing: 10) {
                            Text("GAME OVER")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(GameColors.danger)
                            
                            Text("Score: \(gameState.score)")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                
                            Text("Waves Survived: \(gameState.waveNumber)")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(GameColors.gold)
                        }
                        .padding()
                    }
                    
                    Button(action: {
                        withAnimation {
                            gameState.startGame()
                        }
                    }) {
                        Text("START")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 60)
                            .background(GameColors.accent)
                            .clipShape(Capsule())
                            .shadow(color: GameColors.accent.opacity(0.5), radius: 10, x: 0, y: 0)
                    }
                }
            } else {
                // Game Elements
                ZStack {
                    // Particles
                    ForEach(gameState.particles) { particle in
                        Circle()
                            .fill(GameColors.danger)
                            .frame(width: particle.scale, height: particle.scale)
                            .position(particle.position)
                            .rotationEffect(.degrees(particle.rotation))
                            .opacity(particle.opacity)
                    }
                    
                    // Enemies
                    ForEach(gameState.enemies) { enemy in
                        ZStack {
                            Circle()
                                .fill(GameColors.danger)
                                .frame(width: enemy.size, height: enemy.size)
                            
                            // Health indicator for stronger enemies
                            if enemy.health > 1 {
                                Text("\(enemy.health)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .position(enemy.position)
                        .rotationEffect(.degrees(enemy.rotation))
                        .shadow(color: GameColors.danger.opacity(0.5), radius: 5)
                    }
                    
                    // Shockwave
                    if gameState.shockwave > 0 {
                        Circle()
                            .stroke(GameColors.accent.opacity(0.5), lineWidth: 2)
                            .frame(width: gameState.shockwave * 5, height: gameState.shockwave * 5)
                            .position(x: UIScreen.main.bounds.width / 2,
                                    y: UIScreen.main.bounds.height / 2)
                    }
                    
                    // Wave Complete Banner
                    if gameState.isWaveComplete {
                        Text("WAVE \(gameState.waveNumber) COMPLETE!")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(GameColors.gold)
                            .shadow(color: GameColors.gold.opacity(0.5), radius: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Stats Overlay
                    VStack {
                        HStack {
                            // Wave Counter
                            Text("WAVE \(gameState.waveNumber)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(GameColors.gold)
                            
                            Spacer()
                            
                            // Score and Combo
                            VStack(alignment: .trailing) {
                                Text("SCORE: \(gameState.score)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                if gameState.comboMultiplier > 1 {
                                    Text("COMBO x\(gameState.comboMultiplier)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(GameColors.accent)
                                }
                            }
                        }
                        .padding()
                        
                        // Health Bar
                        GeometryReader { geometry in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.3))
            .frame(height: 20)
        
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        gameState.health > 30 ? GameColors.success : GameColors.danger,
                        gameState.health > 30 ? GameColors.success.opacity(0.7) : GameColors.danger.opacity(0.7)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: geometry.size.width * CGFloat(gameState.health) / 100, height: 20)
            .animation(.easeOut(duration: 0.3), value: gameState.health)
    }
    .overlay(
        Text("HP: \(gameState.health)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    )
}
                                                                       .frame(height: 20)
                                                                       .padding()
                                                                       
                                                                       Spacer()
                                                                   }
                                                                   
                                                                   // Center Button
                                                                   Button(action: {
                                                                       withAnimation {
                                                                           gameState.defendAgainstEnemies()
                                                                       }
                                                                   }) {
                                                                       ZStack {
                                                                           // Outer glow
                                                                           Circle()
                                                                               .fill(GameColors.buttonGlow)
                                                                               .frame(width: 140, height: 140)
                                                                               .blur(radius: 10)
                                                                           
                                                                           // Main button
                                                                           Circle()
                                                                               .fill(
                                                                                   LinearGradient(
                                                                                       gradient: Gradient(colors: [
                                                                                           GameColors.accent,
                                                                                           GameColors.accent.opacity(0.8)
                                                                                       ]),
                                                                                       startPoint: .topLeading,
                                                                                       endPoint: .bottomTrailing
                                                                                   )
                                                                               )
                                                                               .frame(width: 120, height: 120)
                                                                           
                                                                           // Button border
                                                                           Circle()
                                                                               .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                                                               .frame(width: 118, height: 118)
                                                                           
                                                                           // Button text
                                                                           VStack {
                                                                               Text("DEFEND")
                                                                                   .font(.system(size: 20, weight: .black, design: .rounded))
                                                                                   .foregroundColor(.white)
                                                                               
                                                                               if gameState.comboMultiplier > 1 {
                                                                                   Text("x\(gameState.comboMultiplier)")
                                                                                       .font(.system(size: 16, weight: .bold, design: .rounded))
                                                                                       .foregroundColor(.white.opacity(0.8))
                                                                               }
                                                                           }
                                                                       }
                                                                       .scaleEffect(gameState.enemies.isEmpty ? 0.95 : 1.0)
                                                                       .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gameState.enemies.isEmpty)
                                                                   }
                                                                   .buttonStyle(PulsatingButtonStyle())
                                                                   .position(x: UIScreen.main.bounds.width / 2,
                                                                            y: UIScreen.main.bounds.height / 2)
                                                               }
                                                           }
                                                       }
                                                       .onReceive(gameTimer) { _ in
                                                           gameState.updateGame()
                                                       }
                                                       .preferredColorScheme(.dark)
                                                   }
                                               }

                                               // Existing PulsatingButtonStyle remains the same
                                               struct PulsatingButtonStyle: ButtonStyle {
                                                   func makeBody(configuration: Configuration) -> some View {
                                                       configuration.label
                                                           .scaleEffect(configuration.isPressed ? 0.95 : 1)
                                                           .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
                                                   }
                                               }
//MARK: - Preview
#Preview {
    ContentView()
}
