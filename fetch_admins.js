const { google } = require('../backend/node_modules/googleapis');

const SPREADSHEET_ID = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

const auth = new google.auth.GoogleAuth({
  keyFile: '../backend/google-sheets-credentials.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets'],
});

const sheets = google.sheets({ version: 'v4', auth });

async function getPermissions() {
  try {
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range: 'Admins!A:Z',
    });

    const rows = response.data.values;
    if (!rows || rows.length === 0) {
      console.log('No data found.');
      return;
    }

    const headers = rows[0].map(h => h.toString().trim());
    const userCol = headers.findIndex(h => h.toLowerCase() === 'username' || h.toLowerCase() === 'user');
    const permCol = headers.findIndex(h => h.toLowerCase().includes('permissions'));
    const accessCol = headers.findIndex(h => h.toLowerCase().includes('access permissions') || h.toLowerCase() === 'access permissions');

    console.log(`User Column Index: ${userCol}`);
    console.log(`Permissions Column Index: ${permCol}`);
    console.log(`Access Permissions Column Index: ${accessCol}`);

    // Print out all users' permissions
    for (let i = 1; i < rows.length; i++) {
        const row = rows[i];
        if (row.length === 0) continue;
        
        // Find columns dynamically
        let u = "Unknown User";
        if (userCol !== -1 && row[userCol]) u = row[userCol];
        else u = row[0]; // fallback
        
        let permissions = "Not found";
        let accessPermissions = "Not found";

        // Since the columns could be named exactly 'Permissions' and 'Access Permissions' Let's just find them exactly
        const exactPermCol = headers.findIndex(h => h.trim() === 'Permissions');
        const exactAccessCol = headers.findIndex(h => h.trim() === 'Access Permissions');

        if (exactPermCol !== -1 && row[exactPermCol]) permissions = row[exactPermCol];
        if (exactAccessCol !== -1 && row[exactAccessCol]) accessPermissions = row[exactAccessCol];

        console.log(`\n=================================`);
        console.log(`USER: ${u}`);
        console.log(`Permissions:\n${permissions}`);
        console.log(`Access Permissions:\n${accessPermissions}`);
        console.log(`=================================\n`);
    }

  } catch (err) {
    console.error('Error fetching admins:', err.message);
  }
}

getPermissions();
