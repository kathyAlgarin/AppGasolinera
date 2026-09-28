//
//  App76App.swift
//  App76
//
//  Punto de entrada de la app. Inyecta el AppStore (estado global +
//  lógica de negocio) a todo el árbol de vistas.
//

import SwiftUI
import UIKit

/// Ignora los toques dentro de campos de texto para no ocultar el teclado al enfocarlos.
private final class KeyboardTapDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardTapDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// Tocar fuera de un campo de texto oculta el teclado en toda la app (los teclados
/// numéricos no tienen tecla "return"). Necesita UIKit porque SwiftUI no lo ofrece.
private func installKeyboardDismissTap() {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
          !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === KeyboardTapDelegate.shared })
    else { return }
    let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing(_:)))
    tap.cancelsTouchesInView = false
    tap.delegate = KeyboardTapDelegate.shared
    window.addGestureRecognizer(tap)
}

@main
struct App76App: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear { DispatchQueue.main.async { installKeyboardDismissTap() } }
        }
    }
}
