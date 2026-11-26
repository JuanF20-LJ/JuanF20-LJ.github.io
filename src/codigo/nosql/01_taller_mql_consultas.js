//Parte A
//1
use("sample_mflix");

db.getCollection("movies").find({
    genres:"Drama",
    released: {
        $gte: ISODate('2000-01-01T00:00:00.000Z'),
        $lte: ISODate('2010-12-31T00:00:00.000Z')
    },
    'imdb.rating': {$gte: 8}
},{
    title:1, year:1, 'imdb.rating':1, _id:0
}).sort({'imdb.rating': -1}).limit(10);
 
//2 
use("sample_mflix");

db.getCollection("movies").find({
    cast:"Tom Hanks",
    directors:{$ne:"Steven Spielberg"}
},{title: 1, cast: 1, directors: 1, _id:0});

//3
use("sample_mflix");

db.getCollection("movies").find({
    genres: {$all: ["Comedy", "Romance"], $size:3}
},{title: 1, genres: 1, _id:0});

//4
use("sample_mflix");

db.getCollection("movies").find({
    $or: [
        {rated: {$exists: false}},
        {rated: {$eq: "NOT RATED"}},
        {rated: {$eq: "UNRATED"}}
    ]
},{title: 1, rated: 1, _id:0});

use("sample_mflix");

db.getCollection("movies").countDocuments({
    $or: [
        {rated: {$exists: false}},
        {rated: {$eq: "NOT RATED"}},
        {rated: {$eq: "UNRATED"}}
    ]
});

//5
use("sample_mflix");

db.getCollection("movies").find({
    title: {$regex:'^The.*man$', $options: 'i'}
}, {title: 1, _id:0});
