(function(root){
 'use strict';
 function clean(text){return String(text||'').replace(/\r\n?/g,'\n').replace(/&nbsp;|&#160;|&#x[aA]0;/g,' ').trim()}
 function parseLocation(location){
  const parts=clean(location).replace(/\s*\(\s*/g,', ').replace(/\)\s*$/,'').split(/[\n;,]+/).map(s=>s.trim()).filter(Boolean);const result={customer:'',street:'',city:''};
  for(const part of parts){const city=part.match(/^(.*?)(\b\d{5}\s+.+)$/);if(city){result.city=city[2].trim();const prefix=city[1].trim();if(prefix)result.street=prefix;continue}if(/(?:stra(?:ß|ss)e|str\.?|weg|platz|allee|gasse|ring|ufer|chaussee|damm)\b.*\d|\d+\s*[a-z]?$/i.test(part)){result.street=part;continue}if(!result.customer)result.customer=part}
  return result;
 }
 function parseText(text,summary='',location=''){
  text=clean(text);const result={customer:'',order:'',email:'',task:'',date:'',street:'',city:'',phone:'',machine:'',postcode:'',town:'',officeContact:''};const remaining=[];
  const aliases={sachbearbeiter:'officeContact',sachbearbeiterin:'officeContact','büro-kontak':'officeContact','buero-kontak':'officeContact','büro-kontakt':'officeContact','buero-kontakt':'officeContact','büro kontakt':'officeContact','buero kontakt':'officeContact','bürokontakt':'officeContact','buerokontakt':'officeContact','büro':'officeContact','buero':'officeContact',kunde:'customer',kundenname:'customer',firma:'customer',auftrag:'order',auftragsnummer:'order','auftrags-nr.':'order','auftrags-nr':'order','kunden-e-mail':'email','kunden-email':'email','e-mail':'email',email:'email',arbeiten:'task',beschreibung:'task',aufgabe:'task',datum:'date',straße:'street',strasse:'street',plz:'postcode',postleitzahl:'postcode',ort:'town','plz / ort':'city','plz/ort':'city',telefon:'phone',tel:'phone',maschine:'machine',anlage:'machine'};
  for(const line of text.split('\n')){const match=line.match(/^\s*([^:]+):\s*(.*)$/);const key=match&&aliases[match[1].trim().toLowerCase().replace(/[‐‑–—]/g,'-').replace(/\s+/g,' ')];if(key){const value=match[2].trim();if(key==='date'){const iso=value.match(/^(\d{4})-(\d{2})-(\d{2})$/),de=value.match(/^(\d{2})\.(\d{2})\.(\d{4})$/);result.date=iso?value:de?`${de[3]}-${de[2]}-${de[1]}`:''}else if(key==='task')remaining.push(value);else result[key]=value}else remaining.push(line)}
  if(!result.order){const match=(summary+'\n'+text).match(/(?:Auftrags?(?:nummer|[-\s]?Nr\.?)?|Auftrag)\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9/._-]*)/i);if(match)result.order=match[1]}
  if(!result.email){const emails=[...new Set((text.match(/[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi)||[]))];if(emails.length===1)result.email=emails[0]}
  const address=parseLocation(location);for(const key of ['customer','street','city'])if(!result[key]&&!(key==='city'&&(result.postcode||result.town)))result[key]=address[key];
  if(!result.customer&&summary)result.customer=summary.replace(/(?:Auftrags?(?:nummer|[-\s]?Nr\.?)?|Auftrag)\s*[:#]?\s*[A-Za-z0-9/._-]+/i,'').replace(/^[\s|;–-]+|[\s|;–-]+$/g,'').trim();
  if(result.postcode||result.town)result.city=[result.postcode,result.town].filter(Boolean).join(' ');delete result.postcode;delete result.town;
  result.task=remaining.join('\n').trim();return result;
 }
 function unescapeText(value){return value.replace(/\\([nN,;\\])/g,(_,c)=>c.toLowerCase()==='n'?'\n':c)}
 function startDate(value,params){const match=value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);if(!match)return '';const date=`${match[1]}-${match[2]}-${match[3]}`;if(match[7]){const d=new Date(`${date}T${match[4]}:${match[5]}:${match[6]}Z`);if(!Number.isFinite(d.getTime()))return '';return new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Berlin'}).format(d)}return date}
 function parseIcs(source){if(source.length>2_000_000)throw new Error('Die Termindatei ist zu groß (maximal 2 MB).');const lines=source.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n').replace(/\n[ \t]/g,'').split('\n');if(!lines.some(l=>l.toUpperCase()==='BEGIN:VCALENDAR'))throw new Error('Bitte eine gültige .ics-Kalenderdatei auswählen.');const events=[];let event=null,nested=0;
  for(const line of lines){const upper=line.toUpperCase();if(upper==='BEGIN:VEVENT'){event={summary:'',description:'',location:'',date:''};nested=0;continue}if(!event)continue;if(upper==='END:VEVENT'){events.push(event);event=null;continue}if(upper.startsWith('BEGIN:')){nested++;continue}if(upper.startsWith('END:')){nested--;continue}if(nested)continue;const colon=line.indexOf(':');if(colon<0)continue;const property=line.slice(0,colon),name=property.split(';')[0].toUpperCase(),value=line.slice(colon+1);if(name==='SUMMARY')event.summary=unescapeText(value);if(name==='LOCATION')event.location=unescapeText(value);if(name==='DESCRIPTION')event.description=unescapeText(value);if(name==='DTSTART')event.date=startDate(value,property)}
  if(!events.length)throw new Error('In dieser Datei wurde kein vollständiger Termin gefunden.');if(events.length>500)throw new Error('Bitte höchstens 500 Termine auf einmal importieren.');return events;
 }
 const api={parseText,parseIcs};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.ReportImport=api;
})(typeof window==='undefined'?globalThis:window);



