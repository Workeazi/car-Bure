const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnL() {
  try {
    console.log("Clearing L column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!L8:L',
    });
    
    console.log("Applying ARRAYFORMULA to L8 (L = F - I)...");
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!L8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [['=ARRAYFORMULA(IF(ISBLANK(F8:F), "", F8:F - I8:I))']]
      }
    });

    console.log("Successfully applied L = F - I!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnL();
