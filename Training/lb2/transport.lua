-- Coin/Start workflow compatible with3rd Training. Independent implementation;
-- no callbacks, game memory or file I/O. Single taps wait11 emulated frames so
-- a double tap cannot accidentally start playback or overwrite a slot.
local T={};T.__index=T
function T.new(recorder)return setmetatable({recorder=recorder,state='normal',changed=false},T)end
function T:stop()
 self.recorder:stop();self.state='normal';self.coin_at=nil;self.changed=true
end
function T:arm()
 self:stop();self.state='waiting'
end
function T:owns_dummy()return self.state=='waiting'or self.state=='recording'end
function T:update(engine,coin_edge)
 self.changed=false
 if self.state=='recording'and not self.recorder.recording or self.state=='playing'and not self.recorder.playing then
  self.state='normal';self.changed=true
 end
 if coin_edge then
  if self.coin_at and engine-self.coin_at<11 then
   if self:owns_dummy()then self:stop()else self:arm()end
  else self.coin_at=engine end
 end
 if self.coin_at and engine-self.coin_at>=11 then
  self.coin_at=nil
  if self.state=='waiting'then
   self.recorder:start_record(self.recorder.selected,true);self.state='recording';self.changed=true
  elseif self.state=='recording'or self.state=='playing'then self:stop()
  else
   local ok,message=self.recorder:start_playback();self.recorder.last_error=message
   if ok then self.state='playing';self.changed=true end
  end
 end
end
return T
