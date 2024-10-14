const express = require('express');
const mysql = require('mysql2');
const https = require('https');
const fs = require('fs');
const simpleGit = require('simple-git');
const session = require('express-session');
const url = require('url');
const dotenv = require('dotenv');
const aws = require('aws-sdk');
const cors = require('cors');
const patreon = require('patreon');
const patreonAPI = patreon.patreon;
const patreonOAuth = patreon.oauth;
dotenv.config();
// Load self-signed certificate
// const privateKey = fs.readFileSync('key.pem', 'utf8');
// const certificate = fs.readFileSync('cert.pem', 'utf8');
// const credentials = { key: privateKey, cert: certificate };
const app = express();
const port = 3000;
const clientId = encodeURIComponent(process.env.PATREON_CLIENT_ID);
const redirectUri = encodeURIComponent(process.env.PATREON_REDIRECT_URI);
const scope = encodeURIComponent('identity identity[email] identity.memberships');
const oauthUrl = `https://www.patreon.com/oauth2/authorize?response_type=code&client_id=${clientId}&redirect_uri=${redirectUri}&scope=${scope}`;
const cfdomain = "benefits.hashstudiosllc.com"
const frontend_url = "https://" + cfdomain
//#region CORS and Middleware Configuration

// Allow frontend to communicate with this server using CORS
app.use(cors({
    origin: 'benefits.hashstudiosllc.com',  // Allow requests from CloudFront
    methods: ['GET', 'POST', 'OPTIONS'],  // Allow necessary HTTP methods
    allowedHeaders: ['Content-Type', 'Authorization'],  // Allow necessary headers
    credentials: true  // Allow cookies and credentials to be sent
}));
// //can redirect HTTP requests to HTTPS if necessary by inspecting this header.
// app.use((req, res, next) => {
//     if (req.headers['x-forwarded-proto'] !== 'https') {
//         return res.redirect(`https://${req.headers.host}${req.url}`);
//     }
//     next();
// });


// Use Express to parse incoming JSON payloads
app.use(express.json());
const patreonOAuthClient = patreonOAuth(
    process.env.PATREON_CLIENT_ID,
    process.env.PATREON_CLIENT_SECRET
);
// Configure session with secure settings
app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: {
        secure: true,  // Only send cookies over HTTPS
        httpOnly: true,  // Prevent client-side access to the cookie
        sameSite: 'none'  // Allow cross-site cookies for CORS requests
    }
}));
// Middleware to check if the user is authenticated
function isAuthenticated(req, res, next) {
    if (req.session.accessToken) {
        return next();
    } else {
        res.redirect(frontend_url);
    }
}
//#endregion
//#region Routes
app.get('/', (req, res) => { //test
    res.send('<script>alert("Yay it works");</script>');
});

app.get('/login', (req, res) => {
    return res.redirect(oauthUrl);
});

// Function to generate a CloudFront signed URL and redirect the user
function generateCloudFrontSignedUrl(res, cfdomain, filePath = '/user.html') {
    try {
        // Create CloudFront Signer
        const cloudfront = new aws.CloudFront.Signer(process.env.CLOUDFRONT_KEY_PAIR_ID, fs.readFileSync(process.env.CLOUDFRONT_PRIVATE_KEY, 'utf8'));

        // Generate signed URL
        const signedUrl = cloudfront.getSignedUrl({
            url: `https://${cfdomain}${filePath}`,
            expires: Math.floor(Date.now() / 1000) + 60 * 60  // 1 hour expiration
        });

        // console.log('Redirecting to signed URL:', signedUrl); // Log the signed URL
        res.redirect(signedUrl); // Redirect to the signed URL
    } catch (error) {
        console.error('Error generating CloudFront signed URL:', error);
        res.status(500).send('Error generating signed URL');  // Handle error
    }
}
app.get('/bypass', (req, res) => {
    generateCloudFrontSignedUrl(res,cfdomain)
});
app.get('/callback', async (req, res) => {
    const oauthGrantCode = url.parse(req.url, true).query.code;

    console.log('Authorization Code:', oauthGrantCode);

    if (!oauthGrantCode) {
        console.error('Authorization code is missing.');
        return res.status(400).send('Authorization code is missing.');
    }

    try {
        const tokensResponse = await patreonOAuthClient.getTokens(oauthGrantCode, process.env.PATREON_REDIRECT_URI);
        console.log('Token Response:', tokensResponse);
        // Create a Patreon API client using the access token
        const patreonAPIClient = patreonAPI(tokensResponse.access_token);
        // Get user information, including their memberships
        const userResponse = await patreonAPIClient('/current_user?include=memberships');
        //console.log('Full API Response:', JSON.stringify(userResponse, null, 2));

        const user = userResponse.store.findAll('user')[0];
        //console.log('User:', user);
        const email = user.email;
        //console.log('Email:', email);

        if (!email) {
            console.error('No email found in the user data');
            //return res.status(400).send('No user email found.');
            return res.redirect(frontend_url + '/err_email.html');
        }

        if (!user.is_email_verified) {
            console.error('User email is not verified');
            //return res.status(400).send('Your Patreon account is not email verified.');
            return res.redirect(frontend_url + '/err_email.html');
        }

        // Check if the user is subscribed to the specific campaign
        const pledges = user.pledges;
        let isSubscribed = false;

        //console.log('Pledges:', pledges); // Log all pledges

        for (const pledge of pledges) {
            const campaignId = pledge.creator.url;
            //console.log('Campaign ID:', campaignId); // Log campaign ID
            //console.log(`Patreon Campaign ID: ${process.env.PATREON_CAMPAIGN_ID}`);
            if (campaignId === process.env.PATREON_CAMPAIGN_ID) {
                // Check if the pledge is currently active
                //console.log("Pledge Amount:", pledge.amount_cents);
                //console.log("Declined Since:", pledge.declined_since);
                if (pledge.amount_cents > 0 && !pledge.declined_since) {
                    isSubscribed = true;
                    break;
                }
            }
        }

        if (!isSubscribed) {
            console.error('User is not subscribed to the campaign');
            //return res.status(400).send('Your Patreon account is not subscribed with us.');
            return res.redirect(frontend_url + '/err_subscription_issue.html');
        }
        // Store the access token and email in the session
        req.session.accessToken = tokensResponse.access_token;
        req.session.email = email;
        //#region Create Cloudfront sign URL
        generateCloudFrontSignedUrl(res,cfdomain);

        //#endregion
    } catch (error) {
        console.error('Error getting user info:', error);
        //res.status(500).send('Error getting Patreon access token');
        return res.redirect(frontend_url + '/err_patreon.html');
    }
});


// Form submission endpoint
app.post('/submit', isAuthenticated, (req, res) => {
    const { username, display, url } = req.body;
    const email = req.session.email;

    //check if the image url is reachable
    let parsedUrl;
    try {
        parsedUrl = new URL(url);
    } catch (err) {
        console.error('Invalid URL:', url);
        return res.redirect(frontend_url + '/err_dataenter.html');
    }
    //check if url on domain whitelist
    const validDomains = [
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
    const domain = parsedUrl.hostname;
    const isValidDomain = validDomains.some(validDomain => {
        if (validDomain.startsWith('*')) {
            return domain.endsWith(validDomain.slice(1));
        }
        return domain === validDomain;
    });

    if (!isValidDomain) {
        console.error('Invalid image URL domain.');
        return res.redirect(frontend_url + '/err_dataenter.html');
    }
    //insert form data into database
    const sql = `INSERT INTO ${process.env.DB_TABLE} (email, username, display, url) VALUES (?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE username = VALUES(username), display = VALUES(display), url = VALUES(url)`;
    db.query(sql, [email, username, display, url], (err) => {
        if (err) {
            console.error('Error inserting data into database:', err);
            return res.redirect(frontend_url + '/err_dataenter.html');
        }
        console.log('User data inserted into db:', { email, username, display, url });
        res.redirect(frontend_url + '/success.html');
    });
});
//#endregion

//#region Database
const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
});

db.connect((err) => {
    if (err) {
        console.error('Error connecting to the database:', err);
        process.exit(1); // terminate the app
    }
    console.log('Connected to the database');
});

// Function to query the database
function queryDatabase_and_updateGit() {
    // Fetch all data from DB and send to GitHub page
    const sql_q = 'SELECT username, url, display FROM users'
    db.query(sql_q, async (err, results) => {
        if (err) {
            console.error('Error querying data from database:', err);
            return;
        }

        const formattedData = formatData(results);
        console.log('Formatted Data:', formattedData);

        const passphrase1 = process.env.EN_PASS1
        const passphrase2 = process.env.EN_PASS2

        const encryptedData = xorEncrypt(formattedData, passphrase1, passphrase2);
        // console.log('Encrypted Data:', encryptedData);

        // Write the encrypted data to a file
        fs.writeFileSync('index.html', encryptedData);

        // Initialize simple-git
        const git = simpleGit();

        // Add, commit, and push the changes
        try {
            await git.add('index.html');
            await git.commit('Automated update of encrypted text');
            await git.push('origin', 'main'); // Adjust branch as needed
            console.log('Pushed changes to main branch');
        } catch (error) {
            console.error('Error pushing changes:', error);
        }
    });
}
// Schedule the query to run every 30 minutes
setInterval(queryDatabase_and_updateGit, 30 * 60 * 1000); // 30 minutes * 60 seconds * 1000 milliseconds

//#endregion

//#region Encryption functions
const formatData = (rows) => {
    let formattedData = '[RANK:PATREON]\n';
    rows.forEach(row => {
        formattedData += `${row.username}|${row.display}|${row.url}\n`;
    });
    formattedData += '[/RANK]';
    return formattedData;
};

const xorEncrypt = (plaintext, passphrase1, passphrase2) => {
    const plainBytes = Buffer.from(plaintext, 'ascii');
    const passBytes1 = Buffer.from(passphrase1, 'ascii');
    const passBytes2 = Buffer.from(passphrase2, 'ascii');

    const encryptedBytes = Buffer.alloc(plainBytes.length);
    for (let i = 0; i < plainBytes.length; i++) {
        encryptedBytes[i] = plainBytes[i] ^ passBytes1[i % passBytes1.length] ^ passBytes2[i % passBytes2.length];
    }

    return encryptedBytes.toString('ascii');
};
//#endregion


// Start the server HTTPS
// const httpsServer = https.createServer(credentials, app);

// httpsServer.listen(port, () => {
//     console.log(`HTTPS Server running on port ${port}`);
// });

// Start the server HTTP
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
