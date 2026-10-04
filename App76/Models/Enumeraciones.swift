import Foundation

enum RolUsuario: String, Codable, CaseIterable, Hashable, Identifiable {
    case gerenteGeneral = "gerente_general"
    case gerenteSucursal = "gerente_sucursal"
    case cajero
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .gerenteGeneral: return "Gerente General"
        case .gerenteSucursal: return "Gerente de Sucursal"
        case .cajero: return "Cajero"
        }
    }
}

enum Combustible: String, Codable, CaseIterable, Hashable, Identifiable {
    case superior = "super"
    case regular
    case diesel
    var id: String { rawValue }
    var orden: Int { Combustible.allCases.firstIndex(of: self) ?? 0 }
    var nombre: String {
        switch self {
        case .superior: return "Súper"
        case .regular: return "Regular"
        case .diesel: return "Diésel"
        }
    }
}

enum EstadoCorte: String, Codable, Hashable {
    case enCurso = "en_curso"
    case cerrado
}

enum TipoCorte: String, Codable, CaseIterable, Hashable, Identifiable {
    case matutino
    case vespertino
    var id: String { rawValue }
    var nombre: String { self == .matutino ? "Matutino" : "Vespertino" }
}

enum TipoPerdida: String, Codable, CaseIterable, Hashable, Identifiable {
    case merma
    case fuga
    case fallaTecnica = "falla_tecnica"
    case derrame
    case contaminacion
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .merma: return "Merma"
        case .fuga: return "Fuga"
        case .fallaTecnica: return "Falla técnica"
        case .derrame: return "Derrame"
        case .contaminacion: return "Contaminación"
        }
    }
    /// Los tipos que el Gerente de Sucursal puede registrar a mano (contaminación solo sale del vaciado).
    static var manuales: [TipoPerdida] { [.merma, .fuga, .fallaTecnica, .derrame] }
}

enum OrigenLinea: String, Codable, Hashable {
    case manual
    case vaciado
}

enum MotivoVaciado: String, Codable, CaseIterable, Hashable, Identifiable {
    case descargaErronea = "descarga_erronea"
    case otraContaminacion = "otra_contaminacion_mantenimiento"
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .descargaErronea: return "Descarga de combustible equivocado"
        case .otraContaminacion: return "Otra contaminación o mantenimiento"
        }
    }
}

enum TipoArticulo: String, Codable, CaseIterable, Hashable, Identifiable {
    case producto
    case servicio
    var id: String { rawValue }
    var nombre: String { self == .producto ? "Producto" : "Servicio" }
}

enum CategoriaArticulo: String, Codable, CaseIterable, Hashable, Identifiable {
    case lubricantes
    case bebidas
    case snacks
    case otrosProductos = "otros_productos"
    case servicios
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .lubricantes: return "Lubricantes"
        case .bebidas: return "Bebidas"
        case .snacks: return "Snacks"
        case .otrosProductos: return "Otros productos"
        case .servicios: return "Servicios"
        }
    }
}

enum MotivoBaja: String, Codable, CaseIterable, Hashable, Identifiable {
    case vencido
    case danado
    case otro
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .vencido: return "Vencido"
        case .danado: return "Dañado"
        case .otro: return "Otro"
        }
    }
}

enum MetodoPago: String, Codable, CaseIterable, Hashable, Identifiable {
    case efectivo
    case tarjeta
    var id: String { rawValue }
    var nombre: String { self == .efectivo ? "Efectivo" : "Tarjeta (simulada)" }
}

enum EstadoVenta: String, Codable, Hashable {
    case completada
    case anulada
}

enum CargoEmpleado: String, Codable, CaseIterable, Hashable, Identifiable {
    case despachador
    case cajero
    case supervisor
    case mantenimiento
    case otro
    var id: String { rawValue }
    var nombre: String {
        switch self {
        case .despachador: return "Despachador"
        case .cajero: return "Cajero"
        case .supervisor: return "Supervisor"
        case .mantenimiento: return "Mantenimiento"
        case .otro: return "Otro"
        }
    }
}

/// Estado de un tanque tal como lo calcula la vista `v_estado_tanque` (el peor entre porcentaje y autonomía).
enum NivelAlerta: String, Codable, Hashable, Comparable {
    case critico
    case medio
    case optimo

    var nombre: String {
        switch self {
        case .critico: return "Crítico"
        case .medio: return "Medio"
        case .optimo: return "Óptimo"
        }
    }
    private var gravedad: Int { self == .critico ? 0 : (self == .medio ? 1 : 2) }
    static func < (a: NivelAlerta, b: NivelAlerta) -> Bool { a.gravedad < b.gravedad }
}
