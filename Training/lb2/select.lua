-- Native menu flow. No ROM patches, distributed savestates or combat-state hacks.
-- Validated against original disassembly 0286A/0293C,1A03A,1B05C and flow-probe03.
local U=require('lb2.util')
local S={};S.__index=S
local names={returning='Returning to character select',char1='P1: choose character',char2='P2: choose character',
  mode1='P1: choose Power / Speed / EX',mode2='P2: choose Power / Speed / EX',intro='Starting training match'}
local contracts={
 {0x293c,{0x08ad,0x0000,0x0501,0x426d,0x0560,0x4eb9}},
 {0x1a03a,{0x3b7c,0xffff,0x3d58,0x422d,0x3d62,0x4e75}},
 {0x1b05c,{0x4a2d,0x7d82,0x6602,0x4e75,0x4a2c,0x0100}},
}
local buttons={'Up','Down','Left','Right','Button A','Button B','Button C','Button D','Start','Coin'}
function S.new(api)
 return setmetatable({api=api,active=false,fast_transitions=true,fast_active=false,stage='returning',ticks=0,wait_release=true,stable=0},S)
end
function S:set_fast(enabled)
 enabled=not not(enabled and self.fast_transitions)
 if enabled==self.fast_active then return end
 local emu=self.api.emu
 if not emu or not emu.speedmode then self.fast_unavailable=true;return end
 local ok,message=pcall(emu.speedmode,enabled and 'turbo' or 'normal')
 if ok then self.fast_active=enabled else self.speed_error=tostring(message)end
end
function S:cancel()
 self:set_fast(false);self.active=false;self.finished=false
end
function S:compatible()
 for _,row in ipairs(contracts) do for i,w in ipairs(row[2])do
  if self.api.memory.readword(row[1]+(i-1)*2)~=w then return false,string.format('Unsupported menu code %06X',row[1])end
 end end
 return true
end
function S:request()
 self:set_fast(false)
 local ok,message=self:compatible();if not ok then self.error=message;return false,message end
 self.active=true;self.stage='returning';self.ticks=0;self.wait_release=true;self.stable=0
 self.jumped=false;self.error=nil;self.release_after=false
 self.finished=false;self:set_fast(true)
 return true
end
function S:install()
 local ok=self:compatible();if not ok then return end
 self.api.memory.registerexec(0x1b05c,function()
  if not self.active then return end
  local a=self.api.memory.getregister('m68000.a4')
  if U.valid(a) then
   -- This exact native timer callback only belongs to selection. BCD21 seconds.
   self.api.memory.writebyte(a+0x100,0x21);self.api.memory.writebyte(a+0x101,60)
  end
 end)
 self.installed=true
end
function S:stop()self:cancel();if self.installed then self.api.memory.registerexec(0x1b05c,nil)end;self.installed=false end
function S:transition(stage)
 if self.stage~=stage then self.stage=stage;self.wait_release=true;self.stable=0;self:set_fast(stage=='returning'or stage=='intro')end
end
function S:before(physical)
 local m=self.api.memory;local keys={}
 for k,v in pairs(physical)do keys[k]=v end
 for _,prefix in ipairs({'P1','P2'})do for _,b in ipairs(buttons)do keys[prefix..' '..b]=false end end
 if not self.active then return keys end
 self.ticks=self.ticks+1
 if self.stage=='returning' and not self.jumped then
  local ptr=m.readdword(0x108530);local fn=m.readdword(0x100000)
  local menu=fn==0x2b9c or fn==0x2c58 or fn==0x2a90 or fn==0x292a or fn==0x42ee
  if ptr==0x100000 or menu then
   -- Ask the native game controller to perform its own scene teardown/reinit.
   -- Native VS setup029D4 sets both joined-player words. This prevents an AI P2.
   m.writeword(0x10fdb6,0x0101);m.writeword(0x1082c6,0x0101);m.writeword(0x10852a,0x0202)
   m.writedword(0x100000,0x293c);self.jumped=true
  else
   -- Native title/attract bootstrap, no guessed controller pointer or CPU PC.
   if self.ticks%60<4 then keys['P1 Coin']=true;keys['P2 Coin']=true end
   if self.ticks%60>=12 and self.ticks%60<16 then keys['P1 Start']=true;keys['P2 Start']=true end
  end
 end
 -- Native how-to-play/interstitial screens require Start before character select.
 if self.stage=='returning' and self.jumped and self.ticks%60>=12 and self.ticks%60<14 then
  keys['P1 Start']=true;keys['P2 Start']=true
 end
 if self.stage=='returning' or self.stage=='intro' then return keys end
 local held=false
 for _,b in ipairs(buttons)do if physical['P1 '..b]then held=true;break end end
 if self.wait_release then if not held then self.wait_release=false end;return keys end
 local target=(self.stage=='char2' or self.stage=='mode2')and 'P2' or 'P1'
 for _,b in ipairs(buttons)do if b~='Coin'then keys[target..' '..b]=not not physical['P1 '..b]end end
 return keys
end
function S:after(frame)
 if not self.active then return end
 local m=self.api.memory
 local p1,p2=m.readword(0x10bd58),m.readword(0x10bd5a)
 local mode1,mode2=m.readbyte(0x10bd62),m.readbyte(0x10bd63)
 if self.stage=='returning' and self.jumped and p1==0xffff and p2==0xffff and
   (m.readdword(0x100000)==0x2b9c or m.readdword(0x100000)==0x2c58) then self:transition('char1')end
 if self.stage=='char1' and p1<20 then self:transition('char2')end
 if self.stage=='char2' and p2<20 then self:transition('mode1')end
 if self.stage=='mode1' and mode1~=0 then self:transition('mode2')end
 if self.stage=='mode2' and mode2~=0 then self:transition('intro')end
 if self.stage=='intro' and m.readdword(0x100000)==0x42ee and not U.bit(m.readbyte(0x108501),2) and not U.bit(m.readbyte(0x108501),64) and m.readbyte(0x10bd80)==0 and m.readdword(0x10853e)==0 and frame and frame.players[1].ready and frame.players[2].ready then
  self.stable=self.stable+1
  if self.stable>=3 then self:set_fast(false);self.active=false;self.release_after=true;self.finished=true end
 elseif self.stage=='intro'then self.stable=0 end
 if self.ticks>7200 then self.error='Selection timed out; Alt+1 retries';self:cancel() end
end
function S:draw(gui,width)
 if not self.active then return end
 gui.box(3,3,width-4,29,0x07111dcc,0x9fb3c177)
 gui.text(7,5,(names[self.stage] or self.stage)..(self.fast_active and ' [FAST]' or ''),0xffe080ff,0x000000c0)
 gui.text(7,16,'Use P1 directions + A | release A between selections',0xffffffff,0x000000c0)
end
return S
