const assert=require('node:assert/strict');const {parseText,normalizeEmail}=require('../ui/import-parser.js');
for(const raw of ['worker@example.de <mailto:worker@example.de>','mailto:worker@example.de','Max Mustermann <worker@example.de>','worker@example.de <mailto:WORKER@example.de>']){assert.equal(normalizeEmail(raw),'worker@example.de');assert.equal(parseText('Kunden-E-Mail: '+raw).email,'worker@example.de')}
assert.equal(normalizeEmail(' worker+service@example.de '),'worker+service@example.de');
const ambiguous='a@example.de <mailto:b@example.de>';assert.equal(normalizeEmail(ambiguous),ambiguous);
assert.equal(normalizeEmail('keine Adresse'),'keine Adresse');
console.log('PASS: Outlook mailto/display-name normalization, duplicate addresses, plus addresses and ambiguous recipients.');

const {recipients}=require('../ui/mail-recipients.js');
const office='team@example.de';
for(const customer of [undefined,null,'','ungültig','a@local','a@.example.de','a@-example.de','a..b@example.de','a@example.de; b@example.de','a@example.de <mailto:b@example.de>','TEAM@example.de'])assert.deepEqual(recipients(office,customer),[office]);
assert.deepEqual(recipients(office,' worker+service@example.de '),[office,'worker+service@example.de']);
assert.deepEqual(recipients('', 'worker@example.de'),[]);
console.log('PASS: office-only fallback, recipient deduplication and valid customer email.');
