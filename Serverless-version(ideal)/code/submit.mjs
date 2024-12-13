// Import MySQL library (promise-based version)
import mysql from 'mysql2/promise';
import { URL } from 'url';
const frontend_url = "https://benefits.hashstudiosllc.com"

// Create a MySQL connection config
const dbConfig = {
    host: process.env.DB_HOST,         // RDS endpoint
    user: process.env.DB_USER,         // Database username
    password: process.env.DB_PASSWORD, // Database password
    database: process.env.DB_NAME,     // Database name
    port: process.env.DB_PORT || 3306  // Default MySQL port
};

// Lambda function handler
export const handler = async (event) => {
    const { username, display, url } = JSON.parse(event.body);
    if (!username || !display || !url) {
        console.info("Missing required fields.");
        return {
            statusCode: 400,
            body: JSON.stringify({ message: 'Missing required fields.' })
        };
    }
    console.info("[+] Detected data");

    //Verify data
    //check if url on domain whitelist
    const validDomains = [
        'media.discordapp.net',
        'cdn.discordapp.com',
        'dl.dropbox.com',
        '*.github.io',
        'images4.imagebam.com',
        'i.ibb.co',
        'images2.imgbox.com',
        'i.imgur.com',
        'i.postimg.cc',
        'i.redd.it',
        'pbs.twimg.com',
        'assets.vrchat.com'
    ];
    const domain = new URL(url).hostname;
    const isValidDomain = validDomains.some(validDomain => {
        if (validDomain.startsWith('*')) {
            return domain.endsWith(validDomain.slice(1));
        }
        return domain === validDomain;
    });
    if (!isValidDomain) {
        console.error('Invalid image URL domain: '+url);
        return {
            statusCode: 302,
            headers: {
                Location: frontend_url + '/err_dataenter.html'
            },
            body: JSON.stringify({ message: 'URL invalid error...' })};
    }



    // SQL Query to insert data
    //const sqlQuery = 'INSERT INTO users (username, display, url) VALUES (?, ?, ?)';
    const sqlQuery = `INSERT INTO ${process.env.DB_TABLE} (username, url, display) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE username = VALUES(username), url = VALUES(url), display = VALUES(display)`;

    let connection;
    try {
        // Initialize database connection
        connection = await mysql.createConnection(dbConfig);
        console.info("[+] Created db connection");

        // Insert data into the database
        const [insertResult] = await connection.execute(sqlQuery, [username, url, display]);
        console.info("[+] Inserted data into DB");

        // Redirect on success
        return {
            statusCode: 302,
            headers: {
                Location: frontend_url + '/success.html'
            },
            body: JSON.stringify({ message: 'Redirecting...' })};
        
    } catch (error) {
        console.error('Database error:', error);
        return {
            statusCode: 302,
            headers: {
                Location: frontend_url + '/err_internal.html'
            },
            body: JSON.stringify({ message: 'DB error...' })};
    } finally {
        if (connection) {
            await connection.destroy(); // Properly close the connection
            console.info("[+] Closed db connection");
        }
    }
};
