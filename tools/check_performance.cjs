#!/usr/bin/env node
'use strict';
const fs=require('node:fs'), path=require('node:path'), vm=require('node:vm'), assert=require('node:assert/strict');
const source=fs.readFileSync(path.join(__dirname,'../source/PerformanceStats.mc'),'utf8')
  .replace(/^import .*;$/gm,'')
  .replace(/\s+as\s+(?:Lang\.\w+|Activity\.\w+|Void)(?:\s+or\s+Null)?/g,'')
  .replace(/^    var (\w+)([^;]*);$/gm,'    $1$2;')
  .replace(/\bself\./g,'this.')
  .replace(/function initialize\(/,'constructor(').replace(/\bfunction (\w+)\(/g,'$1(');
const Stats=vm.runInNewContext(source+'\nPerformanceStats;');
let passed=0;
function test(name,fn){fn();passed++;process.stdout.write('PASS '+name+'\n');}
function values(s){return [s.heartRate,s.averageHeartRate,s.maxHeartRate,s.calories];}
test('unavailable measurements start null rather than invented zero',()=>{
  assert.deepEqual(values(new Stats()),[null,null,null,null]);
});
test('captures current, average, maximum heart rate and device calories',()=>{
  const s=new Stats();s.capture({currentHeartRate:135,averageHeartRate:128,maxHeartRate:158,calories:76});
  assert.deepEqual(values(s),[135,128,158,76]);
});
test('missing live sample clears live HR while retaining last device summary',()=>{
  const s=new Stats();s.capture({currentHeartRate:135,averageHeartRate:128,maxHeartRate:158,calories:76});
  s.capture(null);assert.deepEqual(values(s),[null,128,158,76]);
});
test('new activity reset clears previous activity measurements',()=>{
  const s=new Stats();s.capture({currentHeartRate:135,averageHeartRate:128,maxHeartRate:158,calories:76});
  s.reset();assert.deepEqual(values(s),[null,null,null,null]);
});
process.stdout.write('\n'+passed+' performance snapshot checks passed; real Garmin sensors NOT TESTED.\n');
