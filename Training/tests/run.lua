package.path="Training/?.lua;Training/?/init.lua;"..package.path
local Observe,Game,Controls=require("lb2.observe"),require("lb2.game"),require("lb2.controls")
local tests=0
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a));tests=tests+1 end
local function player(address)
 return {address=address,character=0,mode=0,state=0,script=0,control=1,height=0,hitpause=0,ready=true,
  hp=256,meter=0,stun=60,stun_capacity=60,progress="idle",contact_remaining=1,guard=false,facing=1,x=0,pose=0}
end
local function frame(n)
 return {engine=n,players={player(0x100400),player(0x100800)},boxes={},guard_policy="manual"}
end
local function busy(p) p.ready=false;p.control=2;p.progress="move" end
local function attack(f,actor,owner)
 f.boxes[#f.boxes+1]={kind="attack",actor=actor or f.players[1].address,owner=owner or f.players[1].address}
end
local function events() return {entries={},overlaps={},grabs={},stuns={}} end
local function start(o,n)
 local f=frame(n or 1);busy(f.players[1]);local e=events();e.entries={{actor=f.players[1].address,script=0x30}}
 o:update(f,e);return f
end
-- Exact boundaries, no-contact whiff and ready-inclusive recovery.
local o=Observe.new();o:update(frame(0),events());start(o)
for n=2,7 do local f=frame(n);if n<7 then busy(f.players[1]) end;if n==3 or n==4 then attack(f) end;o:update(f,events()) end
equal(o.last[1].startup,2,"whiff startup");equal(o.last[1].active_frames,2,"active advancing samples")
equal(o.last[1].recovery,3,"last-active to ready");equal(o.last[1].advantage,nil,"whiff has no advantage")
-- Contact actual HP, positive/negative advantage waits for both ready boundaries.
o=Observe.new();o:update(frame(0),events());start(o)
for n=2,9 do
 local f=frame(n);if n<9 then busy(f.players[1]) end
 if n>=3 then f.players[2].hp=244 end
 if n>=3 and n<6 then busy(f.players[2]) end
 if n==3 then attack(f) end
 o:update(f,events());if n==6 then equal(o.current[1].advantage,nil,"pending attacker recovery") end
end
equal(o.last[1].damage,12);equal(o.last[1].advantage,-3);equal(o.last[1].outcome,"hit")
-- Harmless overlaps never become hits, guards require fresh native reaction.
o=Observe.new();o:update(frame(0),events());start(o)
for n=2,5 do local f=frame(n);if n<5 then busy(f.players[1]) end
 local e=events();e.overlaps={{owner=f.players[1].address,target=f.players[2].address}};o:update(f,e) end
equal(o.last[1].outcome,"whiff");equal(#o.last[1].contacts,0)
o=Observe.new();o:update(frame(0),events());start(o)
for n=2,6 do
 local f=frame(n);if n<6 then busy(f.players[1]) end
 local e=events()
 if n==2 then attack(f);f.players[2].guard=true;busy(f.players[2]);e.overlaps={{owner=f.players[1].address,target=f.players[2].address}} end
 o:update(f,e)
end
equal(o.last[1].outcome,"block");equal(o.last[1].chip,0);equal(#o.last[1].contacts,1)
-- Standing deflect needs paired defender125/126 and source52/53 reactions.
o=Observe.new();o:update(frame(0),events());start(o)
local f=frame(2);busy(f.players[1]);busy(f.players[2]);f.players[2].guard=true;f.players[2].state=0x125
local e=events();e.overlaps={{owner=f.players[1].address,target=f.players[2].address}};o:update(f,e)
equal(o.current[1].outcome,"block","defender pose alone is insufficient")
f=frame(3);busy(f.players[1]);busy(f.players[2]);f.players[1].state=0x52;f.players[2].state=0x126
o:update(f,events());equal(o.current[1].outcome,"deflect");equal(#o.current[1].contacts,1,"no duplicate contact")
equal(o.current[1].contacts[1].kind,"deflect");equal(o.current[1].damage,0)
-- Freeze excludes held/release hitpause samples from body-active timing.
o=Observe.new();o:update(frame(0),events());start(o)
for n=2,7 do
 local f=frame(n);if n<7 then busy(f.players[1]) end
 if n<=5 then attack(f) end
 if n==2 or n==3 then f.players[1].hitpause=255 end
 o:update(f,events())
end
equal(o.last[1].body_active,2,"freeze and unchanged release excluded")
-- Projectile activity can continue after the owner is ready.
o=Observe.new();o:update(frame(0),events());start(o)
for n=2,6 do
 local f=frame(n);if n<3 then busy(f.players[1]) end
 if n<=5 then attack(f,0x100c00) end
 o:update(f,events())
end
equal(o.last[1].attacker_ready,3);equal(o.last[1].projectile_active,4);equal(o.last[1].recovery,nil,"projectile outlives recovery")
-- Interruptions/cancels/clock discontinuities never certify ordinary advantage.
o=Observe.new();o:update(frame(0),events());start(o)
local f=frame(2);f.players[1].hp=244;o:update(f,events());equal(o.last[1].interrupted,true);equal(o.last[1].advantage,nil)
o=Observe.new();o:update(frame(0),events());start(o);start(o,2);equal(o.last[1].status,"superseded / cancel");equal(o.last[1].recovery,nil)
o:update(frame(90),events());equal(o.current[1],nil,"load/skip resets partial attempt")
-- Event cap / input scopes / range directional limit and facing transforms.
local injected=0;local last_keys;local writes=0
local api={joypad={get=function() return {['P1 Button A']=true,['P2 Button B']=true} end,
 set=function(k) injected=injected+1;last_keys=k end},memory={writeword=function()writes=writes+1 end,writebyte=function()writes=writes+1 end}}
local c=Controls.new(api);c.training_mode=false;local f=frame(0)
c:before(f);equal(injected,0,"observation never injects")
for i=1,90 do c:after(f) end;equal(writes,0,"resources off by default")
c.training_mode=true;c.guard=4;c:before(f);equal(last_keys['P1 Button A'],true,"P1 input preserved");equal(last_keys['P2 Left'],true)
f.players[2].guard=true;busy(f.players[2]);c:after(f);c:before(f);equal(last_keys['P2 Left'],false,"release immediately after guard")
local mem={readword=function(a) return 0 end};local g=Game.new({memory=mem,emu={}})
local p=player(0x100400);p.character=5;p.x=0
local q=player(0x100800);q.x=72
local r=g:range(p,q,true);equal(r.limit,72);equal(r.within,true,"72 is one-sided origin limit")
q.x=73;equal(g:range(p,q,true).within,false)
p.mode=1;equal(g:range(p,q,true).base,58)
local t={sx=128,sy=256,ox=3,oy=-16};local x,y=Game.point(-3,10,t);equal(x,1,"native floor at negative x");equal(y,-6)
-- A failed grab can finish with no invented conventional active duration.
o=Observe.new();o:update(frame(0),events());start(o)
o:update(frame(2),events());equal(o.last[1].first_active,nil);equal(o.last[1].startup,nil)
-- Bounded history even if recovery is never reached.
o=Observe.new();o.limit=10;o:update(frame(0),events());start(o)
for n=2,11 do local f=frame(n);busy(f.players[1]);o:update(f,events()) end
equal(o.last[1].status,"limit reached");equal(#o.last[1].timeline,10)
-- Guard switch / rebound initializers must not masquerade as attack admission.
local Hooks=require('lb2.hooks');local Profile=require('lb2.profile')
local byte,word,dword,regs,registered={},{},{},{},{}
local m={readbyte=function(a)return byte[a] or 0 end,readword=function(a)return word[a] or 0 end,
 readdword=function(a)return dword[a] or 0 end,getregister=function(k)return regs[k] or 0 end,
 registerexec=function(a,f)registered[a]=f end}
local pp,qq=0x100400,0x100800
dword[Profile.ram.p1]=pp;dword[Profile.ram.p2]=qq
regs['m68000.a4']=pp;regs['m68000.d1']=0x31;regs['m68000.a7']=0x10fff0;dword[0x10fff0]=0x3235e
local gg=Game.new({memory=m,emu={framecount=function()return 12 end}})
local h=Hooks.new(gg,{memory=m,emu={framecount=function()return 12 end}});h:install(function()return 320 end)
registered[Profile.hooks.entry]();equal(#h:take(12).entries,1,"native attack initializer")
regs['m68000.d1']=0x82;dword[0x10fff0]=0x37db0;registered[Profile.hooks.entry]()
equal(#h:take(12).entries,0,"weapon rebound is a response")
regs['m68000.d1']=0x48;dword[0x10fff0]=0x323e6;byte[pp+0x152]=5;word[pp+0x150]=0x19
registered[Profile.hooks.entry]();equal(#h:take(12).entries,0,"switch guard is a response")
regs['m68000.d1']=0x30;registered[Profile.hooks.entry]()
equal(#h:take(12).entries,1,"4A admitted from switched control remains an attack")
h:stop();equal(next(registered),nil,"owned hooks cleaned up")
-- Readonly geometry respects mirror, signed offsets, scale and native crop.
word[0x70272]=1
local slot=pp+0x100;byte[slot]=1;byte[slot+2]=0
byte[slot+3]=246;byte[slot+4]=10;byte[slot+5]=206;byte[slot+6]=216
local actor={address=pp,character=0,x=100,height=20,facing=1,transform={sx=256,sy=256,ox=0,oy=-16}}
gg.flag_cache={};local boxes=gg:boxes(actor,false)
equal(#boxes,1);equal(boxes[1].kind,'hurt');equal(boxes[1].left,90);equal(boxes[1].right,110);equal(boxes[1].top,-86)
-- Incompatible ROMs never install hooks or write game state.
local App=require('lb2.app');local gui_callback;local hook_count=0
local bad_api={memory={readword=function()return 0 end,registerexec=function()hook_count=hook_count+1 end,getregister=function()return 0 end},
 emu={romname=function()return 'lastbld2' end,registerbefore=function()end},
 gui={register=function(f)gui_callback=f end},joypad={get=function()return{}end,set=function()error('input injected')end}}
local app=App.new(bad_api);app:start();equal(app.compatible,false);equal(hook_count,0);equal(type(gui_callback),'function')
app:stop();app:step();equal(app.frame,nil,"stopped callbacks do not sample/write")
-- Native grab gate and subsequent damage are one grab outcome, not mixed.
o=Observe.new();o:update(frame(0),events());start(o)
f=frame(2);busy(f.players[1]);busy(f.players[2]);local e=events();e.grabs={{source=f.players[1].address,target=f.players[2].address}};o:update(f,e)
f=frame(3);busy(f.players[1]);busy(f.players[2]);f.players[2].hp=237;o:update(f,events())
f=frame(4);f.players[2].hp=237;o:update(f,events());equal(o.last[1].outcome,'grab');equal(o.last[1].damage,19)
print(string.format("PASS: %d assertions",tests))
