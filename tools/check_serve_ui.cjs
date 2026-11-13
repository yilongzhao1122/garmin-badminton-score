#!/usr/bin/env node
'use strict';
// Raw declaration guard plus adapted actual MC classes with mock Garmin APIs.
// This is deliberately NOT a Monkey C compiler, native renderer, or sync test.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.join(__dirname,'..'),stack=[];let failures=0;
class Base{};class Item{constructor(label,subtitle,id){Object.assign(this,{label,subtitle,id});}getId(){return this.id;}}
function classEnd(source,start){let level=0,quoted=false,escaped=false;for(let i=source.indexOf('{',start);i<source.length;i++){
 const c=source[i];if(quoted){if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c==='"')quoted=false;continue;}
 if(c==='"'){quoted=true;continue;}if(c==='{')level++;if(c==='}'&&--level===0)return i+1;}throw Error('Unbalanced class');}
function checkLocalDeclarations(source,filename){
 const clean=source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"/g,t=>t.replace(/[^\n]/g,' '));
 const funcs=/\bfunction\s+\w+\s*\(/g;let m;
 while((m=funcs.exec(clean))){const begin=clean.indexOf('{',m.index),end=classEnd(clean,begin),bad=/\bvar\s+\w+\s+as\b/.exec(clean.slice(begin,end));
  if(bad)throw Error(filename+': local variable declaration cannot specify a type');funcs.lastIndex=end;}}
assert.throws(()=>checkLocalDeclarations('function bad(){var x as Array=[];}','fixture'),/local variable/);
checkLocalDeclarations('class X{var n as Number; function ok(){var a=[] as Array;}}','fixture');
for(const n of fs.readdirSync(path.join(root,'source')).filter(n=>n.endsWith('.mc'))){const raw=fs.readFileSync(path.join(root,'source',n),'utf8');checkLocalDeclarations(raw,n);const names=[...raw.matchAll(/^    function (\w+)\(/gm)].map(x=>x[1]);if(n==='BadmintonApp.mc')assert.equal(new Set(names).size,names.length,'Duplicate app method');}
function adapt(file){let source=fs.readFileSync(path.join(root,file),'utf8').replace(/^import .*;$/gm,'')
 .replace(/\s+as\s+(?:(?:Lang|WatchUi|Graphics|Activity)\.\w+(?:<[^>]+>)?|Void)(?:\s+or\s+Null)?/g,'')
 .replace(/(\w+) instanceof Lang\.Number/g,'typeof $1 === "number"').replace(/:(\w+)\s*=>/g,'$1:');
 const chunks=[];let cursor=0,m;const re=/class\s+(\w+)(?:\s+extends\s+(?:WatchUi|Application)\.\w+)?\s*\{/g;
 while((m=re.exec(source))){const begin=m.index,end=classEnd(source,begin);chunks.push(source.slice(cursor,begin));let block=source.slice(begin,end);
  // Renaming MC member identifiers must never rewrite storage keys or labels.
  const literals=[];block=block.replace(/"(?:\\.|[^"\\])*"/g,s=>'__STRING_'+(literals.push(s)-1)+'__');
  const ds=[...block.matchAll(/^    var (\w+)(\s*=\s*[^;]+)?;$/gm)],fields=ds.map(d=>d[1]);
  ds.forEach((d,i)=>{block=block.replace(d[0],'    __FIELD_'+i+'__'+(d[2]||'')+';');});
  for(const f of fields)block=block.replace(new RegExp('(?<![\\w.$])\\b'+f+'\\b','g'),'this.'+f);
  fields.forEach((f,i)=>{block=block.replace('__FIELD_'+i+'__',f);});
  block=block.replace(/function initialize\(/g,'constructor(').replace(/\bfunction (\w+)\(/g,'$1(')
   .replace(/(?:View|BehaviorDelegate|AppBase)\.initialize\(\)/g,'super()').replace(/\bself\b/g,'this');
  block=block.replace(/__STRING_(\d+)__/g,(_,index)=>literals[Number(index)]);
  chunks.push(block);cursor=end;re.lastIndex=end;
 }
 chunks.push(source.slice(cursor));return chunks.join('\n').replace(/Attention has :vibrate/g,'typeof Attention.vibrate === "function"')
  .replace(/method\(:(\w+)\)/g,'this.$1.bind(this)').replace(/\.size\(\)/g,'.length').replace(/\.add\(/g,'.push(').replace(/\(:test\)/g,'');}
let time=1000,exits=0,storageFailure=null,resourceLoads=0;const storage=new Map(),properties=new Map();
const WatchUi={View:Base,BehaviorDelegate:Base,MenuItem:Item,SLIDE_IMMEDIATE:0,
 pushView(view,delegate){stack.push({view,delegate});},popView(){assert(stack.length);stack.pop();},requestUpdate(){},loadResource(id){resourceLoads++;return id===30||id===31||id===32?id:{};}};
class Session{constructor(){this.active=false;this.saves=0;this.discards=0;this.failStart=false;this.failSave=false;this.failDiscard=false;this.fields=[];}
 createField(name,id,type,options){assert(this.fields.length<16,'developer-field count limit');assert(!this.fields.some(f=>f.id===id));const field={name,id,type,options,value:null,setData(value){assert(Number.isInteger(value));assert(value>=0&&value<=(type===2?254:4294967294));this.value=value;}};this.fields.push(field);return field;}
 isRecording(){return this.active;}start(){if(this.failStart)return false;this.active=true;return true;}
 stop(){this.active=false;return true;}save(){this.saves++;return !this.failSave;}discard(){this.discards++;if(this.failDiscard)return false;this.active=false;return true;}}
class Backend{constructor(){this.creates=0;this.session=null;this.failCreate=false;}now(){return time;}
 createSession(){this.creates++;if(this.failCreate)throw Error('create');this.session=new Session();this.matchFields=new context.MatchFitFieldsClass(this.session);return this.session;}
 updateScore(e){this.matchFields.updateScore(e);}
 writeSummary(e,r,end){if(this.failSummary)throw Error('summary');this.matchFields.writeSummary(e,r,end);}
 info(){return null;}}
const nativeSessions=[];
const context=vm.createContext({Time:{now:()=>({value:()=>1794570000}),Moment:class{constructor(v){this.v=v;}},FORMAT_SHORT:0},Gregorian:{info:()=>({year:2026,month:11,day:13})},Properties:{getValue:k=>{if(!properties.has(k))throw Error("missing property");return properties.get(k);}},Activity:{SPORT_GENERIC:0,SUB_SPORT_GENERIC:0,getActivityInfo:()=>null},ActivityRecording:{createSession(){const s=new Session();nativeSessions.push(s);return s;}},FitContributor:{DATA_TYPE_UINT8:2,DATA_TYPE_UINT32:6,MESG_TYPE_RECORD:20,MESG_TYPE_SESSION:18},WatchUi,Application:{AppBase:Base},Timer:{Timer:class{constructor(){this.active=false;this.interval=0;}start(callback,interval,repeat){this.active=true;this.interval=interval;}stop(){this.active=false;}}},Attention:{},
 System:{getTimer:()=>time,getClockTime:()=>({hour:15,min:42,sec:8}),exit:()=>exits++},GarminRecordingBackend:Backend,
 Storage:{getValue:k=>storage.get(k)??null,setValue:(k,v)=>{if((storageFailure===k || (storageFailure==='archive-commit' && k==='match-state-v2' && (v[1]===null || !v[1][6]))))throw Error('store');storage.set(k,JSON.parse(JSON.stringify(v)));},
  deleteValue:k=>{if(storageFailure===k)throw Error('delete');storage.delete(k);}},Test:{assertEqual:(a,b)=>assert.equal(a,b)},Rez:{Drawables:{CourtBackground:1},Fonts:{CnText:30,CnSmall:31,CnMenu:32}}});
vm.runInContext('String.prototype.toCharArray=function(){return [...this.toString()];};String.prototype.equals=function(v){return this.toString()===v;};Number.prototype.toNumber=function(){return Math.trunc(Number(this));};Number.prototype.format=function(p){if(p!=="%02d")throw Error(p);return String(this).padStart(2,"0");};',context);
for(const file of ['ScoreEngine','MatchReport','GameCheckpoints','MatchFitFields','RecordingController','PerformanceStats','ServeUi','DataPagesUi','CourtUi','ChineseFonts','BadmintonApp','ScoreDelegate','MatchMenu','ScoreView']){
 vm.runInContext(adapt('source/'+file+'.mc')+'\nthis.'+file+'Class=typeof '+file+'!=="undefined"?'+file+':null;',context);
}
vm.runInContext(adapt('source/GarminRecordingBackend.mc').replace(/\bGarminRecordingBackend\b/g,'NativeRecordingBackend')+'\nthis.NativeRecordingBackendClass=NativeRecordingBackend;',context);
for(const file of ['UiTests','CourtTests','ServeEditTests','ReportTests','CheckpointTests'])vm.runInContext(adapt('source/'+file+'.mc'),context);
// Most cases exercise the optional compact exporter via the injected backend.
// stableApp uses the actual production backend, whose default creates NO fields.
function app(){return new context.BadmintonAppClass();}
function stableApp(){const a=app();a.recorder=new context.RecordingControllerClass(new context.NativeRecordingBackendClass());return a;}
function fitValues(session){const values=[];for(const f of session.fields)values[f.id]=f.value;return values;}
function open(a){context.showScoreMenu(a);return stack.at(-1).view;}
function choose(menu,id,value){const f=menu.frame(),index=f[1].findIndex(r=>r[1]===id&&(arguments.length<3||r[2]===value));assert(index>=0,`Missing ${id} in ${f[0]}`);f[2]=index;menu.select();}
function key(input,name){time+=500;return input[name]();}
const packed=a=>JSON.stringify(a.engine.pack());
let passed=0;function test(name,fn){stack.length=0;storage.clear();properties.clear();storageFailure=null;exits=0;time+=1000;try{fn();passed++;process.stdout.write('PASS '+name+'\n');}catch(e){failures++;process.stderr.write('FAIL '+name+'\n'+e.stack+'\n');}}
function openNew(menu,keep=true){choose(menu,'new');choose(menu,'settle',keep);}
function configureNew(menu,mode=1,points=21,record=false){openNew(menu);choose(menu,'newMode',mode);choose(menu,'newPoints');
 if(points!==21){menu.back();choose(menu,'newPoints',menu.frame()[1].find(r=>r[2][0]===points)[2]);}
 choose(menu,'newFormat',3);choose(menu,'newRule',0);choose(menu,'newServer',0);if(mode===1)choose(menu,'newReceiver',2);choose(menu,'newRecord',record);}
function finishGame(a,team=0){while(a.engine.state[4]===0)assert(a.award(team));}
function gameFlow(a){const input=new context.ScoreDelegateClass(a);key(input,'onSelect');return stack.at(-1).view;}

test('raw source declaration guard runs before type stripping',()=>assert.throws(()=>checkLocalDeclarations('function x(){var n as Number=0;}','x'),/local variable/));
test('root has eight short categories and no guide',()=>{const m=open(app());assert.deepEqual(Array.from(m.frame()[1],r=>r[0]),['新建比赛','比赛设置','数据页面','暂停比赛','运动记录','按键锁定','结束对局','退出应用']);});
test('BACK in a child returns one level; root BACK closes once without undo',()=>{
 const a=app();a.award(0);const before=packed(a),m=open(a),d=stack.at(-1).delegate;choose(m,'match');choose(m,'history');
 key(d,'onBack');assert.equal(m.frame()[3],'match');assert.equal(stack.length,1);key(d,'onBack');assert.equal(m.frame()[3],'root');key(d,'onBack');assert.equal(stack.length,0);assert.equal(packed(a),before);});
test('wizard BACK keeps pending settings after explicitly saving old match',()=>{
 const a=app();a.award(0);const before=packed(a),m=open(a);openNew(m);choose(m,'newMode',1);choose(m,'newPoints');choose(m,'newFormat',3);choose(m,'newRule',0);
 choose(m,'newServer',1);m.back();assert.equal(m.frame()[3],'newServer');choose(m,'newServer',0);choose(m,'newReceiver',3);choose(m,'newRecord',false);
 m.back();assert.equal(m.frame()[3],'newRecord');assert.equal(a.engine.state[0],0);assert.equal(storage.get('match-state-v2')?.[2][0][0][4][0],1);assert.equal(a.recorder.backend.creates,1);});
test('new doubles match commits chosen mode/points/players only on Start',()=>{
 const a=app(),m=open(a);configureNew(m,1,15,false);assert.equal(a.engine.target,21);choose(m,'newApply');
 assert.equal(a.engine.target,15);assert(a.engine.isDoubles());assert.equal(a.engine.serverPlayer(),0);assert.equal(a.engine.receiverPlayer(),2);assert.equal(a.recordWanted,false);assert.equal(stack.length,0);});
test('new singles can choose opponent as first server',()=>{
 const a=app(),m=open(a);openNew(m);choose(m,'newMode',0);choose(m,'newPoints');choose(m,'newFormat',1);choose(m,'newRule',0);choose(m,'newServer',2);choose(m,'newRecord',false);choose(m,'newApply');
 assert.equal(a.engine.serverPlayer(),2);assert.equal(a.engine.bestOf,1);});
test('cancelling new settings leaves ready state and prior saved result',()=>{
 const a=app();a.award(0);const before=packed(a),m=open(a);configureNew(m,1,21,true);choose(m,'cancelNew');assert.equal(m.frame()[3],'root');assert.equal(a.engine.state[0],0);assert.equal(storage.get('match-state-v2')?.[2][0][0][4][0],1);assert.equal(a.recorder.backend.creates,1);});
test('configured recording match waits for START before creating a FIT',()=>{
 const a=app(),m=open(a);configureNew(m,1,21,true);assert.equal(a.recorder.backend.creates,0);choose(m,'newApply');assert.equal(a.recorder.status,0);assert.equal(a.recorder.backend.creates,0);assert(a.startRally());assert.equal(a.recorder.status,1);assert.equal(a.recorder.backend.creates,1);});
test('default first START auto records; later rallies use the same session',()=>{
 const a=app(),input=new context.ScoreDelegateClass(a);key(input,'onSelect');assert.equal(a.page,3);assert.equal(a.recorder.status,1);assert.equal(a.recorder.backend.creates,1);
 key(input,'onPreviousPage');assert.equal(a.page,0);key(input,'onSelect');assert.equal(a.recorder.backend.creates,1);assert.equal(a.engine.state[0],1);});
test('explicit Score only START creates no activity',()=>{const a=app();a.newMatch(21,30,3,false,0,0,2);a.startRally();assert.equal(a.recorder.backend.creates,0);assert.equal(a.page,3);});
test('record creation failure prevents a misleading recording start',()=>{const a=app();a.recorder.backend.failCreate=true;assert.equal(a.startRally(),false);assert.equal(a.page,0);assert(a.notice.includes('运动'));});
test('court BACK returns unchanged; next scoreboard BACK performs undo',()=>{const a=app(),i=new context.ScoreDelegateClass(a);a.recordWanted=false;key(i,'onPreviousPage');key(i,'onSelect');const before=packed(a);key(i,'onBack');assert.equal(packed(a),before);assert.equal(a.page,0);key(i,'onBack');assert.equal(a.engine.state[0],0);});
test('court point awards exactly once and returns to score',()=>{const a=app(),i=new context.ScoreDelegateClass(a);a.recordWanted=false;key(i,'onSelect');key(i,'onNextPage');assert.equal(a.page,0);assert.equal(a.engine.state[1],1);key(i,'onSelect');key(i,'onPreviousPage');assert.equal(a.engine.state[0],1);assert.equal(a.page,0);});
test('long-menu callback does not score',()=>{const a=app(),i=new context.ScoreDelegateClass(a),before=packed(a);i.onMenu();assert.equal(packed(a),before);assert.equal(stack.length,1);});
test('Lock and Unlock are explicit, repeatable, visible and remain in Keys',()=>{
 const a=app(),m=open(a);choose(m,'keys');choose(m,'lock');assert.equal(a.locked,true);assert.equal(m.frame()[3],'keys');assert.equal(a.award(0),false);assert.equal(a.startRally(),false);
 choose(m,'unlock');choose(m,'unlock');assert.equal(a.locked,false);assert.equal(a.award(0),true);choose(m,'lock');choose(m,'lock');choose(m,'unlock');assert.equal(a.award(1),true);});
test('unlock never silently resumes a paused activity',()=>{
 const a=app();a.startRally();a.showPage(0);a.recordingAction('recPause');const m=open(a);choose(m,'keys');choose(m,'lock');choose(m,'unlock');
 assert.equal(a.locked,false);assert.equal(a.award(0),false);assert(a.notice.includes('继续记录'));assert(a.recordingAction('recResume'));assert(a.award(0));});
test('activity actions remain in submenu, saving one FIT; status is explicit',()=>{
 const a=app();a.startRally();a.showPage(0);time+=2000;const m=open(a);choose(m,'activity');choose(m,'recPause');assert.equal(m.frame()[3],'activity');choose(m,'recResume');
 choose(m,'recSave');assert.equal(a.recorder.status,3);assert.equal(a.recorder.backend.session.saves,1);choose(m,'status');assert.equal(m.frame()[1][0][0],'运动已保存');});
test('failed FIT save keeps activity and does not exit or clear score',()=>{
 const a=app();a.startRally();a.award(0);const before=packed(a);a.recorder.backend.session.failSave=true;
 assert.equal(a.saveAndExit(),false);assert.equal(exits,0);assert.equal(a.closed,false);assert.equal(packed(a),before);assert((storage.get('match-state-v2')?.[1]!=null));assert(a.recorder.hasSession());});
test('Save & exit saves FIT, archives result, deletes active score, and onStop cannot recreate it',()=>{
 const a=app();a.startRally();a.award(0);time+=3000;const session=a.recorder.backend.session;
 assert(a.saveAndExit());assert.equal(session.saves,1);assert.equal(exits,1);assert.equal(a.closed,true);assert.equal((storage.get('match-state-v2')?.[1]!=null),false);
 a.onStop(null);assert.equal((storage.get('match-state-v2')?.[1]!=null),false);const next=app();next.onStart(null);assert.equal(next.engine.state[0],0);assert.equal(next.lastMatch[1],true);assert.equal(next.lastMatch[0][4][0],1);
 assert(a.saveAndExit());assert.equal(session.saves,1);assert.equal(exits,1);});
test('score-only exit confirms No recording and archives No FIT, then starts fresh',()=>{
 const a=app();a.recordWanted=false;a.award(1);const m=open(a);choose(m,'exit');choose(m,'endConfirm');assert.equal(m.frame()[0],'尚未记录');
 choose(m,'endApply');assert.equal(exits,1);assert.equal(storage.get('match-state-v2')?.[2][0][1],false);a.onStop(null);const next=app();next.onStart(null);assert.equal(next.engine.state[1],0);});
test('exit cancellation returns to Exit parent with current match untouched',()=>{
 const a=app();a.award(0);const before=packed(a),m=open(a);choose(m,'exit');choose(m,'endConfirm');choose(m,'back');assert.equal(m.frame()[3],'exit');assert.equal(exits,0);assert.equal(packed(a),before);});
test('archive storage failure blocks exit; retry does not save duplicate FIT',()=>{
 const a=app();a.startRally();a.award(0);storageFailure='archive-commit';assert.equal(a.saveAndExit(),false);assert.equal(exits,0);assert.equal(a.recorder.status,3);
 assert((storage.get('match-state-v2')?.[1]!=null));storageFailure=null;assert(a.saveAndExit());assert.equal(a.recorder.backend.session.saves,1);});
test('active-score deletion failure retains resumable state until successful retry',()=>{
 const a=app();a.award(1);storageFailure='archive-commit';assert.equal(a.saveAndExit(),false);assert.equal(exits,0);assert.equal(a.closed,false);
 storageFailure=null;assert(a.saveAndExit());assert.equal((storage.get('match-state-v2')?.[1]!=null),false);});
test('ordinary interruption preserves score and next launch does not force Lock',()=>{
 const a=app();a.recordWanted=false;a.award(0);a.onStop(null);const next=app();next.onStart(null);assert.equal(next.engine.state[0],1);assert.equal(next.locked,false);assert.equal(next.recordWanted,false);});
test('an earlier saved FIT is not relabeled No FIT after a later recording is discarded',()=>{
 const a=app();a.startRally();a.award(0);a.recordingAction('recSave');const first=a.recorder.backend.session;
 assert(a.matchFitSaved);a.recordingAction('recStart');a.recordingAction('recDiscard');assert.equal(a.recorder.status,0);assert(a.matchFitSaved);
 const m=open(a);choose(m,'exit');choose(m,'endConfirm');assert.equal(m.frame()[0],'结束本场？');choose(m,'endApply');assert.equal(storage.get('match-state-v2')?.[2][0][1],true);assert.equal(first.saves,1);});
test('earlier saved FIT flag survives score resume and resets for a new match',()=>{
 const a=app();a.startRally();a.award(0);a.recordingAction('recSave');a.onStop(null);const next=app();next.onStart(null);assert(next.matchFitSaved);
 assert(next.newMatch(21,30,3,false,0,0,2));assert.equal(next.matchFitSaved,false);});
test('midgame double serve correction keeps scores, last scorer and results, and is undoable',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);a.award(0);a.award(0);a.award(1);const before=packed(a),m=open(a);choose(m,'match');choose(m,'edit');choose(m,'editServer',2);choose(m,'editReceiver',0);
 choose(m,'editApply');assert.equal(m.frame()[3],'match');assert.equal(a.engine.serverPlayer(),2);assert.equal(a.engine.receiverPlayer(),0);assert.equal(a.engine.serviceCourt(),1);
 assert.equal(a.engine.state[0],2);assert.equal(a.engine.state[1],1);assert.equal(a.engine.state[7],1);a.undo();assert.equal(packed(a),before);});
test('serve correction cancellation and BACK leave lineup unchanged',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);a.award(0);const before=packed(a),m=open(a);choose(m,'match');choose(m,'edit');choose(m,'editServer',1);m.back();assert.equal(m.frame()[3],'editServer');assert.equal(packed(a),before);});
test('single serve correction works at nonzero points without adding points',()=>{
 const a=app();a.award(0);const m=open(a);choose(m,'match');choose(m,'edit');choose(m,'editServer',2);choose(m,'editApply');assert.equal(a.engine.serverPlayer(),2);assert.equal(a.engine.state[0],1);});
test('invalid/finished/locked serve corrections are rejected',()=>{
 const a=app();assert.equal(a.engine.editService(1,2),false);assert.equal(a.engine.editService(0,0),false);a.setLocked(true);assert.equal(a.editServe(2,0,false),false);
 a.setLocked(false);for(let n=0;n<21;n++)a.engine.point(0);assert.equal(a.engine.editService(2,0),false);});
test('menu next-game alias uses save/continue flow and defaults to prior winning team',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);for(let n=0;n<21;n++)a.award(1);const m=open(a);choose(m,'match');choose(m,'next');
 assert.equal(m.frame()[3],'roundSave');choose(m,'roundKeep',true);choose(m,'roundNext',true);
 assert.equal(m.frame()[3],'roundTeam');assert.equal(m.frame()[2],1);assert.equal(a.engine.state[6],1);});
test('pages select their view; BACK navigation never adds or undoes points',()=>{
 const a=app();a.award(0);const before=packed(a),m=open(a);choose(m,'pages');choose(m,'page',2);assert.equal(stack.length,0);assert.equal(a.page,2);
 const i=new context.ScoreDelegateClass(a);key(i,'onPreviousPage');key(i,'onNextPage');key(i,'onSelect');assert.equal(packed(a),before);key(i,'onBack');assert.equal(a.page,0);assert.equal(packed(a),before);});
test('new match first asks yes/no without changing an active FIT',()=>{
 const a=app();a.startRally();const before=packed(a),m=open(a);choose(m,'new');assert.equal(m.frame()[3],'settle');assert.deepEqual(Array.from(m.frame()[1],r=>r[0]),['是','否']);assert.equal(packed(a),before);assert.equal(a.newMatch(21,30,3,false,0,0,2),false);});
test('root menu wraps up from first to last and down from last to first',()=>{
 const m=open(app()),d=stack.at(-1).delegate;key(d,'onPreviousPage');assert.equal(m.frame()[2],7);key(d,'onNextPage');assert.equal(m.frame()[2],0);
 m.frame()[2]=7;key(d,'onNextPage');assert.equal(m.frame()[2],0);});
test('two-entry and one-entry submenus wrap safely without leaving their level',()=>{
 const m=open(app());choose(m,'keys');m.move(-1);assert.equal(m.frame()[2],1);m.move(1);assert.equal(m.frame()[2],0);m.back();
 choose(m,'match');choose(m,'history');assert.equal(m.frame()[1].length,1);m.move(-1);m.move(1);assert.equal(m.frame()[2],0);assert.equal(m.frame()[3],'history');});
test('exit offers save, discard, or return; destructive confirmation starts on Cancel',()=>{
 const a=app();a.startRally();const m=open(a);choose(m,'exit');assert.deepEqual(Array.from(m.frame()[1],r=>r[0]),['保存退出','放弃退出','返回比赛']);
 choose(m,'dropConfirm');assert.equal(m.frame()[1][m.frame()[2]][0],'取消');assert.equal(exits,0);});
test('discard & exit calls discard but never save, then onStop cannot save it',()=>{
 const a=app();a.startRally();a.award(0);const session=a.recorder.backend.session,m=open(a);choose(m,'exit');choose(m,'dropConfirm');choose(m,'dropApply');
 assert.equal(session.discards,1);assert.equal(session.saves,0);assert(a.closed);assert.equal(exits,1);a.onStop(null);assert.equal(session.saves,0);
 assert.equal((storage.get('match-state-v2')?.[1]!=null),false);assert.equal(storage.get('match-state-v2')?.[2][0][1],false);assert.equal(storage.get('match-state-v2')?.[2][0][0][4][0],1);
 const next=app();next.onStart(null);assert.equal(next.engine.state[0],0);});
test('cancelling discard and returning to match preserve recording and points',()=>{
 const a=app();a.startRally();a.award(1);const session=a.recorder.backend.session,before=packed(a),m=open(a);
 choose(m,'exit');choose(m,'dropConfirm');choose(m,'back');assert.equal(m.frame()[3],'exit');assert.equal(session.discards,0);assert.equal(session.saves,0);
 choose(m,'returnPlay');assert.equal(stack.length,0);assert.equal(a.recorder.status,1);assert.equal(packed(a),before);assert.equal(exits,0);});
test('failed discard blocks exit and can be retried without saving',()=>{
 const a=app();a.startRally();a.award(0);const session=a.recorder.backend.session,before=packed(a);session.failDiscard=true;
 assert.equal(a.discardAndExit(),false);assert.equal(exits,0);assert(a.recorder.hasSession());assert.equal(packed(a),before);assert.equal(session.saves,0);
 session.failDiscard=false;assert(a.discardAndExit());assert.equal(session.saves,0);assert.equal(exits,1);});
test('discarding current session never deletes or relabels earlier saved activity',()=>{
 const a=app();a.startRally();a.award(0);a.recordingAction('recSave');const first=a.recorder.backend.session;
 a.recordingAction('recStart');const second=a.recorder.backend.session;assert(a.discardAndExit());assert.equal(first.saves,1);assert.equal(second.saves,0);assert.equal(second.discards,1);assert.equal(storage.get('match-state-v2')?.[2][0][1],true);});
test('already-saved session shows honest discard dialog and creates no second save',()=>{
 const a=app();a.startRally();a.recordingAction('recSave');const session=a.recorder.backend.session,m=open(a);
 choose(m,'exit');choose(m,'dropConfirm');assert.equal(m.frame()[0],'运动已经保存');choose(m,'dropApply');assert.equal(session.saves,1);assert.equal(session.discards,0);});
test('score-only discard exit generates no workout file',()=>{
 const a=app();a.recordWanted=false;a.award(0);assert(a.discardAndExit());assert.equal(a.recorder.backend.creates,0);assert.equal(storage.get('match-state-v2')?.[2][0][1],false);});
test('new YES saves current FIT and score, opens mode selection, never exits',()=>{
 const a=app();a.startRally();a.award(0);const old=a.recorder.backend.session,m=open(a);choose(m,'new');
 assert.equal(m.frame()[0],'是否保存当前对局结果');choose(m,'settle',true);
 assert.equal(old.saves,1);assert.equal(old.discards,0);assert.equal(exits,0);assert.equal(m.frame()[3],'newMode');
 assert.equal(storage.get('match-state-v2')?.[2][0][0][4][0],1);assert.equal(a.engine.state[0],0);assert.equal(a.recorder.status,0);});
test('new NO discards pending FIT and does not archive the declined result',()=>{
 const a=app();a.startRally();a.award(1);const old=a.recorder.backend.session,m=open(a);choose(m,'new');choose(m,'settle',false);
 assert.equal(old.saves,0);assert.equal(old.discards,1);assert.equal(exits,0);assert.equal(m.frame()[3],'newMode');assert.equal((storage.get('match-state-v2')?.[2].length>0),false);});
test('BACK on new save question keeps playing score and recording untouched',()=>{
 const a=app();a.startRally();a.award(1);const old=a.recorder.backend.session,before=packed(a),m=open(a);choose(m,'new');m.back();
 assert.equal(m.frame()[3],'root');assert.equal(old.saves,0);assert.equal(old.discards,0);assert.equal(packed(a),before);assert.equal(a.recorder.status,1);});
test('finish YES returns ready inside app with current format and archived partial result',()=>{
 const a=app();a.newMatch(15,21,3,true,1,0,2);a.startRally();a.award(1);const old=a.recorder.backend.session,m=open(a);choose(m,'finish');choose(m,'settle',true);
 assert.equal(stack.length,0);assert.equal(exits,0);assert.equal(a.closed,false);assert.equal(a.page,0);assert.equal(a.engine.target,15);assert(a.engine.isDoubles());
 assert.equal(a.engine.state[1],0);assert.equal(a.recorder.status,0);assert.equal(a.report.started,false);assert.equal(storage.get('match-state-v2')?.[2][0][4],true);assert.equal(old.saves,1);
 assert(a.startRally());assert.notEqual(a.recorder.backend.session,old);assert.equal(a.recorder.backend.creates,2);});
test('finish NO keeps older saved result and resets without saving declined match',()=>{
 const a=app();a.award(0);assert(a.endCurrent(true));const older=JSON.stringify(storage.get('match-state-v2')?.[2][0]);
 a.startRally();a.award(1);const old=a.recorder.backend.session,m=open(a);choose(m,'finish');choose(m,'settle',false);
 assert.equal(old.saves,0);assert.equal(old.discards,1);assert.equal(JSON.stringify(storage.get('match-state-v2')?.[2][0]),older);assert.equal(exits,0);});
test('save failure in new question keeps score and does not enter wizard',()=>{
 const a=app();a.startRally();a.award(0);const old=a.recorder.backend.session,before=packed(a),m=open(a);old.failSave=true;choose(m,'new');choose(m,'settle',true);
 assert.equal(m.frame()[3],'message');assert.equal(packed(a),before);assert(a.recorder.hasSession());assert.equal(exits,0);old.failSave=false;m.back();choose(m,'settle',true);assert.equal(m.frame()[3],'newMode');});
test('discard failure in finish question does not reset current score',()=>{
 const a=app();a.startRally();a.award(1);const old=a.recorder.backend.session,before=packed(a);old.failDiscard=true;
 assert.equal(a.endCurrent(false),false);assert.equal(packed(a),before);assert.equal(exits,0);assert(a.recorder.hasSession());});
test('archive error blocks ready transition; retry never duplicates saved FIT',()=>{
 const a=app();a.startRally();a.award(0);const old=a.recorder.backend.session,before=packed(a);storageFailure='archive-commit';
 assert.equal(a.endCurrent(true),false);assert.equal(packed(a),before);assert.equal(old.saves,1);storageFailure=null;assert(a.endCurrent(true));assert.equal(old.saves,1);});
test('new active-score storage error restores old resumable match',()=>{
 const a=app();a.award(1);const before=packed(a);storageFailure='archive-commit';assert.equal(a.endCurrent(true),false);assert.equal(packed(a),before);
 assert.equal(storage.get('match-state-v2')[1][0][4][1],1);storageFailure=null;assert(a.endCurrent(true));assert.equal(storage.get('match-state-v2')[1][0][4][1],0);});
test('leaving ready state does not overwrite the just-saved last match with zeroes',()=>{
 const a=app();a.award(1);assert(a.endCurrent(true));const saved=JSON.stringify(storage.get('match-state-v2')?.[2][0]);assert(a.saveAndExit());assert.equal(JSON.stringify(storage.get('match-state-v2')?.[2][0]),saved);});
test('declining a new result cannot delete an activity already saved earlier',()=>{
 const a=app();a.startRally();a.award(0);a.recordingAction('recSave');const saved=a.recorder.backend.session;
 assert(a.endCurrent(false));assert.equal(saved.saves,1);assert.equal(saved.discards,0);});
test('FIT fields have stable unique IDs, small payloads and correct message types',()=>{
 const a=app();a.startRally();const fields=a.recorder.backend.session.fields;assert.equal(fields.length,13);
 assert.deepEqual(fields.map(f=>f.id),Array.from({length:13},(_,i)=>i+4));
 for(const [message,expected] of [[18,25],[20,0]])assert.equal(fields.filter(f=>f.options.mesgType===message).reduce((n,f)=>n+(f.type===6?4:1),0),expected);});
test('manual stop writes partial scores and elapsed time before saving',()=>{
 const a=app();a.startRally();time+=6000;a.award(0);time+=4000;a.award(1);const old=a.recorder.backend.session;assert(a.endCurrent(true));
 const v=fitValues(old);assert.equal(v[4],10);assert.equal(v[5],2);assert.equal(v[6],1);assert.equal(v[7],1);assert.equal(v[8],10);assert.equal(v[15],1);assert.equal(v[16],1);});
test('three-game summary keeps scores/durations distinct and records natural finish',()=>{
 const a=app();a.newMatch(21,30,3,true,0,0,2);a.startRally();const old=a.recorder.backend.session;
 for(let game=0;game<3;game++){if(game){time+=5000;assert(a.nextGame());time+=5000;assert(a.startRally());}
  for(let point=0;point<21;point++){time+=1000;a.award(game===1?1:0);}}
 assert(a.endCurrent(true));const v=fitValues(old);assert.equal(v[5],1);assert.equal(a.lastMatch[0][4][2],2);assert.equal(a.lastMatch[0][4][3],1);
 assert.deepEqual(v.slice(6,15),[21,0,21,0,21,21,21,0,21]);assert.equal(v[15],3);assert.equal(v[4],83);});
test('summary uses corrected score and no live chart fields are created',()=>{
 const a=app();a.startRally();a.award(0);a.award(1);a.undo();const old=a.recorder.backend.session;
 assert(!old.fields.some(f=>f.id===17||f.id===18));assert(a.endCurrent(true));assert.equal(fitValues(old)[6],1);assert.equal(fitValues(old)[7],0);});
test('FIT summary failure prevents save and reset, allowing retry',()=>{
 const a=app();a.startRally();a.award(1);const old=a.recorder.backend.session,before=packed(a);a.recorder.backend.failSummary=true;
 assert.equal(a.endCurrent(true),false);assert.equal(old.saves,0);assert.equal(packed(a),before);a.recorder.backend.failSummary=false;assert(a.endCurrent(true));assert.equal(old.saves,1);});
test('old score storage restores honestly with unknown timing, without counting downtime',()=>{
 const a=app();a.award(0);a.save();storage.delete('match-state-v2');storage.set('match-v1',JSON.parse(packed(a)));storage.set('record-wanted',true);time+=100000;const next=app();next.onStart(null);assert.equal(next.report.known,false);
 time+=100000;next.refreshMatch();assert.equal(next.report.totalMs,0);next.startRally();assert(next.endCurrent(true));assert.equal(fitValues(next.recorder.backend.session)[16],0);});
test('paused activity time is excluded from match and game summary',()=>{
 const a=app();a.startRally();time+=2000;a.recordingAction('recPause');time+=20000;a.recordingAction('recResume');time+=3000;const old=a.recorder.backend.session;
 assert(a.endCurrent(true));assert.equal(fitValues(old)[4],5);assert.equal(fitValues(old)[8],5);});
test('actual stable START path never invokes createField, even if it would fail',()=>{
 const factory=context.ActivityRecording.createSession;let calls=0;
 context.ActivityRecording.createSession=()=>{const s=factory();s.createField=()=>{calls++;throw Error('fatal native field allocation');};return s;};
 try{const a=stableApp(),input=new context.ScoreDelegateClass(a);assert.equal(a.recorder.backend.fitEnabled,false);key(input,'onSelect');
  assert.equal(a.page,3);assert.equal(a.recorder.status,1);assert.equal(calls,0);assert.equal(nativeSessions.at(-1).fields.length,0);
 }finally{context.ActivityRecording.createSession=factory;}});
test('actual stable backend keeps one ordinary session across repeated START presses',()=>{
 const a=stableApp(),input=new context.ScoreDelegateClass(a),before=nativeSessions.length;
 for(let i=0;i<12;i++){key(input,'onSelect');key(input,'onSelect');key(input,'onPreviousPage');}
 assert.equal(nativeSessions.length,before+1);assert.equal(nativeSessions.at(-1).fields.length,0);assert.equal(a.engine.state[0],12);});
test('ordinary session saves while detailed scores and timing remain in watch archive',()=>{
 const a=stableApp();a.startRally();time+=5000;a.award(1);const s=nativeSessions.at(-1);assert(a.endCurrent(true));
 assert.equal(s.saves,1);assert.equal(s.fields.length,0);assert.equal(a.lastMatch[0][4][1],1);assert.equal(a.lastMatch[2],5000);assert.equal(a.lastMatch[1],true);});
test('stable new-match YES saves ordinary activity and opens wizard without exit',()=>{
 const a=stableApp();a.startRally();a.award(0);const s=nativeSessions.at(-1),m=open(a);choose(m,'new');choose(m,'settle',true);
 assert.equal(s.saves,1);assert.equal(s.fields.length,0);assert.equal(m.frame()[3],'newMode');assert.equal(exits,0);});
test('stable finish NO discards ordinary session and stays ready',()=>{
 const a=stableApp();a.startRally();a.award(1);const s=nativeSessions.at(-1);assert(a.endCurrent(false));
 assert.equal(s.discards,1);assert.equal(s.saves,0);assert.equal(a.engine.state[1],0);assert.equal(a.report.started,false);assert.equal(exits,0);});
test('stable pause/resume still records normal activity without any custom fields',()=>{
 const a=stableApp();a.startRally();time+=2000;assert(a.recordingAction('recPause'));time+=10000;assert(a.recordingAction('recResume'));time+=3000;
 const s=nativeSessions.at(-1);assert(a.saveAndExit());assert.equal(s.saves,1);assert.equal(s.fields.length,0);assert.equal(a.recorder.elapsedMs,5000);});
test('optional compact exporter through actual backend stays below modeled 16-field limit',()=>{
 const a=stableApp();a.recorder.backend.fitEnabled=true;assert(a.startRally());const s=nativeSessions.at(-1);assert.equal(s.fields.length,13);
 a.award(0);assert(a.endCurrent(true));assert.equal(fitValues(s)[6],1);assert.equal(s.saves,1);});
test('catchable optional export failure keeps ordinary session instead of discarding it',()=>{
 const factory=context.ActivityRecording.createSession;
 context.ActivityRecording.createSession=()=>{const s=factory();s.createField=()=>{throw Error('catchable extension error');};return s;};
 try{const a=stableApp();a.recorder.backend.fitEnabled=true;assert(a.startRally());const s=nativeSessions.at(-1);
  assert.equal(a.recorder.backend.lastExportError,'比分扩展不可用');assert.equal(s.discards,0);assert(a.endCurrent(true));assert.equal(s.saves,1);
 }finally{context.ActivityRecording.createSession=factory;}});
test('mock hardware rejects a seventeenth field so byte-only checks cannot hide the regression',()=>{
 const s=new Session();for(let i=0;i<16;i++)s.createField('field'+i,i,2,{mesgType:18});
 assert.throws(()=>s.createField('too_many',16,2,{mesgType:18}),/developer-field count limit/);});
test('small labels and larger menus each cache one font object',()=>{
 const before=resourceLoads,a=app();assert.equal(resourceLoads-before,2);assert.equal(a.fonts.small,31);assert.equal(a.fonts.normal,32);assert.equal(a.fonts.menuSize,19);});
test('terminal game START opens save question with YES selected, preserving scoreboard',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);
 assert.equal(m.frame()[3],'roundSave');assert.equal(m.frame()[1][m.frame()[2]][0],'是');assert.equal(packed(a),before);});
test('decline game checkpoint then decline next game returns unchanged terminal score',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);choose(m,'roundKeep',false);
 assert.equal(m.frame()[3],'roundNext');assert.equal(m.frame()[1][m.frame()[2]][0],'是');choose(m,'roundNext',false);
 assert.equal(stack.length,0);assert.equal(packed(a),before);assert.equal(a.checkpoints.choices[0],0);assert.equal(a.checkpoints.snapshots[0],null);assert.equal(a.page,0);});
test('returned terminal scoreboard can repeat START flow without duplicate saved games',()=>{
 const a=stableApp();finishGame(a);const before=packed(a);
 for(let i=0;i<5;i++){const m=gameFlow(a);assert.equal(m.frame()[2],0);choose(m,'roundKeep',true);choose(m,'roundNext',false);assert.equal(packed(a),before);}
 assert.equal(a.checkpoints.snapshots.filter(Boolean).length,1);assert.equal(a.checkpoints.snapshots.length,3);});
test('BACK out of save question leaves game choice pending and never advances',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);m.back();assert.equal(stack.length,0);
 assert.equal(a.checkpoints.choices[0],-1);assert.equal(packed(a),before);});
test('next-game serve selection is staged; BACK and NO keep original score',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',true);
 choose(m,'roundTeam',0);assert.equal(m.frame()[3],'roundReceiver');assert.equal(packed(a),before);m.back();m.back();
 assert.equal(m.frame()[3],'roundNext');choose(m,'roundNext',false);assert.equal(packed(a),before);});
test('single next game starts at zero only after explicit opposing receiver confirmation',()=>{
 const a=stableApp();finishGame(a);const m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',true);choose(m,'roundTeam',1);
 assert.equal(m.frame()[1].length,1);assert.equal(m.frame()[1][0][2],0);choose(m,'roundReceiver',0);
 assert.equal(stack.length,0);assert.equal(a.engine.state[6],2);assert.equal(a.engine.state[0],0);assert.equal(a.engine.state[1],0);
 assert.equal(a.engine.state[2],1);assert.equal(a.engine.serverPlayer(),2);assert.equal(a.report.gameRunning,false);});
test('double next game permits chosen team/player/receiver with correct zero-score courts',()=>{
 const a=stableApp();a.newMatch(21,30,3,false,1,0,2);finishGame(a,1);const m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',true);
 assert.equal(m.frame()[2],1);choose(m,'roundTeam',0);choose(m,'roundServer',1);choose(m,'roundReceiver',3);
 assert.equal(a.engine.state[6],2);assert.equal(a.engine.serverPlayer(),1);assert.equal(a.engine.receiverPlayer(),3);
 assert.equal(a.engine.serviceCourt(),0);assert.equal(a.engine.playerAtCourt(0,0),1);assert.equal(a.engine.playerAtCourt(1,0),3);});
test('next-game commit is one undo operation restoring terminal score and checkpoint',()=>{
 const a=stableApp();a.newMatch(21,30,3,false,1,0,2);finishGame(a);const before=packed(a),m=gameFlow(a);
 choose(m,'roundKeep',true);choose(m,'roundNext',true);choose(m,'roundTeam',1);choose(m,'roundServer',3);choose(m,'roundReceiver',1);
 a.undo();assert.equal(packed(a),before);assert.equal(a.engine.state[4],1);assert.equal(a.checkpoints.choices[0],1);});
test('next-game staging reuses bounded immutable history instead of cloning old states',()=>{
 const a=stableApp();a.recordWanted=false;for(let i=0;i<29;i++){a.award(0);a.award(1);}
 for(let i=0;i<12;i++)a.editServe(i%2===0?0:2,i%2===0?2:0,false);a.award(0);
 const prior=a.engine,history=prior.history;assert.equal(history.length,64);assert(a.prepareNextGame(0,2));
 assert.equal(a.engine.history.length,64);assert.equal(a.engine.history[0],history[1]);assert.equal(prior.state[0],30);assert.equal(prior.state[1],29);});
test('undoing last winning point invalidates the old saved game checkpoint',()=>{
 const a=stableApp();finishGame(a);const m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',false);a.undo();
 assert.equal(a.engine.state[4],0);assert.equal(a.engine.state[0],20);assert.equal(a.checkpoints.choices[0],-1);assert.equal(a.checkpoints.snapshots[0],null);});
test('game checkpoint failure blocks next question and allows retry without score change',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);storageFailure='match-state-v2';choose(m,'roundKeep',true);
 assert.equal(m.frame()[3],'message');assert.equal(packed(a),before);assert.equal(a.checkpoints.choices[0],-1);
 storageFailure=null;m.back();choose(m,'roundKeep',true);assert.equal(m.frame()[3],'roundNext');});
test('next-game storage failure preserves game number, score and serve choices for retry',()=>{
 const a=stableApp();finishGame(a);const before=packed(a),m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',true);choose(m,'roundTeam',0);
 storageFailure='archive-commit';choose(m,'roundReceiver',2);assert.equal(m.frame()[3],'message');assert.equal(packed(a),before);
 storageFailure=null;m.back();choose(m,'roundReceiver',2);assert.equal(a.engine.state[6],2);});
test('game checkpoint choice survives restart and still opens terminal START flow',()=>{
 const a=stableApp();finishGame(a);assert(a.saveCompletedGame(true));a.save();const next=stableApp();next.onStart(null);
 assert.equal(next.checkpoints.choices[0],1);assert.equal(next.checkpoints.snapshots[0][0],21);assert.equal(gameFlow(next).frame()[3],'roundSave');});
test('per-game save keeps one ordinary FIT open; next-game waiting is not game time',()=>{
 const a=stableApp();a.startRally();finishGame(a);const s=nativeSessions.at(-1),before=nativeSessions.length,m=gameFlow(a);
 choose(m,'roundKeep',true);choose(m,'roundNext',true);choose(m,'roundTeam',0);choose(m,'roundReceiver',2);
 time+=5000;a.refreshMatch();assert.equal(a.report.gameMs[1],0);assert(a.primarySelect());time+=2000;a.refreshMatch();
 assert.equal(a.report.gameMs[1],2000);assert.equal(s.saves,0);assert.equal(nativeSessions.length,before);assert.equal(s.fields.length,0);});
test('21:20 is not terminal; 22:20 shows next-game action',()=>{
 const a=stableApp();a.recordWanted=false;for(let i=0;i<20;i++){a.award(0);a.award(1);}a.award(0);
 assert.equal(a.engine.state[4],0);assert(a.primarySelect());assert.equal(a.page,3);assert.equal(stack.length,0);
 a.award(0);assert.equal(a.engine.state[4],1);assert.equal(gameFlow(a).frame()[3],'roundSave');});
test('one-game completed match opens result and switches to save after six bounded ticks',()=>{
 const a=stableApp();a.newMatch(21,30,1,false,0,0,2);finishGame(a);const before=packed(a),m=gameFlow(a);
 assert.equal(m.frame()[3],'result');assert.equal(m.timer.interval,400);for(let i=0;i<5;i++){m.tick();assert.equal(m.frame()[3],'result');}
 m.tick();assert.equal(m.frame()[3],'matchSave');assert.equal(m.frame()[2],0);assert.equal(m.timer.interval,1000);assert.equal(packed(a),before);});
test('result can be skipped and save-question BACK returns final score for another START',()=>{
 const a=stableApp();a.newMatch(21,30,1,false,0,0,2);finishGame(a,1);const before=packed(a),m=gameFlow(a);
 m.select();assert.equal(m.frame()[3],'matchSave');m.back();assert.equal(stack.length,0);assert.equal(packed(a),before);
 assert.equal(gameFlow(a).frame()[3],'result');});
test('best of three ends after two wins, without offering an unnecessary third game',()=>{
 const a=stableApp();finishGame(a);assert(a.prepareNextGame(0,2));finishGame(a);assert.equal(a.engine.state[6],2);assert.equal(a.engine.state[4],2);
 assert.equal(gameFlow(a).frame()[3],'result');assert.equal(a.prepareNextGame(0,2),false);});
test('final YES saves whole match and ordinary FIT then stays ready for direct START',()=>{
 const a=stableApp();a.newMatch(21,30,1,true,0,0,2);a.startRally();finishGame(a);const s=nativeSessions.at(-1),m=gameFlow(a);m.select();choose(m,'matchKeep',true);
 assert.equal(stack.length,0);assert.equal(exits,0);assert.equal(a.engine.state[0],0);assert.equal(a.engine.state[2],0);assert.equal(a.engine.bestOf,1);
 assert.equal(a.lastMatch[0][4][0],21);assert.equal(a.lastMatch[5][1][0],1);assert.equal(s.saves,1);assert.equal(a.checkpoints.choices[0],-1);
 assert(a.primarySelect());assert.equal(a.recorder.status,1);assert.notEqual(nativeSessions.at(-1),s);});
test('final NO discards pending ordinary FIT, preserves older archive, and stays ready',()=>{
 const a=stableApp();a.award(1);assert(a.endCurrent(true));const prior=JSON.stringify(storage.get('match-state-v2')?.[2][0]);
 a.newMatch(21,30,1,true,0,0,2);a.startRally();finishGame(a,1);const s=nativeSessions.at(-1),m=gameFlow(a);m.select();choose(m,'matchKeep',false);
 assert.equal(s.discards,1);assert.equal(s.saves,0);assert.equal(exits,0);assert.equal(a.engine.state[0],0);assert.equal(JSON.stringify(storage.get('match-state-v2')?.[2][0]),prior);});
test('whole-match YES includes complete results even if a separate game checkpoint was declined',()=>{
 const a=stableApp();finishGame(a);assert(a.saveCompletedGame(false));assert(a.prepareNextGame(0,2));finishGame(a);
 const m=gameFlow(a);m.select();choose(m,'matchKeep',true);assert.deepEqual(Array.from(a.lastMatch[5][1]),[1,1,-1]);});
test('final FIT save failure preserves winning score and can retry from question',()=>{
 const a=stableApp();a.newMatch(21,30,1,true,0,0,2);a.startRally();finishGame(a);const s=nativeSessions.at(-1),before=packed(a),m=gameFlow(a);
 m.select();s.failSave=true;choose(m,'matchKeep',true);assert.equal(m.frame()[3],'message');assert.equal(packed(a),before);assert(a.recorder.hasSession());
 s.failSave=false;m.back();choose(m,'matchKeep',true);assert.equal(a.engine.state[0],0);});
test('archive failure after final FIT save retries without a second FIT save',()=>{
 const a=stableApp();a.newMatch(21,30,1,true,0,0,2);a.startRally();finishGame(a);const s=nativeSessions.at(-1),m=gameFlow(a);m.select();storageFailure='archive-commit';
 choose(m,'matchKeep',true);assert.equal(m.frame()[3],'message');assert.equal(s.saves,1);assert.equal(a.engine.state[4],2);
 storageFailure=null;m.back();choose(m,'matchKeep',true);assert.equal(s.saves,1);assert.equal(a.engine.state[0],0);});
test('active lock blocks terminal START flow until unlocked',()=>{
 const a=stableApp();finishGame(a);a.setLocked(true);assert.equal(a.primarySelect(),false);assert.equal(stack.length,0);a.setLocked(false);assert(a.primarySelect());assert.equal(stack.at(-1).view.frame()[3],'roundSave');});
for(const name of ['numericMenuIdRegression','clockTextRegression','courtPerspectiveRegression','singlesCourtRegression','doublesCourtRegression','editDoublesMidGame','editSinglesMidGame','editServeRestore','reportGameBreaks','reportPause','reportRestoreGap','reportLegacyUnknown','reportPartialRows','reportUndoBoundary','checkpointReplaces','checkpointDecline','checkpointUndoInvalidates','checkpointRestore'])test('native-format regression via adapter: '+name,()=>assert.equal(context[name]({}),true));

const Graphics={COLOR_BLACK:0,COLOR_WHITE:1,COLOR_GREEN:2,COLOR_LT_GRAY:3,COLOR_DK_GRAY:4,COLOR_YELLOW:5,COLOR_RED:6,COLOR_TRANSPARENT:-1,
 FONT_XTINY:0,FONT_TINY:1,FONT_SMALL:2,FONT_MEDIUM:3,FONT_LARGE:4,FONT_NUMBER_MILD:5,FONT_NUMBER_HOT:6,TEXT_JUSTIFY_CENTER:1};
const heights=[20,22,24,28,34,66,104];const fontMetrics=JSON.parse(fs.readFileSync(path.join(root,'design/font_metrics.json'),'utf8'));context.Graphics=Graphics;
class Dc{constructor(){this.commands=[];this.foreground=1;this.background=0;}
 getWidth(){return 280;}getHeight(){return 280;}getFontHeight(f){return fontMetrics[f]?.lineHeight??heights[f];}
 getTextWidthInPixels(s,f){if(fontMetrics[f])return [...s].reduce((n,c)=>{const g=fontMetrics[f].glyphs[c.codePointAt(0)];assert(g,'Missing glyph: '+c);return n+g.xadvance;},0);return Math.ceil([...s].reduce((n,c)=>n+(c===' '?0.25:('1:I'.includes(c)?0.30:0.53)),0)*heights[f]);}
 setColor(f,b){this.foreground=f;this.background=b;}cmd(op,args){this.commands.push({op,args,color:this.foreground,background:this.background});}
 clear(){this.cmd('clear',[]);}drawText(x,y,font,text){this.cmd('text',[x,y,font,text,this.getTextWidthInPixels(text,font),this.getFontHeight(font)]);}
 drawLine(...a){this.cmd('line',a);}drawRectangle(...a){this.cmd('rect',a);}fillRectangle(...a){this.cmd('fillRect',a);}drawCircle(...a){this.cmd('circle',a);}fillCircle(...a){this.cmd('fillCircle',a);}drawBitmap(...a){this.cmd('bitmap',a);}}
function render(view){const dc=new Dc();view.onUpdate(dc);return dc.commands;}
function scene(a){return render(new context.ScoreViewClass(a));}
function greenMarkers(c){return c.filter(x=>x.op==='fillCircle'&&x.color===2);}
test('startup reads saved phone preference and defaults to the enlarged menu',()=>{
 const a=app();a.onStart(null);assert.equal(a.fonts.menuSize,19);
 properties.set('MenuFontSize',16);const b=app();b.onStart(null);assert.equal(b.fonts.menuSize,16);assert.equal(b.fonts.normal,31);
 properties.set('MenuFontSize',19);const c=app();c.onStart(null);assert.equal(c.fonts.normal,32);
});
test('live phone changes redraw menus without touching a match or activity session',()=>{
 const a=stableApp();a.startRally();a.award(0);a.award(1);const score=packed(a),report=JSON.stringify(a.report.pack()),saved=JSON.stringify([...storage]),session=a.recorder.backend.session,before=resourceLoads;
 properties.set('MenuFontSize',16);a.onSettingsChanged();assert.equal(a.fonts.normal,31);
 properties.set('MenuFontSize',19);a.onSettingsChanged();assert.equal(a.fonts.normal,32);
 assert.equal(packed(a),score);assert.equal(JSON.stringify(a.report.pack()),report);assert.equal(JSON.stringify([...storage]),saved);assert.equal(a.recorder.backend.session,session);assert.equal(resourceLoads,before);
});
test('missing, invalid or mistyped phone values safely fall back to 19px',()=>{
 const a=app();for(const v of [null,999,-1,'16',true]){properties.set('MenuFontSize',v);a.onSettingsChanged();assert.equal(a.fonts.menuSize,19);}properties.clear();a.onSettingsChanged();assert.equal(a.fonts.menuSize,19);
});
test('every ordinary menu label uses the 19px font by default',()=>{
 const a=app(),m=open(a);const inspect=()=>assert(render(m).filter(c=>c.op==='text').every(c=>c.args[2]===32));inspect();
 for(const id of ['match','pages','activity','keys','exit']){choose(m,id);inspect();m.back();}choose(m,'new');inspect();
});
test('long menu text wraps at the selected size instead of silently shrinking',()=>{
 const a=app(),m=open(a),dc=new Dc();m.drawTextFit(dc,140,140,'是否保存当前对局结果是否保存当前对局结果',1,130);
 const rows=dc.commands.filter(c=>c.op==='text');assert.equal(rows.length,2);assert(rows.every(c=>c.args[2]===32&&c.args[4]<=130));
});
test('menu glyphs fit the circular face after the 3px increase',()=>{
 const a=app(),m=open(a);const inspect=()=>{for(const t of render(m).filter(c=>c.op==='text')){const [x,y,f,text,width]=t.args;let pen=x-width/2;
  for(const ch of text){const g=fontMetrics[f].glyphs[ch.codePointAt(0)];if(g.width&&g.height)for(const px of [pen+g.xoffset,pen+g.xoffset+g.width])for(const py of [y+g.yoffset,y+g.yoffset+g.height])assert((px-140)**2+(py-140)**2<=140**2,'Clipped glyph in '+text);pen+=g.xadvance;}}};inspect();
 for(const id of ['match','pages','activity','keys','exit']){choose(m,id);inspect();m.back();}choose(m,'new');inspect();
});
test('single/double court markers keep own-right mirroring and one colored server',()=>{
 const a=app();a.recordWanted=false;a.startRally();assert.deepEqual(greenMarkers(scene(a))[0].args,[168,188,9]);a.award(1);a.startRally();assert.deepEqual(greenMarkers(scene(a))[0].args,[168,112,9]);
 a.showPage(0);a.newMatch(21,30,3,false,1,0,2);a.award(0);a.startRally();const c=scene(a);assert.deepEqual(greenMarkers(c)[0].args,[112,188,16]);assert.equal(c.filter(x=>x.op==='text'&&/^[AB][12]$/.test(x.args[3])).length,4);});
test('score and metrics layout rejects oversized numeric font and shows READY truthfully',()=>{
 const a=app();const c=scene(a);assert(c.some(x=>x.op==='text'&&x.args[3]==='4开始记录'));assert(c.filter(x=>x.op==='text'&&x.args[3]==='0').every(x=>x.args[5]<=78));
 for(const page of [1,2]){a.page=page;assert(scene(a).some(x=>x.op==='text'));}});
test('custom menu uses measured small labels; key state reflects real boolean immediately',()=>{
 const a=app(),m=open(a);choose(m,'keys');choose(m,'lock');let c=render(m);assert(c.some(x=>x.op==='text'&&x.args[3]==='按键已锁定'));
 choose(m,'unlock');c=render(m);assert(c.some(x=>x.op==='text'&&x.args[3]==='按键已解锁'));assert(c.filter(x=>x.op==='text').every(x=>x.args[5]<=28));});
test('all reachable normal menu row labels use at most three words',()=>{
 const a=app(),m=open(a);const inspect=()=>m.frame()[1].forEach(r=>assert(r[0].trim().split(/\s+/).length<=3,r[0]));inspect();
 for(const id of ['match','pages','activity','keys','exit']){choose(m,id);inspect();m.back();}
 configureNew(m,1,21,false);inspect();m.back();inspect();m.back();inspect();});
test('court is drawn with primitives, with no bitmap load or draw',()=>{const a=app();a.recordWanted=false;a.startRally();const before=resourceLoads,c=scene(a);assert.equal(resourceLoads,before);assert(!c.some(x=>x.op==='bitmap'));assert(c.some(x=>x.op==='line'));assert(c.some(x=>x.op==='fillCircle'));});
test('rendered menus use Chinese; court player IDs retain A1/A2/B1/B2',()=>{
 const a=app(),m=open(a);const chinese=c=>c.filter(x=>x.op==='text').forEach(x=>assert(!/[A-Za-z]/.test(x.args[3].replace(/[AB][12]/g,'')),x.args[3]));
 chinese(render(m));for(const id of ['match','pages','activity','keys','exit']){choose(m,id);chinese(render(m));m.back();}
 m.close();a.recordWanted=false;for(const page of [0,1,2,3]){a.page=page;chinese(scene(a));}});
test('retained player IDs fit circle bounds using the bundled font',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);a.startRally();const labels=scene(a).filter(x=>x.op==='text'&&/^[AB][12]$/.test(x.args[3]));
 assert.equal(labels.length,4);assert(labels.every(x=>x.args[4]<=27&&x.args[5]<=26));});
test('bitmap font resources are loaded once per app, not during screen refresh',()=>{
 const a=app(),before=resourceLoads,v=new context.ScoreViewClass(a);render(v);render(v);const m=open(a);render(m);render(m);assert.equal(resourceLoads,before);});
test('long save question is split into two lines inside the circular screen',()=>{
 const m=open(app());choose(m,'new');const c=render(m).filter(x=>x.op==='text');
 assert(c.some(x=>x.args[3]==='是否保存当前'));assert(c.some(x=>x.args[3]==='对局结果'));
 for(const t of c.filter(x=>['是否保存当前','对局结果'].includes(x.args[3]))){const [x,y,font,value,width]=t.args;let pen=x-width/2;
  for(const ch of value){const g=fontMetrics[font].glyphs[ch.codePointAt(0)];for(const px of [pen+g.xoffset,pen+g.xoffset+g.width])for(const py of [y+g.yoffset,y+g.yoffset+g.height])assert((px-140)**2+(py-140)**2<=140**2);pen+=g.xadvance;}}});
test('win and encouragement animations use bounded primitive draws and no resource loads',()=>{
 for(const team of [0,1]){const a=stableApp();a.newMatch(21,30,1,false,0,0,2);finishGame(a,team);const m=gameFlow(a),before=resourceLoads;
  for(let frame=0;frame<6;frame++){const c=render(m);assert(c.length<50);assert(!c.some(x=>x.op==='bitmap'));
   assert(c.some(x=>x.op==='text'&&x.args[3]===(team===0?'恭喜获胜':'继续加油')));assert.equal(m.frames.length,1);m.tick();}
  assert.equal(resourceLoads,before);assert.equal(m.frame()[3],'matchSave');m.onHide();assert.equal(m.timer.active,false);m.close();}});
test('animation advances to a question, never automatically saves or starts a new match',()=>{
 const a=stableApp();a.newMatch(21,30,1,true,0,0,2);a.startRally();finishGame(a);const s=nativeSessions.at(-1),m=gameFlow(a),before=packed(a);
 for(let i=0;i<20;i++)m.tick();assert.equal(m.frame()[3],'matchSave');assert.equal(m.frame()[2],0);assert.equal(s.saves,0);assert.equal(s.discards,0);assert.equal(packed(a),before);});
test('terminal score view explicitly labels START for next-game or result action',()=>{
 const a=stableApp();finishGame(a);let c=scene(a);assert(c.some(x=>x.op==='text'&&x.args[3]==='4下一局 5撤销'));
 assert(a.prepareNextGame(0,2));finishGame(a);c=scene(a);assert(c.some(x=>x.op==='text'&&x.args[3]==='4查看结果 5撤销'));});
test('game history distinguishes saved and separately declined checkpoints',()=>{
 const a=stableApp();finishGame(a);assert(a.saveCompletedGame(false));let m=open(a);choose(m,'match');choose(m,'history');
 assert(render(m).some(x=>x.op==='text'&&x.args[3].includes('未单存')));m.close();assert(a.saveCompletedGame(true));
 m=open(a);choose(m,'match');choose(m,'history');assert(render(m).some(x=>x.op==='text'&&x.args[3].includes('已保存')));});
test('first direct score auto-starts one FIT and the game timer',()=>{
 const a=stableApp();assert(a.award(0));assert.equal(a.recorder.status,1);assert(a.report.gameRunning);
 time+=6000;assert(a.award(1));assert.equal(a.report.gameMs[0],6000);assert.equal(nativeSessions.at(-1).fields.length,0);
});
test('next-game direct score restarts its timer and retains the same FIT',()=>{
 const a=stableApp();a.startRally();time+=21000;finishGame(a);const session=a.recorder.session;
 assert(a.prepareNextGame(2,0));assert.equal(a.report.gameRunning,false);time+=30000;
 assert(a.award(1));time+=7000;a.refreshMatch();assert.equal(a.report.gameMs[1],7000);assert.equal(a.recorder.session,session);
});
test('first direct score cannot proceed when the requested activity fails to start',()=>{
 const a=app();a.recorder.backend.failCreate=true;assert.equal(a.award(0),false);assert.equal(a.engine.state[0],0);assert.equal(a.report.started,false);
});
test('invalid score team cannot start a recording',()=>{
 const a=app();assert.equal(a.award(5),false);assert.equal(a.recorder.backend.creates,0);
});
test('a failed snapshot write restores one coherent previous score and timer',()=>{
 const a=app();a.recordWanted=false;a.award(0);time+=10000;a.award(1);const before=JSON.stringify(storage.get('match-state-v2'));
 storageFailure='match-state-v2';time+=7000;a.award(0);assert(a.saveFailed);assert.equal(JSON.stringify(storage.get('match-state-v2')),before);
 storageFailure=null;const next=app();next.onStart(null);assert.equal(next.engine.state[0],1);assert.equal(next.engine.state[1],1);assert.equal(next.report.totalMs,10000);
});
test('new snapshot score timing checkpoints and flags are written in one value',()=>{
 const a=app();a.recordWanted=false;finishGame(a);a.saveCompletedGame(true);assert.deepEqual([...storage.keys()],['match-state-v2']);
 const next=app();next.onStart(null);assert.equal(next.engine.state[0],21);assert.equal(next.checkpoints.choices[0],1);assert.equal(next.recordWanted,false);
});
test('legacy migration keeps scores and last archive without changing UUID or creating FIT',()=>{
 const old=app();old.recordWanted=false;old.award(0);const packedOld=JSON.parse(packed(old));storage.clear();
 storage.set('match-v1',packedOld);storage.set('record-wanted',false);storage.set('match-report',old.report.pack());
 storage.set('last-match',[packedOld,false,0,old.report.pack(),true,old.checkpoints.pack()]);
 const next=app();next.onStart(null);assert.equal(next.engine.state[0],1);assert(next.lastMatch);assert(storage.has('match-state-v2'));assert.equal(next.recorder.backend.creates,0);
});
test('closed snapshot overrides all stale legacy keys and never resurrects an old match',()=>{
 const a=app();a.recordWanted=false;a.award(1);storage.set('match-v1',JSON.parse(packed(a)));assert(a.saveAndExit());
 const next=app();next.onStart(null);assert.equal(next.engine.state[1],0);assert.equal(next.lastMatch[0][4][1],1);
});
test('FIT saved but archive failed freezes all play and timing until one successful retry',()=>{
 const a=stableApp();a.startRally();time+=10000;a.award(0);const s=a.recorder.session,before=packed(a);
 storageFailure='archive-commit';assert.equal(a.endCurrent(true),false);assert.equal(s.saves,1);assert(a.settling);
 time+=20000;assert.equal(a.award(1),false);assert.equal(a.startRally(),false);a.undo();assert.equal(a.editServe(2,0,false),false);
 assert.equal(a.recordingAction('recStart'),false);assert.equal(packed(a),before);assert.equal(a.report.totalMs,10000);
 storageFailure=null;assert(a.endCurrent(true));assert.equal(s.saves,1);assert.equal(a.archives.length,1);assert.equal(a.lastMatch[2],10000);
});
test('pending settlement survives relaunch and completes scores without creating another FIT',()=>{
 const a=stableApp();a.award(0);const s=a.recorder.session;storageFailure='archive-commit';assert.equal(a.endCurrent(true),false);
 storageFailure=null;const next=app();next.onStart(null);assert(next.settling);assert(next.matchFitSaved);assert.equal(next.award(1),false);
 assert(next.endCurrent(true));assert.equal(next.recorder.backend.creates,0);assert.equal(s.saves,1);assert.equal(next.lastMatch[1],true);
});
test('failure persisting settlement intent prevents the irreversible FIT save',()=>{
 const a=stableApp();a.award(0);const s=a.recorder.session;storageFailure='match-state-v2';assert.equal(a.endCurrent(true),false);assert.equal(s.saves,0);
 storageFailure=null;assert(a.endCurrent(true));assert.equal(s.saves,1);
});
test('failed standalone save refreshes its activity parent to Resume on BACK',()=>{
 const a=app();a.award(0);const m=open(a);choose(m,'activity');a.recorder.session.failSave=true;choose(m,'recSave');assert.equal(m.frame()[3],'message');
 m.back();assert(m.frame()[1].some(r=>r[1]==='recResume'));assert(!m.frame()[1].some(r=>r[1]==='recPause'));
 a.recorder.session.failSave=false;choose(m,'recResume');assert.equal(a.recorder.status,1);assert(a.award(0));
});
test('failed initial native start refreshes its parent to Resume instead of Start',()=>{
 const a=app(),b=a.recorder.backend,create=b.createSession.bind(b);b.createSession=()=>{const s=create();s.failStart=true;return s;};
 const m=open(a);choose(m,'activity');choose(m,'recStart');assert.equal(m.frame()[3],'message');m.back();
 assert(m.frame()[1].some(r=>r[1]==='recResume'));assert(!m.frame()[1].some(r=>r[1]==='recStart'));a.recorder.session.failStart=false;choose(m,'recResume');assert(a.award(0));
});
test('undoing a serve edit at next-game READY keeps that game clock stopped',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);finishGame(a);a.prepareNextGame(0,2);assert(a.editServe(1,3,false));a.undo();
 time+=15000;a.refreshMatch();assert.equal(a.report.gameMs[1],0);assert.equal(a.report.gameRunning,false);assert(a.award(0));time+=5000;a.refreshMatch();assert.equal(a.report.gameMs[1],5000);
});
test('undoing a winning point reopens the same game clock',()=>{
 const a=app();a.recordWanted=false;finishGame(a);a.undo();time+=5000;a.refreshMatch();assert.equal(a.report.gameMs[0],5000);
});
test('score-only pause excludes both clocks and blocks scoring until explicit resume',()=>{
 const a=app();a.recordWanted=false;a.award(0);time+=2000;assert(a.setMatchPaused(true));time+=20000;assert.equal(a.award(1),false);
 assert.equal(a.startRally(),false);assert(a.setMatchPaused(false));time+=3000;a.refreshMatch();assert.equal(a.report.totalMs,5000);assert.equal(a.report.gameMs[0],5000);assert.equal(a.recorder.backend.creates,0);
});
test('pure-scoring pause is restored without counting app downtime',()=>{
 const a=app();a.recordWanted=false;a.award(0);a.setMatchPaused(true);time+=60000;const next=app();next.onStart(null);assert(next.paused);assert.equal(next.award(0),false);
 assert(next.setMatchPaused(false));assert(next.award(0));assert.equal(next.report.gameMs[0],0);
});
test('live HR clears on pause and save, while saved aggregate values remain available',()=>{
 const a=app();a.award(0);a.recorder.backend.info=()=>({currentHeartRate:130,averageHeartRate:120,maxHeartRate:150,calories:30});a.refreshMetrics();assert.equal(a.stats.heartRate,130);
 assert(a.recordingAction('recPause'));a.refreshMetrics();assert.equal(a.stats.heartRate,null);assert.equal(a.stats.averageHeartRate,120);
 assert(a.recordingAction('recResume'));assert(a.recordingAction('recSave'));assert.equal(a.stats.heartRate,null);assert.equal(a.stats.calories,30);
});
test('discard clears all previous activity measurements',()=>{
 const a=app();a.award(0);a.stats.capture({currentHeartRate:130,averageHeartRate:120,maxHeartRate:150,calories:30});assert(a.recordingAction('recDiscard'));
 assert.deepEqual([a.stats.heartRate,a.stats.averageHeartRate,a.stats.maxHeartRate,a.stats.calories],[null,null,null,null]);
});
test('menu opening and cross-page confirmation share the same input barrier',()=>{
 const a=app();a.recordWanted=false;finishGame(a);const d=new context.ScoreDelegateClass(a);key(d,'onSelect');const m=stack.at(-1).view,md=stack.at(-1).delegate;
 md.onSelect();assert.equal(m.frame()[3],'roundSave');key(md,'onSelect');assert.equal(m.frame()[3],'roundNext');md.onSelect();assert.equal(m.frame()[3],'roundNext');
});
test('menu closing blocks a residual score event on the underlying screen',()=>{
 const a=app(),m=open(a);m.close();const d=new context.ScoreDelegateClass(a);d.onPreviousPage();assert.equal(a.engine.state[0],0);key(d,'onPreviousPage');assert.equal(a.engine.state[0],1);
});
test('score page names the actual current server court and receiver',()=>{
 const a=app();a.newMatch(21,30,3,false,1,1,3);a.award(0);assert(scene(a).some(c=>c.op==='text'&&c.args[3]==='A2左 发 B1接'));
});
test('winner-first rule constrains next-game team but allows choosing doubles players',()=>{
 const a=app();a.newMatch(21,30,3,false,1,0,2);a.ruleMode=1;finishGame(a,1);assert.equal(a.prepareNextGame(0,2),false);
 const m=gameFlow(a);choose(m,'roundKeep',true);choose(m,'roundNext',true);assert.equal(m.frame()[1].length,1);assert.equal(m.frame()[1][0][2],1);
 choose(m,'roundTeam',1);choose(m,'roundServer',3);choose(m,'roundReceiver',1);assert.equal(a.engine.serverPlayer(),3);assert.equal(a.engine.receiverPlayer(),1);
 assert.equal(a.editServe(0,2,false),false);
});
test('explicit free-play rule preserves the requested ability to choose either next server',()=>{
 const a=app();a.recordWanted=false;finishGame(a,1);assert(a.prepareNextGame(0,2));assert.equal(a.engine.serverPlayer(),0);
});
test('rule panel exposes cap interval deciding-game change and future 15-point date',()=>{
 const a=app();a.newMatch(15,21,3,false,0,0,2);const m=open(a);choose(m,'match');choose(m,'rules');const labels=m.frame()[1].map(r=>r[0]).join('|');
 assert(labels.includes('15分 封顶21'));assert(labels.includes('8分间歇'));assert(labels.includes('第三局8分换边'));assert(labels.includes('2027年1月4日'));
});
test('21 and 15 point midgame reminders use their own threshold without pausing play',()=>{
 for(const [target,cap,threshold] of [[21,30,11],[15,21,8]]){const a=app();a.newMatch(target,cap,3,false,0,0,2);for(let i=0;i<threshold;i++)a.award(0);assert.equal(a.notice,'局中间歇');assert.equal(a.paused,false);}
});
test('third-game midpoint reminds players to change ends',()=>{
 const a=app();a.recordWanted=false;finishGame(a);a.prepareNextGame(2,0);finishGame(a,1);a.prepareNextGame(0,2);for(let i=0;i<11;i++)a.award(0);assert.equal(a.notice,'间歇并交换场地');
});
test('bounded match history stores dates mode rule scores and times, without undo stacks',()=>{
 const a=app();a.recordWanted=false;for(let i=0;i<12;i++){a.award(i%2);assert(a.endCurrent(true));}
 assert.equal(a.archives.length,8);assert(a.archives.every(r=>r[0][6].length===0&&r.length===8&&r[6]>0));
 const next=app();next.onStart(null);assert.equal(next.archives.length,8);const m=open(next);choose(m,'match');choose(m,'archives');assert.equal(m.frame()[1].length,8);
 choose(m,'archiveItem',0);assert.equal(m.frame()[1][0][0],'局数 0:0');assert(m.frame()[1].some(r=>r[0]==='中途结束'));
 choose(m,'lastGames');assert.equal(m.frame()[3],'history');
});
test('archiving a completed match prioritizes match winner and games over last-game score',()=>{
 const a=app();a.newMatch(21,30,1,false,0,0,2);finishGame(a);a.endCurrent(true);const m=open(a);choose(m,'match');choose(m,'last');
 assert.equal(m.frame()[1][0][0],'局数 1:0');assert.equal(m.frame()[1][1][0],'我方获胜');
});

test('new-match storage failure keeps the old score timing and mode',()=>{
 const a=app();a.recordWanted=false;a.award(0);time+=5000;a.refreshMatch();const before=packed(a),oldReport=a.report;storageFailure='match-state-v2';
 assert.equal(a.newMatch(15,21,1,true,1,1,3),false);assert.equal(packed(a),before);assert.equal(a.report,oldReport);assert.equal(a.engine.target,21);
});
if(process.argv.includes('--preview')){
 const scenes={};const a=app();a.newMatch(21,30,3,true,1,0,2);a.startRally();a.award(0);a.recorder.elapsedMs=890000;a.recorder.backend.info=()=>({currentHeartRate:135,averageHeartRate:128,maxHeartRate:158,calories:76});
 scenes.score=scene(a);a.startRally();scenes.doubles_1_0=scene(a);a.award(1);a.startRally();scenes.doubles_1_1=scene(a);a.showPage(1);scenes.performance=scene(a);a.showPage(2);scenes.clock=scene(a);
 const s=app();s.recordWanted=false;s.startRally();scenes.singles_0_0=scene(s);s.award(1);s.startRally();scenes.singles_0_1=scene(s);
 const m=open(a);m.frame()[2]=1;scenes.menu_root=render(m);properties.set('MenuFontSize',16);a.onSettingsChanged();scenes.menu_root_compact=render(m);properties.set('MenuFontSize',19);a.onSettingsChanged();a.lastMatch=[a.engine.pack(),true,890000];choose(m,'match');m.frame()[2]=1;scenes.menu_match=render(m);m.back();choose(m,'keys');choose(m,'lock');scenes.menu_locked=render(m);choose(m,'unlock');scenes.menu_unlocked=render(m);m.back();choose(m,'activity');scenes.menu_activity=render(m);m.back();choose(m,'exit');m.frame()[2]=1;scenes.menu_exit=render(m);choose(m,'dropConfirm');scenes.menu_discard=render(m);m.root();choose(m,'new');scenes.menu_new_save=render(m);m.back();choose(m,'finish');scenes.menu_finish=render(m);m.root();m.frame()[2]=5;scenes.menu_finish_entry=render(m);
 stack.length=0;const g=stableApp();g.startRally();for(let i=0;i<18;i++)g.award(1);for(let i=0;i<21;i++)g.award(0);
 g.recorder.elapsedMs=840000;g.report.gameMs[0]=780000;g.report.totalMs=840000;scenes.game_over=scene(g);const gm=gameFlow(g);
 scenes.round_save=render(gm);choose(gm,'roundKeep',true);scenes.round_next=render(gm);choose(gm,'roundNext',true);scenes.round_team=render(gm);gm.close();
 const w=stableApp();w.newMatch(21,30,3,false,0,0,2);finishGame(w);w.prepareNextGame(0,2);finishGame(w);const wm=gameFlow(w);scenes.result_win=render(wm);wm.select();scenes.match_save=render(wm);wm.close();
 const l=stableApp();l.newMatch(21,30,1,false,0,0,2);finishGame(l,1);const lm=gameFlow(l);scenes.result_lose=render(lm);lm.close();
 fs.writeFileSync(path.join(root,'design/preview_scenes.json'),JSON.stringify({fontHeights:heights,scenes},null,2));}
process.stdout.write(`\n${passed} raw-source/application/menu/flow/render checks passed with mock Garmin APIs. Native SDK, FIT files and sync NOT TESTED.\n`);

if(failures){process.stderr.write(`${failures} failed checks\n`);process.exitCode=1;}
