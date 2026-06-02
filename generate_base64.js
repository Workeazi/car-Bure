const fs = require('fs');

try {
  // Read the credentials file
  const credentials = fs.readFileSync('../backend/google-sheets-credentials.json', 'utf8');
  
  // Encode it to Base64
  const base64Credentials = Buffer.from(credentials).toString('base64');
  
  console.log('\n======================================================');
  console.log('✅ Base64 Encoded Credentials Generated Successfully!');
  console.log('======================================================\n');
  console.log('Please copy the string below and paste it into Render.com as the value for GOOGLE_CREDENTIALS_BASE64:\n');
  console.log(base64Credentials);
  console.log('\n======================================================');
  
  // Copy to clipboard if on Windows
  require('child_process').exec(`echo ${base64Credentials} | clip`, (err) => {
    if (!err) {
      console.log('✅ The Base64 string has also been copied to your clipboard!');
    }
  });
} catch (error) {
  console.error('Error reading the credentials file:', error.message);
}
