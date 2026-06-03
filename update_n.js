const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnN() {
  try {
    console.log("Clearing N column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!N8:N',
    });
    
    console.log("Applying robust ARRAYFORMULA to N8 (N = M - L)...");
    
    const formula = '=ARRAYFORMULA(IF(ISBLANK(M8:M), "", IFERROR(VALUE(REGEXREPLACE(TO_TEXT(M8:M), "[^0-9.-]", "")) - VALUE(REGEXREPLACE(TO_TEXT(L8:L), "[^0-9.-]", "")), "")))';

    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!N8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [[formula]]
      }
    });

    console.log("Successfully applied formula to Column N!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnN();
