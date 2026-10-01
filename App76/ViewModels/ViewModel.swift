import Foundation
import Combine

class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    /// Reenvía los cambios de un servicio a las vistas que observan este ViewModel.
    func forwardChanges<O: ObservableObject>(from object: O) {
        object.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
