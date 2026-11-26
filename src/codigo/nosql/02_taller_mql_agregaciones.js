//Parte B
//6
use("sample_mflix");

db.getCollection("movies").aggregate([
    {
        $match: {
            "imdb.rating": { $type: "number" },
            genres: { $exists: true, $ne: null }
        }
    },
    {
        $unwind: "$genres"
    },
    {
        $group: {
            _id: "$genres",
            cantidadPeliculas: { $sum: 1 },
            promedioRating: { $avg: "$imdb.rating" },
            ratingMaximo: { $max: "$imdb.rating" }
        }
    },
    {
        $match: {
            cantidadPeliculas: { $gt: 500 }
        }
    },
    {
        $project: {
            _id: 0,
            genero: "$_id",
            cantidadPeliculas: 1,
            promedioRating: {
                $round: ["$promedioRating", 2]
            },
            ratingMaximo: 1
        }
    },
    {
        $sort: {
            promedioRating: -1
        }
    }
]);  

//7
db.getCollection("movies").aggregate([
    {
        $match: {
            "imdb.rating": { $gte: 7.5 },
            directors: { $exists: true, $ne: null }
        }
    },
    {
        $unwind: "$directors"
    },
    {
        $group: {
            _id: "$directors",
            cantidadPeliculas: { $sum: 1 },
            titulos: { $push: "$title" }
        }
    },
    {
        $match: {
            cantidadPeliculas: { $gte: 5 }
        }
    },
    {
        $project: {
            _id: 0,
            director: "$_id",
            cantidadPeliculas: 1,
            titulos: {
                $slice: ["$titulos", 3]
            }
        }
    },
    {
        $sort: {
            cantidadPeliculas: -1
        }
    },
    {
        $limit: 5
    }
]);

//8
db.getCollection("movies").aggregate([
    {
        $match: {
            year: { $gte: 1950, $type: "number" }
        }
    },
    {
        $group: {
            _id: {
                $multiply: [
                    { $floor: { $divide: ["$year", 10] } },
                    10
                ]
            },
            cantidadPeliculas: { $sum: 1 }
        }
    },
    {
        $project: {
            _id: 0,
            decada: {
                $concat: [
                    { $toString: "$_id" },
                    "s"
                ]
            },
            cantidadPeliculas: 1
        }
    },
    {
        $sort: {
            _id: 1
        }
    }
]);

//9


//10
db.getCollection("comments").aggregate([
    {
        $match: {
            email: { $exists: true, $ne: null },
            date: { $type: "date" }
        }
    },
    {
        $group: {
            _id: "$email",
            cantidadComentarios: { $sum: 1 },
            primerComentario: { $min: "$date" },
            ultimoComentario: { $max: "$date" }
        }
    },
    {
        $match: {
            cantidadComentarios: { $gt: 250 }
        }
    },
    {
        $project: {
            _id: 0,
            email: "$_id",
            cantidadComentarios: 1,
            primerComentario: 1,
            ultimoComentario: 1
        }
    },
    {
        $sort: {
            cantidadComentarios: -1
        }
    }
]);
