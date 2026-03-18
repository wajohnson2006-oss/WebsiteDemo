// ─────────────────────────────────────────────────────────────────
//  Platinum Roofing & Construction — Form Backend
//  Google Apps Script
//
//  SETUP INSTRUCTIONS:
//  1. Go to https://script.google.com and create a new project
//  2. Paste this entire file into the editor
//  3. Click "Deploy" → "New deployment"
//  4. Type: Web app
//  5. Execute as: Me
//  6. Who has access: Anyone
//  7. Click Deploy → copy the Web App URL
//  8. Paste that URL into index.html where it says PASTE_YOUR_SCRIPT_URL_HERE
//  9. Push index.html to GitHub
// ─────────────────────────────────────────────────────────────────

const NOTIFY_EMAIL = 'wajohnson2006@gmail.com';
const SHEET_NAME   = 'Submissions';

function doPost(e) {
  try {
    const p = e.parameter;

    // ── 1. Log to Google Sheets ──────────────────────────────────
    const ss    = SpreadsheetApp.getActiveSpreadsheet();
    let sheet   = ss.getSheetByName(SHEET_NAME);

    // Create sheet with headers on first run
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      sheet.appendRow(['Timestamp', 'First Name', 'Last Name', 'Phone', 'Service', 'Message']);
      sheet.getRange(1, 1, 1, 6).setFontWeight('bold');
    }

    sheet.appendRow([
      new Date(),
      p.firstName  || '',
      p.lastName   || '',
      p.phone      || '',
      p.service    || '',
      p.message    || '',
    ]);

    // ── 2. Send email notification ───────────────────────────────
    const name    = `${p.firstName || ''} ${p.lastName || ''}`.trim();
    const subject = `New Estimate Request — ${name}`;
    const body    = [
      'You have a new estimate request from your website.',
      '',
      `Name:     ${name}`,
      `Phone:    ${p.phone    || 'Not provided'}`,
      `Service:  ${p.service  || 'Not specified'}`,
      `Message:  ${p.message  || 'None'}`,
      '',
      `Submitted: ${new Date().toLocaleString('en-US', { timeZone: 'America/Chicago' })}`,
      '',
      '─────────────────────────────',
      'Platinum Roofing & Construction',
      '515 Industrial Dr SE, Elgin, MN 55932',
      '(507) 871-3040',
    ].join('\n');

    GmailApp.sendEmail(NOTIFY_EMAIL, subject, body, {
      replyTo: NOTIFY_EMAIL,
      name:    'Platinum Roofing Website',
    });

    return respond({ success: true });

  } catch (err) {
    return respond({ success: false, error: err.message });
  }
}

function respond(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
