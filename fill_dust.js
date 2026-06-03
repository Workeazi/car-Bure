const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function fillDust() {
  try {
    console.log("Fetching current rows to determine bounds...");
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!A:A', // Fetch column A to count rows
    });

    const rows = response.data.values;
    if (!rows || rows.length < 8) {
      console.log("Not enough rows to fill data.");
      return;
    }

    const lastRowIndex = rows.length;
    console.log(`Found ${lastRowIndex} rows. Filling Dust from O8 to O${lastRowIndex}...`);

    // Create an array of dummy values for each row starting from row 8
    const values = [];
    for (let i = 8; i <= lastRowIndex; i++) {
      values.push(["2.8"]); // 2.8 is the dummy value
    }

    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: `CarbonInput!O8:O${lastRowIndex}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: values
      }
    });

    console.log("Successfully filled Dust column with dummy values!");
  } catch (err) {
    console.error("Error filling Dust column:", err.message);
  }
}

fillDust();
