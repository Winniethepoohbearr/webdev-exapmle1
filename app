/* Pooh Bear: pages, search, likes and the advice/review section. */
const $=s=>document.querySelector(s),app=$('#app');
let q='',tag='',bq='',cat='';
const tagsAll=[...new Set(BUILDS.flatMap(b=>b.tags))].sort();
const blocksOf=b=>[...new Set(b.steps.flatMap(s=>s[2].map(m=>m[0])))];
const sw=n=>`<i class="sw" style="background:${(B[n]||["#999"])[0]}"></i>`;
const bi=b=>BUILDS.indexOf(b);
const meta=b=>[b.diff,b.time&&"about "+b.time,b.size&&b.size+" footprint",b.tall&&b.tall+" tall",MODELS[b.id]&&(APPROX.has(b.id)?"rough 3D shape":"3D guide")].filter(Boolean).join(", ");
const here=()=>location.hash.slice(1)||'home';
let dbOn=false,sortLikes=false,counts={},mine=new Set(),uid=null,canW=false,db0=null,local=new Set(),tt;
try{local=new Set(JSON.parse(localStorage.getItem('pb-likes')||'[]'))}catch(e){}
const shared=()=>dbOn&&uid&&canW;
const isLiked=id=>shared()?mine.has(id):local.has(id);
const likeIn=id=>`<span class="h" aria-hidden="true">${isLiked(id)?'♥':'♡'}</span>${dbOn?`<span>${counts[id]||0}</span>`:''}`;
const likeLab=id=>`Like ${BUILDS.find(b=>b.id===id).name}${dbOn?`, ${counts[id]||0} likes`:''}`;
const likeBtn=id=>`<button class="like" data-act="like" data-v="${id}" aria-pressed="${isLiked(id)}" aria-label="${likeLab(id)}">${likeIn(id)}</button>`;
function say(m){const e=$('#lm');e.textContent=m;clearTimeout(tt);tt=setTimeout(()=>{e.textContent=''},4500)}
function paint(){
  if(here()==='home'&&$('#res'))return results();
  document.querySelectorAll('.like').forEach(b=>{const id=b.dataset.v;b.setAttribute('aria-pressed',isLiked(id));b.setAttribute('aria-label',likeLab(id));b.innerHTML=likeIn(id)});
}
function toggleLocal(id){local.has(id)?local.delete(id):local.add(id);try{localStorage.setItem('pb-likes',JSON.stringify([...local]))}catch(e){}paint()}
async function toggleLike(id){
  if(!shared())return toggleLocal(id);
  const nx=new Set(mine);nx.has(id)?nx.delete(id):nx.add(id);
  try{await db0.collection('likes').doc(uid).set({b:[...nx]});mine=nx;counts[id]=Math.max(0,(counts[id]||0)+(nx.has(id)?1:-1));paint()}
  catch(e){canW=false;say('Your like is saved on this device only. This page isn’t open to shared likes for you.');toggleLocal(id)}
}
/* advice and reviews: one shared doc per person at comments/<their id>, holding all their entries */
let allC=[],cmState='load',usr=null,isOwn=false,cmBusy=false,delArm='',delT,cmNote='',cmSeq=0;
const CM_MAX=800,CM_CAP=60,stars=n=>'★'.repeat(n)+'☆'.repeat(5-n);
const cmCan=()=>cmState==='ready'&&!!uid&&canW;
const strip=m=>{const o={i:m.i,b:m.b,t:m.t,x:m.x};if(m.r)o.r=m.r;return o};
function parseC(snap){
  const out=[];
  snap.docs.forEach(d=>{const c=(d.data()||{}).c;if(!Array.isArray(c))return;
    c.forEach(m=>{if(!m||typeof m.x!=='string'||typeof m.b!=='string'||typeof m.i!=='string')return;
      out.push({u:d.id,i:m.i,b:m.b,t:Number(m.t)||0,x:m.x.slice(0,CM_MAX),r:m.r>=1&&m.r<=5?Math.round(m.r):0})})});
  return out.sort((a,b)=>b.t-a.t);
}
function cmSection(b){
  return `<section class="cm" id="cm" aria-labelledby="cmh"><h2 id="cmh">Advice from other builders</h2><p class="lab" id="cmsum" style="margin:0">Loading advice…</p>
  <form class="cmf" id="cmf" novalidate><label class="lab" for="cmta">Share your advice for ${b.name}</label>
  <textarea id="cmta" maxlength="${CM_MAX}" rows="4" placeholder="What worked, what you’d change, which blocks you swapped…" disabled></textarea>
  <fieldset class="cmr"><legend>Rating (optional)</legend>${[1,2,3,4,5].map(n=>`<input type="radio" class="sr" name="cr" id="cr${n}" value="${n}"><label for="cr${n}"><span aria-hidden="true">☆</span><span class="sr">${n} ${n===1?'star':'stars'}</span></label>`).join('')}<button type="button" class="go" data-act="cclear">Clear rating</button></fieldset>
  <div class="acts"><button class="btn" type="submit" id="cmgo" disabled>Post advice</button><span class="lab" id="cc" style="margin:0">0 / ${CM_MAX}</span></div>
  <p class="lab" id="cmnote" style="margin:12px 0 0"></p></form><div id="cml"></div></section>`;
}
function cmStatus(){
  if(cmCan())return '';
  if(cmState==='load')return 'Loading…';
  if(cmState==='off')return 'Advice isn’t available in this view, so posting is switched off.';
  if(!uid)return 'Posting needs a signed-in viewer.';
  return 'Posting is limited to people the owner has shared this page with as Contributors.';
}
function cmSay(m){cmNote=m||'';const e=$('#cmnote');if(e)e.textContent=cmNote||cmStatus()}
function starFill(){
  const sel=document.querySelector('input[name="cr"]:checked'),n=sel?+sel.value:0;
  document.querySelectorAll('.cmr label').forEach((l,i)=>{l.firstChild.textContent=i<n?'★':'☆'});
}
function clearRate(){document.querySelectorAll('input[name="cr"]').forEach(x=>{x.checked=false});starFill()}
function cItem(m,p){
  const a=document.createElement('article');a.className='cmi';
  const h=document.createElement('div');h.className='cmh';
  if(p.avatarUrl){const im=document.createElement('img');im.src=p.avatarUrl;im.alt='';h.appendChild(im)}
  const mine=m.u===uid,nm=mine?(p.name?p.name+' (you)':'You'):(p.name||'Someone');
  const n=document.createElement('span');n.className='cmn';n.textContent=nm;h.appendChild(n);
  if(m.r){const r=document.createElement('span');r.className='cms';r.setAttribute('role','img');r.setAttribute('aria-label','Rated '+m.r+' out of 5');r.textContent=stars(m.r);h.appendChild(r)}
  const dt=new Date(m.t);
  if(m.t>0&&!isNaN(dt)){const d=document.createElement('span');d.className='cmd';d.textContent=dt.toLocaleDateString(undefined,{year:'numeric',month:'short',day:'numeric'});h.appendChild(d)}
  if(mine||isOwn){const k=m.u+'|'+m.i,x=document.createElement('button');x.type='button';x.className='go';x.dataset.act='cdel';x.dataset.v=k;
    x.textContent=delArm===k?'Tap again to delete':'Delete';x.setAttribute('aria-label',(delArm===k?'Confirm delete of advice by ':'Delete advice by ')+nm);h.appendChild(x)}
  const t=document.createElement('p');t.className='cmt';t.textContent=m.x;
  a.append(h,t);return a;
}
async function paintC(){
  const box=$('#cm');if(!box)return;
  const my=++cmSeq,bid=here().slice(6),list=allC.filter(m=>m.b===bid),can=cmCan();
  $('#cmta').disabled=!can;$('#cmgo').disabled=!can||cmBusy;$('#cmnote').textContent=cmNote||cmStatus();
  const rs=list.filter(m=>m.r),avg=rs.length?rs.reduce((a,m)=>a+m.r,0)/rs.length:0;
  $('#cmsum').textContent=list.length?`${list.length} ${list.length===1?'tip':'tips'}${rs.length?` · ${avg.toFixed(1)} out of 5 from ${rs.length} ${rs.length===1?'rating':'ratings'}`:''}`
    :cmState==='load'?'Loading advice…':cmState==='off'?'Advice couldn’t be loaded right now.':'No advice yet. Be the first to share a tip for this build.';
  let ps={};try{if(usr)ps=await usr.profiles([...new Set(list.map(m=>m.u))])}catch(e){}
  if(my!==cmSeq||here().slice(6)!==bid||!$('#cml'))return;
  const el=$('#cml');el.textContent='';
  list.forEach(m=>el.appendChild(cItem(m,ps[m.u]||{})));
}
async function postC(){
  const ta=$('#cmta');if(!ta||!cmCan()||cmBusy)return;
  const x=ta.value.trim();
  if(x.length<3){cmSay('Write a little more before posting.');ta.focus();return}
  const mine=allC.filter(m=>m.u===uid).map(strip);
  if(mine.length>=CM_CAP){cmSay('You’ve reached the limit of '+CM_CAP+' pieces of advice. Delete one to add another.');return}
  const sel=document.querySelector('input[name="cr"]:checked'),r=sel?+sel.value:0;
  const m={i:Date.now().toString(36)+Math.random().toString(36).slice(2,6),b:here().slice(6),t:Date.now(),x:x.slice(0,CM_MAX)};if(r)m.r=r;
  cmBusy=true;$('#cmgo').disabled=true;
  try{
    await db0.collection('comments').doc(uid).set({c:[...mine,m]});
    ta.value='';$('#cc').textContent='0 / '+CM_MAX;clearRate();cmSay('');say('Thanks! Your advice is posted.');
  }catch(e){
    if(e&&e.code==='invalid_argument')canW=false;
    cmSay(e&&e.code==='quota_exceeded'?'This page has reached its storage limit, so new advice can’t be saved.':'Couldn’t post just now. Your text is still here, so try again in a moment.');
  }
  cmBusy=false;paintC();
}
async function delC(v){
  const m=allC.find(x=>x.u+'|'+x.i===v);if(!m||cmBusy)return;
  if(delArm!==v){delArm=v;clearTimeout(delT);delT=setTimeout(()=>{delArm='';paintC()},4000);return paintC()}
  delArm='';clearTimeout(delT);cmBusy=true;
  try{await db0.collection('comments').doc(m.u).set({c:allC.filter(x=>x.u===m.u&&x.i!==m.i).map(strip)});say('Advice deleted.')}
  catch(e){say('That advice couldn’t be deleted. Try again in a moment.')}
  cmBusy=false;paintC();
}
function art(b){
  if(b.photos)return `<img src="${b.photos[0]}" alt="${b.name} in Minecraft">`;
  const i=bi(b),cols=blocksOf(b).map(n=>B[n][0]),W=28,H=14;let s=(i+3)*9301,o='';
  const r=()=>{s=(s*9301+49297)%233280;return s/233280};
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const p=Math.pow(y/H,1.7);
    o+=r()<p*1.15?`<rect x="${x}" y="${y}" width="1.03" height="1.03" fill="${cols[Math.floor(r()*cols.length)]}" opacity=".88"/>`:`<rect x="${x}" y="${y}" width="1.03" height="1.03" fill="${GR[i%6][x%2]}" opacity="${(.16+r()*.22).toFixed(2)}"/>`;
  }
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice" shape-rendering="crispEdges" aria-hidden="true">${o}</svg><span class="em" aria-hidden="true">${b.emoji}</span>`;
}
const tagChips=()=>(dbOn?`<button class="chip" data-act="sort" aria-pressed="${sortLikes}">Most liked first</button>`:'')+tagsAll.map(t=>`<button class="chip" data-act="tag" data-v="${t}" aria-pressed="${t===tag}">${t}</button>`).join('');
function row(b,k){return `<article class="row${k%2?' flip':''}"><button class="img"${b.pr?` style="aspect-ratio:${b.pr[0]}"`:""} data-act="go" data-v="build-${b.id}" aria-label="Open ${b.name}">${art(b)}</button><div><p class="lab">${b.tags.join(', ')}</p><h2>${b.name}</h2><p>${b.desc}</p><p class="lab">${meta(b)}</p><div class="acts"><button class="go" data-act="go" data-v="build-${b.id}">See the steps</button>${likeBtn(b.id)}</div></div></article>`}
function home(){
  app.innerHTML=`<section class="hero"><h1>Find your next build</h1><p>Pick a build, follow the steps, and gather the blocks as you go.</p>
  <div class="search" role="search"><input id="q" type="search" placeholder="Search builds, tags or blocks" aria-label="Search builds, tags or blocks" autocomplete="off"></div>
  <div class="chips" id="tagrow" aria-label="Tags"></div></section><div id="res"></div>`;
  $('#q').value=q;results();
}
function results(){
  const s=q.trim().toLowerCase(),on=s||tag;
  const hits=BUILDS.filter(b=>(!tag||b.tags.includes(tag))&&(!s||[b.name,b.desc,...b.tags,...blocksOf(b)].join(' ').toLowerCase().includes(s))).sort((a,b)=>sortLikes?(counts[b.id]||0)-(counts[a.id]||0):0);
  const bl=s?Object.keys(B).filter(n=>n.toLowerCase().includes(s)):[];
  $('#res').innerHTML=`<p class="lab" style="margin-bottom:12px">${on?'Matching builds':'Popular builds'}</p>`+(hits.length?hits.map(row).join(''):`<div class="empty">No builds match that yet. Try a block name like “oak” or clear the tag.</div>`)+
  (bl.length?`<p class="lab" style="margin:30px 0 4px">Matching blocks</p><div class="chips">${bl.map(n=>`<button class="chip" data-act="block" data-v="${n}">${sw(n)}${n}</button>`).join('')}</div>`:'')+
  (on?`<p style="margin-top:24px"><button class="go" data-act="clear">Clear search and tags</button></p>`:'');
  $('#tagrow').innerHTML=tagChips();
}
function build(id){
  const b=BUILDS.find(x=>x.id===id);
  if(!b)return go('home');
  const tot={};b.steps.forEach(s=>s[2].forEach(([n,c])=>tot[n]=(tot[n]||0)+(c||0)));
  app.innerHTML=`<button class="back" data-act="go" data-v="home">← All builds</button>
  ${b.photos?`<div class="gal${b.photos.length<2?' one':''}"${b.photos.length<2?` style="max-width:${Math.round(Math.min(1040,640*Math.max(1,b.pr[0]/1.1)))}px"`:""}>${b.photos.map((p,i)=>`<div class="img" style="aspect-ratio:${b.pr[i]}"><img src="${p}" alt="${b.name} in Minecraft"></div>`).join("")}</div>${(b.photoCredit??"Screenshots taken in-game by the site author.")?`<p class="lab" style="margin-top:10px">${b.photoCredit??"Screenshots taken in-game by the site author."}</p>`:""}`:`<div class="img banner">${art(b)}</div>`}
  <h1 class="bt">${b.name}</h1><div class="acts"><span class="lab" style="margin:0">${meta(b)}</span>${likeBtn(b.id)}</div>
  <div class="chips" style="margin-top:8px">${b.tags.map(t=>`<button class="chip" data-act="tag" data-v="${t}">${t}</button>`).join('')}</div>
  ${b.note?`<p class="lab" style="margin-top:18px">${b.note}</p>`:""}
  ${view3(b)}
  <div class="two"><div><p class="lab" id="pt">0 of ${b.steps.length} steps done</p><div class="prog"><div id="pb"></div></div>${b.steps.some(s=>s[3]&&s[3].length)?`<p class="lab" style="margin:14px 0 0">Measurements are in blocks. “Wide” runs left to right across the front, “deep” runs front to back, and layer 1 is the bottom row of the build, with each layer sitting on top of the one before.</p>`:""}
  ${b.steps.map((s,i)=>`<div class="srow"><div class="n" aria-hidden="true">${i+1}</div><div><label><input type="checkbox" data-step><h3>${s[0]}</h3></label><p>${s[1]}</p>${s[3]&&s[3].length?`<p class="meas"><span class="ml">Measure</span>${s[3].map(m=>`<span>${m.replace(/(\d+(?:\s?[×–]\s?\d+)*)/g,'<b>$1</b>')}</span>`).join('')}</p>`:''}<div class="chips" style="margin-top:0">${s[2].map(([n,c])=>`<button class="chip" data-act="block" data-v="${n}">${sw(n)}${n}${c?" × "+c:""}</button>`).join('')}</div></div></div>`).join('')}</div>
  <aside class="side"><h3>Materials list</h3>${Object.entries(tot).map(([n,c])=>`<button class="mat" data-act="block" data-v="${n}">${sw(n)}${n}<b>${c||""}</b></button>`).join('')}</aside></div>${cmSection(b)}`;
  init3d(b.id);paintC();
}
function blocks(){
  app.innerHTML=`<section class="hero" style="padding-bottom:18px"><h1>Block lookup</h1><p>Find a block and see which builds use it.</p>
  <div class="search" role="search"><input id="bq" type="search" placeholder="Search blocks, like “cherry”" aria-label="Search blocks" autocomplete="off"></div>
  <div class="chips" id="cats"></div></section><div id="bl"></div>`;
  $('#bq').value=bq;blist();
}
function blist(){
  const s=bq.trim().toLowerCase(),cats=[...new Set(Object.values(B).map(v=>v[1]))];
  $('#cats').innerHTML=cats.map(c=>`<button class="chip" data-act="cat" data-v="${c}" aria-pressed="${c===cat}">${c}</button>`).join('');
  const names=Object.keys(B).filter(n=>(!cat||B[n][1]===cat)&&(!s||n.toLowerCase().includes(s)));
  $('#bl').innerHTML=names.length?names.map(n=>{
    const used=BUILDS.filter(b=>blocksOf(b).includes(n)).map(b=>[b,b.steps.reduce((a,st)=>a+st[2].filter(m=>m[0]===n).reduce((x,m)=>x+(m[1]||0),0),0)]);
    return `<div class="brow"><div class="bigsw" style="background:${B[n][0]}"></div><div><h3>${n}</h3><div class="lab" style="margin:0">${B[n][1]}</div></div><div class="used">${used.length?'Used in '+used.map(([b,c])=>`<button class="go" data-act="go" data-v="build-${b.id}">${b.name}</button>${c?" ("+c+")":""}`).join(', '):'Not used in any build yet'}</div></div>`}).join(''):`<div class="empty">No blocks match. Check the spelling or clear the category.</div>`;
}
function render(){
  stop3d();
  const h=here();
  $('#n-home').removeAttribute('aria-current');$('#n-blocks').removeAttribute('aria-current');
  if(h==='blocks'){$('#n-blocks').setAttribute('aria-current','page');blocks()}
  else if(h.startsWith('build-')){build(h.slice(6))}
  else{$('#n-home').setAttribute('aria-current','page');home()}
  scrollTo(0,0);
}
function go(v){if(here()===v)render();else location.hash=v}
function closeMenu(){$('#menu').classList.remove('open');$('#mb').setAttribute('aria-expanded','false')}
document.addEventListener('click',e=>{
  const t=e.target.closest('[data-act]');
  if(!t){closeMenu();return}
  const a=t.dataset.act,v=t.dataset.v;
  if(a!=='menu')closeMenu();
  if(a==='go')go(v);
  else if(a==='menu'){const o=$('#menu').classList.toggle('open');t.setAttribute('aria-expanded',o)}
  else if(a==='tag'){if(here()==='home'){tag=tag===v?'':v;results()}else{tag=v;go('home')}}
  else if(a==='tags'){if(here()!=='home')go('home');setTimeout(()=>$('#tagrow').scrollIntoView({behavior:'smooth',block:'center'}),60)}
  else if(a==='random'){go('build-'+BUILDS[Math.floor(Math.random()*BUILDS.length)].id)}
  else if(a==='clear'){q='';tag='';$('#q').value='';results()}
  else if(a==='block'){bq=v;cat='';go('blocks')}
  else if(a==='cat'){cat=cat===v?'':v;blist()}
  else if(a==='like'){toggleLike(v)}
  else if(a==='cdel'){delC(v)}
  else if(a==='cclear'){clearRate()}
  else if(a==='sort'){sortLikes=!sortLikes;results()}
});
document.addEventListener('input',e=>{
  if(e.target.id==='q'){q=e.target.value;results()}
  else if(e.target.id==='bq'){bq=e.target.value;blist()}
  else if(e.target.id==='cmta'){$('#cc').textContent=e.target.value.length+' / '+CM_MAX;if(cmNote)cmSay('')}
});
document.addEventListener('change',e=>{
  if(e.target.name==='cr')starFill();
  if(e.target.matches('[data-step]')){
    const all=[...document.querySelectorAll('[data-step]')],d=all.filter(x=>x.checked).length;
    $('#pb').style.width=(d/all.length*100)+'%';
    $('#pt').textContent=d===all.length?'All steps done. Enjoy your build!':`${d} of ${all.length} steps done`;
  }
});
document.addEventListener('submit',e=>{if(e.target.id==='cmf'){e.preventDefault();postC()}});
addEventListener('hashchange',render);
render();
(async()=>{
  const off=()=>{if(cmState==='load'){cmState='off';paintC()}};
  setTimeout(off,10000);
  try{
    if(!window.claude||!claude.use)return off();
    const [db,user]=await Promise.all([claude.use('db'),claude.use('user')]);
    if(!db)return off();
    db0=db;usr=user;
    if(user){uid=await user.id();canW=!!uid&&(await user.can('data.write'))!==false;isOwn=await user.isOwner()}
    db.collection('likes').onSnapshot(snap=>{
      counts={};mine=new Set();
      snap.docs.forEach(d=>{const b=(d.data()||{}).b;if(Array.isArray(b)){b.forEach(i=>{counts[i]=(counts[i]||0)+1});if(d.id===uid)mine=new Set(b)}});
      dbOn=true;paint();
    },()=>{});
    db.collection('comments').onSnapshot(snap=>{allC=parseC(snap);cmState='ready';paintC()},()=>{cmState='off';paintC()});
  }catch(e){off()}
})();
