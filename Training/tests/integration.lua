package.path='Training/?.lua;'..package.path
local C,R=require('lb2.controls'),require('lb2.recorder')
local checks=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local physical,last={},{}
local c=C.new({joypad={get=function()local r={};for k,v in pairs(physical)do r[k]=v end;return r end,set=function(k)last=k end}})
c.recorder=R.new();local engine=0
local function step(input)
 engine=engine+1;physical=input or {}
 c:before({engine=engine,players={{facing=1},{facing=0}}})
end
c:toggle_menu();c.tab=5;c.row=6;c:change(1)
step({['P1 Button A']=true});eq(#c.recorder.slots[1].frames,0,'menu cannot record')
step({['P1 Button B']=true});eq(c.menu,false);eq(c.transport.state,'waiting','menu arms same3S waiting mode')
step({['P1 Button B']=true});eq(last['P1 Button B'],false,'closing input suppressed')
step({});step({['P1 Right']=true,['P1 Button A']=true,['P2 Button C']=true})
eq(last['P1 Button A'],false);eq(last['P2 Button A'],true);eq(last['P2 Button C'],false)
eq(#c.recorder.slots[1].frames,0,'waiting controls dummy without capturing')
step({['P1 Coin']=true});for n=1,12 do step()end
eq(c.transport.state,'recording');eq(c.recorder.record_dummy,true)
step({['P1 Right']=true,['P1 Button A']=true});step({['P1 Right']=true,['P1 Button A']=true})
step({['P1 Start']=true});eq(c.menu,true,'Start opens immediately');eq(last['P1 Start'],false,'native taunt suppressed')
eq(c.recorder.recording,false);eq(c.transport.state,'normal')
local frames=c.recorder.slots[1].frames;local a=0
for _,f in ipairs(frames)do if f.buttons=='A'then a=a+1;eq(f.back,true,'normalize against dummy facing')end;eq(f.start,false)end
eq(a,2,'exact attack frames')
c.tab=5;c.row=7;c:change(1);eq(c.recorder.playing,true)
step({['P1 Button B']=true});step();local seen=false
for n=1,#frames+3 do step();if last['P2 Button A']then seen=true;eq(last['P2 Right'],true)end end
eq(seen,true,'playback uses actual recorded dummy direction');eq(c.recorder.playing,false)
c:toggle_menu();c.tab=5;c.row=6;c:change(1);eq(c.transport.state,'waiting')
c.row=7;c:change(1);eq(c.transport.state,'normal','Play supersedes waiting in same menu');eq(c.recorder.playing,true)
c.row=8;c:change(1);eq(c.transport.state,'normal');eq(c.recorder.playing,false)
c:reset();eq(#c.recorder.slots[1].frames,#frames,'reset preserves slot');eq(c.close_release,false)
print('PASS Integration: '..checks..' assertions')
