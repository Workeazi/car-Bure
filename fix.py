import re

with open('../backend/server.js', 'r', encoding='utf-8') as f:
    code = f.read()

# Replace the append logic in addRow
new_update = '''      let insertIdx = headerRowIndex + 1;
      while (insertIdx < rows.length && rows[insertIdx].some(c => c && c.toString().trim() !== '')) {
        insertIdx++;
      }
      await sheets.spreadsheets.values.update({
        spreadsheetId: SPREADSHEET_ID,
        range: `${sheetName}!A${insertIdx + 1}`,
        valueInputOption: 'USER_ENTERED',
        requestBody: { values: [rowValues] }
      });'''

code = re.sub(r'await sheets\.spreadsheets\.values\.append\(\{\s*spreadsheetId:\s*SPREADSHEET_ID,\s*range:\s*`\$\{sheetName\}!A:ZZ`,\s*valueInputOption:\s*\'USER_ENTERED\',\s*requestBody:\s*\{\s*values:\s*\[rowValues\]\s*\}\s*\}\);', new_update, code)

with open('../backend/server.js', 'w', encoding='utf-8') as f:
    f.write(code)

print("Replaced successfully")
