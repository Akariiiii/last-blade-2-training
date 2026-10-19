package.path='Training/?.lua;'..package.path
local R,T=require('lb2.recorder'),require('lb2.transport')
local tests=0
local function eq(a,b,m)assert(a==b,(m or 'value')..': '..tostring(a)..' ~= '..tostring(b));tests=tests+1 end
local r=R.new();local t=T.new(r)
t:update(0,true);t:update(5,true);eq(t.state,'waiting');eq(r.recording,false)
t:update(10,true);t:update(20,false);eq(r.recording,false,'11frame ambiguity window')
t:update(21,false);eq(t.state,'recording');eq(r.record_dummy,true)
local f={engine=22,players={{facing=1},{facing=0}}}
local keys={['P1 Button A']=true,['P1 Left']=true,['P1 Start']=true,['P1 Coin']=true,['P2 Button B']=true}
local out=r:before(f,keys)
eq(out['P1 Button A'],false);eq(out['P2 Button A'],true);eq(out['P2 Button B'],false)
eq(out['P2 Left'],true);eq(out['P2 Start'],false);eq(out['P2 Coin'],false)
eq(r.slots[1].frames[1].forward,true,'capture actual dummy facing');eq(r.slots[1].frames[1].start,false)
t:update(30,true);t:update(41,false);eq(t.state,'normal');eq(r.recording,false)
t:update(50,true);t:update(61,false);eq(t.state,'playing')
-- Double Coin stops playback and arms recording without clearing the slot.
t:update(70,true);t:update(73,true);eq(t.state,'waiting');eq(#r.slots[1].frames,1)
t:update(80,true);t:update(84,true);eq(t.state,'normal');eq(#r.slots[1].frames,1)
-- Exact11 boundary is a single tap; an empty playback slot is a harmless error.
r=R.new();t=T.new(r);t:update(0,true);t:update(11,false)
eq(t.state,'normal');eq(r.last_error,'Selected slots are empty')
t:update(20,true);t:stop();t:update(40,false);eq(t.state,'normal');eq(t.coin_at,nil)
print('PASS Transport: '..tests..' assertions')
