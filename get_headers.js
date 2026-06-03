const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function getHeaders() {
  try {
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!A5:Z5',
    });

    const headers = response.data.values[0];
    headers.forEach((header, index) => {
      // Calculate column letter (A=0, B=1, etc.)
      const letter = String.fromCharCode(65 + index);
      console.log(`Column ${letter}: ${header}`);
    });
  } catch (err) {
    console.error(err);
  }
}

getHeaders();
