const assert=require('node:assert/strict');const {parseText,normalizeEmail}=require('../ui/import-parser.js');
for(const raw of ['worker@example.de <mailto:worker@example.de>','mailto:worker@example.de','Max Mustermann <worker@example.de>','worker@example.de <mailto:WORKER@example.de>']){assert.equal(normalizeEmail(raw),'worker@example.de');assert.equal(parseText('Kunden-E-Mail: '+raw).email,'worker@example.de')}
assert.equal(normalizeEmail(' worker+service@example.de '),'worker+service@example.de');
const ambiguous='a@example.de <mailto:b@example.de>';assert.equal(normalizeEmail(ambiguous),ambiguous);
assert.equal(normalizeEmail('keine Adresse'),'keine Adresse');
console.log('PASS: Outlook mailto/display-name normalization, duplicate addresses, plus addresses and ambiguous recipients.');
