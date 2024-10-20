const config = require("./config.json");
const express = require('express')
var busboy = require('connect-busboy');
const mysql = require('mysql2/promise');
const { exec } = require('child_process');
var cors = require('cors')

const app = express();
const port = 3032

app.use(busboy());
app.use(express.static('./../data'));

async function connect() {
    return mysql.createConnection({
        host     : config['sql']['host'],
        user     : config['sql']['username'],
        password : config['sql']['password'],
        database : 'wikiradio'
        });
}

app.use(cors());

async function setUser(username) {
    const insert_query = `INSERT INTO USERS (username, provider, last_logged_in) VALUES (?, ?, ?)`;
    const con = await connect()
    await con.execute(insert_query, [username, 'default', new Date()]);
    con.close();
} 

async function getUser(username) {
    const query = `SELECT id, username, provider, last_logged_in FROM USERS WHERE username=?`;
    const con = await connect();
    const [results, fileds] = await con.query(query, [username]);
    con.close();
    if (results.length > 0) {
        return {
            id: results[0]['id'],
            username: results[0]['username'],
            provider: results[0]['provider']
        };
    } else {
        await setUser(username);
        return await getUser(username);
    }
}

async function updateSeekerProgress(userId, sectionId, progress) {
    const query = `UPDATE users_progress SET audio_progress=? WHERE user_id=? and wikipedia_section_id=?`;
    const con = await connect();
    await con.execute(query, [progress, userId, sectionId]);
    con.close();
}

async function updateOverallProgress(userId, sectionId, status) {
    const query = `UPDATE users_progress SET audio_progress=0, status=? WHERE user_id=? and wikipedia_section_id=?`;
    const con = await connect();
    await con.execute(query, [status, userId, sectionId]);
    con.close();
}

async function getUserId(username) {
    const query = `SELECT id FROM USERS where username = ?`;
    const con = await connect();
    const [res, fields] = (await con.query(query, [username]));
    con.close();
    return res[0]['id'];
}

async function getAllSections(userId, wikiId) {
    //const query = `SELECT id FROM wikipedia_sections WHERE wikipedia_article_id = ?`;
    const query = `SELECT ws.id "id" FROM wikipedia_sections ws 
            LEFT JOIN USERS_PROGRESS up ON up.wikipedia_section_id = ws.id AND up.user_id=?
            WHERE  wikipedia_article_id = ? and up.id is null`
    const con = await connect();
    const res = (await con.query(query, [userId, wikiId]))[0].map(res => res['id']);
    con.close();
    return res;
}

async function addNewArticleForUser(userId, wikiId) {
    const insert_query = `INSERT INTO USERS_PROGRESS (user_id, wikipedia_section_id, status, audio_progress, last_accessed_date)
                        VALUES (?, ?, ?, ?, ?)`;
    const allSectionIds = await getAllSections(userId, wikiId);
    const con = await connect()
    for(sectionId of allSectionIds) {
        await con.execute(insert_query, [userId, sectionId, 'INPROGRESS', 0, new Date()]);
    }
    con.close();
}

async function getAllArticlesForUser(userId, wikiId) {
    const query = `SELECT wa.id 'article_id', ws.id 'section_id', wa.title 'article_title', ws.title 'section_title', up.audio_progress 'audio_progress', wa.url 'url', wa.version 'version'
        FROM wikipedia_articles wa
        JOIN wikipedia_sections ws ON ws.wikipedia_article_id = wa.id
        JOIN users_progress up ON up.wikipedia_section_id = ws.id
        WHERE up.user_id = ? and wa.id=? and up.status != 'COMPLETE' and content != ''
        ORDER BY ws.order_index asc`;
    const con = await connect();
    const results = (await con.query(query, [userId, wikiId]))[0].map(res => {
        return {
            article_id: res['article_id'],
            section_id: res['section_id'],
            article_title: res['article_title'],
            section_title: res['section_title'],
            audio_progress: res['audio_progress'],
            url: res['url'],
            version: res['version']
        }
    });
    con.close();
    return results;
}

async function getMostRecent(userId) {
    const query = `SELECT distinct t.article_id, t.article_title, t.version FROM (
        SELECT  wa.id 'article_id', wa.title 'article_title', wa.version 'version', up.last_accessed_date
        FROM wikipedia_articles wa
        JOIN wikipedia_sections ws on ws.wikipedia_article_id = wa.id
        JOIN users_progress up on up.wikipedia_section_id = ws.id
        WHERE user_id = ?
        ORDER BY up.last_accessed_date desc
        ) t LIMIT 10`;
    const con = await connect();
    const results = (await con.query(query, [userId]))[0].map(res => {
        return {
            article_id: res['article_id'],
            article_title: res['article_title'],
            version: res['version']
        }
    });
    con.close();
    return results;
}

function toFname(str) {
    return str.replace(/-/g, "_");
}

app.get('/article', async (req, res) => {
    try {
        const username = req.query.username;
        const wikiId = req.query.wikiId;
        const userId = await getUserId(username);
        await addNewArticleForUser(userId, wikiId);
        const results = await getAllArticlesForUser(userId, wikiId);
        res.send(results);
    } catch(ex) {
        res.sendStatus(500);
    }
});

app.get('/user', async (req, res) => {
    try {
        const username = req.query.username;
        res.send(await getUser(username));
    } catch(ex) {
        res.sendStatus(500);
    }
});

app.get('/recent', async (req, res) => {
    try {
        const username = req.query.username;
        const userId = await getUserId(username);
        res.send(await getMostRecent(userId));
    } catch(ex) {
        res.sendStatus(500);
    }
});

app.get('/search', async (req, res) => {
    try {
        const article = req.query.article;
        const username = req.query.username;
        // Call python program
        const output = await new Promise((resolve, reject) => {
            exec(`cd ../ETL && python wiki.py download "${article}"`, (err, stdout, stderr) => {
                resolve(stdout.split("~"));
            });
        });
        // Probably not needed?
        const version = parseInt(output[2].trim());
        const wikiId = output[1];
        res.send({
            article_id: wikiId
        });
    } catch(err) {
        res.sendStatus(500);
    }
});

// queery: id -> string
app.get('/audio', async (req, res) => {
    try {
        const id = req.query.id;
        const query = `SELECT location_directory FROM WIKIPEDIA_SECTIONS WHERE ID=?`;
        const con = await connect();
        const [results, field] = await con.query(query, [id]);
        con.close();
        if (results.length > 0) {
            const path = results[0].location_directory + "/" + toFname(id) + ".MP3";
            res.download(path);
            return;
        }
        res.sendStatus(404);
    } catch(err) {
        res.sendStatus(500);
    }
});

app.put('/audioProgress', async (req, res) => {
    try {
        const sectionId = req.query.sectionId;
        const username = req.query.username;
        const progress = req.query.progress;
        const userId = await getUserId(username);
        await updateSeekerProgress(userId, sectionId, progress);
        res.sendStatus(200);
    } catch(err) {
        res.sendStatus(500);
    }
});

app.put('/overallProgress', async (req, res) => {
    try {
        // STATUS
        // INPROGRESS - STARTED OR NOT YET STARTED
        // COMPLETED - COMPLETED
        const sectionId = req.query.sectionId;
        const username = req.query.username;
        const status = req.query.status;
        const userId = await getUserId(username);
        await updateOverallProgress(userId, sectionId, status);
        res.sendStatus(200);
    } catch(err) {
        res.sendStatus(500);
    }
});

// ----------------------------------------------------------

// TODO: Get playlist

// TODO: Add to playlist

// TODO: Remove from playlist

//-----------------------------------------------------------

app.listen(port, () =>
    console.log(`app listening on port ${port}!`),
);