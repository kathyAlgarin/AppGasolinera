import Foundation
import Supabase

struct SupabaseDashboardService: DashboardService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func combustible(desde: String, hasta: String, sucursalId: UUID?) async throws -> [DashboardCombustible] {
        try await Traductor.ejecutar {
            var q = cliente.from("v_dashboard_combustible").select().gte("fecha_operativa", value: desde).lte("fecha_operativa", value: hasta)
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.execute().value
        }
    }

    func cortesCerrados(desde: String, hasta: String, sucursalId: UUID?) async throws -> [Corte] {
        try await Traductor.ejecutar {
            var q = cliente.from("cortes").select().eq("estado", value: "cerrado")
                .gte("fecha_operativa", value: desde).lte("fecha_operativa", value: hasta)
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.execute().value
        }
    }

    func tiendaIngresos(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaIngreso] {
        try await Traductor.ejecutar {
            var q = cliente.from("v_tienda_ingresos").select().gte("fecha_operativa", value: desde).lte("fecha_operativa", value: hasta)
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.execute().value
        }
    }

    func tiendaAnulaciones(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaAnulacion] {
        try await Traductor.ejecutar {
            var q = cliente.from("v_tienda_anulaciones").select().gte("fecha_operativa", value: desde).lte("fecha_operativa", value: hasta)
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.execute().value
        }
    }

    func tiendaCajas(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaCaja] {
        try await Traductor.ejecutar {
            var q = cliente.from("v_tienda_cajas").select().gte("fecha_operativa", value: desde).lte("fecha_operativa", value: hasta)
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.order("abierta_en", ascending: false).execute().value
        }
    }

    func stockBajo(sucursalId: UUID?) async throws -> [StockBajo] {
        try await Traductor.ejecutar {
            var q = cliente.from("v_stock_bajo").select()
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            return try await q.execute().value
        }
    }
}
