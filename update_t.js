const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnT() {
  try {
    console.log("Clearing T column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!T8:T',
    });
    
    console.log("Applying robust ARRAYFORMULA to T8 (T = P * (J/100))...");
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!T8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [['=ARRAYFORMULA(IF(ISBLANK(J8:J), "", IFERROR(P8:P * (VALUE(REGEXREPLACE(TO_TEXT(J8:J), "[^0-9.]", "")) / 100), "")))']]
      }
    });

    console.log("Successfully applied formula to Column T!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnT();
