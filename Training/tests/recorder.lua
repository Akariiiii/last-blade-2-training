package.path="Training/?.lua;Training/?/init.lua;"..package.path
local R=require('lb2.recorder');local checks=0
local function eq(a,b,msg) checks=checks+1;assert(a==b,(msg or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function record(r,slot,frames)
 assert(r:start_record(slot));for _,f in ipairs(frames) do r:tick({physical_p1=f,p1_facing=1}) end;r:stop()
end
local r=R.new();eq(#r.slots,8);eq(r:tick({}),nil,'passive does not own P2')
record(r,1,{{right=true,buttons='A'},{down=true,left=true,buttons={B=true,C=true}}, {buttons=''}})
eq(#r.slots[1].frames,3);eq(r.slots[1].frames[1].forward,true);eq(r.slots[1].frames[2].back,true)
assert(r:start_playback({slot=1}));local out=r:tick({engine=10});eq(out.direction,'6');eq(out.buttons,'A')
local again=r:tick({engine=10});eq(again.frame,1,'paused duplicate does not advance')
again.buttons='BAD';eq(r.slots[1].frames[1].buttons,'A','output isolated')
out=r:tick({engine=11});eq(out.direction,'1');eq(out.buttons,'BC')
out=r:tick({engine=12});eq(out.buttons,'')
out=r:tick({engine=13});eq(out.release,true);eq(r:tick({engine=14}),nil,'once releases then passive')
-- Adapter mirrors against current P2 facing and never changes P1 inputs.
assert(r:start_playback({slot=1}));local frame={engine=20,players={{facing=1},{facing=0}}}
local keys={['P1 Button D']=true,['P2 Button D']=true,['P2 Right']=true}
local result,active=r:before(frame,keys);eq(active,true);eq(result['P2 Left'],true);eq(result['P2 Right'],false)
eq(result['P2 Button A'],true);eq(result['P2 Button D'],false);eq(result['P1 Button D'],true)
r:stop();frame.engine=21;result,active=r:before(frame,keys);eq(active,true);eq(result['P2 Left'],false);eq(result['P2 Button A'],false)
frame.engine=22;local _,passive=r:before(frame,keys);eq(passive,false)
-- Capture facing flip/SOCD/start exactly rather than collapsing opposite keys.
r=R.new();r:start_record(2);r:tick({physical_p1={left=true,right=true,up=true,down=true,start=true,buttons='AD'},p1_facing=0});r:stop()
local sample=r.slots[2].frames[1];eq(sample.back,true);eq(sample.forward,true);eq(sample.up,true);eq(sample.down,true);eq(sample.start,true)
assert(r:start_playback({slot=2}));out=r:tick({});eq(out.direction,'5');eq(out.buttons,'AD');eq(out.back,true)
-- Limit is exact and slot clear remains isolated.
r=R.new({max_frames=2});r:start_record(1);for i=1,5 do r:tick({input={direction='6',buttons='A'}}) end
eq(#r.slots[1].frames,2);eq(r.recording,false)
record(r,2,{{buttons='B'}});r:clear(1);eq(#r.slots[1].frames,0);eq(#r.slots[2].frames,1)
local ok=r:start_playback({slot=1});eq(ok,false)
-- Repeats have one explicit neutral inter-clip frame by default.
r=R.new();record(r,1,{{buttons='A'}});assert(r:start_playback({slot=1,mode='repeat'}))
eq(r:tick({}).buttons,'A');eq(r:tick({}).buttons,'');eq(r:tick({}).buttons,'A')
r:stop();eq(r:tick({}).release,true)
-- Ordered once stops after all chosen slots; random weights use injected RNG.
record(r,2,{{buttons='B'}});assert(r:start_playback({slots={1,2},mode='ordered',gap_frames=0}))
eq(r:tick({}).buttons,'A');eq(r:tick({}).buttons,'B');eq(r:tick({}).release,true);eq(r:tick({}),nil)
r=R.new({rng=function(n)return n end});record(r,1,{{buttons='A'}});record(r,2,{{buttons='B'}})
r.slots[1].weight=2;r.slots[2].weight=4
assert(r:start_playback({mode='random',gap_frames=0}));eq(r:tick({}).buttons,'B');eq(r:tick({}).buttons,'B')
r.rng=function()return 0 end;out=r:tick({});eq(out.release,true);eq(r.playing,false)
-- Restarting transport releases the previous held button before a new clip.
assert(r:start_playback({slot=1}));eq(r:tick({}).buttons,'A');assert(r:start_playback({slot=2}))
eq(r:tick({}).release,true);eq(r:tick({}).buttons,'B')
-- Export/import is explicit in-memory data only, dense and bounded.
local data=r:export_slot(1);data.frames[1].buttons='D';eq(r.slots[1].frames[1].buttons,'A')
assert(r:import_slot(3,data));eq(r.slots[3].frames[1].buttons,'D')
eq(r:import_slot(3,{schema_version=1,frames={[2]=sample}}),false)
eq(r:import_slot(3,{schema_version=1,frames={{buttons=string.rep('A',100)}}}),false)
local valid=pcall(function()r:import_slot(9,data)end);eq(valid,false)
print('Recorder checks passed: '..checks)
