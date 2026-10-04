import Foundation

func pruebasValidadores() async {
    await grupo("Validadores numéricos") {
        igual(Validadores.filtrarDecimal("12.345"), "12.34", "recorta a 2 decimales")
        igual(Validadores.filtrarDecimal("abc1-2.5x"), "12.5", "descarta letras y signos")
        igual(Validadores.filtrarDecimal("-5"), "5", "sin negativos")
        igual(Validadores.filtrarDecimal("1.2.3"), "1.23", "un solo punto")
        igual(Validadores.filtrarDecimal("3,5"), "3.5", "coma a punto")
        igual(Validadores.filtrarDecimal(""), "", "vacío")
        igual(Validadores.filtrarDecimal("٣"), "", "dígitos no ASCII fuera")
        igual(Validadores.filtrarEntero("12.5"), "125", "entero sin punto")
        igual(Validadores.decimal("12.5"), Decimal(string: "12.5"), "parsea decimal")
        verificar(Validadores.decimal("") == nil, "vacío = nil")
        verificar(Validadores.decimal(".") == nil, "solo punto = nil")
        igual(Validadores.entero("7"), 7, "entero")
        verificar(Validadores.entero("") == nil, "entero vacío")
    }
    await grupo("Validadores de texto") {
        verificar(Validadores.esCorreoValido("a@b.com"), "correo válido")
        verificar(Validadores.esCorreoValido(" A@B.com "), "correo con espacios y mayúsculas")
        verificar(!Validadores.esCorreoValido("a@b"), "sin dominio")
        verificar(!Validadores.esCorreoValido("ab.com"), "sin arroba")
        verificar(!Validadores.esCorreoValido("a b@c.com"), "con espacio interno")
        igual(Validadores.correo("  Ana@Gmail.COM "), "ana@gmail.com", "normaliza correo")
        verificar(Validadores.passwordValida("12345678"), "8 caracteres")
        verificar(!Validadores.passwordValida("1234567"), "7 caracteres")
        verificar(!Validadores.passwordValida(String(repeating: "a", count: 73)), "73 caracteres")
    }
}
