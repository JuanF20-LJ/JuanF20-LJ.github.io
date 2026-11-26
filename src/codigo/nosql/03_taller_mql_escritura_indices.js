//Parte C
//11
use("sample_mflix");

db.getCollection("movies").aggregate([
    { $match: { year: 2015, 'imdb.rating': { $type: "number" } } },
    { $addFields: { categoria: { $switch: {
        branches: [
            { case: { $gte: ["$imdb.rating", 7.5] }, then: "Alta" },
            { case: { $gte: ["$imdb.rating", 6] },   then: "Media" }
        ],
        default: "Baja"
    } } } },
    { $project: { title: 1, genres: 1, 'imdb.rating': 1, categoria: 1, _id: 0 } },
    { $out: "peliculas_pareja" }
]);

use("sample_mflix");
db.getCollection("peliculas_pareja").find();

//12
use("sample_mflix");

const resultado = db.getCollection("peliculas_pareja").updateMany(
    { categoria: "Media" },
    { $set: { revisado: true }, $inc: { "imdb.rating": 0.1 } }
);

print("matchedCount: " + resultado.matchedCount);
print("modifiedCount: " + resultado.modifiedCount);

//13
use("sample_mflix");

const resultado = db.getCollection("peliculas_pareja").deleteMany({
    categoria: "Baja"
});

print("Documentos eliminados: " + resultado.deletedCount);

//14
//14.1 - Ejecución punto 1 con ".explain("executionStats")"
db.getCollection("movies").find({
    genres:"Drama",
    released: {
        $gte: ISODate('2000-01-01T00:00:00.000Z'),
        $lte: ISODate('2010-12-31T00:00:00.000Z')
    },
    'imdb.rating': {$gte: 8}
},{
    title:1, year:1, 'imdb.rating':1, _id:0
}).sort({'imdb.rating': -1}).limit(10).explain("executionStats");
/**
 * totalDocsExamined: 21349
 * executionTimeMillis: 27
 */
//14.2 - Crear el índice
db.getCollection("movies").createIndex({
    genres: 1,
    "imdb.rating": -1,
    released: 1
});
//14.3 - Ejecutar 14.1 otra vez
/**
 * totalDocsExamined: 10
 * executionTimeMillis: 1
 */
//14.4 - Eliminar índice
db.getCollection("movies").dropIndex(
    "genres_1_imdb.rating_-1_released_1"
);
