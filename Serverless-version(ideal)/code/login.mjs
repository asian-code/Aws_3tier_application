
export const handler = async (event) => {
    const clientId = encodeURIComponent(process.env.PATREON_CLIENT_ID);
    const redirectUri = encodeURIComponent(process.env.PATREON_REDIRECT_URI);
    const scope = encodeURIComponent('identity identity[email] identity.memberships');
    const oauthUrl = `https://www.patreon.com/oauth2/authorize?response_type=code&client_id=${clientId}&redirect_uri=${redirectUri}&scope=${scope}`;

    return {
        statusCode: 302,
        headers: {
            Location: oauthUrl,
        },
    };
};
