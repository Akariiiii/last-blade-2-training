local U,D=require("lb2.util"),require("lb2.dummy")
local Transport=require('lb2.transport')
local C={};C.__index=C
local tabs={"Display","Dummy","Resources","Actions","Recording"}
local function on(v) return v and "On" or "Off" end
local function row(label,value,key) return {label,value,key,label=label,value=value,key=key} end
function C.new(api)
 return setmetatable({api=api,menu=false,tab=1,row=0,previous={},guard=1,counter=1,counter_command=1,counter_delay=0,
  training_mode=true,fast_transitions=true,infinite_time=true,refill_p2=true,heal_delay=60,counter_switch=false,retaliation=false,dummy=D.new(),refill_hp=false,refill_meter=false,quiet=0,reset_requested=false,
  show_boxes=true,box_fill=false,show_hud=true,show_distance=true,show_inputs=true,show_timeline=false,show_stun=true,
  hud_detail=false,hud_alpha=80,hud_x=0,hud_y=0,input_history_rows=6},C)
end
function C:label() return self.training_mode and D.guard_names[self.guard] or "Manual P2" end
function C:tabs() return tabs end
function C:items()
 if self.tab==2 then return {
  row("P2 control",self.training_mode and "Dummy" or "Manual","training_mode"),
  row("Guard / defense",self:label(),"guard"),row("Counter trigger",D.counter_names[self.counter],"counter"),
  row("Counter command",D.commands[self.counter_command],"counter_command"),row("Counter delay",self.counter_delay.."f","counter_delay"),
  row("Switch before counter",on(self.counter_switch),"counter_switch")}
 elseif self.tab==3 then return {
  row("Infinite time",self.timer_supported==false and "Unavailable"or on(self.infinite_time),"infinite_time"),
  row("P2 HP after combo",on(self.refill_p2),"refill_p2"),
  row("Recovery wait",string.format("%.1fs / %df",self.heal_delay/60,self.heal_delay),"heal_delay"),
  row("Both HP (idle)",on(self.refill_hp),"refill_hp"),row("Meter refill (idle)",on(self.refill_meter),"refill_meter")}
 elseif self.tab==4 then return {row("Character select","A","return_select"),row("Clear measurements","A","reset_requested"),row("Fast transitions",on(self.fast_transitions),"fast_transitions")}
 elseif self.tab==5 then
  if self.recorder then return self.recorder:items() end
  return {row("Input recording","Not available","none")}
 end
 return {row("Collision boxes",on(self.show_boxes),"show_boxes"),row("Frame / damage HUD",on(self.show_hud),"show_hud"),
  row("Stun bars",on(self.show_stun),"show_stun"),row("Distance / range",on(self.show_distance),"show_distance"),
  row("Input history",on(self.show_inputs),"show_inputs"),row("Input rows",self.input_history_rows,"input_history_rows"),
  row("Frame timeline",on(self.show_timeline),"show_timeline"),row("Contact details",on(self.hud_detail),"hud_detail"),
  row("HUD background",self.hud_alpha,"hud_alpha"),row("HUD offset X",self.hud_x,"hud_x"),row("HUD offset Y",self.hud_y,"hud_y"),row("Filled collision boxes",on(self.box_fill),"box_fill")}
end
function C:clear_dummy()
 self.dummy:reset();self.release=nil;self.contact=nil;self.retaliation_done=nil
end
function C:change_tab(delta)
 self.tab=(self.tab-1+delta)%#tabs+1;self.row=0
end
function C:change(delta)
 if self.row==0 then self:change_tab(delta);return end
 local item=self:items()[self.row];if not item then return end
 local key=item.key or item[3]
 if key=="heal_delay" then self.heal_delay=U.clamp(self.heal_delay+delta*30,30,300)
 elseif key=="guard" then self.guard=(self.guard-1+delta)%#D.guard_names+1;self:clear_dummy()
 elseif key=="counter" then self.counter=(self.counter-1+delta)%#D.counter_names+1;self:clear_dummy()
 elseif key=="counter_command" then self.counter_command=(self.counter_command-1+delta)%#D.commands+1;self:clear_dummy()
 elseif key=="counter_switch" then self.counter_switch=not self.counter_switch;self:clear_dummy()
 elseif key=="counter_delay" then self.counter_delay=U.clamp(self.counter_delay+delta,0,60)
 elseif key=="hud_alpha" then self.hud_alpha=U.clamp(self.hud_alpha+delta*16,0,255)
 elseif key=="hud_x" or key=="hud_y" then self[key]=U.clamp(self[key]+delta*2,-48,48)
 elseif key=="input_history_rows" then self[key]=U.clamp(self[key]+delta,1,12)
 elseif key=="return_select" then if self.return_select then self.menu=false;self.return_select() end
 elseif key=="none" then return
 elseif key=='rec_record'then
  self.transport=self.transport or Transport.new(self.recorder);self.transport:arm();self:clear_dummy()
 elseif key=='rec_play'or key=='rec_stop'or key=='rec_clear'then
  if self.transport then self.transport:stop()end
  self.recorder:change(key,delta);self:clear_dummy()
 elseif key:match("^rec_") then self.recorder:change(key,delta)
 else self[key]=not self[key];if key=="training_mode" then self:clear_dummy() end end
end
function C:toggle_menu()
 self.menu=not self.menu;self:clear_dummy()
 if self.menu then self.row=0;if self.transport then self.transport:stop()elseif self.recorder then self.recorder:stop()end
 else self.close_release=true end
end
function C:before(frame)
 local keys=self.api.joypad.get();local previous=self.previous
 self.physical_keys=U.copy(keys)
 local function edge(name) return keys[name] and not previous[name] end
 self.previous=U.copy(keys)
 if frame and edge('P1 Start')then self:toggle_menu()end
 if self.menu then
  if edge("P1 Button C") then self:change_tab(-1) end
  if edge("P1 Button D") then self:change_tab(1) end
  if edge("P1 Up") then self.row=(self.row-1)%(#self:items()+1) end
  if edge("P1 Down") then self.row=(self.row+1)%(#self:items()+1) end
  if edge("P1 Left") then self:change(-1) end
  if edge("P1 Right") or edge("P1 Button A") then self:change(1) end
  if edge("P1 Button B") then self.menu=false;self.close_release=true end
  for k,v in pairs(keys) do if type(v)=="boolean" and (k:match("^P1 ") or k:match("^P2 ")) then keys[k]=false end end
  self.last_keys=U.copy(keys);self.api.joypad.set(keys);return
 end
 if frame and self.recorder then
  self.transport=self.transport or Transport.new(self.recorder)
  self.transport:update(frame.engine,edge('P1 Coin'))
  if self.transport.changed then self.close_release=true;self:clear_dummy()end
 end
 -- Coin is a training command in battle, never an extra credit or clip input.
 if frame then keys['P1 Coin']=false;keys['P2 Coin']=false end
 if self.close_release then
  local held=false
  for k,v in pairs(keys)do if k:match('^P1 ')and v==true then held=true end end
  for k,v in pairs(keys)do if type(v)=='boolean'and(k:match('^P1 ')or k:match('^P2 '))then keys[k]=false end end
  if not held then self.close_release=false end
  self.last_keys=U.copy(keys);self.api.joypad.set(keys);return
 end
 if not frame then
  if self.training_mode then D.apply(keys,'P2',{direction='5',buttons={}},1);self.api.joypad.set(keys)end
  self.last_keys=U.copy(keys);return
 end
 if self.transport and self.transport:owns_dummy()then
  if self.transport.state=='recording'then keys=self.recorder:before(frame,keys)
  else keys=self.recorder:drive_dummy(keys)end
  self.playback_active=true;self.last_keys=U.copy(keys);self.api.joypad.set(keys);return
 end
 if self.training_mode then
  local options={guard=self.guard,counter=self.counter,counter_command=self.counter_command,counter_delay=self.counter_delay,counter_switch=self.counter_switch}
  if self.retaliation then options.guard=10 end -- Previous API compatibility.
  D.apply(keys,"P2",self.dummy:request(frame,options),frame.players[2].facing)
 end
 local active=false
 if self.recorder then keys,active=self.recorder:before(frame,keys) end
 self.playback_active=active
 self.last_keys=U.copy(keys)
 if self.training_mode or active or self.physical_keys['P1 Coin']then self.api.joypad.set(keys)end
end
function C:after(frame)
 local p,q=frame.players[1],frame.players[2]
 local options={guard=self.retaliation and 10 or self.guard,counter=self.counter,counter_command=self.counter_command,counter_delay=self.counter_delay,counter_switch=self.counter_switch}
 if self.training_mode then self.dummy:after(frame,options) end
 self.release=self.dummy.switched;self.contact=self.dummy.contact;self.quiet=self.dummy.quiet
 -- Resource maintenance occurs only after the observer sampled, after 60 quiet
 -- frames. The app receives an explicit marker so refill cannot be read as damage.
 if self.training_mode and self.quiet>=60 and not self.menu and not self.playback_active then
  if self.refill_hp and (p.hp<256 or q.hp<256) then
   self.api.memory.writeword(p.address+0x17e,256);self.api.memory.writeword(q.address+0x17e,256)
   frame.resource_refill=true
  end
  if self.refill_meter and (p.meter<128 or q.meter<128) then
   self.api.memory.writebyte(p.address+0x17d,128);self.api.memory.writebyte(q.address+0x17d,128)
   frame.resource_refill=true
  end
 end
end
function C:reset()
 self:clear_dummy();self.quiet=0;self.previous={};self.start_hold=0;self.playback_active=false;self.last_keys=nil;self.physical_keys=nil;self.close_release=false
 if self.transport then self.transport:stop()elseif self.recorder then self.recorder:stop()end
end
function C:hotkeys(reset,return_select)
 self.return_select=return_select
 local input=self.api.input;if not input or not input.registerhotkey then return end
 input.registerhotkey(1,function() self:clear_dummy();if self.recorder then self.recorder:stop() end;if self.return_select then self.return_select() end end)
 input.registerhotkey(2,function() self:toggle_menu() end)
 input.registerhotkey(3,function() self.show_boxes=not self.show_boxes end)
 input.registerhotkey(4,function() self.show_hud=not self.show_hud end)
 input.registerhotkey(5,reset)
end
return C
