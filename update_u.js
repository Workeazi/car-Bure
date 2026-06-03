const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function updateColumnU() {
  try {
    console.log("Clearing U column data from row 8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!U8:U',
    });
    
    console.log("Applying robust ARRAYFORMULA to U8 (U = J - T - R - S)...");
    
    const formula = '=ARRAYFORMULA(IF(ISBLANK(J8:J), "", IFERROR(VALUE(REGEXREPLACE(TO_TEXT(J8:J), "[^0-9.-]", "")), 0) - IFERROR(VALUE(REGEXREPLACE(TO_TEXT(T8:T), "[^0-9.-]", "")), 0) - IFERROR(VALUE(REGEXREPLACE(TO_TEXT(R8:R), "[^0-9.-]", "")), 0) - IFERROR(VALUE(REGEXREPLACE(TO_TEXT(S8:S), "[^0-9.-]", "")), 0)))';

    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!U8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [[formula]]
      }
    });

    console.log("Successfully applied formula to Column U!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

updateColumnU();
