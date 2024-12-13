import AWS from 'aws-sdk';
import { URL } from 'url';
import patreonPackage from 'patreon';
const { patreon: patreonAPI, oauth: patreonOAuth } = patreonPackage;
import mysql from 'mysql2'

// Setup Patreon OAuth client
const patreonOAuthClient = patreonOAuth(
    process.env.PATREON_CLIENT_ID,
    process.env.PATREON_CLIENT_SECRET
);

// MySQL connection
const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
});

db.connect((err) => {
    if (err) {
        console.error('Error connecting to the database:', err);
        process.exit(1); 
    }
    console.info('Connected to the database');
});

export const handler = async (event) => {
    const oauthGrantCode = event.queryStringParameters.code;
    console.log('Authorization Code:', oauthGrantCode);

    if (!oauthGrantCode) {
        console.error('Authorization code is missing.');
        return {
            statusCode: 400,
            body: JSON.stringify({ message: 'Authorization code is missing.' })
        };
    }

    try {
        // Fetch tokens from Patreon OAuth
        const tokensResponse = await patreonOAuthClient.getTokens(oauthGrantCode, process.env.PATREON_REDIRECT_URI);

        // Create a Patreon API client using the access token
        const patreonAPIClient = patreonAPI(tokensResponse.access_token);

        // Fetch user info, including their memberships
        const userResponse = await patreonAPIClient('/current_user?include=memberships');
        const user = userResponse.store.findAll('user')[0];
        const email = user.email;

        if (!email || !user.is_email_verified) {
            console.error('Email verification failed.');
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Email verification failed.' })
            };
        }

        // Verify if the user is subscribed to the campaign
        const pledges = user.pledges;
        let isSubscribed = false;

        for (const pledge of pledges) {
            const campaignId = pledge.creator.url;
            if (campaignId === process.env.PATREON_CAMPAIGN_ID && pledge.amount_cents > 0 && !pledge.declined_since) {
                isSubscribed = true;
                break;
            }
        }

        if (!isSubscribed) {
            console.error('User is not subscribed.');
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'User is not subscribed to the campaign.' })
            };
        }

        // Generate CloudFront Signed URL (to grant access)
        const signedUrl = generateCloudFrontSignedUrl(cfdomain);

        // Return success with the signed URL
        return {
            statusCode: 302,
            headers: { Location: signedUrl },
            body: JSON.stringify({ message: 'Success' })
        };

    } catch (error) {
        console.error('Error during callback:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal Server Error' })
        };
    }
};

// gen signed url from cloudfront to access user.html on successful