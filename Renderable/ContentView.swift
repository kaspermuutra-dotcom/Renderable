import SwiftUI

struct ContentView: View {

    @State private var showScanner = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Renderable")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Button(action: {
                    showScanner = true
                }) {
                    Text("Scan Room")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(width: 220, height: 60)
                        .background(Color.white)
                        .cornerRadius(30)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            RoomScannerView()
        }
    }
}
