(function(root){
 'use strict';
 function address(value){
  if(typeof value!=='string')return '';
  const email=value.trim();
  const [local,domain,extra]=email.split('@');
  if(email.length>254||extra!==undefined||!domain||local.length>64||!/^[-a-z0-9!#$%&'*+/=?^_`{|}~]+(?:\.[-a-z0-9!#$%&'*+/=?^_`{|}~]+)*$/i.test(local))return '';
  const labels=domain.split('.');
  return labels.length>1&&labels.every(label=>/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label))?email:'';
 }
 function recipients(office,customer){const first=address(office),second=address(customer);return !first?[]:second&&second.toLowerCase()!==first.toLowerCase()?[first,second]:[first]}
 const api={address,recipients};
 if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.ReportMail=api;
})(typeof globalThis!=='undefined'?globalThis:this);
