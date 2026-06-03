const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnS() {
  try {
    console.log("Clearing S column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!S8:S',
    });
    
    console.log("Applying ARRAYFORMULA to S8 (S = J * 0.001)...");
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!S8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [['=ARRAYFORMULA(IF(ISBLANK(J8:J), "", J8:J * 0.001))']]
      }
    });

    console.log("Successfully applied S = J * 0.001!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnS();
