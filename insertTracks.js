const SQL = require('sql-template-strings');
const { Pool } = require('pg');
const axios = require('axios')

// PSQL credentials, may vary for each machine */
const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'postgres',
    password: '2525',
    port: 5432,
})


const getArtist = async (uri) => {
    const url = 'http://localhost:8080/api/artist'
    return await axios.get(`${url}/${uri}`)
}

const insert = async () => {
    const poll_id  = 'a78f7cbf-5216-4a0b-8f78-6d433606f394'
    const url = 'http://localhost:8080/api/catalog/full?sort=asc&limit=100'

    try {
        let res = await axios.get(url)
        let data = res.data.Data
        for (let i = 0; i < data.length; i++) {
            // If it's not released, don't insert
            if (!data[i].Release.CatalogId) continue

            let artistsURI = data[i].Artists.map(artist => artist.URI)
            let requests = []
            for (let uri of artistsURI) {
                requests.push(getArtist(uri))
            }
            let details = {
                TrackID : data[i].Id,
                ArtistsTitle : data[i].ArtistsTitle,
                Title : data[i].Title,
                Version : data[i].Version,
                CatalogID : data[i].Release.CatalogId,
                ReleaseID : data[i].Release.Id
            }
            let poTitle = `${data[i].Title + ' ' + data[i].Version} - ${data[i].ArtistsTitle}`

            Promise.all(requests).
                then((values) => {
                    let artists = []
                    for (let i = 0; i < values.length; i++) {
                        let artist = {
                            ID : values[i].data.Id,
                            URI : values[i].data.URI,
                            Name : values[i].data.Name,
                            TwitterHandle : ""
                        }
                        // Check if artist have a twitter link, insert if they do
                        let twitterLink = values[i].data.Links.filter(link => link.Platform == "Twitter")
                        if (twitterLink) artist["TwitterHandle"] = twitterLink[0].URL
                        artists.push(artist)
                    }
                    details["Artists"] = artists
                    let detailsJSON = JSON.stringify(details)
                    res = pool.query(SQL
                        `
                        INSERT INTO poll_options (title, poll_id, details) VALUES (${poTitle}, ${poll_id}, ${detailsJSON})
                        `)
                }).
                catch(e => {
                    console.error(e)
                })
            }
    } catch (e) {
        console.log(e)
    }
}

insert()