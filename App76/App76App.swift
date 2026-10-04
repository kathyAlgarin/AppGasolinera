//
//  App76App.swift
//  App76
//
//  Punto de entrada de la app.
//

import SwiftUI

@main
struct App76App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "es_SV"))
        }
    }
}
