package.path='Training/?.lua;Training/?/init.lua;'..package.path
local D,C=require('lb2.dummy'),require('lb2.controls')
local count=0
local function eq(a,b,label) assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b));count=count+1 end
local function f(n)
 return {engine=n,players={{address=1,hp=256,ready=true,hitpause=0,facing=1},{address=2,hp=256,ready=true,hitpause=0,facing=0}},entries={},boxes={}}
end
local opt={guard=1,counter=1,counter_command=1,counter_delay=0}
local d=D.new();local a=f(0);d:after(a,opt)
local r=d:request(a,opt);eq(r.direction,'5');eq(next(r.buttons),nil)
local keys={['P1 Button A']=true,['P2 Button A']=true,['P2 Start']=true,['P2 Coin']=true}
D.apply(keys,'P2',r,0);eq(keys['P1 Button A'],true);eq(keys['P2 Button A'],false);eq(keys['P2 Start'],false);eq(keys['P2 Coin'],false)
D.apply(keys,'P2',{direction='1',buttons={D=true}},1);eq(keys['P2 Left'],true);eq(keys['P2 Down'],true);eq(keys['P2 Button D'],true)
D.apply(keys,'P2',{direction='6',buttons={}},0);eq(keys['P2 Left'],true);eq(keys['P2 Down'],false);eq(keys['P2 Button D'],false)
-- Guard release and switch only react to observed guard, never an overlap.
d:reset();opt.guard=4;a=f(0);d:after(a,opt);eq(d:request(a,opt).direction,'4')
a=f(1);a.players[2].guard=true;a.players[2].ready=false;d:after(a,opt);eq(d:request(a,opt).direction,'5')
d:reset();opt.guard=6;a=f(0);d:after(a,opt);a=f(1);a.players[2].guard=true;d:after(a,opt);eq(d:request(a,opt).direction,'1')
-- Random guard is stable for all frames of an interaction.
local calls=0;d=D.new(function() calls=calls+1;return 1 end);opt.guard=8
local first=d:request(f(0),opt).direction
for n=1,20 do eq(d:request(f(n),opt).direction,first) end
eq(calls,2,'random chosen once, not once per frame')
-- A counter waits for native action permission, applies delay, pulses and releases.
d=D.new();opt.guard=1;opt.counter=2;opt.counter_command=1;opt.counter_delay=2
d:after(f(0),opt);a=f(1);a.players[2].hp=244;a.players[2].ready=false;d:after(a,opt)
eq(d:request(a,opt).direction,'5');eq(d.sequence,nil)
a=f(2);a.players[2].hp=244;d:after(a,opt);eq(next(d:request(a,opt).buttons),nil)
a.engine=3;eq(next(d:request(a,opt).buttons),nil)
a.engine=4;eq(d:request(a,opt).buttons.A,true)
a.engine=5;eq(next(d:request(a,opt).buttons),nil,'release edge')
a.engine=6;eq(d:request(a,opt).buttons.A,true,'retry rejected input')
a=f(7);a.entries={{actor=2,script=0x30}};d:after(a,opt);eq(d.pending,nil);eq(d.sequence,nil,'stop on native admission')
-- Chip in guard does not trigger the after-hit counter.
d=D.new();d:after(f(0),opt);a=f(1);a.players[2].hp=255;a.players[2].guard=true;d:after(a,opt);eq(d.pending,nil)
-- Wakeup has an explicit adapter classification; ordinary recovery does not qualify.
d=D.new();opt.counter=5;d:after(f(0),opt);a=f(1);a.players[2].ready=false;d:after(a,opt);d:after(f(2),opt);eq(d.pending,nil)
a=f(3);a.players[2].knockdown=true;a.players[2].ready=false;d:after(a,opt);a=f(4);a.players[2].knockdown=false;d:after(a,opt);eq(d.pending.kind,'wakeup')
-- Switch ->4A changes guard first, then probes native admission; no forced ready write.
d=D.new();opt.counter=1;opt.counter_delay=0;opt.guard=10;d:after(f(0),opt);a=f(1);a.players[2].guard=true;d:after(a,opt)
eq(d:request(a,opt).direction,'1');eq(d:request(a,opt).buttons.A,nil)
a.engine=2;eq(d:request(a,opt).direction,'4');eq(d:request(a,opt).buttons.A,nil)
a.engine=3;eq(d:request(a,opt).buttons.A,true)
a.engine=183;d:request(a,opt);eq(d.sequence,nil,'switch counter times out')
-- A fresh block within30 neutral frames re-arms; zero-chip contacts qualify too.
d=D.new();opt.guard=2;opt.counter=3;opt.counter_delay=0
a=f(0);a.contacts={};d:after(a,opt)
a=f(1);a.players[2].guard=true;a.players[2].ready=false;a.contacts={{target=2,kind='block'}};d:after(a,opt)
eq(d.pending.at,1);eq(d:request(a,opt).buttons.A,nil,'prepare stance')
a.engine=2;eq(d:request(a,opt).buttons.A,true,'probe before generic ready')
a=f(2);a.contacts={};a.entries={{actor=2,script=0x30}};d:after(a,opt);eq(d.counter_done,true)
a=f(3);a.players[2].guard=true;a.contacts={{target=2,kind='block'}};d:after(a,opt)
eq(d.pending.at,3);eq(d.counter_done,nil,'no30frame cooldown')
-- Switch is optional, block-only, and gets its own direction-change frame.
opt.counter_switch=true;d=D.new();a=f(10);a.players[2].guard=true;a.players[2].ready=false
a.contacts={{target=2,kind='block'}};d:after(a,opt);eq(d:request(a,opt).direction,'1')
eq(d.sequence,nil);a.engine=11;eq(d:request(a,opt).buttons.A,nil);a.engine=12;eq(d:request(a,opt).buttons.A,true)
-- Deflect is not a block counter trigger; mere overlap/guard retention is not a new contact.
a=f(12);a.contacts={{target=2,kind='deflect'}};a.entries={{actor=2,script=0x30}};d:after(a,opt)
eq(d.pending,nil);a=f(13);a.players[2].guard=true;a.contacts={};d:after(a,opt);eq(d.pending,nil)
opt.counter_switch=false
-- Release keeps stance: no stand/crouch oscillation and no4,5,4 backdash.
d=D.new();opt.guard=6;opt.counter=3;opt.counter_command=1
a=f(20);a.contacts={{target=2,kind='block'}};d:after(a,opt);d:request(a,opt)
a.engine=21;eq(d:request(a,opt).direction,'4');a.engine=22;eq(d:request(a,opt).buttons.A,true)
a.engine=23;eq(d:request(a,opt).direction,'4');eq(d:request(a,opt).buttons.A,nil)
d=D.new();opt.guard=3;opt.counter_command=2;a=f(30);a.contacts={{target=2,kind='block'}};d:after(a,opt)
eq(d:request(a,opt).direction,'4');a.engine=31;eq(d:request(a,opt).direction,'5');a.engine=32;eq(d:request(a,opt).direction,'5')
-- Jump has a native airborne admission even though its initializer is below30.
d=D.new();opt.guard=1;opt.counter=2;opt.counter_command=13;a=f(40);a.contacts={{target=2,kind='hit'}};d:after(a,opt)
eq(d:request(a,opt).direction,'8');a=f(41);a.players[2].height=10;a.contacts={};d:after(a,opt)
eq(d.sequence,nil);eq(d.pending,nil);eq(d.counter_done,true)
-- Nonzero delay begins at observed readiness, not during blockstun/hitpause.
d=D.new();opt.guard=2;opt.counter=3;opt.counter_command=1;opt.counter_delay=2
a=f(50);a.players[2].ready=false;a.contacts={{target=2,kind='block'}};d:after(a,opt);d:request(a,opt);eq(d.sequence,nil)
a=f(60);a.contacts={};d:after(a,opt);eq(d:request(a,opt).buttons.A,nil);a.engine=61;eq(d:request(a,opt).buttons.A,nil)
a.engine=62;eq(d:request(a,opt).buttons.A,true)
-- Never loop236 into a623 priority match; one whole motion after ready, release.
d=D.new();opt.counter_command=10;opt.counter_delay=0;a=f(70);a.players[2].ready=false;a.contacts={{target=2,kind='block'}}
d:after(a,opt);d:request(a,opt);eq(d.sequence,nil)
a=f(80);a.contacts={};d:after(a,opt);eq(d:request(a,opt).direction,'2')
a.engine=85;eq(d:request(a,opt).direction,'6');eq(d:request(a,opt).buttons.A,true)
a.engine=87;eq(d:request(a,opt).direction,'5');eq(d.pending,nil);eq(d.sequence,nil)
-- A deflect pulse is bounded; repeated D cannot accidentally issue a follow-up.
d=D.new();opt.guard=9;opt.counter=1;a=f(10);a.players[1].ready=false
eq(d:request(a,opt).buttons.D,true);a.engine=11;eq(d:request(a,opt).buttons.D,true)
a.engine=12;eq(d:request(a,opt).buttons.D,false);a.engine=80;eq(d:request(a,opt).buttons.D,false)
-- P2 default neutral overrides physical P2 while retaining P1. Explicit manual is passive.
local injected=0;local last;local c=C.new({joypad={get=function() return {['P1 Button A']=true,['P2 Button B']=true} end,set=function(v) injected=injected+1;last=v end}})
c:before(f(0));eq(injected,1);eq(last['P1 Button A'],true);eq(last['P2 Button B'],false)
c.training_mode=false;c:before(f(1));eq(injected,1)
-- Tabbed row schema and numeric settings do not toggle into booleans.
eq(#c:tabs(),5);eq(c:items()[1].key,c:items()[1][3]);c.row=9;c:change(1);eq(c.hud_alpha,96)
c.tab=2;c.row=4;c:change(1);eq(c.counter_command,2);c.row=5;c:change(1);eq(c.counter_delay,1)
-- Alt1 select and Alt2 menu retain explicit callbacks.
local hotkeys={};local returned=0;c=C.new({input={registerhotkey=function(i,fn)hotkeys[i]=fn end}})
c:hotkeys(function()end,function() returned=returned+1 end);hotkeys[1]();eq(returned,1);hotkeys[2]();eq(c.menu,true)
print(string.format('PASS: %d dummy/control assertions',count))
