const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnR() {
  try {
    console.log("Clearing R column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!R8:R',
    });
    
    console.log("Applying robust ARRAYFORMULA to R8 (R = N * F)...");
    
    const formula = '=ARRAYFORMULA(IF(ISBLANK(F8:F), "", IFERROR(VALUE(REGEXREPLACE(TO_TEXT(N8:N), "[^0-9.-]", "")) * VALUE(REGEXREPLACE(TO_TEXT(F8:F), "[^0-9.-]", "")), "")))';

    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!R8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [[formula]]
      }
    });

    console.log("Successfully applied formula to Column R!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnR();
