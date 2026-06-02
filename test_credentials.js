const { google } = require('../backend/node_modules/googleapis');

async function testCredentials() {
  console.log('Testing Google Sheets Credentials...');
  
  try {
    const auth = new google.auth.GoogleAuth({
      keyFile: '../backend/google-sheets-credentials.json',
      scopes: ['https://www.googleapis.com/auth/spreadsheets']
    });

    const sheets = google.sheets({ version: 'v4', auth });
    
    // Attempt to read the spreadsheet
    await sheets.spreadsheets.get({ 
      spreadsheetId: '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM' 
    });
    
    console.log('\n✅ SUCCESS: Your credentials are valid and the backend can connect to Google Sheets!');
  } catch (error) {
    console.error('\n❌ ERROR: Your credentials failed.');
    console.error('Reason:', error.message);
    if (error.message.includes('invalid_grant')) {
      console.error('\n--> The key in your google-sheets-credentials.json has been REVOKED by Google or is corrupted. You MUST generate a new one from the Google Cloud Console.');
    }
  }
}

testCredentials();
