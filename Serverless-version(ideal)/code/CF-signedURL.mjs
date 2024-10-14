import { readFileSync } from 'fs';
import aws from 'aws-sdk';

export const handler = async (event) => {
    const cloudfront = new aws.CloudFront.Signer(
        process.env.CLOUDFRONT_KEY_PAIR_ID, 
        readFileSync(`/opt/${process.env.CLOUDFRONT_PRIVATE_KEY}`, 'utf8') //private key stored in /opt/ (lambda layer)
    );

    const signedUrl = cloudfront.getSignedUrl({
        url: `https://benefits.hashstudiosllc.com/user.html`,
        expires: Math.floor(Date.now() / 1000) + 60 * 60
    });

    return {
        statusCode: 302,
        headers: {
            Location: signedUrl,
        },
    };
};
