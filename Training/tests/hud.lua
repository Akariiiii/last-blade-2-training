package.path="Training/?.lua;Training/?/init.lua;"..package.path
local HUD,I=require('lb2.hud'),require('lb2.input_display')
local calls,tests={},0
local function eq(a,b,label) assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b));tests=tests+1 end
local gui={}
for _,name in ipairs({'text','box','line'}) do gui[name]=function(...) calls[#calls+1]={kind=name,args={...}} end end
local function text(s)
 for _,c in ipairs(calls) do if c.kind=='text' and c.args[3]==s then return c end end
end
local function reset()calls={} end
-- D button and Down direction remain distinct. Diagonal arrows use primitive geometry.
I.draw(gui,{{direction={down=true,right=true},buttons={A=true,D=true},frames=23}},4,130,6,80)
eq(text('A')~=nil,true,'A icon');eq(text('D')~=nil,true,'D icon');eq(text('23')~=nil,true,'duration')
eq(text('DRAD')==nil,true,'no UDLR strings')
reset();I.draw(gui,{{direction={},buttons={D=true},frames=1}},4,130,6,80)
local arrowdot=false
for _,c in ipairs(calls) do if c.kind=='box' and c.args[1]==21 and c.args[2]==129 then arrowdot=true end end
eq(arrowdot,true,'button D is neutral direction')
-- History bounds and neutral-state durations.
reset();local h={};for n=1,12 do h[n]={direction={},buttons={},frames=n} end
I.draw(gui,h,4,130,6,80);eq(text('6'),nil);eq(text('7')~=nil,true);eq(text('12')~=nil,true)
-- Native HP-aligned stun bar, depleted stun with safe clamping, mirrored side.
reset();local hud=HUD.new(gui);hud:stun_bar({stun_capacity=60,stun=30},1,320)
eq(text('STUN 30/60')~=nil,true);eq(calls[1].args[1],14);eq(calls[1].args[2],29);eq(calls[1].args[3]-calls[1].args[1]+1,96,'compact width')
hud:stun_bar({stun_capacity=60,stun=-20},2,320);eq(text('STUN 60/60')~=nil,true)
reset();hud:stun_bar({stun_capacity=220,stun=220,stun_prime=240,stun_stage='primed'},2,320)
eq(text('STUN: PRIMED')~=nil,true);eq(calls[2].args[3]-calls[2].args[1]+1,94,'native refill remains full while primed')
reset();hud:stun_bar({stun_capacity=220,stun=220,stun_stage='dizzy'},1,320)
eq(text('STUN: DIZZY')~=nil,true)
reset();hud:stun_bar({stun_capacity=220,stun=0,stun_prime=0,stun_stage='normal'},1,320)
eq(text('STUN 220/220')~=nil,true,'exact zero does not claim priming')
-- Actual attempt uses separate clocks; never adds 1 to exclusive startup itself.
reset();local p={name='Moriya',mode=0};local m={startup=5,first_active_tick=5,first_active=15,start=10,contact=15,
 body_active=2,projectile_active=0,recovery=14,advantage=-7,outcome='block',damage=0,chip=0,stun=0,meter_gain=6,status='complete',contacts={}}
hud:attempt(1,p,m,6,46,false)
eq(text('Startup: 5f')~=nil,true);eq(text('Hit frame: 6e  block')~=nil,true)
eq(text('Adv(ctrl): -7')~=nil,true);eq(text('Adv(ctrl): -7').args[4],0xff897aff)
reset();m.stun=0;m.stun_operand=64;hud:attempt(1,p,m,6,46,false)
eq(text('Stun: 64  Meter: +6')~=nil,true,'borrow/refill must not display zero native stun')
reset();m.startup=nil;m.first_active_tick=nil;m.startup_bound=0;m.contact=10
hud:attempt(1,p,m,6,46,false);eq(text('Startup: <=0f')~=nil,true,'zero bound preserved')
-- Scroll follows selection, all tab labels stay within menu. No giant panels during gameplay.
reset();local c={tab=3,row=12,tabs=function()return {'Display','Dummy','Resources','Actions','Recording'} end,
 items=function()local r={};for n=1,15 do r[n]={'Option '..n,'On','k'} end;return r end}
hud:menu(c,320);eq(text('> Option 12')~=nil,true);eq(text('  Option 1'),nil);eq(text('12/15')~=nil,true)
print('PASS HUD: '..tests..' assertions')
