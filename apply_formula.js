const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateFormula() {
  try {
    console.log("Clearing old data in DEBIT % column...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!O2:O',
    });
    
    console.log("Applying ARRAYFORMULA...");
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!O2',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [['=ARRAYFORMULA(IF(ISBLANK(G2:G), "", (G2:G + N2:N) - 18))']]
      }
    });

    console.log("Formula successfully applied to the entire column!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateFormula();
