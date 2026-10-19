-- Training assistance. Native clock/HP writes are separate from observation.
local U=require('lb2.util')
local R={};R.__index=R
local clock=0x10e594
local signature={0x322d,0x6594,0x7000,0x5240,0x8300,0x3b41,0x6594,0x6606,0x3b7c,0x0001,0x6596}
function R.new(api,controls,active)
 return setmetatable({api=api,controls=controls,active=active,installed=false},R)
end
function R:install()
 local m=self.api.memory
 for i,w in ipairs(signature)do
  if m.readword(0x5aeaa+(i-1)*2)~=w then self.controls.timer_supported=false;return false end
 end
 self.controls.timer_supported=true
 -- Native decrement has committed; restore before its HUD/timeout consumers.
 -- No register/CCR/ROM changes and no timer-state or task-divider overrides.
 m.registerexec(0x5aeb8,function()self:freeze()end);self.installed=true;return true
end
function R:live()
 local m=self.api.memory
 return self.controls.training_mode and (not self.active or self.active()) and
  m.readdword(0x100000)==0x42ee and m.readbyte(0x10853a)==0 and
  not U.bit(m.readbyte(0x108501),64) and not U.bit(m.readbyte(0x108501),2) and
  m.readbyte(0x10bd80)==0 and m.readdword(0x10853e)==0
end
function R:freeze()
 if self.installed and self.controls.infinite_time and self:live()then
  local m=self.api.memory
  if m.readword(clock)~=0x60 then m.writeword(clock,0x60)end
 end
end
function R:reset()self.last_contact=nil;self.previous_hp=nil end
function R:after(frame,observe)
 local q=frame.players[2];local now=frame.engine
 if not self.last_contact then self.last_contact=now end
 local contact=self.previous_hp and q.hp<self.previous_hp
 for _,list in ipairs({observe.current,observe.last})do
  for i=1,2 do if list[i]and list[i].last_contact==now then contact=true end end
 end
 if contact then self.last_contact=now end
 self.previous_hp=q.hp
 local busy=observe.current[1]or observe.current[2]
 for _,box in ipairs(frame.boxes)do if box.kind=='attack'then busy=true;break end end
 if self.controls.refill_p2 and self:live()and not self.controls.menu and
   not self.controls.playback_active and not busy and q.ready and q.hitpause==0 and
   U.s16(q.hp)>=0 and q.hp<256 and now-self.last_contact>=self.controls.heal_delay then
  self.api.memory.writeword(q.address+0x17e,256)
  self.previous_hp=256;frame.resource_refill=true
 end
end
function R:stop()
 if self.installed then self.api.memory.registerexec(0x5aeb8,nil)end
 self.installed=false;self:reset()
end
return R
