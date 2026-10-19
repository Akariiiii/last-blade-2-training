package.path='Training/?.lua;'..package.path
local R,C=require('lb2.resources'),require('lb2.controls')
local words,bytes,longs,registered,writes={},{},{}, {},{};local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' != '..tostring(b));count=count+1 end
local signature={0x322d,0x6594,0x7000,0x5240,0x8300,0x3b41,0x6594,0x6606,0x3b7c,1,0x6596}
for i,w in ipairs(signature)do words[0x5aeaa+(i-1)*2]=w end
longs[0x100000]=0x42ee;words[0x10e594]=0x59;words[0x10e596]=2
local keys,last={},{}
local api={memory={readword=function(a)return words[a]or 0 end,readbyte=function(a)return bytes[a]or 0 end,
 readdword=function(a)return longs[a]or 0 end,writeword=function(a,v)words[a]=v;writes[#writes+1]={a,v}end,
 registerexec=function(a,fn)registered[a]=fn end},joypad={get=function()local r={};for k,v in pairs(keys)do r[k]=v end;return r end,set=function(k)last=k end}}
local c=C.new(api);local r=R.new(api,c)
eq(c.infinite_time,true);eq(c.refill_p2,true);eq(c.heal_delay,60);eq(r:install(),true)
registered[0x5aeb8]();eq(words[0x10e594],0x60);eq(words[0x10e596],2,'timer state untouched')
local n=#writes;r:freeze();eq(#writes,n,'no redundant write')
c.infinite_time=false;words[0x10e594]=0x59;r:freeze();eq(words[0x10e594],0x59)
c.infinite_time=true;bytes[0x108501]=64;r:freeze();eq(words[0x10e594],0x59,'no scene write')
bytes[0x108501]=0
local function f(t,hp,ready)
 return {engine=t,players={{address=0x100400,ready=false},{address=0x100800,hp=hp or 243,ready=ready~=false,hitpause=0}},boxes={}}
end
local o={current={},last={}}
r:reset();r:after(f(0,256),o);r:after(f(10),o);n=#writes
r:after(f(69),o);eq(#writes,n,'wait59 after hit')
local frame=f(70);r:after(frame,o);eq(words[0x10097e],256);eq(frame.resource_refill,true,'baseline marker')
eq(#writes,n+1,'P2 only');eq(words[0x10057e],nil,'P1 unchanged')
-- A later hit resets the delay; active attempts/boxes/down states prevent heals.
r:reset();r:after(f(0,256),o);r:after(f(10,245),o);r:after(f(40,230),o);n=#writes
r:after(f(99,230),o);eq(#writes,n)
o.current[1]={last_contact=40};r:after(f(100,230),o);eq(#writes,n,'unfinished measurement')
o.current={};frame=f(101,230);frame.boxes={{kind='attack'}};r:after(frame,o);eq(#writes,n,'active projectile')
r:after(f(102,230,false),o);eq(#writes,n,'still down or stunned')
frame=f(103,230);r:after(frame,o);eq(#writes,n+1);eq(frame.resource_refill,true)
-- KO/menu/manual/playback do not revive or heal. Controls remain explicit.
for _,mode in ipairs({'ko','menu','manual','playback'})do
 r:reset();r:after(f(0,256),o);c.menu=mode=='menu';c.training_mode=mode~='manual';c.playback_active=mode=='playback'
 n=#writes;r:after(f(100,mode=='ko'and 0xfff0 or 200),o);eq(#writes,n,mode)
end
c.menu=false;c.training_mode=true;c.playback_active=false
-- Header is navigable with just the already-working directions and A.
c:toggle_menu();eq(c.row,0);keys={['P1 Button A']=true};c:before(nil);eq(c.tab,2);eq(last['P1 Button A'],false)
keys={};c:before(nil);keys={['P1 Down']=true};c:before(nil);eq(c.row,1)
keys={};c:before(nil);keys={['P1 Up']=true};c:before(nil);eq(c.row,0)
keys={};c:before(nil);keys={['P1 Right']=true};c:before(nil);eq(c.tab,3)
keys={};c:before(nil);keys={['P1 Left']=true};c:before(nil);eq(c.tab,2)
c.tab=3;c.row=3;c:change(1);eq(c.heal_delay,90);c:change(-1);eq(c.heal_delay,60)
for i=1,30 do c:change(-1)end;eq(c.heal_delay,30)
for i=1,30 do c:change(1)end;eq(c.heal_delay,300)
r:stop();eq(registered[0x5aeb8],nil)
words[0x5aeaa]=0;eq(r:install(),false);eq(c.timer_supported,false)
print('PASS Resources: '..count..' assertions')
