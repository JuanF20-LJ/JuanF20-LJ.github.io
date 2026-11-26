/* =====================================================================
   PRÁCTICA 3 - MONGODB BÁSICO - Base "restaurante"
   ---------------------------------------------------------------------
   Abrir la consola:   mongosh
   Copiar y pegar CASO POR CASO (así se ve el resultado de cada uno para
   la evidencia). No cargar el archivo completo con load(): los comandos
   "use" y "show" solo funcionan escritos en la consola.

   Colecciones:
     restaurantes  -> datos del restaurante, dirección y calificaciones (subdocumentos y arreglos)
     platos        -> menú de cada restaurante (referencia restauranteId)
     clientes      -> datos de los clientes
     pedidos       -> pedidos con sus ítems (referencia a cliente y restaurante)

   TEMAS
     0.  Preparar la base
     1.  Insertar documentos
     2.  Consultas básicas y proyección
     3.  Operadores de comparación y lógicos
     4.  Subdocumentos y arreglos
     5.  Expresiones regulares
     6.  Ordenar, limitar, contar y distinct
     7.  Actualizar documentos
     8.  Eliminar documentos
     9.  Agregaciones básicas
     10. Índices básicos
     11. Extra: dataset oficial "restaurants" de MongoDB
     12. Limpieza
   ===================================================================== */


/* =====================================================================
   TEMA 0. PREPARAR LA BASE
   ===================================================================== */

// Caso 0.1: Usar (y crear si no existe) la base "restaurante"
use restaurante                                   // una base se crea sola al insertar el primer documento

// Caso 0.2: Borrar las colecciones si ya existen (para poder repetir la práctica)
db.restaurantes.drop()
db.platos.drop()
db.clientes.drop()
db.pedidos.drop()

// Caso 0.3: Ver en qué base estoy y qué bases hay
db.getName()
show dbs


/* =====================================================================
   TEMA 1. INSERTAR DOCUMENTOS
   ===================================================================== */

// Caso 1.1: Insertar UN restaurante (insertOne). Si no se da _id, Mongo crea un ObjectId
db.restaurantes.insertOne({
  _id: 1,                                         // _id propio para poder referenciarlo fácil desde otras colecciones
  nombre: "La Brasa Roja",
  tipoCocina: "Colombiana",
  barrio: "Chapinero",
  direccion: {                                    // subdocumento: un objeto dentro del documento
    calle: "Calle 63",
    numero: "11-45",
    coord: [-74.0636, 4.6486]                     // [longitud, latitud]
  },
  calificaciones: [                               // arreglo de subdocumentos
    { fecha: ISODate("2026-01-15"), grado: "A", puntaje: 9 },
    { fecha: ISODate("2026-06-10"), grado: "B", puntaje: 7 }
  ],
  precioPromedio: 35000,
  abierto: true,
  servicios: ["domicilio", "parqueadero"]          // arreglo de textos
})

// Caso 1.2: Insertar VARIOS restaurantes (insertMany)
db.restaurantes.insertMany([
  {
    _id: 2, nombre: "Sushi Zen", tipoCocina: "Japonesa", barrio: "Usaquén",
    direccion: { calle: "Carrera 6", numero: "119-24", coord: [-74.0306, 4.6965] },
    calificaciones: [
      { fecha: ISODate("2026-02-20"), grado: "A", puntaje: 10 },
      { fecha: ISODate("2026-08-05"), grado: "A", puntaje: 9 }
    ],
    precioPromedio: 60000, abierto: true, servicios: ["domicilio", "reservas", "wifi"]
  },
  {
    _id: 3, nombre: "Pasta e Basta", tipoCocina: "Italiana", barrio: "Chapinero",
    direccion: { calle: "Calle 70", numero: "5-20", coord: [-74.0567, 4.6545] },
    calificaciones: [
      { fecha: ISODate("2026-03-11"), grado: "B", puntaje: 7 },
      { fecha: ISODate("2026-09-01"), grado: "C", puntaje: 5 }
    ],
    precioPromedio: 45000, abierto: true, servicios: ["reservas"]
  },
  {
    _id: 4, nombre: "Tacos El Güero", tipoCocina: "Mexicana", barrio: "Teusaquillo",
    direccion: { calle: "Calle 45", numero: "19-10", coord: [-74.0712, 4.6312] },
    calificaciones: [
      { fecha: ISODate("2026-04-02"), grado: "A", puntaje: 8 }
    ],
    precioPromedio: 28000, abierto: false, servicios: ["domicilio"]
  },
  {
    _id: 5, nombre: "Ajiaco de la Abuela", tipoCocina: "Colombiana", barrio: "La Candelaria",
    direccion: { calle: "Calle 11", numero: "4-15", coord: [-74.0726, 4.5981] },
    calificaciones: [
      { fecha: ISODate("2026-05-18"), grado: "A", puntaje: 10 },
      { fecha: ISODate("2026-10-22"), grado: "A", puntaje: 9 },
      { fecha: ISODate("2026-11-02"), grado: "B", puntaje: 8 }
    ],
    precioPromedio: 30000, abierto: true, servicios: ["domicilio", "parqueadero", "reservas"]
  },
  {
    _id: 6, nombre: "Burger Lab", tipoCocina: "Americana", barrio: "Usaquén",
    direccion: { calle: "Calle 116", numero: "15-30", coord: [-74.0451, 4.6971] },
    calificaciones: [
      { fecha: ISODate("2026-07-07"), grado: "C", puntaje: 4 }
    ],
    precioPromedio: 32000, abierto: true, servicios: ["domicilio", "wifi"],
    redesSociales: { instagram: "@burgerlab" }      // campo que los demás NO tienen: Mongo lo permite (esquema flexible)
  }
])

// Caso 1.3: Insertar el menú (platos) de los restaurantes
db.platos.insertMany([
  { _id: 101, restauranteId: 1, nombre: "Bandeja paisa",   categoria: "Fuerte",  precio: 38000, ingredientes: ["fríjol", "arroz", "chicharrón", "huevo"], vegetariano: false },
  { _id: 102, restauranteId: 1, nombre: "Arepa de choclo", categoria: "Entrada", precio: 12000, ingredientes: ["maíz", "queso"], vegetariano: true },
  { _id: 103, restauranteId: 2, nombre: "Roll California", categoria: "Fuerte",  precio: 42000, ingredientes: ["arroz", "cangrejo", "aguacate"], vegetariano: false },
  { _id: 104, restauranteId: 2, nombre: "Edamame",         categoria: "Entrada", precio: 15000, ingredientes: ["soya", "sal"], vegetariano: true },
  { _id: 105, restauranteId: 3, nombre: "Lasaña",          categoria: "Fuerte",  precio: 39000, ingredientes: ["pasta", "carne", "queso", "tomate"], vegetariano: false },
  { _id: 106, restauranteId: 3, nombre: "Tiramisú",        categoria: "Postre",  precio: 16000, ingredientes: ["café", "queso", "cacao"], vegetariano: true },
  { _id: 107, restauranteId: 4, nombre: "Tacos al pastor", categoria: "Fuerte",  precio: 26000, ingredientes: ["tortilla", "cerdo", "piña"], vegetariano: false },
  { _id: 108, restauranteId: 5, nombre: "Ajiaco",          categoria: "Fuerte",  precio: 32000, ingredientes: ["papa", "pollo", "guascas", "mazorca"], vegetariano: false },
  { _id: 109, restauranteId: 5, nombre: "Postre de natas", categoria: "Postre",  precio: 11000, ingredientes: ["leche", "azúcar"], vegetariano: true },
  { _id: 110, restauranteId: 6, nombre: "Hamburguesa doble", categoria: "Fuerte", precio: 34000, ingredientes: ["pan", "carne", "queso", "tomate"], vegetariano: false }
])

// Caso 1.4: Insertar clientes
db.clientes.insertMany([
  { _id: "C1", nombre: "Laura Gómez",  correo: "laura@correo.com",  ciudad: "Bogotá",   edad: 24, preferencias: ["Japonesa", "Italiana"] },
  { _id: "C2", nombre: "Andrés Ruiz",  correo: "andres@correo.com", ciudad: "Bogotá",   edad: 31, preferencias: ["Colombiana"] },
  { _id: "C3", nombre: "Camila Torres", correo: "camila@correo.com", ciudad: "Medellín", edad: 19, preferencias: ["Mexicana", "Americana"] },
  { _id: "C4", nombre: "Santiago Díaz", correo: "santi@correo.com",  ciudad: "Bogotá",   edad: 42 }    // sin preferencias
])

// Caso 1.5: Insertar pedidos (con referencias a cliente y restaurante, e ítems embebidos)
db.pedidos.insertMany([
  { _id: 1001, clienteId: "C1", restauranteId: 2, fecha: ISODate("2026-11-01T19:30:00Z"), estado: "ENTREGADO",
    items: [ { platoId: 103, nombre: "Roll California", cantidad: 2, precio: 42000 },
             { platoId: 104, nombre: "Edamame",         cantidad: 1, precio: 15000 } ], total: 99000 },
  { _id: 1002, clienteId: "C2", restauranteId: 1, fecha: ISODate("2026-11-02T13:00:00Z"), estado: "ENTREGADO",
    items: [ { platoId: 101, nombre: "Bandeja paisa",   cantidad: 1, precio: 38000 } ], total: 38000 },
  { _id: 1003, clienteId: "C1", restauranteId: 3, fecha: ISODate("2026-11-05T20:15:00Z"), estado: "CANCELADO",
    items: [ { platoId: 105, nombre: "Lasaña",          cantidad: 1, precio: 39000 },
             { platoId: 106, nombre: "Tiramisú",        cantidad: 2, precio: 16000 } ], total: 71000 },
  { _id: 1004, clienteId: "C3", restauranteId: 6, fecha: ISODate("2026-11-10T21:00:00Z"), estado: "EN_CAMINO",
    items: [ { platoId: 110, nombre: "Hamburguesa doble", cantidad: 3, precio: 34000 } ], total: 102000 },
  { _id: 1005, clienteId: "C2", restauranteId: 5, fecha: ISODate("2026-11-12T12:45:00Z"), estado: "ENTREGADO",
    items: [ { platoId: 108, nombre: "Ajiaco",          cantidad: 2, precio: 32000 },
             { platoId: 109, nombre: "Postre de natas", cantidad: 2, precio: 11000 } ], total: 86000 },
  { _id: 1006, clienteId: "C4", restauranteId: 1, fecha: ISODate("2026-11-20T18:10:00Z"), estado: "PENDIENTE",
    items: [ { platoId: 102, nombre: "Arepa de choclo", cantidad: 4, precio: 12000 } ], total: 48000 }
])

// Caso 1.6: Ver las colecciones creadas
show collections


/* =====================================================================
   TEMA 2. CONSULTAS BÁSICAS Y PROYECCIÓN
   find(filtro, proyección)
   ===================================================================== */

// Caso 2.1: Consultar todos los restaurantes
db.restaurantes.find()

// Caso 2.2: Consultar un solo documento (el primero que encuentre)
db.restaurantes.findOne()

// Caso 2.3: Consultar los restaurantes de cocina colombiana (igualdad)
db.restaurantes.find({ tipoCocina: "Colombiana" })

// Caso 2.4: Consultar con dos condiciones a la vez (coma = Y)
db.restaurantes.find({ barrio: "Chapinero", abierto: true })

// Caso 2.5: Consultar solo algunos campos (proyección: 1 = mostrar, 0 = ocultar)
db.restaurantes.find({}, { nombre: 1, barrio: 1, _id: 0 })      // el _id sale siempre, salvo que se ponga 0

// Caso 2.6: Consultar todo MENOS algunos campos
db.restaurantes.find({}, { calificaciones: 0, direccion: 0 })


/* =====================================================================
   TEMA 3. OPERADORES DE COMPARACIÓN Y LÓGICOS
   ===================================================================== */

// Caso 3.1: Consultar platos con precio mayor a 35.000 ($gt = mayor que)
db.platos.find({ precio: { $gt: 35000 } }, { nombre: 1, precio: 1, _id: 0 })

// Caso 3.2: Consultar platos entre 15.000 y 30.000 ($gte = mayor o igual, $lte = menor o igual)
db.platos.find({ precio: { $gte: 15000, $lte: 30000 } })

// Caso 3.3: Consultar restaurantes de varias cocinas ($in = está en la lista)
db.restaurantes.find({ tipoCocina: { $in: ["Japonesa", "Italiana", "Mexicana"] } }, { nombre: 1, tipoCocina: 1 })

// Caso 3.4: Consultar restaurantes que NO son colombianos ($ne = diferente, $nin = no está en la lista)
db.restaurantes.find({ tipoCocina: { $ne: "Colombiana" } }, { nombre: 1, tipoCocina: 1 })
db.restaurantes.find({ barrio: { $nin: ["Chapinero", "Usaquén"] } }, { nombre: 1, barrio: 1 })

// Caso 3.5: Consultar restaurantes de Usaquén O baratos ($or)
db.restaurantes.find({
  $or: [ { barrio: "Usaquén" }, { precioPromedio: { $lt: 30000 } } ]
}, { nombre: 1, barrio: 1, precioPromedio: 1 })

// Caso 3.6: $and explícito (necesario cuando se repite el mismo campo o se combinan varios $or)
db.platos.find({
  $and: [
    { $or: [ { categoria: "Entrada" }, { categoria: "Postre" } ] },
    { $or: [ { vegetariano: true }, { precio: { $lt: 12000 } } ] }
  ]
})

// Caso 3.7: Consultar los restaurantes que tienen el campo redesSociales ($exists)
db.restaurantes.find({ redesSociales: { $exists: true } })

// Caso 3.8: Consultar los clientes que NO tienen preferencias registradas
db.clientes.find({ preferencias: { $exists: false } })

// Caso 3.9: $not: platos cuyo precio NO es mayor a 30.000
db.platos.find({ precio: { $not: { $gt: 30000 } } }, { nombre: 1, precio: 1 })


/* =====================================================================
   TEMA 4. SUBDOCUMENTOS Y ARREGLOS
   ===================================================================== */

// Caso 4.1: Consultar por un campo de un subdocumento (notación de punto, va entre comillas)
db.restaurantes.find({ "direccion.calle": "Calle 63" })

// Caso 4.2: Consultar restaurantes que ofrecen domicilio (buscar un valor dentro de un arreglo)
db.restaurantes.find({ servicios: "domicilio" }, { nombre: 1, servicios: 1 })

// Caso 4.3: Consultar restaurantes que tienen domicilio Y reservas ($all = contiene todos)
db.restaurantes.find({ servicios: { $all: ["domicilio", "reservas"] } }, { nombre: 1, servicios: 1 })

// Caso 4.4: Consultar restaurantes con exactamente 2 servicios ($size = tamaño del arreglo)
db.restaurantes.find({ servicios: { $size: 2 } }, { nombre: 1, servicios: 1 })

// Caso 4.5: Consultar restaurantes con alguna calificación de grado "C"
db.restaurantes.find({ "calificaciones.grado": "C" }, { nombre: 1, calificaciones: 1 })

// Caso 4.6: Consultar restaurantes con UNA calificación que sea grado "A" Y puntaje 10 a la vez ($elemMatch)
db.restaurantes.find(
  { calificaciones: { $elemMatch: { grado: "A", puntaje: 10 } } },   // las dos condiciones en el MISMO elemento
  { nombre: 1 }
)

// Caso 4.7: Mostrar solo el primer elemento del arreglo de calificaciones ($slice)
db.restaurantes.find({}, { nombre: 1, calificaciones: { $slice: 1 } })

// Caso 4.8: Consultar pedidos que incluyen el plato 104 (buscar dentro de un arreglo de subdocumentos)
db.pedidos.find({ "items.platoId": 104 })

// Caso 4.9: Consultar platos que llevan queso
db.platos.find({ ingredientes: "queso" }, { nombre: 1, ingredientes: 1, _id: 0 })


/* =====================================================================
   TEMA 5. EXPRESIONES REGULARES
   ===================================================================== */

// Caso 5.1: Consultar restaurantes cuyo nombre empieza por "B" (^ = empieza por)
db.restaurantes.find({ nombre: /^B/ }, { nombre: 1 })

// Caso 5.2: Consultar platos que contienen "taco" sin importar mayúsculas (la "i" ignora mayúsculas)
db.platos.find({ nombre: /taco/i })

// Caso 5.3: Lo mismo con el operador $regex
db.clientes.find({ correo: { $regex: "correo\\.com$" } }, { nombre: 1, correo: 1 })   // $ = termina en; \\. = punto literal


/* =====================================================================
   TEMA 6. ORDENAR, LIMITAR, CONTAR Y DISTINCT
   ===================================================================== */

// Caso 6.1: Consultar platos ordenados por precio de mayor a menor (1 = ascendente, -1 = descendente)
db.platos.find({}, { nombre: 1, precio: 1, _id: 0 }).sort({ precio: -1 })

// Caso 6.2: Consultar los 3 platos más baratos
db.platos.find({}, { nombre: 1, precio: 1, _id: 0 }).sort({ precio: 1 }).limit(3)

// Caso 6.3: Paginación: saltar los primeros 3 y traer los siguientes 3
db.platos.find({}, { nombre: 1, _id: 0 }).sort({ nombre: 1 }).skip(3).limit(3)

// Caso 6.4: Ordenar por dos campos: barrio ascendente y precio descendente
db.restaurantes.find({}, { nombre: 1, barrio: 1, precioPromedio: 1, _id: 0 }).sort({ barrio: 1, precioPromedio: -1 })

// Caso 6.5: Contar documentos
db.restaurantes.countDocuments()
db.restaurantes.countDocuments({ abierto: true })
db.pedidos.countDocuments({ estado: "ENTREGADO" })

// Caso 6.6: Valores distintos de un campo
db.restaurantes.distinct("tipoCocina")
db.platos.distinct("categoria")
db.restaurantes.distinct("servicios")              // en un arreglo, saca cada valor por separado


/* =====================================================================
   TEMA 7. ACTUALIZAR DOCUMENTOS
   updateOne(filtro, cambios) / updateMany(filtro, cambios)
   ===================================================================== */

// Caso 7.1: Cambiar el precio promedio de un restaurante ($set cambia o crea el campo)
db.restaurantes.updateOne({ _id: 4 }, { $set: { precioPromedio: 30000, abierto: true } })
db.restaurantes.findOne({ _id: 4 }, { nombre: 1, precioPromedio: 1, abierto: 1 })

// Caso 7.2: Cambiar un campo de un subdocumento
db.restaurantes.updateOne({ _id: 3 }, { $set: { "direccion.numero": "5-22" } })

// Caso 7.3: Subir 2.000 a todos los platos fuertes ($inc suma; con número negativo resta)
db.platos.updateMany({ categoria: "Fuerte" }, { $inc: { precio: 2000 } })
db.platos.find({ categoria: "Fuerte" }, { nombre: 1, precio: 1, _id: 0 })

// Caso 7.4: Agregar una calificación al arreglo ($push)
db.restaurantes.updateOne(
  { _id: 6 },
  { $push: { calificaciones: { fecha: new Date(), grado: "B", puntaje: 7 } } }   // new Date() = fecha y hora actual
)

// Caso 7.5: Agregar un servicio sin repetirlo ($addToSet solo agrega si no está)
db.restaurantes.updateOne({ _id: 1 }, { $addToSet: { servicios: "wifi" } })
db.restaurantes.updateOne({ _id: 1 }, { $addToSet: { servicios: "wifi" } })      // la 2.ª vez no cambia nada (modifiedCount: 0)

// Caso 7.6: Quitar un valor de un arreglo ($pull)
db.restaurantes.updateMany({}, { $pull: { servicios: "parqueadero" } })

// Caso 7.7: Eliminar un campo ($unset)
db.restaurantes.updateOne({ _id: 6 }, { $unset: { redesSociales: "" } })

// Caso 7.8: Renombrar un campo en todos los documentos ($rename)
db.clientes.updateMany({}, { $rename: { ciudad: "ciudadResidencia" } })
db.clientes.find({}, { nombre: 1, ciudadResidencia: 1 })

// Caso 7.9: Cambiar el estado de un pedido y guardar la fecha del cambio ($currentDate)
db.pedidos.updateOne(
  { _id: 1004 },
  { $set: { estado: "ENTREGADO" }, $currentDate: { fechaEntrega: true } }
)

// Caso 7.10: Modificar SOLO el ítem que cumple el filtro dentro de un arreglo (operador posicional $)
db.pedidos.updateOne(
  { _id: 1005, "items.platoId": 109 },
  { $set: { "items.$.cantidad": 3 } }              // $ = "el elemento que coincidió en el filtro"
)

// Caso 7.11: UPSERT: actualiza si existe; si no, lo inserta
db.clientes.updateOne(
  { _id: "C5" },
  { $set: { nombre: "Valentina Mora", correo: "vale@correo.com", edad: 27 } },
  { upsert: true }                                 // como no existe C5, lo crea (upsertedId)
)

// Caso 7.12: Reemplazar un documento completo (replaceOne: se pierden los campos que no se envíen)
db.clientes.replaceOne(
  { _id: "C4" },
  { nombre: "Santiago Díaz", correo: "santiago.diaz@correo.com", edad: 43, preferencias: ["Colombiana"] }
)
db.clientes.findOne({ _id: "C4" })


/* =====================================================================
   TEMA 8. ELIMINAR DOCUMENTOS
   ===================================================================== */

// Caso 8.1: Eliminar un pedido (deleteOne borra el primero que coincida)
db.pedidos.deleteOne({ _id: 1003 })

// Caso 8.2: Eliminar todos los pedidos pendientes (deleteMany)
db.pedidos.deleteMany({ estado: "PENDIENTE" })

// Caso 8.3: Buscar y eliminar a la vez, devolviendo el documento borrado
db.clientes.findOneAndDelete({ _id: "C5" })

// Caso 8.4: Verificar
db.pedidos.find({}, { _id: 1, estado: 1 })
// Nota: db.coleccion.deleteMany({}) borra TODOS los documentos pero deja la colección y sus índices.


/* =====================================================================
   TEMA 9. AGREGACIONES BÁSICAS
   aggregate([ etapa1, etapa2, ... ]): los documentos pasan por cada etapa en orden.
   ===================================================================== */

// Caso 9.1: Contar restaurantes por tipo de cocina ($group; "$campo" con $ = valor del campo)
db.restaurantes.aggregate([
  { $group: { _id: "$tipoCocina", cantidad: { $sum: 1 } } },
  { $sort: { cantidad: -1 } }
])

// Caso 9.2: Precio promedio, mínimo y máximo de los platos por categoría
db.platos.aggregate([
  { $group: {
      _id: "$categoria",
      promedio: { $avg: "$precio" },
      minimo:   { $min: "$precio" },
      maximo:   { $max: "$precio" },
      platos:   { $push: "$nombre" }               // junta los nombres en un arreglo
  } }
])

// Caso 9.3: Total vendido por restaurante, solo pedidos entregados ($match filtra, como un WHERE)
db.pedidos.aggregate([
  { $match: { estado: "ENTREGADO" } },
  { $group: { _id: "$restauranteId", ventas: { $sum: "$total" }, pedidos: { $sum: 1 } } },
  { $sort: { ventas: -1 } }
])

// Caso 9.4: Calcular el puntaje promedio de cada restaurante ($project crea o transforma campos)
db.restaurantes.aggregate([
  { $project: {
      _id: 0,
      nombre: 1,
      numCalificaciones: { $size: "$calificaciones" },
      puntajePromedio:   { $round: [ { $avg: "$calificaciones.puntaje" }, 1 ] }
  } },
  { $sort: { puntajePromedio: -1 } }
])

// Caso 9.5: Platos más vendidos ($unwind "desarma" el arreglo: un documento por cada ítem)
db.pedidos.aggregate([
  { $unwind: "$items" },
  { $group: { _id: "$items.nombre", unidades: { $sum: "$items.cantidad" } } },
  { $sort: { unidades: -1 } },
  { $limit: 3 }
])

// Caso 9.6: Pedidos con el nombre del cliente y del restaurante ($lookup = parecido a un JOIN)
db.pedidos.aggregate([
  { $lookup: { from: "clientes",     localField: "clienteId",     foreignField: "_id", as: "cliente" } },
  { $lookup: { from: "restaurantes", localField: "restauranteId", foreignField: "_id", as: "restaurante" } },
  { $unwind: "$cliente" },                         // $lookup devuelve un arreglo; $unwind lo vuelve objeto
  { $unwind: "$restaurante" },
  { $project: { _id: 1, fecha: 1, total: 1, estado: 1,
                cliente: "$cliente.nombre", restaurante: "$restaurante.nombre" } }
])

// Caso 9.7: Cada restaurante con su menú ($lookup inverso: un restaurante -> muchos platos)
db.restaurantes.aggregate([
  { $lookup: { from: "platos", localField: "_id", foreignField: "restauranteId", as: "menu" } },
  { $project: { _id: 0, nombre: 1, platos: "$menu.nombre", cantidadPlatos: { $size: "$menu" } } }
])

// Caso 9.8: Clasificar los platos por rango de precio ($cond = si/entonces/si no)
db.platos.aggregate([
  { $project: {
      _id: 0, nombre: 1, precio: 1,
      rango: { $cond: { if: { $gte: ["$precio", 35000] }, then: "Costoso", else: "Económico" } }
  } }
])

// Caso 9.9: Cuánto ha gastado cada cliente, solo los que superan 50.000 ($match DESPUÉS del $group = HAVING)
db.pedidos.aggregate([
  { $group: { _id: "$clienteId", gastado: { $sum: "$total" } } },
  { $match: { gastado: { $gt: 50000 } } }
])


/* =====================================================================
   TEMA 10. ÍNDICES BÁSICOS
   ===================================================================== */

// Caso 10.1: Ver los índices de una colección (siempre existe el de _id)
db.restaurantes.getIndexes()

// Caso 10.2: Ver el plan de una consulta SIN índice (COLLSCAN = recorre toda la colección)
db.restaurantes.find({ tipoCocina: "Colombiana" }).explain("executionStats")

// Caso 10.3: Crear un índice simple y repetir la consulta (IXSCAN = usa el índice)
db.restaurantes.createIndex({ tipoCocina: 1 })
db.restaurantes.find({ tipoCocina: "Colombiana" }).explain("executionStats")
// En la salida, buscar: winningPlan -> stage (COLLSCAN o IXSCAN) y executionStats.totalDocsExamined

// Caso 10.4: Índice compuesto con nombre propio
db.platos.createIndex({ restauranteId: 1, precio: -1 }, { name: "restaurante_precio" })

// Caso 10.5: Índice único: impide correos repetidos
db.clientes.createIndex({ correo: 1 }, { unique: true })
db.clientes.insertOne({ _id: "C9", nombre: "Repetida", correo: "laura@correo.com" })   // falla: E11000 duplicate key

// Caso 10.6: Índice de texto para buscar palabras
db.platos.createIndex({ nombre: "text" })
db.platos.find({ $text: { $search: "tacos" } })    // busca por palabra (y sus variantes en inglés)

// Caso 10.7: Eliminar un índice por su nombre
db.platos.getIndexes()
db.platos.dropIndex("restaurante_precio")


/* =====================================================================
   TEMA 11. EXTRA: DATASET OFICIAL "restaurants" DE MONGODB
   Solo si se tiene cargado el dataset de ejemplo de MongoDB
   (en Atlas: base sample_restaurants, colección restaurants;
    en el tutorial clásico: base test, colección restaurants).
   Campos: name, borough, cuisine, address{building, street, zipcode, coord}, grades[{date, grade, score}]
   ===================================================================== */

// Caso 11.1: Cambiar a la base del dataset
// use sample_restaurants

// Caso 11.2: Consultar restaurantes italianos de Manhattan
// db.restaurants.find({ borough: "Manhattan", cuisine: "Italian" }, { name: 1, _id: 0 }).limit(10)

// Caso 11.3: Consultar restaurantes con alguna calificación mayor a 90
// db.restaurants.find({ "grades.score": { $gt: 90 } }, { name: 1, "grades.score": 1 })

// Caso 11.4: Contar restaurantes por barrio (borough)
// db.restaurants.aggregate([ { $group: { _id: "$borough", total: { $sum: 1 } } }, { $sort: { total: -1 } } ])

// Caso 11.5: Los 5 tipos de cocina más comunes
// db.restaurants.aggregate([ { $group: { _id: "$cuisine", total: { $sum: 1 } } }, { $sort: { total: -1 } }, { $limit: 5 } ])

// Caso 11.6: Volver a la base de la práctica
// use restaurante


/* =====================================================================
   TEMA 12. LIMPIEZA
   ===================================================================== */

// Caso 12.1: Borrar una colección completa (documentos e índices)
// db.pedidos.drop()

// Caso 12.2: Borrar la base completa (estando dentro de ella)
// db.dropDatabase()
