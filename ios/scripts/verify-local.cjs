const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const repository = path.dirname(root);
const source = path.resolve(repository,'../Stundennachweis APP/Stundennachweis APP/windows-app');
const manifestPath = path.join(root,'reference-hashes.json');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function walk(directory) {return fs.readdirSync(directory,{withFileTypes:true}).flatMap(item => item.isDirectory() ? walk(path.join(directory,item.name)) : [path.join(directory,item.name)]);}
if (fs.existsSync(source)) {
  const files = [...fs.readdirSync(source).filter(name=> /\.(cjs|ps1|json|yaml|md)$/.test(name)).map(name=>path.join(source,name)),...walk(path.join(source,'ui')),...walk(path.join(source,'tests'))];
  const hashes = Object.fromEntries(files.map(file=>[path.relative(source,file).replaceAll('\\','/'),sha(file)]).sort(([a],[b])=>a.localeCompare(b)));
  if (process.argv.includes('--record-reference')) {assert(!fs.existsSync(manifestPath),'Refusing to overwrite existing reference');fs.writeFileSync(manifestPath,JSON.stringify(hashes,null,2)+'\n');}
  else {assert.deepEqual(hashes,JSON.parse(fs.readFileSync(manifestPath,'utf8')));console.log(`PASS: ${files.length} Windows reference files retain recorded SHA-256 hashes.`);}
  assert.equal(sha(path.join(source,'ui/company-logo.png')),sha(path.join(root,'Montagebericht/Assets/company-logo.png')));
  console.log('PASS: company logo is an unchanged binary copy.');
}
const paths = cp.execFileSync('git',['diff','--name-only','7b218cc','HEAD'],{cwd:repository,encoding:'utf8'}).trim().split('\n');
assert(paths.every(name=>name.startsWith('ios/') || name.startsWith('windows-app/') || ['.github/workflows/ios-test.yml','README.md','CHANGELOG-REPORTS.md','REPORT-FORMAT.md','PR-DESCRIPTION.md'].includes(name)));
console.log('PASS: committed changes remain within the Windows/iOS applications, workflow and documentation.');
const project = path.join(root,'Montagebericht.xcodeproj/project.pbxproj');
const original = fs.readFileSync(project,'utf8');
cp.execFileSync(process.execPath,[path.join(__dirname,'generate-project.cjs')]);
assert.equal(fs.readFileSync(project,'utf8'),original);
for(const file of walk(path.join(root,'Montagebericht')).filter(name=>name.endsWith('.swift'))) {assert(original.includes(path.relative(root,file).replaceAll('\\','/')));}
console.log('PASS: reproducible project contains all application Swift files.');
const secretPattern = /BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}/;
for(const file of walk(root).filter(name=>!name.includes(path.sep+'build'+path.sep) && !name.endsWith('verify-local.cjs'))) {
  if (/\.(swift|json|md|plist|xcprivacy|pbxproj|xcscheme|ps1|cjs|yml)$/.test(file)) assert(!secretPattern.test(fs.readFileSync(file,'utf8')),`Potential credential in ${file}`);
}
assert(!secretPattern.test(fs.readFileSync(path.join(repository,'.github/workflows/ios-test.yml'),'utf8')));
console.log('PASS: no secret matches in the committed source/configuration.');
