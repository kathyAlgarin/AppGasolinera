import SwiftUI

/// Corte diario (matutino o vespertino). Se registra la información de las 6 bombas,
/// que se puede seguir editando hasta pulsar "Guardar corte". Una vez guardado, las
/// bombas solo se pueden consultar.
struct CutFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let branch: Branch

    @State private var shift: CutShift = .morning
    @State private var showCloseConfirmation = false
    @State private var errorMessage: String?

    private var cut: FuelCut? { store.cut(for: branch.id, shift: shift) }

    private var isClosed: Bool { cut?.isClosed == true }

    private var blockedByMorning: Bool {
        shift == .evening && store.cut(for: branch.id, shift: .morning)?.isClosed != true
    }

    var body: some View {
        Form {
            Section("Corte") {
                Picker("Corte", selection: $shift) {
                    ForEach(CutShift.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(1...Pump.count, id: \.self) { pump in
                    let reading = cut?.readings.first(where: { $0.pumpNumber == pump })
                    if isClosed, let reading {
                        NavigationLink {
                            PumpDetailView(pump: pump, reading: reading)
                        } label: {
                            pumpRow(pump, detail: "\(Int(reading.totalSales)) L vendidos · ver detalle", done: true)
                        }
                    } else if blockedByMorning {
                        pumpRow(pump, detail: "Pendiente", done: false)
                    } else {
                        NavigationLink {
                            PumpReadingFormView(branch: branch, shift: shift, pump: pump)
                        } label: {
                            pumpRow(pump,
                                    detail: reading.map { "\(Int($0.totalSales)) L vendidos · editable" } ?? "Pendiente",
                                    done: reading != nil)
                        }
                    }
                }
            } header: {
                Text("Bombas registradas: \(cut?.readings.count ?? 0) de \(Pump.count)")
            } footer: {
                if isClosed {
                    Text("Corte guardado: ya no se puede editar, solo consultar el detalle de cada bomba.")
                } else if blockedByMorning {
                    Text("Debes guardar el corte matutino antes de registrar el vespertino.")
                } else {
                    Text("Puedes editar las bombas hasta que pulses \"Guardar corte\".")
                }
            }

            if let cut, !cut.readings.isEmpty {
                Section("Consolidado del corte") {
                    ForEach(FuelType.allCases) { type in
                        let t = cut.totals(for: type)
                        VStack(alignment: .leading, spacing: 4) {
                            Label(type.rawValue, systemImage: type.symbolName)
                                .font(.subheadline.bold())
                            Text("Ventas \(Int(t.sales)) L · Compras \(Int(t.purchases)) L · Pérdidas \(Int(t.losses)) L")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                }
            }

            if !isClosed && !blockedByMorning {
                Section {
                    Button("Guardar corte") { showCloseConfirmation = true }
                        .disabled(cut?.isComplete != true)
                } footer: {
                    if cut?.isComplete != true {
                        Text("Registra las 6 bombas para poder guardar el corte.")
                    }
                }
            }
        }
        .navigationTitle("Registrar corte")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
        }
        .onChange(of: shift) { _, _ in errorMessage = nil }
        .alert("¿Guardar el corte \(shift.rawValue)?", isPresented: $showCloseConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Guardar corte") {
                do {
                    try store.closeCut(branchID: branch.id, shift: shift)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text("Después de guardarlo no podrás editar la información de las bombas.")
        }
    }

    private func pumpRow(_ pump: Int, detail: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? .green : .secondary)
            VStack(alignment: .leading) {
                Text("Bomba \(pump)")
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Captura o edición de una bomba: para cada combustible, ventas, compras / recepción
/// y pérdidas o daños.
struct PumpReadingFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let branch: Branch
    let shift: CutShift
    let pump: Int

    @State private var salesTexts: [FuelType: String] = [:]
    @State private var purchasesTexts: [FuelType: String] = [:]
    @State private var lossesTexts: [FuelType: String] = [:]
    @State private var lossReasons: [FuelType: LossReason] = [:]
    @State private var errorMessage: String?

    private var existing: PumpReading? {
        store.cut(for: branch.id, shift: shift)?.readings.first { $0.pumpNumber == pump }
    }

    /// Vacío = 0. Nil si el texto no es un número válido (≥ 0).
    private func liters(_ text: String?) -> Double? {
        let clean = (text ?? "").trimmingCharacters(in: .whitespaces)
        if clean.isEmpty { return 0 }
        guard let value = Double(clean), value >= 0 else { return nil }
        return value
    }

    private func text(_ value: Double) -> String {
        value == 0 ? "" : (value == value.rounded() ? String(Int(value)) : String(value))
    }

    private func field(_ title: String, _ texts: Binding<[FuelType: String]>, _ type: FuelType) -> some View {
        let text = Binding(get: { texts.wrappedValue[type] ?? "" }, set: { texts.wrappedValue[type] = $0 })
        return HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .numericInput(text, decimal: true)
        }
    }

    var body: some View {
        Form {
            ForEach(FuelType.allCases) { type in
                Section {
                    field("Ventas (L)", $salesTexts, type)
                    field("Compras / recepción (L)", $purchasesTexts, type)
                    field("Pérdidas o daños (L)", $lossesTexts, type)
                    if (liters(lossesTexts[type]) ?? 0) > 0 {
                        Picker("Motivo", selection: Binding(
                            get: { lossReasons[type] ?? .shrinkage },
                            set: { lossReasons[type] = $0 }
                        )) {
                            ForEach(LossReason.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                } header: {
                    Label(type.rawValue, systemImage: type.symbolName)
                } footer: {
                    if let tank = store.projectedLevel(branchID: branch.id, fuelType: type, shift: shift, excludingPump: pump) {
                        Text("Tanque: \(Int(tank.level)) L disponibles · espacio libre \(Int(tank.capacity - tank.level)) L")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                }
            }

            Section {
                Button(existing == nil ? "Guardar bomba" : "Guardar cambios") { save() }
            } footer: {
                Text("Corte \(shift.rawValue). Deja en blanco lo que no aplique (cuenta como 0).")
            }
        }
        .navigationTitle("Bomba \(pump)")
        .dismissKeyboardSupport()
        .onAppear {
            guard let existing else { return }
            for (type, t) in existing.amounts {
                salesTexts[type] = text(t.sales)
                purchasesTexts[type] = text(t.purchases)
                lossesTexts[type] = text(t.losses)
                lossReasons[type] = t.lossReason
            }
        }
    }

    private func save() {
        var amounts: [FuelType: FuelTotals] = [:]
        for type in FuelType.allCases {
            guard let sales = liters(salesTexts[type]),
                  let purchases = liters(purchasesTexts[type]),
                  let losses = liters(lossesTexts[type]) else {
                errorMessage = "Ingresa cantidades válidas (números mayores o iguales a 0)."
                return
            }
            amounts[type] = FuelTotals(sales: sales, purchases: purchases, losses: losses,
                                       lossReason: losses > 0 ? (lossReasons[type] ?? .shrinkage) : nil)
        }
        do {
            try store.savePumpReading(branchID: branch.id, shift: shift, pumpNumber: pump, amounts: amounts)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Detalle de solo lectura de una bomba de un corte ya guardado.
struct PumpDetailView: View {
    let pump: Int
    let reading: PumpReading

    var body: some View {
        Form {
            ForEach(FuelType.allCases) { type in
                let t = reading.amounts[type] ?? FuelTotals()
                Section {
                    LabeledContent("Ventas", value: "\(Int(t.sales)) L")
                    LabeledContent("Compras / recepción", value: "\(Int(t.purchases)) L")
                    LabeledContent("Pérdidas o daños", value: "\(Int(t.losses)) L")
                    if t.losses > 0, let reason = t.lossReason {
                        LabeledContent("Motivo", value: reason.rawValue)
                    }
                } header: {
                    Label(type.rawValue, systemImage: type.symbolName)
                }
            }
        }
        .navigationTitle("Bomba \(pump)")
    }
}
