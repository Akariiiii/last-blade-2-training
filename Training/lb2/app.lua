local U=require("lb2.util")
local Game,Hooks,Observe,Controls,HUD=require("lb2.game"),require("lb2.hooks"),require("lb2.observe"),require("lb2.controls"),require("lb2.hud")
local Select,Recorder,Resources=require('lb2.select'),require('lb2.recorder'),require('lb2.resources')
local A={};A.__index=A
function A.new(api,options)
  api=api or {memory=memory,emu=emu,gui=gui,joypad=joypad,input=input,savestate=savestate}
  local app=setmetatable({api=api,options=options or {},game=Game.new(api),hooks=nil,observe=Observe.new(),controls=Controls.new(api),hud=HUD.new(api.gui),
    frame=nil,engine=nil,compatible=false,message="Starting",stopped=false,draws=0,flow=Select.new(api)},A)
  app.controls.recorder=Recorder.new()
  app.resources=Resources.new(api,app.controls,function()return not app.stopped and not app.flow.active and not app.flow.error and app.frame~=nil end)
  return app
end
function A:width() return self.api.emu.screenwidth and self.api.emu.screenwidth() or 320 end
function A:height() return self.api.emu.screenheight and self.api.emu.screenheight() or 224 end
function A:reset()
  self.observe:reset();self.controls:reset();self.resources:reset();self.frame=nil;self.engine=nil
  if self.hooks then self.hooks:reset() end
  self.game.flag_cache={}
end
function A:return_select()
  self:reset();self.controls.menu=false
  self.flow.fast_transitions=self.controls.fast_transitions
  local ok,message=self.flow:request()
  if ok and self.hooks then self.hooks:stop();self.observations_suspended=true;self.select_engine=nil
  elseif not ok then self.message=message end
  return ok,message
end
function A:input_history(frame)
  local keys=self.controls.last_keys or self.api.joypad.get()
  for i=1,2 do
    local prefix="P"..i.." ";local parts={}
    for _,key in ipairs({"Up","Down","Left","Right"}) do if keys[prefix..key] then parts[#parts+1]=key:sub(1,1) end end
    for _,key in ipairs({"A","B","C","D"}) do if keys[prefix.."Button "..key] then parts[#parts+1]=key end end
    local direction,buttons={},{}
    for _,key in ipairs({'Up','Down','Left','Right'})do direction[key:lower()]=not not keys[prefix..key]end
    for _,key in ipairs({'A','B','C','D'})do buttons[key]=not not keys[prefix..'Button '..key]end
    local bits={}
    for _,key in ipairs({'Up','Down','Left','Right','Button A','Button B','Button C','Button D'})do bits[#bits+1]=keys[prefix..key]and '1'or '0'end
    local text=table.concat(bits)
    local h=self.observe.history[i];local last=h[#h]
    if last and last.text==text then last.frames=last.frames+1 else U.push(h,{text=text,frames=1,direction=direction,buttons=buttons},12) end
  end
end
function A:step()
  if self.stopped then return end
  if self.flow.active then
    local engine=self.api.emu.framecount()
    if engine==self.select_engine then return end
    self.select_engine=engine
    -- Selection preview tasks reuse actor memory. Do not decode them as fighters.
    local preview=self.flow.stage=='intro' and self.api.memory.readdword(0x100000)==0x42ee and self.game:sample(self:width()) or nil
    self.flow:after(preview)
    if self.flow.finished then
      self.flow.finished=false;self:reset()
      self.hooks:install(function()return self:width()end);self.observations_suspended=false
    end
    return
  end
  if self.flow.error then return end
  if self.observations_suspended then
    self.hooks:install(function()return self:width()end);self.observations_suspended=false
  end
  local frame=self.game:sample(self:width())
  if not frame then
    if self.frame then self:reset() end
    return
  end
  if self.engine==frame.engine then return end -- Drawing while paused never advances measurements.
  if self.engine and frame.engine~=self.engine+1 then self:reset() end
  local events=self.hooks:take(frame.engine)
  frame.entries=events.entries
  for _,b in ipairs(events.boxes) do frame.boxes[#frame.boxes+1]=b end
  frame.guard_policy=self.controls:label()
  self.observe:update(frame,events);self:input_history(frame)
  self.engine=frame.engine;self.frame=frame
  self.controls:after(frame);self.resources:after(frame,self.observe)
  if frame.resource_refill then
    -- Optional maintenance changes the next tick's resource baseline, not damage
    -- or meter earned by the move which has already been observed above.
    for _,p in ipairs(frame.players)do
      p.hp=self.api.memory.readword(p.address+0x17e);p.meter=self.api.memory.readbyte(p.address+0x17d)
    end
  end
  if self.controls.reset_requested then self:reset();self.controls.reset_requested=false end
end
function A:draw()
  if self.stopped then return end
  self.draws=self.draws+1
  if not self.compatible then self.hud:warning(self.message,self:width());return end
  if self.flow.active then self.flow:draw(self.api.gui,self:width());return end
  if self.flow.error then self.hud:warning(self.flow.error,self:width());return end
  if not self.frame then self.hud:warning("Start a match with P1 and P2",self:width());return end
  self.hud:draw(self.frame,self.observe,self.controls,self.game,self:width(),self:height(),self.hooks.stats)
end
function A:stop()
  if self.stopped then return end
  self.stopped=true
  if self.hooks then self.hooks:stop() end
  self.flow:stop();self.resources:stop();self.controls.recorder:stop()
  -- No resource settings or ROM bytes were changed by observation.
end
function A:start()
  local api=self.api
  assert(api.memory and api.memory.registerexec and api.memory.getregister,"FBNeo Lua memory hooks required")
  assert(api.emu.registerbefore and api.gui.register,"FBNeo Lua callbacks required")
  self.compatible,self.message=self.game:compatible()
  if self.compatible then
    self.hooks=Hooks.new(self.game,api);self.hooks:install(function() return self:width() end)
    self.flow:install();self.resources:install()
    api.emu.registerbefore(function()
      if self.stopped then return end
      if self.flow.active then self.api.joypad.set(self.flow:before(self.api.joypad.get()));return end
      self.resources:freeze();self.controls:before(self.frame)
    end)
    -- Capture in GUI callback: same synchronized path as the accepted private recorder.
    api.gui.register(function() self:step();self:draw() end)
    self.controls:hotkeys(function() self:reset() end,function()self:return_select()end)
    if api.savestate and api.savestate.registerload then api.savestate.registerload(function()self.flow:cancel();self.flow.error=nil;self:reset()end) end
    if api.emu.registerexit then api.emu.registerexit(function() self:stop() end) end
    if self.options.startup_select~=false then self:return_select() end
  else api.gui.register(function() self:draw() end) end
  print("Last Blade 2 Live Training: "..self.message)
  print("Alt+1: character select | Alt+2: GUI | Alt+3: boxes | Alt+4: HUD | Alt+5: clear")
  print("Start: menu | Coin x2: recording mode | Coin: record/stop in recording mode; play/stop otherwise")
  print("REC WAIT/REC: P1 controller drives P2; select one of8slots in Recording. No automatic recording files.")
  print("P1 selects both players. P2 defaults to neutral dummy. Menu: Up selects tab header; Left/Right/A changes tabs; Down options; B close.")
  print("Observation does not patch ROM. Menu setup/dummy/resources are separate training actions; no automatic log files.")
end
return A
