// =====================================================================
// BLOOM - Script completo de MongoDB
// Ejecutar con mongosh, por ejemplo:
//     mongosh -u admin -p --authenticationDatabase admin bloom_mongodb.js
// (Si Mongo aún no tiene usuarios, se puede correr sin -u / -p.)
// =====================================================================

// ---------------------------------------------------------------------
// PARTE 1. Usuario administrador (solo si no existe)
// ---------------------------------------------------------------------
db = db.getSiblingDB("admin");
if (db.getUser("admin") == null) {
  db.createUser({
    user: "admin",
    pwd: "TU_PASSWORD_ADMIN",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" }, { role: "readWriteAnyDatabase", db: "admin" } ]
  });
  print("Usuario admin creado.");
}

// ---------------------------------------------------------------------
// PARTE 2. Base bloom y usuario de la aplicación
// ---------------------------------------------------------------------
db = db.getSiblingDB("bloom");   // usa (y crea si no existe) la base bloom
// Es el que va en spring.data.mongodb.uri: mongodb://bloom_mongo:TU_PASSWORD@IP:27017/bloom?authSource=bloom
if (db.getUser("bloom_mongo") == null) {
  db.createUser({ user: "bloom_mongo", pwd: "TU_PASSWORD", roles: [ { role: "readWrite", db: "bloom" } ] });
  print("Usuario bloom_mongo creado.");
}

// ---------------------------------------------------------------------
// PARTE 3. Colecciones con validación ($jsonSchema)
// ---------------------------------------------------------------------
// Si la colección ya existe, solo le actualiza la validación (no borra datos).
// validationLevel "moderate": valida los documentos nuevos y los que se actualicen.
function crearColeccion(nombre, esquema) {
  if (db.getCollectionNames().indexOf(nombre) >= 0) {
    db.runCommand({ collMod: nombre, validator: { $jsonSchema: esquema }, validationLevel: "moderate" });
    print("Colección " + nombre + " actualizada.");
  } else {
    db.createCollection(nombre, { validator: { $jsonSchema: esquema }, validationLevel: "moderate" });
    print("Colección " + nombre + " creada.");
  }
}

// articulos: el artículo con sus 10 comentarios más recientes (Subset) y el total (Computed).
crearColeccion("articulos", {
  bsonType: "object",
  required: ["titulo", "contenido", "categoria", "fuente"],
  properties: {
    schemaVersion:   { bsonType: "int" },
    titulo:          { bsonType: "string" },
    resumen:         { bsonType: "string" },
    contenido:       { bsonType: "string" },
    urlImagen:       { bsonType: "string" },
    autor:           { bsonType: "string" },
    fechaPublicacion:{ bsonType: "date" },
    categoria:       { bsonType: "string" },
    fuente: {
      bsonType: "object",
      required: ["nombre"],
      properties: { nombre: { bsonType: "string" }, url: { bsonType: "string" } }
    },
    totalComentarios:     { bsonType: "int", minimum: 0 },
    comentariosRecientes: { bsonType: "array", maxItems: 10 }
  }
});

// comentarios: TODOS los comentarios. autora = copia de idUsuario y apodo de PostgreSQL (Extended Reference).
crearColeccion("comentarios", {
  bsonType: "object",
  required: ["idArticulo", "autora", "contenido", "fechaCreacion"],
  properties: {
    schemaVersion: { bsonType: "int" },
    idArticulo:    { bsonType: "string" },
    autora: {
      bsonType: "object",
      required: ["idUsuario", "apodo"],
      properties: { idUsuario: { bsonType: ["long", "int"] }, apodo: { bsonType: "string" } }
    },
    contenido:     { bsonType: "string", maxLength: 1000 },
    fechaCreacion: { bsonType: "date" },
    fechaEdicion:  { bsonType: ["date", "null"] }
  }
});

// estadisticas_resumen: un documento por usuaria, ya calculado (Computed). _id = idUsuario.
crearColeccion("estadisticas_resumen", {
  bsonType: "object",
  required: ["_id", "fechaCalculo"],
  properties: {
    _id:                     { bsonType: ["long", "int"] },
    schemaVersion:           { bsonType: "int" },
    fechaCalculo:            { bsonType: "date" },
    totalCiclos:             { bsonType: "int" },
    promedioDuracionCiclo:   { bsonType: ["double", "null"] },
    promedioDuracionPeriodo: { bsonType: ["double", "null"] },
    sintomasFrecuentes:      { bsonType: "array", maxItems: 5 }
  }
});

// estadisticas_mensuales: un documento por usuaria y mes (Bucket). _id = "idUsuario_año-mes".
crearColeccion("estadisticas_mensuales", {
  bsonType: "object",
  required: ["_id", "idUsuario", "anio", "mes"],
  properties: {
    _id:              { bsonType: "string" },
    schemaVersion:    { bsonType: "int" },
    idUsuario:        { bsonType: ["long", "int"] },
    anio:             { bsonType: "int" },
    mes:              { bsonType: "int", minimum: 1, maximum: 12 },
    diasRegistrados:  { bsonType: "int" },
    diasMenstruacion: { bsonType: "int" },
    ciclosFinalizados:  { bsonType: "array" },
    duracionesPeriodo:  { bsonType: "array" },
    sintomas:           { bsonType: "array" }
  }
});

// ---------------------------------------------------------------------
// PARTE 4. Índices (aceleran las consultas que hace el backend)
// ---------------------------------------------------------------------
db.articulos.createIndex({ categoria: 1, fechaPublicacion: -1 }, { name: "categoria_fecha" });
db.comentarios.createIndex({ idArticulo: 1, fechaCreacion: -1 }, { name: "articulo_fecha" });
db.comentarios.createIndex({ "autora.idUsuario": 1 }, { name: "autora" });
db.estadisticas_mensuales.createIndex({ idUsuario: 1, anio: 1, mes: 1 }, { name: "usuaria_anio_mes", unique: true });
print("Índices creados.");

// ---------------------------------------------------------------------
// PARTE 5. Artículos de ejemplo (solo si la colección está vacía)
// ---------------------------------------------------------------------
// Reemplázalos por artículos reales tomados de fuentes confiables (supuesto L.1).
if (db.articulos.countDocuments({}) === 0) {
  var hoy = new Date();
  function haceDias(n) { return new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() - n); }
  db.articulos.insertMany([
    { schemaVersion: NumberInt(1), titulo: "¿Qué es el ciclo menstrual? (ejemplo)", resumen: "Artículo de prueba para la categoría Ciclo menstrual.",
      contenido: "Texto de ejemplo. Reemplazar por el contenido del artículo tomado de una fuente confiable (L.1).",
      autor: "Autor de ejemplo", fechaPublicacion: haceDias(30), categoria: "Ciclo menstrual",
      fuente: { nombre: "Fuente de ejemplo", url: "https://example.com/articulo" },
      totalComentarios: NumberInt(0), comentariosRecientes: [] },
    { schemaVersion: NumberInt(1), titulo: "Autocuidado durante la menstruación (ejemplo)", resumen: "Artículo de prueba para la categoría Bienestar.",
      contenido: "Texto de ejemplo. Reemplazar por el contenido del artículo tomado de una fuente confiable (L.1).",
      autor: "Autor de ejemplo", fechaPublicacion: haceDias(20), categoria: "Bienestar",
      fuente: { nombre: "Fuente de ejemplo", url: "https://example.com/articulo" },
      totalComentarios: NumberInt(0), comentariosRecientes: [] },
    { schemaVersion: NumberInt(1), titulo: "Síntomas comunes del ciclo (ejemplo)", resumen: "Artículo de prueba para la categoría Síntomas.",
      contenido: "Texto de ejemplo. Reemplazar por el contenido del artículo tomado de una fuente confiable (L.1).",
      autor: "Autor de ejemplo", fechaPublicacion: haceDias(10), categoria: "Síntomas",
      fuente: { nombre: "Fuente de ejemplo", url: "https://example.com/articulo" },
      totalComentarios: NumberInt(0), comentariosRecientes: [] }
  ]);
  print("Artículos de ejemplo insertados.");
}

print("Listo. Colecciones: " + db.getCollectionNames().join(", "));
