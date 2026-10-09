'use strict';
const RELEASES='https://github.com/alexanderrippke-create/montagebericht-app/releases';
function versionParts(value){const match=String(value).match(/^v?(\d+)\.(\d+)\.(\d+)$/);return match?match.slice(1).map(Number):null}
function newer(candidate,current){const a=versionParts(candidate),b=versionParts(current);if(!a||!b)return false;for(let i=0;i<3;i++){if(a[i]!==b[i])return a[i]>b[i]}return false}
function releaseInfo(release,current){if(release.draft||release.prerelease||!versionParts(release.tag_name))throw Error('Keine gültige veröffentlichte Version gefunden.');const version=release.tag_name.replace(/^v/,'');const name='Montagebericht-Setup-'+version+'.exe';const url=RELEASES+'/download/'+release.tag_name+'/'+name;const asset=(release.assets||[]).find(a=>a.name===name&&a.browser_download_url===url);return {ok:true,current,latest:version,available:newer(version,current),downloadUrl:asset?url:null,releaseUrl:RELEASES+'/tag/'+release.tag_name}}
module.exports={newer,releaseInfo};
