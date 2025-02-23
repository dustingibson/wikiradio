const config = require("./config.json");
const express = require('express')
var busboy = require('connect-busboy');
const mysql = require('mysql2/promise');
const { exec } = require('child_process');
var cors = require('cors')
const { v4: uuidv4 } = require('uuid');

const app = express();
const port = 3032

app.use(busboy());
app.use(express.static(`${config['apppath']}/../data`));

async function connect() {
    return mysql.createConnection({
        host: config['sql']['host'],
        user: config['sql']['username'],
        password: config['sql']['password'],
        database: 'wikiradio'
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

async function updateMostRecent(userId, sectionId) {
    const query = `UPDATE USERS_PROGRESS SET last_accessed_date=? WHERE user_id=? AND wikipedia_section_id=?`;
    const con = await connect();
    await con.execute(query, [new Date(), userId, sectionId]);
    con.close();
}

async function updateSeekerProgress(userId, sectionId, progress) {
    const query = `UPDATE users_progress SET audio_progress=?, last_accessed_date=? WHERE user_id=? and wikipedia_section_id=?`;
    const con = await connect();
    await con.execute(query, [progress, new Date(), userId, sectionId]);
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
    for (sectionId of allSectionIds) {
        await con.execute(insert_query, [userId, sectionId, 'INPROGRESS', 0, new Date()]);
    }
    con.close();
}

async function getAllArticlesForUser(userId, wikiId) {
    const query = `SELECT wa.id 'article_id', ws.id 'section_id', wa.title 'article_title', ws.title 'section_title', up.audio_progress 'audio_progress', wa.url 'url', wa.version 'version', up.status 'status'
        FROM wikipedia_articles wa
        JOIN wikipedia_sections ws ON ws.wikipedia_article_id = wa.id
        JOIN users_progress up ON up.wikipedia_section_id = ws.id
        WHERE up.user_id = ? and wa.id=? and content != ''
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
            version: res['version'],
            status: res['status']
        }
    });
    con.close();
    return results;
}

async function getMostRecent(userId) {
    const query = `SELECT distinct  wa.id 'article_id', wa.title 'article_title', wa.version 'version', max(up.last_accessed_date)
        FROM wikipedia_articles wa
        JOIN wikipedia_sections ws on ws.wikipedia_article_id = wa.id
        JOIN users_progress up on up.wikipedia_section_id = ws.id
        WHERE user_id = ?
        GROUP BY  wa.id, wa.title, wa.version
        ORDER BY max(up.last_accessed_date) desc LIMIT 20`;
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

async function getWikipediaArticle(articleId) {
    const query = `SELECT id, title FROM WIKIPEDIA_ARTICLES WHERE id = ?`;
    const con = await connect();
    const results = (await con.query(query, [articleId]))[0].map(res => {
        return {
            id: res['id'],
            title: res['title']
        }
    });
    con.close();
    return results[0];
}

async function articleSearch(article) {
    const output = await new Promise((resolve, reject) => {
        const cmd = `cd "${config['etlpath']}" && python wiki.py download "${article}"`;
        exec(cmd, (err, stdout, stderr) => {
            if (err)
                console.log(err);
            resolve(stdout.split("~"));
        });
    });
    return {
        version: parseInt(output[2].trim()),
        title: output[3].trim(),
        id: output[1]
    };
}

async function getPlaysetPlaylist(id) {
    const get_query = `SELECT id, playset_id, wikipedia_article_id, play_order FROM PLAYSET_PLAYLIST WHERE id = ?`;
    const con = await connect();
    const results = (await con.query(get_query, [id]))[0].map(async res => {
        return {
            id: res['id'],
            playsetId: res['playset_id'],
            wikipediaArticle: await getWikipediaArticle(res['wikipedia_article_id']),
            playOrder: res['play_order']
        }
    });
    con.close();
    return results[0];
}

async function getPlaysetPlaylistFromPlaysetId(id) {
    const get_query = `SELECT id, playset_id, wikipedia_article_id, play_order FROM PLAYSET_PLAYLIST WHERE playset_id = ? ORDER BY play_order asc`;
    const con = await connect();
    const results = await Promise.all((await con.query(get_query, [id]))[0].map(async res => {
        return {
            id: res['id'],
            playsetId: res['playset_id'],
            wikipediaArticle: await getWikipediaArticle(res['wikipedia_article_id']),
            playOrder: res['play_order']
        }
    }));
    con.close();
    return results;
}

async function getUserPlaysetProgress(playset_id, username) {
    const userid = await getUserId(username);
    const get_query = `SELECT playset_playlist_id FROM PLAYSET_USERS_PROGRESS WHERE playset_id =? AND user_id = ?`;
    const con = await connect();
    const results = (await con.query(get_query, [playset_id, userid]))[0].map(res => {return {
        playsetPlaylistId: res['playset_playlist_id']}
    });
    con.close();
    if (results.length <= 0)
        return null;
    else
        return results[0].playsetPlaylistId;
}

async function getPlayset(id, username = null) {
    const get_query = `SELECT id, name FROM playset WHERE id = ?`;
    const playsetPlaylist = await getPlaysetPlaylistFromPlaysetId(id);
    const currentPlaylist = username ? await getUserPlaysetProgress(id, username) : null;
    const con = await connect();
    const results = (await con.query(get_query, [id]))[0].map(res => {
        return {
            id: res['id'],
            name: res['name'],
            currentPlaysetPlaylistId: username ? currentPlaylist : null,
            playlist: playsetPlaylist
        }
    });
    con.close();
    return results[0];
}

async function getNextPlaysetPlaylist(id, username) {
    const curPlaysetPlaylist = await getPlaysetPlaylist(id);
    const curPlayset = await getPlayset(curPlaysetPlaylist.playsetId);
    const curPlaylist = curPlayset.playlist;
    const curIndex = curPlaylist.indexOf( curPlaylist.find(c => c.id === id ) );
    if (curIndex + 1 >= curPlaylist.length) {
        await addToPlaysetUserProgress(username, curPlaylist[0].id)
        return curPlaylist[0];
    }
    await addToPlaysetUserProgress(username, curPlaylist[curIndex + 1].id)
    return curPlaylist[curIndex + 1];
}


async function getUserPlayset(username) {
    const userid = await getUserId(username);
    const userPlayset = `SELECT up.id 'users_playset_id', ps.id 'playset_id', name, last_accessed_date FROM USERS_PLAYSET up
                        JOIN PLAYSET ps ON ps.id = up.playset_id
                        WHERE user_id = ?
                        ORDER BY last_accessed_date LIMIT 20`;
    const con = await connect();
    const results = (await con.query(userPlayset, [userid]))[0].map((res => {
        return {
            usersPlaysetId: res['users_playset_id'],
            playsetId: res['playset_id'],
            name: res['name'],
        }
    }));
    con.close();
    return results;
}


async function searchPlayset(keyword) {
    const get_query = `SELECT id, name FROM playset WHERE name like ? LIMIT 20`;
    const con = await connect();
    const results = (await con.query(get_query, [`%${keyword}%`]))[0].map(res => {
        return {
            id: res['id'],
            name: res['name']
        }
    });
    con.close();
    return results;
}

async function createUserPlayset(username, playset_id) {
    const userid = await getUserId(username);
    const insert_query = `INSERT INTO USERS_PLAYSET (user_id, playset_id, last_accessed_date) values (?, ?, ?)`;
    const con = await connect();
    await con.execute(insert_query, [userid, playset_id, new Date()]);
    con.close();
}

async function removeUserPlayset(id) {
    const delete_query = `DELETE FROM USERS_PLAYSET WHERE id = ?`;
    const con = await connect();
    await con.execute(delete_query, [id]);
    con.close();
}

async function createPlayset(username, name) {
    const guid = uuidv4()
    const userid = await getUserId(username);
    const insert_query = `INSERT INTO PLAYSET (id, name, created_by) VALUES (?, ?, ?)`;
    const con = await connect()
    await con.execute(insert_query, [guid, name, userid]);
    con.close();
    return guid;
}

async function addToPlayset(playsetId, articleName, playOrder) {
    const article_info = await articleSearch(articleName);
    const insert_query = `INSERT INTO PLAYSET_PLAYLIST (playset_id, wikipedia_article_id, play_order) 
        VALUES (?, ?, ?)`;
    const con = await connect();
    await con.execute(insert_query, [playsetId, article_info.id, playOrder]);
    con.close();
}

async function addToPlaysetUserProgress(username, playsetPlaylistId) {
    const playset = await getPlaysetPlaylist(playsetPlaylistId);
    const userid = await getUserId(username);
    const insert_query = `INSERT INTO PLAYSET_USERS_PROGRESS (user_id, playset_id, playset_playlist_id) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE user_id = ?, playset_id = ? `;
    const con = await connect();
    await con.execute(insert_query, [userid, playset.playsetId, playsetPlaylistId, userid, playset.playsetId]);
    con.close();
}

async function removeFromPlayset(playsetPlaylistId) {
    const user_query = `DELETE FROM PLAYSET_USERS_PROGRESS WHERE playset_playlist_id = ?`;
    const query = `DELETE FROM PLAYSET_PLAYLIST WHERE id = ?`;
    const con = await connect();
    await con.execute(user_query, [playsetPlaylistId]);
    await con.execute(query, [playsetPlaylistId]);
    con.close();
}

async function removePlayset(playsetId) {
    const playset_playlist_user = `  DELETE p FROM PLAYSET_USERS_PROGRESS  p
        JOIN PLAYSET_PLAYLIST pl ON p.playset_playlist_id = pl.id
        WHERE pl.playset_id = ?;`
    const palyset_playlist_query = `DELETE FROM PLAYSET_PLAYLIST WHERE playset_id = ?`;
    const playset_query = `DELETE FROM PLAYSET WHERE id=?`;
    const con = await connect();
    await con.execute(playset_playlist_user, [playsetId]);
    await con.execute(palyset_playlist_query, [playsetId]);
    await con.execute(playset_query, [playsetId]);
    con.close();
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
    } catch (ex) {
        res.sendStatus(500);
    }
});

app.get('/user', async (req, res) => {
    try {
        const username = req.query.username;
        res.send(await getUser(username));
    } catch (ex) {
        res.sendStatus(500);
    }
});

app.get('/recent', async (req, res) => {
    try {
        const username = req.query.username;
        const userId = await getUserId(username);
        res.send(await getMostRecent(userId));
    } catch (ex) {
        res.sendStatus(500);
    }
});

app.get('/search', async (req, res) => {
    try {
        const article = req.query.article;
        const username = req.query.username;
        // Call python program
        const results = await articleSearch(article);
        res.send({
            article_id: results.id,
            article_title: results.title
        });
    } catch (err) {
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
            const path = `${config['apppath']}/${results[0].location_directory}/${toFname(id)}.MP3`.replace('/./', '/');
            res.download(path);
            return;
        }
        res.sendStatus(404);
    } catch (err) {
        console.log(err);
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
        res.send({
            status: 1,
            messsage: ''
        });
    } catch (err) {
        console.log(err);
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
        res.send({
            status: 1,
            messsage: ''
        });
    } catch (err) {
        console.log(err);
        res.sendStatus(500);
    }
});

app.put('/lastAccessed', async (req, res) => {
    try {
        const sectionId = req.query.sectionId;
        const username = req.query.username;
        const userId = await getUserId(username);
        await updateMostRecent(userId, sectionId);
        res.send({
            status: 1,
            message: ''
        })
    } catch (err) {
        console.log(err);
        res.sendStatus(500);
    }
})

// ----------------------------------------------------------

app.get('/searchPlayset', async (req, res) => {
    try {
        res.send(await searchPlayset(req.query.keyword));
    } catch (err) {
        res.sendStatus(500);
    }
});

app.get('/playset', async (req, res) => {
    try {
        res.send(await getPlayset(req.query.id, req.query.username));
    } catch (err) {
        res.sendStatus(500);
    }
});

app.get('/playsetPlaylist', async (req, res) => {
    try {
        res.send(await getPlaysetPlaylist(req.query.id));
    } catch (err) {
        res.sendStatus(500);
    }
});

app.get('/nextPlaysetPlaylist', async (req, res) => {
    try {
        res.send(await getNextPlaysetPlaylist(parseInt(req.query.id), req.query.username));
    } catch (err) {
        res.sendStatus(500);
    }
});


app.post('/playset', async (req, res) => {
    try {
        res.send({
            status: 1,
            id: await createPlayset(req.query.username, req.query.name)
        });
    } catch (err) {
        res.sendStatus(500);
    }
});

app.get('/userPlayset', async (req, res) => {
    try {
        res.send(await getUserPlayset(req.query.username));
    } catch (err) {
        res.sendStatus(500);
    }
});


app.post('/userPlayset', async (req, res) => {
    try {
        res.send({
            status: 1,
            id: await createUserPlayset(req.query.username, req.query.playsetId)
        });
    } catch (err) {
        res.sendStatus(500);
    }
});

app.delete('/userPlayset', async (req, res) => {
    try {
        res.send({
            status: 1,
            id: await removeUserPlayset(req.query.id)
        });
    } catch (err) {
        res.sendStatus(500);
    }
});

app.post('/playsetUsersProgress', async (req, res) => {
    try {
        await addToPlaysetUserProgress(req.query.username, parseInt(req.query.playsetPlaylistId));
        res.send({ status: 1 });
    } catch (err) {
        res.sendStatus(500);
    }
});

app.put('/playset', async (req, res) => {
    try {
        await addToPlayset(req.query.playsetId, req.query.articleName, req.query.playOrder);
        res.send({ status: 1 });
    } catch (err) {
        res.sendStatus(500);
    }
});

app.delete('/playsetPlaylist', async (req, res) => {
    try {
        await removeFromPlayset(parseInt(req.query.playsetPlaylistId));
        res.send({ status: 1 });
    } catch (ex) {
        res.sendStatus(500);
    }
});

app.delete('/playset', async (req, res) => {
    try {
        await removePlayset(req.query.playsetId);
        res.send({ status: 1 });
    } catch (err) {
        res.sendStatus(500);
    }
});

//-----------------------------------------------------------

app.listen(port, () =>
    console.log(`app listening on port ${port}!`),
);