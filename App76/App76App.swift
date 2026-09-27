//
//  App76App.swift
//  App76
//
//  Punto de entrada de la app. Inyecta el AppStore (estado global +
//  lógica de negocio) a todo el árbol de vistas.
//

import SwiftUI

@main
struct App76App: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
