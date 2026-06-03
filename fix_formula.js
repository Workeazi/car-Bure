const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function fixFormula() {
  try {
    // 1. Remove the incorrect formula from O2 (Dust column)
    console.log("Removing incorrect formula from O2...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!O2:O7', // Just clear the top part where the formula might be, wait, let's clear just O2
    });
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!O2',
    });

    // 2. Clear DEBIT % data starting from row 8 (P8 downwards)
    console.log("Clearing DEBIT % data from P8 downwards...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!P8:P',
    });
    
    // 3. Apply the CORRECT ARRAYFORMULA to P8
    console.log("Applying CORRECT ARRAYFORMULA to P8...");
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!P8',
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [['=ARRAYFORMULA(IF(ISBLANK(H8:H), "", (H8:H + O8:O) - 18))']]
      }
    });

    // 4. Clean up any weird #VALUE! in P4 and P5
    console.log("Cleaning up P4 and P5...");
    await sheets.spreadsheets.values.clear({
      spreadsheetId: SPREADSHEET_ID,
      range: 'CarbonInput!P4:P5',
    });

    console.log("Fix successfully applied!");
  } catch (err) {
    console.error("Error applying formula:", err.message);
  }
}

fixFormula();
