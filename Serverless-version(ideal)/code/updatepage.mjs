import mysql from "mysql2/promise"; // Use mysql2 with async/await
import axios from "axios";
import fs from "fs";
import path from "path";

// Lambda Handler
export const handler = async (event) => {
  // console.log('Layer contents:', fs.readdirSync('/opt/nodejs/node_modules'));
  try {
    // Query the database and update GitHub
    console.log("Starting");
    await queryDatabaseAndUpdateGit();
    // return { statusCode: 200, body: JSON.stringify("Success") };
  } catch (err) {
    console.error("Error:", err);
    // return { statusCode: 500, body: JSON.stringify("Internal Server Error") };
  }
};
const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306, // Default MySQL port
};
// Function to query the database and update GitHub
async function queryDatabaseAndUpdateGit() {
  // Connect to the database (replace with your actual DB credentials)
  const connection = await mysql.createConnection(dbConfig);

  const sqlQuery = "SELECT username, url, display FROM users";
  const [results] = await connection.execute(sqlQuery);

  const formattedData = formatData(results);
  console.log("Formatted Data:", formattedData);

  const passphrase1 = process.env.EN_PASS1;
  const passphrase2 = process.env.EN_PASS2;

  const encryptedData = xorEncrypt(formattedData, passphrase1, passphrase2);
  // Write the encrypted data to a temporary file in /tmp (Lambda's writable space)
  const filePath = path.join("/tmp", "index.html");
  fs.writeFileSync(filePath, encryptedData);
  console.info("Encrypted the data");

  // Get GitHub credentials from environment variables
  const gitUser = process.env.GIT_USER;
  const gitToken = process.env.GIT_TOKEN;
  //const repoUrl = `https://${gitUser}:${gitToken}@github.com/Hash-Studios-LLC/HashStudiosPatreonSupport.git`;
  try {
    console.log("Starting GitHub upload");

    // Read the file contents
    const fileContent = fs.readFileSync(filePath, "utf8");

    // Encode the file content in Base64
    const base64Content = Buffer.from(fileContent).toString("base64");

    // Get GitHub credentials from environment variables
    const repo = "HashStudiosPatreonSupport";
    const owner = "Hash-Studios-LLC";
    const pathInRepo = "index.html"; // Path to file in GitHub repo
    const branch = "master"; // Target branch

    // GitHub API URL for updating file content
    const apiUrl = `https://api.github.com/repos/${owner}/${repo}/contents/${pathInRepo}`;

    // Fetch the file's current SHA (required to update the file)
    const response = await axios.get(apiUrl, {
      headers: {
        Authorization: `token ${gitToken}`,
        "User-Agent": gitUser,
      },
    });
    const fileSha = response.data.sha;

    // Create the request payload for updating the file
    const payload = {
      message: "Automated update of encrypted data",
      content: base64Content,
      sha: fileSha,
      branch: branch,
    };

    // Send the PUT request to update the file in GitHub
    await axios.put(apiUrl, payload, {
      headers: {
        Authorization: `token ${gitToken}`,
        "User-Agent": gitUser,
      },
    });

    console.log("File uploaded to GitHub successfully");
  } catch (err) {
    console.error("Error uploading to GitHub:", err);
  }
  // try {
  //   await git.add("/tmp/index.html");
  //   await git.commit("Automated update of encrypted data");
  //   await git.push(repoUrl, "master");
  //   console.log("Pushed changes to main branch");
  // } catch (error) {
  //   console.error("Error pushing changes:", error);
  //   throw error;
  // } finally {
  //   await connection.end(); // Close the DB connection
  // }
}

// Helper functions
const formatData = (rows) => {
  let formattedData = "[RANK:PATREON]\n";
  rows.forEach((row) => {
    formattedData += `${row.username}|${row.display}|${row.url}\n`;
  });
  formattedData += "[/RANK]";
  return formattedData;
};

const xorEncrypt = (plaintext, passphrase1, passphrase2) => {
  const plainBytes = Buffer.from(plaintext, "ascii");
  const passBytes1 = Buffer.from(passphrase1, "ascii");
  const passBytes2 = Buffer.from(passphrase2, "ascii");

  const encryptedBytes = Buffer.alloc(plainBytes.length);
  for (let i = 0; i < plainBytes.length; i++) {
    encryptedBytes[i] =
      plainBytes[i] ^
      passBytes1[i % passBytes1.length] ^
      passBytes2[i % passBytes2.length];
  }

  return encryptedBytes.toString("ascii");
};
