//
//  ContentView.swift
//  Roulette_Japan
//
//  Created by 江原弘人 on 2024/12/08.
//




import SwiftUI
import AVFoundation // サウンド再生のためにインポート
import Combine



// テンプレートを管理するクラス
class TemplateManager: ObservableObject {
    @Published var templates: [MyTemplate] = []
    @Published var entries: [String] = []
    @Published var ratios: [Double] = []
    // 新しい項目を追加するためのプロパティ
    @Published var newEntry: String = ""
    @Published var newRatio: Double = 1.0
    
    init() {
        loadTemplatesFromUserDefaults() // アプリ起動時に読み込み
        
        // アプリ起動時にUserDefaultsから保存された項目を読み込む
        loadEntriesFromUserDefaults()
        
        // UserDefaultsからentriesとratiosを読み込む
        if let entriesData = UserDefaults.standard.data(forKey: "savedEntries"),
           let ratiosData = UserDefaults.standard.data(forKey: "savedRatios") {
            do {
                entries = try JSONDecoder().decode([String].self, from: entriesData)
                ratios = try JSONDecoder().decode([Double].self, from: ratiosData)
            } catch {
                print("Failed to load entries and ratios: \(error)")
            }
        }
        
    }
    
    
    private func loadSavedEntriesAndRatios() {
        if let entriesData = UserDefaults.standard.data(forKey: "savedEntries"),
           let ratiosData = UserDefaults.standard.data(forKey: "savedRatios") {
            do {
                entries = try JSONDecoder().decode([String].self, from: entriesData)
                ratios = try JSONDecoder().decode([Double].self, from: ratiosData)
            } catch {
                print("Failed to load saved entries and ratios: \(error)")
            }
        }
    }
    
    
    // エントリ追加メソッド

     
     // UserDefaultsにentriesとratiosを保存
     private func saveEntriesToUserDefaults() {
         UserDefaults.standard.set(entries, forKey: "savedEntries")
         UserDefaults.standard.set(ratios, forKey: "savedRatios")
     }
     
     // UserDefaultsからentriesとratiosを読み込む
     private func loadEntriesFromUserDefaults() {
         let defaults = UserDefaults.standard
         entries = defaults.object(forKey: "savedEntries") as? [String] ?? []
         ratios = defaults.object(forKey: "savedRatios") as? [Double] ?? []
     }
     
     // 入力フィールドをリセット
     private func clearEntryFields() {
         newEntry = ""
         newRatio = 1.0
     }

    
    func saveTemplate(name: String, entries: [String], ratios: [Double]) {
        let newEntries = entries.map { TemplateEntry(name: $0, ratio: 1.0) } // ratioに適切な初期値を指定

        let newTemplate = MyTemplate(name: name, entries: newEntries, ratios: ratios.map { Double($0) })
        templates.append(newTemplate)
        saveTemplatesToUserDefaults() // 保存
    }
    
    
    // UserDefaultsにテンプレートデータを保存するメソッド
    func saveTemplatesToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(templates)
            UserDefaults.standard.set(data, forKey: "templates")
            UserDefaults.standard.synchronize() // 保存を即座に確定
            
            // 保存時のデータをコンソールに出力
            print("Templates saved: \(templates)")
        } catch {
            print("Failed to save templates: \(error)")
        }
        
    }
    
    // UserDefaultsからテンプレートデータを読み込むメソッド
    func loadTemplatesFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "templates") else { return }
        do {
            let decoder = JSONDecoder()
            templates = try decoder.decode([MyTemplate].self, from: data)
            
            // 読み込み時のデータをコンソールに出力
            print("Templates loaded: \(templates)")
        } catch {
            print("Failed to load templates: \(error)")
        }
        
        print("Loaded templates: \(templates)")
    }
    
    
    func deleteTemplate(at index: Int) {
        templates.remove(at: index)
        // UserDefaultsに反映
        saveTemplatesToUserDefaults()
    }
    
    func addEntryToTemplate(_ entry: TemplateEntry) {
        // テンプレートが存在する場合、最初のテンプレートにエントリを追加
        if !templates.isEmpty {
            templates[0].entries.append(entry)
        } else {
            print("テンプレートが空です。")
        }
    }
    
    
}


// サウンド再生クラス
class SoundPlayer: NSObject {
    var dramPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
    }

    func dramPlay() {
        guard let dramData = NSDataAsset(name: "ドラムロール 締めなし")?.data else {
            print("サウンドデータが見つかりません")
            return
        }
        
        do {
            dramPlayer = try AVAudioPlayer(data: dramData)
            dramPlayer?.prepareToPlay()
            dramPlayer?.play()
        } catch {
            print("サウンド再生エラー: \(error.localizedDescription)")
        }
    }
    
    func stopDramPlay() {
        dramPlayer?.stop()
    }
}

// テンプレートデータ
struct MyTemplate: Identifiable, Codable {
    var id = UUID()
    var name: String
    var entries: [TemplateEntry]
    var ratios: [Double]
    

}

struct TemplateEntry: Identifiable, Codable {
    var id = UUID()
    var name: String
    let ratio: Double // 追加

    init(name: String, ratio: Double) {
         self.name = name
         self.ratio = ratio
     }
 }





struct RouletteView: View {
    
    @State private var entries: [String] = []
    @State private var ratios: [Double] = []
    @State private var templateEntries: [String] = [] // テンプレート作成用の項目リスト
    @State private var templateRatios: [Double] = [] // テンプレート作成用の比率リスト
    @State private var angle: Double = 0
    @State private var isSpinning = false
    @State private var spinDuration: Double = 6.0
    @State private var resultText: String = "" // 抽選結果用の状態変数
    @State private var hasSpun = false // 一度回転が終了したかどうかのフラグ
    @State private var showDeleteConfirmations: [Bool] = []
    @State private var templateName: String = ""
    @State private var showingTemplateView = false
    @StateObject private var templateManager = TemplateManager()
    @State private var hasAddedDefaultEntry = false // デフォルト項目追加フラグ
    @State private var hasClearedDefaultEntry = false // デフォルト項目削除フラグ
    
    let soundPlayer = SoundPlayer() // サウンドプレーヤーのインスタンスを作成
    
    // セグメントの色にGBRを追加
    let segmentColors: [Color] = [
        .red, .cyan, .green,  .yellow, .orange, .purple, Color(red: 1, green: 0.5, blue: 0.6), .blue, .indigo, Color(red: 0.7, green: 1, blue: 0.6), .teal, Color(red: 0.7, green: 1, blue: 0.6), .mint, .indigo, .pink, .gray, .secondary, .orange
    ]
    
    struct RouletteView: View {
        @State private var entries: [String] = []
        @State private var ratios: [Double] = []
        @State private var angle: Double = 0
        @State private var isSpinning = false
        @State private var spinDuration: Double = 6.0
        @State private var resultText: String = ""
        @State private var hasSpun = false
        @State private var showDeleteConfirmations: [Bool] = []
        @State private var templateName: String = ""
        @State private var showingTemplateView = false
        @State private var templateEntries: [String] = []
        @State private var templateRatios: [Double] = []
        @ObservedObject var templateManager: TemplateManager
        @State private var hasAddedDefaultEntry = false // デフォルト項目追加フラグ
        @State private var hasClearedDefaultEntry = false // デフォルト項目削除フラグ
        
        let soundPlayer = SoundPlayer()

        // セグメントの色にGBRを追加
        let segmentColors: [Color] = [
            .red, .green, .blue, .yellow, .orange, .purple, Color(red: 1, green: 0.5, blue: 0.6), .gray, .mint, .cyan, .indigo, .mint,
        ]
        
        var body: some View {
            NavigationView {
                GeometryReader { geometry in
                    VStack {
                        // ホイールの表示
                        RouletteWheel(entries: $entries, ratios: $ratios, angle: $angle, spinDuration: $spinDuration, segmentColors: segmentColors, resultText: $resultText)

                        // 結果表示
                        Text("結果: \(resultText)")
                            .font(.system(size: 40))
                            .foregroundColor(.black)
                            .padding()
                            .opacity(hasSpun && !entries.isEmpty ? 1 : 0)
                            .opacity(isSpinning ? 0 : 1)

                        // テンプレート選択ボタン

                    }
                    .padding()
                    .navigationTitle("ルーレット")
                }
            }
            
        }

        
        
        
        func spinRoulette() {
            guard !entries.isEmpty else { return }
            isSpinning = true

            let slowdownSpinAngle = Double.random(in: 6000...9000)
            withAnimation(.easeOut(duration: spinDuration)) {
                angle += slowdownSpinAngle
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
                soundPlayer.stopDramPlay()
                isSpinning = false
                checkNeedlePosition()
                hasSpun = true
            }
        }

        private func checkNeedlePosition() {
            let totalRatio = ratios.reduce(0, +)
            var startAngle = angle.truncatingRemainder(dividingBy: 360)
            if startAngle < 0 { startAngle += 360 }

            for (index, ratio) in ratios.enumerated() {
                let segmentAngle = 360.0 * (ratio / totalRatio)
                if startAngle < segmentAngle {
                    resultText = entries[index]
                    break
                }
                startAngle -= segmentAngle
            }
        }
    }



    struct TemplateAddEntryView: View {
        @ObservedObject var templateManager: TemplateManager
        @State private var newEntries: [String] = []
        @State private var newRatios: [Double] = []
        @State private var templateName: String = ""

        var body: some View {
            VStack {
                TextField("テンプレート名", text: $templateName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                ScrollView {
                    VStack {
                        ForEach(newEntries.indices, id: \.self) { index in
                            HStack {
                                TextField("項目", text: $newEntries[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("比率", value: $newRatios[index], formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                }
                .padding()

                Button("項目を追加") {
                    newEntries.append("")
                    newRatios.append(1.0)
                }

                Button("テンプレートを保存") {
                    templateManager.saveTemplate(name: templateName, entries: newEntries, ratios: newRatios)
                    templateName = ""
                    newEntries = []
                    newRatios = []
                }
            }
            .navigationTitle("テンプレート作成")
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                let wheelSize = min(screenWidth * 0.8, screenHeight * 0.4) // ホイールのサイズを端末に合わせる
                let wheelCenterX = screenWidth / 2
                let wheelCenterY = screenHeight / 2 // ホイールを画面の中央に配置
                let needleOffset = (wheelSize / 2) + 20  // 針をホイールの上に20ポイント配置
                
                
                
                ZStack {
                    // 画面全体の背景を白に設定
                    Color(red: 1, green: 0.9, blue: 0.9)
                        .edgesIgnoringSafeArea(.all) // 画面全体に背景を適用
                    
                    VStack {
                        // タイトルと設定ボタンの配置
                        HStack {
                            Text("")
                                .font(.largeTitle)
                                .padding(.leading)
                                .offset(y: 80)
                            
                            Spacer()
                            
                            // 設定画面に遷移するボタン
                            NavigationLink(destination: SettingsView(spinDuration: $spinDuration)) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 30))
                                    .imageScale(.large)
                                    .padding(.trailing)
                                    .frame(width: 70, height: 70)
                            }
                            .offset(y: 50)
                        }
                        
                        ZStack {
                            RouletteWheel(entries: $entries, ratios: $ratios, angle: $angle, spinDuration: $spinDuration, segmentColors: segmentColors, resultText: $resultText)
                                .offset(y: 110)
                            
                            // 逆三角形の針をホイールの上部に固定
                            Path { path in
                                path.move(to: CGPoint(x: 190, y: 40)) // 下の頂点
                                path.addLine(to: CGPoint(x: 160, y: 0)) // 左の頂点
                                path.addLine(to: CGPoint(x: 220, y: 0)) // 右の頂点
                                path.closeSubpath()
                            }
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .offset(x:-180, y: -103)
                            // Spinボタンをホイールの上に配置
                            Button(action: {
                                soundPlayer.dramPlay()  // 回転開始と同時にサウンドを再生
                                spinRoulette()
                            }) {
                                Text("START")
                                    .padding()
                                    .font(.largeTitle)
                                    .frame(width: 135, height: 135)
                                    .background(Color(red: 0.95, green: 0.99, blue: 0.99))
                                    .foregroundColor(.blue)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 3)
                                        
                                    )
                                
                            }
                            .disabled(entries.isEmpty || isSpinning)
                            .offset(y: 110)
                            .zIndex(1)
                        }
                        
                        // 抽選結果の表示
                        Text("結果: \(resultText)")
                            .font(.system(size: 40)) // サイズを20ポイント大きく変更
                            .foregroundColor(.black)
                            .padding()
                            .opacity(hasSpun && !entries.isEmpty ? 1 : 0)
                            .opacity(isSpinning ? 0 : 1) // 回転中は透明にする
                            .offset(y: -400) // 上に10ポイント移動
                        // 条件を追加:一回目の回転が終了し、エントリーがある場合のみ表示
                        
                        // スピンボタンと他の操作ボタンを配置
                        ControlButtonsView(entries: $entries, ratios: $ratios, isSpinning: $isSpinning, spinDuration: $spinDuration, angle: $angle, showDeleteConfirmations: $showDeleteConfirmations, templateEntries: $templateEntries, templateRatios: $templateRatios, templateManager: templateManager)
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // GeometryReaderに戻り値としてViewを返す
    }
    class SoundPlayer: NSObject {
        var dramPlayer: AVAudioPlayer?
        var resultPlayer: AVAudioPlayer?
        
        // UserDefaultsからサウンド状態を取得
        var isSoundOn: Bool {
            get {
                UserDefaults.standard.bool(forKey: "isSoundOn")
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "isSoundOn")
            }
        }

        override init() {
            super.init()
            initializeSoundSetting() // サウンド設定を初期化
        }
        
        private func initializeSoundSetting() {
            if UserDefaults.standard.object(forKey: "isSoundOn") == nil {
                // サウンド設定が未定義の場合、デフォルトをオンに設定
                UserDefaults.standard.set(true, forKey: "isSoundOn")
            }
        }
        
        // サウンドの読み込みと再生関数
        func dramPlay() {
            guard isSoundOn else {
                   print("サウンドがオフのため再生しません")
                   return
               }
            // オーディオセッションの設定
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("オーディオセッションの設定に失敗: \(error.localizedDescription)")
            }

            // ドラムロール音声データの取得
            guard let dramData = NSDataAsset(name: "ドラムロール 締めなし")?.data else {
                print("サウンドデータが見つかりません")
                return
            }

            // サウンドプレーヤーの初期化と再生
            do {
                dramPlayer = try AVAudioPlayer(data: dramData)
                dramPlayer?.prepareToPlay()  // 再生準備

                dramPlayer?.play()           // 再生開始
            } catch {
                print("サウンド再生エラー: \(error.localizedDescription)")
            }
        }

        // サウンドの停止関数
        func stopDramPlay() {
            dramPlayer?.stop()
        }
        
        // 抽選結果のサウンド再生
        func playResultSound() {
            guard isSoundOn else {
                print("サウンドがオフのため再生しません")
                return
            }

            guard let resultSoundData = NSDataAsset(name: "結果サウンド")?.data else {
                print("結果サウンドデータが見つかりません")
                return
            }

                  do {
                      resultPlayer = try AVAudioPlayer(data: resultSoundData)
                      resultPlayer?.prepareToPlay()
                      resultPlayer?.play()
                  } catch {
                      print("結果サウンド再生エラー: \(error.localizedDescription)")
                  }
              }
    }
    
    


    func spinRoulette() {
        guard !entries.isEmpty else { return }
        isSpinning = true
        let slowdownSpinAngle = Double.random(in: 6000...9000)
        withAnimation(.easeOut(duration: spinDuration)) {
            angle += slowdownSpinAngle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            soundPlayer.stopDramPlay() // 回転終了と同時にサウンドを停止
            isSpinning = false
            checkNeedlePosition()
            hasSpun = true // 回転が終了したらフラグを立てる
            
            // スピン終了時にサウンド停止
            
        }
    }
    
    // 抽選結果を計算する関数
    private func checkNeedlePosition() {
        let wheelRadius = 190.0 // ホイールの半径
        let needlePosition = CGPoint(x: 190, y: 60) // 針の固定位置（画面上の座標）
        var closestDistance = Double.infinity
        var closestSegment: String = ""
        
        // 各セグメントの縁に複数のポイントを置き、その座標を針の座標と比較
        let totalRatio = ratios.reduce(0, +)
        var startAngle = angle.truncatingRemainder(dividingBy: 360)
        if startAngle < 0 {
            startAngle += 360
        }
        
        for (index, ratio) in ratios.enumerated() {
            let segmentAngle = 360.0 * (ratio / totalRatio)
            
            // セグメントの縁に沿って一定間隔でポイントを配置
            for i in stride(from: 0.0, through: segmentAngle, by: 1.0) {
                let currentAngle = startAngle + i
                let pointX = wheelRadius + cos(currentAngle * .pi / 180) * (wheelRadius - 50)
                let pointY = wheelRadius + sin(currentAngle * .pi / 180) * (wheelRadius - 50)
                let pointPosition = CGPoint(x: pointX, y: pointY)
                
                // 針の位置とこのポイントの距離を計算
                let distance = hypot(pointPosition.x - needlePosition.x, pointPosition.y - needlePosition.y)
                
                // 最も近いポイントを持つセグメントを更新
                if distance < closestDistance {
                    closestDistance = distance
                    closestSegment = entries[index]
                }
            }
            
            startAngle += segmentAngle
        }
        
        // 抽選結果を更新
        resultText = closestSegment
        
        // 抽選結果が確定した時にサウンド再生
        soundPlayer.playResultSound()
    }
    
}

// プレビューの追加
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RouletteView()
    }
}


// 他のビューの定義（SettingsView、SpeedControlView、RouletteWheel、RouletteSegmentView、ControlButtonsView、AddEntryView）はそのまま
// 設定画面
struct SettingsView: View {
    @Binding var spinDuration: Double
    @State private var isSoundOn: Bool = true // サウンドのオン/オフフラグ

    var body: some View {
        ZStack {
            // 画面全体の背景を白に設定
            Color(red: 0.9, green: 1, blue: 0.9)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Text("設定")
                    .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                    .font(.largeTitle)
                    .padding()
                    .offset(x: 0, y: -30)
                SpeedControlView(spinDuration: $spinDuration)
                
                // サウンドオン/オフのトグルボタン
                VStack {
                    Text("サウンド")
                        .font(.system(size: 25))
                        .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                        .padding()
                        .offset(x: 0, y: 0)
                    Toggle(isOn: $isSoundOn) {
                        Text(isSoundOn ? "オン" : "オフ")
                            .foregroundColor(isSoundOn ? Color(red: 0.24, green: 0.24, blue: 0.26) : Color(red: 0.24, green: 0.24, blue: 0.26))
                            .font(.system(size: 20))
                            .offset(x: 70, y: 0)

                    }
                    .padding()
                    .offset(x: -30, y: -25)
                }
                .padding()

                
                Spacer()
            }
            
            
            .padding()
        }
        
        .onAppear {
            // UserDefaultsからサウンドの状態を読み込む
            if let savedSoundState = UserDefaults.standard.value(forKey: "isSoundOn") as? Bool {
                isSoundOn = savedSoundState
            }
        }
        .onChange(of: isSoundOn) { newValue in
            // サウンドの状態をUserDefaultsに保存
            UserDefaults.standard.set(newValue, forKey: "isSoundOn")
        }
        
    }
}

struct SpeedControlView: View {
    @Binding var spinDuration: Double
    
    var body: some View {
        VStack {
            Text("回転速度の変更")
                .font(.system(size: 25))
                .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                .padding(.bottom)
            
            HStack {
                Button(action: { spinDuration = 8.0
                    saveSpinDurationToUserDefaults()}) {
                    Text("遅い")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(spinDuration == 8.0 ? Color.blue : Color.clear, lineWidth: 3) // 選択された場合は黒枠
                        )
                }
                Button(action: { spinDuration = 6.0; saveSpinDurationToUserDefaults() }) {
                    Text("普通")
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(spinDuration == 6.0 ? Color.blue : Color.clear, lineWidth: 3) // 選択された場合は黒枠
                        )
                }
                Button(action: { spinDuration = 4.0; saveSpinDurationToUserDefaults() }) {
                    Text("速い")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(spinDuration == 4.0 ? Color.blue : Color.clear, lineWidth: 3) // 選択された場合は黒枠
                        )
                }
            }
            .padding()
            .offset(x: 0, y: -15)
        }
            .onAppear {
                loadSpinDurationFromUserDefaults() // アプリ起動時に設定をロード
    }
}

                       // ユーザーデフォルトに保存
                       private func saveSpinDurationToUserDefaults() {
                           UserDefaults.standard.set(spinDuration, forKey: "spinDuration")
                       }
                       
                       // ユーザーデフォルトから読み込み
                       private func loadSpinDurationFromUserDefaults() {
                           if let savedDuration = UserDefaults.standard.value(forKey: "spinDuration") as? Double {
                               spinDuration = savedDuration
                           }
                       }
                   }
                       
struct RouletteWheel: View {
    @Binding var entries: [String]
    @Binding var ratios: [Double]
    @Binding var angle: Double
    @Binding var spinDuration: Double
    let segmentColors: [Color]
    @Binding var resultText: String

    // ホイールのサイズ
    let wheelSize: CGFloat = 360

    var body: some View {
        ZStack {
            // ホイールの外側の黒い円
            Circle()
                .stroke(Color.gray, lineWidth: 6)
                .frame(width: wheelSize, height: wheelSize)
            
            let totalRatio = ratios.reduce(0, +)
            let segments = calculateSegments(totalRatio: totalRatio)
            
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                
                // サブビューでセグメントを描画
                RouletteSegmentView(
                    entry: segment.entry,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    color: segmentColors[index % segmentColors.count],
                    size: wheelSize // サイズを渡す
                )
            }
        }
        .rotationEffect(.degrees(angle))
        .animation(.easeOut(duration: spinDuration), value: angle)
        .frame(width: wheelSize, height: wheelSize)
        .onAppear {
            checkNeedlePosition()
        }
    }

    private func checkNeedlePosition() {
        let currentAngle = angle.truncatingRemainder(dividingBy: 360)
        var cumulativeAngle: Double = 0

        for (index, ratio) in ratios.enumerated() {
            let segmentAngle = 360 * (ratio / ratios.reduce(0, +))
            cumulativeAngle += segmentAngle

            if currentAngle < cumulativeAngle {
                resultText = entries[index]
                break
            }
        }
    }

    private func calculateSegments(totalRatio: Double) -> [(entry: String, startAngle: Double, endAngle: Double)] {
        var segments: [(entry: String, startAngle: Double, endAngle: Double)] = []
        var startAngle = 0.0
        
        for (index, entry) in entries.enumerated() {
            let segmentRatio = ratios[index] / totalRatio
            let endAngle = startAngle + 360.0 * segmentRatio
            segments.append((entry: entry, startAngle: startAngle, endAngle: endAngle))
            startAngle = endAngle
        }
        
        return segments
    }
}

struct RouletteSegmentView: View {
    var entry: String
    var startAngle: Double
    var endAngle: Double
    var color: Color
    var size: CGFloat

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = size / 2
        let midAngle = (startAngle + endAngle) / 2
        let textX = size / 2 + cos(midAngle * .pi / 180) * (size / 2 - 50)
        let textY = size / 2 + sin(midAngle * .pi / 180) * (size / 2 - 50)
        
        return ZStack {
            Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: false)
                path.addLine(to: center)
            }
            .fill(color)
            
            // セグメントの縁に黒い線を描画
            Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(startAngle),                     endAngle: .degrees(endAngle), clockwise: false)
                path.addLine(to: center)
                path.closeSubpath()
            }
            .stroke(Color.white, lineWidth: 2)
            
            // セグメント上のテキスト
            Text(entry)
                .foregroundColor(Color.black) // 入力された文字の色を黒に設定

                .position(x: textX, y: textY)
        }
    }
}

struct ControlButtonsView: View {
    @Binding var entries: [String]
    @Binding var ratios: [Double]
    @Binding var isSpinning: Bool
    @Binding var spinDuration: Double
    @Binding var angle: Double
    @Binding var showDeleteConfirmations: [Bool]
    @Binding var templateEntries: [String]
    @Binding var templateRatios: [Double]
    var templateManager: TemplateManager
    @State private var showingTemplateView = false
    @State private var newEntry = ""
    @State private var newRatio: Double = 1.0
    @State private var hasAddedDefaultEntry = false // デフォルト項目追加フラグ
    @State private var hasClearedDefaultEntry = false // デフォルト項目削除フラグ

    var body: some View {
        VStack {
            NavigationLink(
                destination: AddEntryView(
                    showDeleteConfirmations: $showDeleteConfirmations,
                    templateManager: templateManager,
                    entries: $entries,
                    ratios: $ratios
                ).onAppear {
                }
            ) {
                Text("項目を追加・編集")
                    .padding()
                    .font(.system(size: 30))
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
            .offset(y: 35) // 上に移動
        }
    }
      
    func spinRoulette() {
        guard !entries.isEmpty else { return }
        isSpinning = true
        
        
        let slowdownSpinAngle = Double.random(in: 6000...9000)
        withAnimation(.easeOut(duration: spinDuration)) {
            angle += slowdownSpinAngle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            isSpinning = false
        }
    }
}


struct TemplateSelectionView: View {
    @ObservedObject var templateManager: TemplateManager
    @Binding var entries: [String]
    @Binding var ratios: [Double]
    @State private var showAddEntryView = false // 項目追加画面表示のフラグ
    @Binding var showDeleteConfirmations: [Bool] // 追加
    @State private var hasAddedDefaultEntry = false // デフォルト項目追加フラグ
    @State private var hasClearedDefaultEntry = false // デフォルト項目削除フラグ
    @State private var showAlert = false // アラート表示フラグ
    @State private var selectedIndexesToDelete: IndexSet? // 削除対象のIndexSet
    @Binding var showModal: Bool // モーダル表示状態を親ビューと同期
    @Binding var showingTemplateView: Bool // モーダル表示状態


    var body: some View {
        NavigationView {

                ZStack{
                    Color(red: 1.5, green: 0.8, blue: 0.5)
                        .edgesIgnoringSafeArea(.all) // 画面全体に適用
                    
                    VStack {

                        if #available(iOS 16.0, *) {
                            ScrollView { // ScrollViewを使ってカスタムスクロールを実現
                                VStack(spacing: 20) { // 項目の間隔を調整
                                    ForEach(templateManager.templates.indices, id: \.self) { index in
                                        ZStack{
                                            Color(red: 1.5, green: 0.8, blue: 0.5)
                                                .edgesIgnoringSafeArea(.all) // 画面全体に適用
                                            HStack {
                                                Button(action: {
                                                    
                                                    loadTemplateEntries(from: templateManager.templates[index])
                                                    showingTemplateView = false

                                                }) {
                                                    
                                                    Text(templateManager.templates[index].name)
                                                        .padding()
                                                        .frame(width: 360, alignment: .leading) // 左揃え
                                                        .background(Color(red: 0.97, green: 0.99, blue: 0.99))
                                                        .foregroundColor(.black)
                                                        .cornerRadius(8) // 角丸を追加
                                                }
                                                .buttonStyle(PlainButtonStyle()) // デフォルトスタイルを無効化
                                                
                                                .background(Color.green) // ボタン全体の背景を白に設定
                                                .cornerRadius(8) // ボタン全体の角丸を追加
                                                .padding(.vertical, -4) // ボタン間の垂直スペース
                                                .frame(maxWidth: .infinity)
                                                // 削除ボタン

                                                
                                            }
                                            
                                            Button(action: {
                                                selectedIndexesToDelete = IndexSet(integer: index) // 削除対象をIndexSetで指定
                                                showAlert = true // アラートを表示
                                            }) {
                                                Image(systemName: "trash")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 20, height: 20)
                                                    .padding(10)
                                                    .background(Color.red)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .offset(x: 150, y: 0)
                                        }
                                        .padding(.horizontal)
                                    }
                                    

                                    
                                }
                                .background(Color(red: 1.5, green: 0.8, blue: 0.5))
                                .scrollContentBackground(.hidden)
                                

                                
                            } // iOS 16以降のスクロール背景を隠す
                            
                        }
                    }
                    .navigationBarTitle("テンプレート選択", displayMode: .inline)
                    .foregroundColor(Color.black)
                    .background(Color(red: 1.5, green: 0.8, blue: 0.5))
                    
                    
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("確認"),
                            message: Text("このテンプレートを削除しますか？"),
                            primaryButton: .destructive(Text("削除")) {
                                if let indexes = selectedIndexesToDelete {
                                    deleteTemplates(at: indexes) // IndexSetを使って削除
                                }
                            },
                            secondaryButton: .cancel(Text("キャンセル"))
                        )
                    }
            }
        }
    }

    // テンプレートからエントリーを読み込み、通常のエントリーとして変換する
    private func loadTemplateEntries(from template: MyTemplate) {
        entries = template.entries.map { $0.name }
        ratios = template.ratios.map { Double($0) }
        
        // UserDefaultsに変換後のentriesとratiosを保存
        do {
            let entriesData = try JSONEncoder().encode(entries)
            let ratiosData = try JSONEncoder().encode(ratios)
            UserDefaults.standard.set(entriesData, forKey: "savedEntries")
            UserDefaults.standard.set(ratiosData, forKey: "savedRatios")
        } catch {
            print("Failed to save entries and ratios: \(error)")
        }
        
        // 各エントリーに対する削除確認フラグの設定
        showDeleteConfirmations = Array(repeating: false, count: entries.count)
    }
    
    
    
    
    // テンプレートを削除する
    func deleteTemplates(at indexes: IndexSet) {
        for index in indexes {
            guard templateManager.templates.indices.contains(index) else { continue }
            templateManager.templates.remove(at: index)
        }
        templateManager.saveTemplatesToUserDefaults()
    }
    // プレビューの追加
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            RouletteView()
        }
    }
    
    func loadTemplate() {
        guard !templateManager.templates.isEmpty else {
            print("テンプレートが空です")
            return
        }
    }
}




struct AddEntryView: View {

    @Binding var showDeleteConfirmations: [Bool]
    @ObservedObject var templateManager: TemplateManager //ContentViewから受け取るためにObservedObjectを使用

    @State private var newEntry = ""
    @State private var newRatio: Double = 1.0
    @Binding var entries: [String]       // 外部と共有するエントリ
    @Binding var ratios: [Double]        // 外部と共有する比率

    @State private var isRatioPickerPresented: Bool = false // アクションシートの表示状態
    @State private var showDeleteConfirmation = false // 削除確認のフラグ
    @State private var showingTemplateView = false // テンプレート選択ビューの表示
    @State private var showingTemplateAddView = false // テンプレート追加ビューの表示フラグ
    @State private var templateEntries: [String] = []  // テンプレートに保存するエントリ
    @State private var templateRatios: [Double] = []  // テンプレートに保存する比率
    @State private var newEntryText = ""
    @State private var displayEntries: [String] = [] // 表示用の一時コピー
    @State private var displayRatios: [Double] = []

    @Environment(\.presentationMode) var presentationMode
    @State private var templateName: String = ""
    @State private var entryText: String = ""
    @State private var temporaryEntries: [TemplateEntry] = [] //一時的な項目リスト
    @State private var showModal = false

    
    let ratioOptions: [Double] = Array(stride(from: 0.5, through: 10.0, by: 0.5)) // 比率の選択肢
    
    
   

    
    
    var body: some View {
        
            VStack {
                // 既存のUI構成
                
                    
                // 他のコンテンツもそのまま
            }
            .navigationBarBackButtonHidden(true) // ここで適用
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss() // "設定完了"で戻る動作
            }) {
                Text("＜ セット完了")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
            })
            
                    
        ZStack {
            // 画面全体の背景を白に設定
            Color(red: 0.9, green: 1, blue: 0.9)
                .edgesIgnoringSafeArea(.all)
            VStack {
                ZStack {
                    // 背景の枠
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 2) // 枠の色と線の太さ
                        .background(Color.green) // 背景色
                        .cornerRadius(8)
                        .padding(5) // 枠内の余白
                        .frame(height: 15)
                        .offset(y: 170)
                    
                    Text("　テキスト入力                      比率      削除")
                        .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                        .font(.system(size: 20))
                        .offset(x: -5, y: 160)
                        .padding() // テキストと枠の間の余白を追加
                }
                .frame(maxWidth: .infinity) // 全幅に広げる場合
                
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 2) // 枠の色と線の太さ
                    .background(Color.green) // 背景色
                    .cornerRadius(8)
                    .padding(5) // 枠内の余白
                    .frame(height: 15)
                    .offset(y: 415)
                
                
                
                
                
                
                
                
                
                VStack {
                    Button(action: {
                        showDeleteConfirmation = true // 削除確認のフラグをオンにする
                        
                    }) {
                        Text("全削除")
                            .padding()
                            .background(Color.red)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .frame(width: 80, height: 68)
                        
                    }
                    .padding()
                    .offset(y: 10)
                    .offset(x: 145)
                    .alert(isPresented: $showDeleteConfirmation) { // アラートの表示
                        Alert(
                            title: Text("確認"),
                            message: Text("本当に全ての項目を削除しますか？"),
                            primaryButton: .destructive(Text("削除")) {
                                // 削除の処理
                                entries.removeAll()
                                ratios.removeAll()
                            },
                            secondaryButton: .cancel(Text("キャンセル"))
                        )
                    }
                }
                
                ScrollView {
                    VStack {
                        ForEach(entries.indices, id: \.self) { index in
                            if entries.indices.contains(index) && ratios.indices.contains(index) {
                                
                                HStack {
                                    ZStack {
                                        // 背景を白に設定
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.97, green: 0.99, blue: 0.99))
                                            .frame(height: 50)
                                        
                                        // テキスト入力欄
                                        TextField("", text: $entries[index])
                                            .foregroundColor(Color.black)
                                        // 入力された文字の色を黒に設定
                                        
                                            .padding(10) // テキスト入力エリアにパディングを追加
                                        
                                    }
                                    .shadow(radius: 1) // 適度なシャドウを追加して強調
                                    .offset(x: 1)
                                    
                                    Spacer()
                                    
                                    // 比率選択ボタン
                                    Picker("比率", selection: $ratios[index]) {
                                        ForEach(ratioOptions, id: \.self) { ratio in
                                            Text("\(ratio, specifier: "%.1f")")
                                                .font(.system(size: 30)) // テキストのフォントサイズを30に設定
                                                .frame(maxWidth: .infinity) // 枠いっぱいにする
                                                .tag(ratio)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(width: 75, height: 30) // 横幅と高さを設定し、20ポイント増加
                                    .overlay( // 黒い枠を追加
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .stroke(Color.blue, lineWidth: 0.5) // 黒縁を2ポイントの太さで追加
                                    )
                                    .background(Color(red: 0.95, green: 0.98, blue: 0.99))
                                    .shadow(radius: 1) // 適度なシャドウを追加して強調
                                    
                                    Button(action: {
                                        showDeleteConfirmations[index] = true
                                        // アラートの表示
                                        
                                    }) {
                                        Image(systemName: "trash")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.red)
                                            .frame(width: 35, height: 35)
                                            .cornerRadius(5)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .alert(isPresented: $showDeleteConfirmations[index]) { // アラートの表示
                                        Alert(
                                            title: Text("確認"),
                                            message: Text("本当にこの項目を削除しますか？"),
                                            primaryButton: .destructive(Text("削除")) {
                                                entries.remove(at: index)
                                                ratios.remove(at: index)
                                                showDeleteConfirmations.remove(at: index)
                                            },
                                            secondaryButton: .cancel(Text("キャンセル"))
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding()
                .offset(y: -9)
                .frame(width: 370, height: 310)
                
                
                
                VStack {
                    
                    
                    Button(action: {
                        let entryToAdd = newEntry.isEmpty ? "" : newEntry
                        entries.append(entryToAdd)
                        ratios.append(newRatio)
                        showDeleteConfirmations.append(false) // 削除確認フラグを追加
                        
                        newEntry = ""
                        newRatio = 1.0
                    }) {
                        Text("項目追加")
                            .padding()
                            .font(.system(size: 38))
                            .background(Color.teal)
                            .foregroundColor(Color(red: 0.97, green: 0.99, blue: 0.99))
                            .cornerRadius(8)
                    }
                }
                
                
                .padding()
                .offset(y: -30)
                
                VStack {
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("セット\n完 了")
                            .padding()
                            .font(.system(size: 17))
                            .background(Color.green)
                            .foregroundColor(Color(red: 0.97, green: 0.99, blue: 0.99))
                            .cornerRadius(8)
                            .frame(width: 80, height: 130)
                    }
                    .padding()
                    .offset(x: 135, y: -175)
                    
                }
                
                VStack {
 
                        // テンプレート保存ボタン
                        Button(action: {
                            showModal = true // モーダル表示をトリガー
                        }) {
                            Text("テンプレートに保存")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            
                        }
                        .sheet(isPresented: $showModal) {
                            VStack {


                                ZStack {
                                    // 画面全体の背景を白に設定
                                    Color(red: 0.7, green: 0.9, blue: 0.9)
                                        .edgesIgnoringSafeArea(.all)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .cornerRadius(30)
   
                                    Text("テンプレート名を入力")
                                        .font(.headline)
                                        .padding()
                                    
                                    ZStack {
                                        // 背景を白に設定
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.97, green: 0.99, blue: 0.99))
                                           
                                        Text("テンプレート名を入力")
                                            .foregroundColor(Color(red: 0.24, green: 0.24, blue: 0.26))
                                            .font(.system(size: 20))
                                            .offset(x: -4, y: -40)
                                        
                                        // テキスト入力欄
                                        TextField("", text: $templateName)
                                            .foregroundColor(Color.black)
                                        // 入力された文字の色を黒に設定
                                        
                                            .padding(10)
                                            
                                        
                                    }
                                    .shadow(radius: 1) // 適度なシャドウを追加して強調
                                    .offset(x: 0)
                                    .frame(width: 300, height: 30)
                                    
                                    if #available(iOS 16.0, *) {
                                        HStack {
                                            
                                            Button("キャンセル") {
                                                showModal = false // モーダルを閉じる
                                            }
                                            .padding()
                                            .background(Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                            
                                            Button(action: {
                                                saveEntryToTemplate(name: templateName) // テンプレートを保存
                                                templateName = "" // 入力をクリア
                                                showModal = false // モーダルを閉じる
                                            }) {
                                                Text("保存")
                                                    .padding()
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        .padding()
                                        .offset(x: 0, y: 70)
                                        .scrollContentBackground(.hidden)
                                        
                                    }


                                }
                                .padding()
                                
                               
                                .background(Color(red: 0.7, green: 0.9, blue: 0.9))

                            }
                            
                            // モーダル全体の高さを300ポイントに制限

                        }
                    
                }
                .offset(y: -218)
              
            }
            
            VStack {
                
                // テンプレート選択ボタン
                Button(action: {
                    showingTemplateView = true
                    

                    
                }) {
                    Text("テンプレートから読み込む")
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                       
                }

                        .sheet(isPresented: $showingTemplateView){
                            
                            TemplateSelectionView(templateManager: templateManager, entries: $entries, ratios: $ratios, showDeleteConfirmations: $showDeleteConfirmations,showModal: $showingTemplateView, showingTemplateView: $showingTemplateView)
                            
                            
                }
                .offset(y: 240)
                
    
            }

           
            .foregroundColor(.black)
            .padding()
            .toolbar {ToolbarItem(placement: .principal) {
                               
                            }
                        }
        }
        
    }
    
    
    
    
    private func addEntry() {
          let entryToAdd = newEntry.isEmpty ? "" : newEntry
          entries.append(entryToAdd)       // entriesを更新
          ratios.append(newRatio)           // ratiosを更新
          showDeleteConfirmations.append(false) // 削除確認フラグを追加

          // TemplateEntryを作成してテンプレートマネージャーに追加
          let newTemplateEntry = TemplateEntry(name: entryToAdd, ratio: newRatio)

          if templateManager.templates.isEmpty {
              // テンプレートが空の場合、新しいテンプレートを作成して追加
              let newTemplate = MyTemplate(name: "新しいテンプレート", entries: [newTemplateEntry], ratios: [newRatio])
              templateManager.templates.append(newTemplate)
          } else {
              // テンプレートが存在する場合、新たなエントリのみをテンプレートに追加
              templateManager.templates[0].entries.append(newTemplateEntry)
              templateManager.templates[0].ratios.append(newRatio)
          }

          templateManager.objectWillChange.send() // 更新を通知

        
          // 入力欄をリセット
          newEntry = ""
          newRatio = 1.0
      }
  
    
    
    
    


    // テンプレートに現在の項目を保存
    private func saveEntryToTemplate(name: String) {
        // 通常のエントリーからテンプレートエントリーに変換
        let templateEntries = entries.map { TemplateEntry(name: $0, ratio: 1.0) } // 必要に応じてratioを調整
        let templateRatios = ratios // 必要であれば比率も調整可能

        // 新しいテンプレートを作成
        let templateName = "新しいテンプレート \(templateManager.templates.count + 1)" // ユニークなテンプレート名
        let newTemplate = MyTemplate(name: name, entries: templateEntries, ratios: templateRatios)

        // TemplateManager にテンプレートを追加
        templateManager.templates.append(newTemplate)
        templateManager.saveTemplatesToUserDefaults() // UserDefaults に保存
        print("テンプレートに保存されました: \(templateName)")
    }

    
    
    struct RouletteApp: App {
        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(TemplateManager()) // TemplateManagerの共有
            }
        }
    }
    
    struct CustomTextField: View {
        @Binding var text: String
        var placeholder: String

        var body: some View {
            ZStack(alignment: .leading) {
                // プレースホルダーが空のときに表示
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.black) // プレースホルダーテキストの色
                        .padding(.leading, 10) // プレースホルダーの左側に余白を追加
                }
                // テキストフィールド
                TextField("", text: $text)
                    .foregroundColor(Color.black) // 入力された文字の色を黒に設定
                    .padding(10) // パディングを追加
                    .background(Color.white) // 背景を白に設定
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white) // 背景色を白に設定

            )
            .shadow(color: .gray, radius: 2, x: 0, y: 2)
        }
    }

    struct ContentView: View {
        @State private var textInput = ""

        var body: some View {
            VStack {
                // カスタムTextFieldの使用
                CustomTextField(text: $textInput, placeholder: "入力")
                    .foregroundColor(Color.black) // 入力された文字の色を黒に設定

                    .padding()

                // 他のUI要素
                Spacer()
            }
            .padding()
        }
    }


    // プレビューの追加
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            RouletteView()
                .environmentObject(TemplateManager()) // TemplateManagerの共有
        }
    }
}


struct RouletteApp: App {
    var body: some Scene {
        WindowGroup {
            RouletteView()
                .environmentObject(TemplateManager()) // TemplateManagerの共有
        }
    }
}
