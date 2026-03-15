import SwiftUI

struct SlideshowView: View {
    let images: [UIImage]
    let startIndex: Int
    @State private var current: Int = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear { current = startIndex }
    }
}//
//  SlideshowView.swift.swift
//  Renderable
//
//  Created by Kasper Muutra on 12.03.2026.
//

