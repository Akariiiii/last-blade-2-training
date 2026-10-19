package.path='Training/?.lua;'..package.path
local Game=require('lb2.game');local tests=0
local function eq(a,b,m)assert(a==b,(m or 'value')..': '..tostring(a)..' ~= '..tostring(b));tests=tests+1 end
local actor=0x100400;local values={}
local api={memory={},emu={}}
for _,kind in ipairs({'readbyte','readword','readdword'})do api.memory[kind]=function(a)return values[a]or 0 end end
local game=Game.new(api)
local function sample(remaining,prime,state,timer)
 values={[actor+0x188]=remaining,[actor+0x189]=220,[actor+0x18d]=prime,[actor+0x72]=state,[actor+0x18e]=timer}
 return game:actor(actor,320)
end
local p=sample(0,0,0,0);eq(p.stun_stage,'normal','exact zero is not prime');eq(p.stun_used,220)
p=sample(220,240,0x100,0);eq(p.stun_prime,240);eq(p.stun_stage,'primed');eq(p.stun_used,220,'native refill does not empty the gauge')
p=sample(220,0,0x112,120);eq(p.stun_stage,'dizzy');eq(p.stun_used,220)
p=sample(220,0,0x114,1);eq(p.stun_stage,'dizzy')
p=sample(220,0,0x115,255);eq(p.stun_stage,'normal','post-dizzy timer residue');eq(p.stun_used,0)
p=sample(255,0,0,0);eq(p.stun_used,0,'immune sentinel safely clamped')
print('PASS Stun: '..tests..' assertions')
