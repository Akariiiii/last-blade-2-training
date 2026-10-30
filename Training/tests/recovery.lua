package.path='Training/?.lua;Training/?/init.lua;'..package.path
local D,C,Game,R=require('lb2.dummy'),require('lb2.controls'),require('lb2.game'),require('lb2.recorder')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b));count=count+1 end
local function frame(n,down,ready)
 return {engine=n,players={{address=1,hp=256,ready=true,hitpause=0,facing=1},
  {address=2,hp=256,ready=not not ready,knockdown=not not down,hitpause=0,height=0,facing=0}},entries={},contacts={},boxes={}}
end
local opt={guard=2,counter=5,counter_command=2,counter_delay=0,recovery_mode=2,recovery_frequency=1}
local d=D.new(function()error('Always must not draw RNG')end)
local f=frame(0,true,false);d:after(f,opt)
eq(d:request(f,opt).direction,'6','forward down request');eq(next(d:request(f,opt).buttons),nil,'no attack/deflect button');eq(d.pending,nil)
-- Roll admission is not counter admission. Preserve wakeup through the roll.
f=frame(1,false,false);f.entries={{actor=2,script=0x17}};d:after(f,opt)
eq(d.was_down,true);eq(d:request(f,opt).direction,'5','release roll input');eq(d.pending,nil)
f=frame(20,false,true);d:after(f,opt);eq(d.pending.kind,'wakeup');eq(d:request(f,opt).buttons.A,true,'counter after roll control-ready')
f=frame(21,false,false);f.entries={{actor=2,script=0x31}};d:after(f,opt);eq(d.pending,nil);eq(d.was_down,nil)
-- Delay starts on readiness after the roll, not on knockdown or roll admission.
d:reset();opt.counter_delay=2;d:after(frame(30,true,false),opt)
f=frame(50,false,false);d:after(f,opt);eq(d:request(f,opt).buttons.A,nil)
f=frame(60,false,true);d:after(f,opt);eq(d:request(f,opt).buttons.A,nil)
f.engine=61;eq(d:request(f,opt).buttons.A,nil);f.engine=62;eq(d:request(f,opt).buttons.A,true)
-- Off and Random skip suppress held/switch/random guard and D while down.
for guard=1,#D.guard_names do
 d=D.new();opt.guard=guard;opt.recovery_mode=1;f=frame(0,true,false);d:after(f,opt)
 local r=d:request(f,opt);eq(r.direction,'5','Off overrides guard '..guard);eq(next(r.buttons),nil)
end
opt.guard=2;opt.recovery_mode=3;opt.recovery_frequency=2
for _,pick in ipairs({1,2})do
 local calls=0;d=D.new(function(n)eq(n,2);calls=calls+1;return pick end)
 for n=0,20 do f=frame(n,true,false);d:after(f,opt);eq(d:request(f,opt).direction,pick==1 and '4'or '5')end
 eq(calls,1,'one random choice per down episode')
 f=frame(21,false,true);d:after(f,opt);d:after(frame(22,true,false),opt);eq(calls,2,'next knockdown chooses again')
end
-- Both facing mappings; no P1 changes, no button inherited from guard/counter.
for _,facing in ipairs({0,1})do
 for _,dir in ipairs({'4','6'})do
  local keys={['P1 Button A']=true,['P2 Button D']=true}
  D.apply(keys,'P2',{direction=dir,buttons={}},facing)
  eq(keys['P2 Right'],(dir=='6')==(facing==1));eq(keys['P2 Left'],(dir=='4')==(facing==1))
  eq(keys['P2 Button D'],false);eq(keys['P1 Button A'],true)
 end
end
-- KO and reset release; ordinary non-ready hitstun cannot invent a wakeup.
opt.guard=1;opt.recovery_frequency=1;opt.recovery_mode=2
d=D.new();f=frame(0,true,false);f.players[2].hp=65535;d:after(f,opt);eq(d:request(f,opt).direction,'5','KO sentinel')
f.players[2].hp=0;eq(d:request(f,opt).direction,'5','zero HP')
d:reset();eq(d.recovery,nil);eq(d.was_down,nil)
d:after(frame(1,false,false),opt);d:after(frame(2,false,true),opt);eq(d.pending,nil,'no ordinary hitstun wakeup')
-- Adapter classification is scoped to native down contexts; no actor writes.
local actor=0x100400;local values={};local memory={}
for _,method in ipairs({'readbyte','readword','readdword'})do memory[method]=function(a)return values[a]or 0 end end
local game=Game.new({memory=memory,emu={}})
for _,context in ipairs({0,1,0x23,0x24,0x4f})do
 values={[actor+0x150]=context,[actor+0x152]=2}
 eq(game:actor(actor,320).knockdown,context==0x23 or context==0x24)
end
-- Settings are numeric, default Off; changing settings discards the old choice.
local c=C.new({});eq(c.recovery_mode,1);eq(c.recovery_frequency,1)
c.tab=2;c.row=7;c:change(1);eq(c.recovery_mode,2);c:change(-1);eq(c.recovery_mode,1)
c.row=8;c:change(1);eq(c.recovery_frequency,2);c:change(1);eq(c.recovery_frequency,1)
c.recovery_mode=2;c.dummy:after(frame(0,true,false),c:dummy_options());c.row=7;c:change(1);eq(c.dummy.was_down,nil)
-- Suspended input owners cannot arm stale wakeup/recovery state.
for _,owner in ipairs({'menu','manual','release','playback','recording'})do
 c=C.new({});c.recovery_mode=2;c.counter=5;c.dummy:after(frame(0,true,false),c:dummy_options())
 c.menu=owner=='menu';c.training_mode=owner~='manual';c.close_release=owner=='release';c.playback_active=owner=='playback'
 if owner=='recording'then c.recorder=R.new();local T=require('lb2.transport');c.transport=T.new(c.recorder);c.transport:arm()end
 c:after(frame(1,true,false));eq(c.dummy.was_down,nil,owner..' clears dummy episode');eq(c.dummy.recovery,nil)
end
print('PASS Recovery: '..count..' assertions')
