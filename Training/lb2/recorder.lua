-- Bounded input transport. No emulator callbacks, game RAM access or file I/O.
local R={};R.__index=R
local modes={"once","repeat","random","ordered","repeat_ordered"}
local labels={once="Once",["repeat"]="Repeat slot",random="Random slots",ordered="Ordered once",repeat_ordered="Repeat ordered"}
local function copy(t) if type(t)~="table" then return t end;local r={};for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end;return r end
local function integer(v,lo,hi) return type(v)=="number" and v==math.floor(v) and v>=lo and v<=hi end
local function neutral(release) return {direction="5",buttons="",start=false,up=false,down=false,back=false,forward=false,active=true,release=release or false} end
local function direction(v)
  local x=(v.forward and 1 or 0)-(v.back and 1 or 0)
  local y=(v.up and 1 or 0)-(v.down and 1 or 0)
  return tostring(5+x+3*y)
end
local function normalize(input,facing)
  input=input or {};local v={up=not not input.up,down=not not input.down,start=not not input.start}
  if input.direction then
    local d=tostring(input.direction)
    assert(d:match("^[1-9]$"),"Direction must be facing-relative numpad1..9")
    v.up=d=="7" or d=="8" or d=="9";v.down=d=="1" or d=="2" or d=="3"
    v.back=d=="1" or d=="4" or d=="7";v.forward=d=="3" or d=="6" or d=="9"
  else
    v.back=not not (facing==1 and input.left or facing~=1 and input.right)
    v.forward=not not (facing==1 and input.right or facing~=1 and input.left)
  end
  local buttons=input.buttons or "";local text=""
  for _,button in ipairs({"A","B","C","D"}) do
    local held=type(buttons)=="table" and buttons[button] or type(buttons)=="string" and buttons:find(button,1,true)
    if held then text=text..button end
  end
  v.buttons=text;return v
end
local function output(frame,slot,pos)
  local r=copy(frame);r.direction=direction(r);r.active=true;r.release=false;r.slot=slot;r.frame=pos;return r
end
local function physical(keys,prefix)
  local v={buttons={},start=not not keys[prefix.." Start"]}
  for _,d in ipairs({"Up","Down","Left","Right"}) do v[d:lower()]=not not keys[prefix.." "..d] end
  for _,b in ipairs({"A","B","C","D"}) do v.buttons[b]=not not keys[prefix.." Button "..b] end
  return v
end
function R.new(options)
  options=options or {};local max=options.max_frames or 3600
  assert(integer(max,1,3600),"Recorder maximum must be1..3600 frames")
  local self=setmetatable({slots={},selected=1,mode="once",max_frames=max,rng=options.rng or math.random,
    gap_frames=1,recording=false,playing=false,release_pending=false,owned=false,last_error=nil},R)
  for i=1,8 do self.slots[i]={frames={},enabled=true,weight=1} end
  return self
end
function R:_invalidate() self.last_engine=nil;self.last_output=nil end
function R:_slot(slot) assert(integer(slot,1,8),"Slot must be1..8");return self.slots[slot] end
function R:stop()
  if self.playing or self.owned then self.release_pending=true end
  self.playing=false;self.recording=false;self.current_slot=nil;self.frame_pos=nil;self.gap_left=0
  self.record_dummy=false
  self:_invalidate();return true
end
function R:reset() self:stop() end -- Savestate/match reset preserves slots, releases transport.
function R:clear(slot)
  local s=self:_slot(slot)
  if self.recording_slot==slot or self.playing then self:stop() end
  s.frames={};self:_invalidate();return true
end
function R:start_record(slot,as_dummy)
  slot=slot or self.selected;self:_slot(slot);self:stop();self.selected=slot
  self.slots[slot].frames={};self.recording=true;self.recording_slot=slot;self.last_error=nil
  self.record_dummy=not not as_dummy
  return true
end
function R:_pick_random(list)
  local total=0;for _,slot in ipairs(list) do total=total+self.slots[slot].weight end
  local ok,pick=pcall(self.rng,total)
  if not ok or not integer(pick,1,total) then return nil,"Random source returned an invalid index" end
  for _,slot in ipairs(list) do pick=pick-self.slots[slot].weight;if pick<=0 then return slot end end
end
function R:start_playback(options)
  options=options or {};local mode=options.mode or self.mode
  local valid=false;for _,v in ipairs(modes) do if mode==v then valid=true end end
  if not valid then return false,"Unknown playback mode" end
  local list,seen={},{}
  local requested=options.slots
  if not requested then
    requested={}
    if mode=="once" or mode=="repeat" then requested[1]=options.slot or self.selected
    else for i=1,8 do if self.slots[i].enabled then requested[#requested+1]=i end end end
  end
  for _,slot in ipairs(requested) do
    if not integer(slot,1,8) then return false,"Slot must be1..8" end
    if not seen[slot] and #self.slots[slot].frames>0 then list[#list+1]=slot;seen[slot]=true end
  end
  if #list==0 then return false,"Selected slots are empty" end
  local gap=options.gap_frames
  if gap==nil then gap=self.gap_frames end
  if not integer(gap,0,600) then return false,"Playback gap must be0..600" end
  local first=list[1]
  if mode=="random" then
    local message;first,message=self:_pick_random(list);if not first then return false,message end
  end
  self:stop();self.playing=true;self.last_error=nil
  self.play_mode=mode;self.play_slots=list;self.order_pos=1;self.current_slot=first;self.frame_pos=1
  self.play_gap=gap;self.gap_left=0;return true
end
function R:_next()
  local mode=self.play_mode
  if mode=="once" then self.playing=false;self.release_pending=true;return end
  if mode=="ordered" or mode=="repeat_ordered" then
    self.order_pos=self.order_pos+1
    if self.order_pos>#self.play_slots then
      if mode=="ordered" then self.playing=false;self.release_pending=true;return end
      self.order_pos=1
    end
    self.current_slot=self.play_slots[self.order_pos]
  elseif mode=="random" then
    local slot,message=self:_pick_random(self.play_slots)
    if not slot then self.last_error=message;self.playing=false;self.release_pending=true;return end
    self.current_slot=slot
  end
  self.frame_pos=1;self.gap_left=self.play_gap
end
function R:tick(context)
  context=context or {}
  if context.engine~=nil and context.engine==self.last_engine then return copy(self.last_output) end
  local result
  if self.recording then
    local slot=self.slots[self.recording_slot]
    slot.frames[#slot.frames+1]=normalize(context.physical_p1 or context.input,context.p1_facing or 1)
    if #slot.frames>=self.max_frames then self.recording=false;self.last_error="Recording reached frame limit" end
  end
  if self.release_pending then
    self.release_pending=false;self.owned=false;result=neutral(true)
  elseif self.playing then
    if self.gap_left>0 then self.gap_left=self.gap_left-1;result=neutral(false)
    else
      local slot=self.slots[self.current_slot]
      if self.frame_pos>#slot.frames then self:_next() end
      if not self.playing then self.release_pending=false;self.owned=false;result=neutral(true)
      elseif self.gap_left>0 then self.gap_left=self.gap_left-1;result=neutral(false)
      else
        result=output(self.slots[self.current_slot].frames[self.frame_pos],self.current_slot,self.frame_pos)
        self.frame_pos=self.frame_pos+1;self.owned=true
      end
    end
  end
  self.last_engine=context.engine;self.last_output=copy(result);return result
end
--3S-style waiting/recording: physical P1 controls P2 in absolute directions;
-- the recorded inputs are normalized against P2's actual facing. P1 is neutral.
function R:drive_dummy(keys)
  local raw=physical(keys,'P1');local values={}
  for _,d in ipairs({'Up','Down','Left','Right'})do values[d]=raw[d:lower()]end
  for _,b in ipairs({'A','B','C','D'})do values['Button '..b]=raw.buttons[b]end
  for _,prefix in ipairs({'P1','P2'})do
    for _,name in ipairs({'Up','Down','Left','Right','Button A','Button B','Button C','Button D','Start','Coin'})do keys[prefix..' '..name]=false end
  end
  for name,v in pairs(values)do keys['P2 '..name]=v end
  self.owned=true;return keys,true
end
-- Playback owns P2; legacy start_record(slot) still samples P1 without swapping.
function R:before(frame,keys)
  if not frame or not frame.players then self:stop() end
  local p=frame and frame.players[1];local q=frame and frame.players[2]
  local dummy=self.recording and self.record_dummy
  local raw=physical(keys,'P1');if dummy then raw.start=false end
  local request=self:tick({engine=frame and frame.engine,physical_p1=raw,p1_facing=dummy and q and q.facing or p and p.facing or 1})
  if dummy then return self:drive_dummy(keys)end
  if not request then return keys,false end
  local forward=q and q.facing==1 and "Right" or "Left";local back=forward=="Right" and "Left" or "Right"
  keys['P2 Up']=request.up;keys['P2 Down']=request.down
  keys['P2 '..back]=request.back;keys['P2 '..forward]=request.forward
  for _,b in ipairs({"A","B","C","D"}) do keys['P2 Button '..b]=not not request.buttons:find(b,1,true) end
  keys['P2 Start']=request.start;return keys,true,request
end
function R:export_slot(slot)
  local s=self:_slot(slot);return {schema_version=1,frames=copy(s.frames)}
end
function R:import_slot(slot,data)
  self:_slot(slot)
  if type(data)~="table" or data.schema_version~=1 or type(data.frames)~="table" or #data.frames>self.max_frames then return false,"Invalid/beyond-limit slot" end
  local count=0
  for key in pairs(data.frames) do if not integer(key,1,#data.frames) then return false,"Frames must be a dense array" end;count=count+1 end
  if count~=#data.frames then return false,"Frames must be a dense array" end
  local frames={}
  for i,v in ipairs(data.frames) do
    if type(v)~="table" or type(v.buttons)~="string" or #v.buttons>4 or not v.buttons:match("^[ABCD]*$") then return false,"Invalid input frame" end
    for _,key in ipairs({"up","down","back","forward","start"}) do if type(v[key])~="boolean" then return false,"Invalid direction/start bit" end end
    frames[i]={buttons=v.buttons,up=v.up,down=v.down,back=v.back,forward=v.forward,start=v.start}
  end
  if self.playing or self.recording_slot==slot then self:stop() end
  self.slots[slot].frames=frames;self:_invalidate();return true
end
function R:items()
  local slot=self.slots[self.selected]
  return {{"Slot",self.selected.." / 8 ("..#slot.frames.."f)","rec_slot"},
    {"Enable slot",slot.enabled and "On" or "Off","rec_enable"},{"Random weight",tostring(slot.weight),"rec_weight"},
    {"Playback",labels[self.mode],"rec_mode"},{"Gap between clips",self.gap_frames.."f","rec_gap"},
    {"Record dummy",self.recording and "Recording" or "A to arm / Coin x2","rec_record"},
    {"Play to P2",self.playing and "Playing" or "A to start","rec_play"},
    {"Stop / release","A","rec_stop"},{"Clear selected slot","A","rec_clear"}}
end
function R:change(key,delta)
  delta=delta or 1;self.last_error=nil
  if key=="rec_slot" then self.selected=(self.selected-1+delta)%8+1
  elseif key=="rec_enable" then local s=self.slots[self.selected];s.enabled=not s.enabled
  elseif key=="rec_weight" then local s=self.slots[self.selected];s.weight=math.max(1,math.min(100,s.weight+delta))
  elseif key=="rec_mode" then local pos=1;for i,v in ipairs(modes) do if self.mode==v then pos=i end end;self.mode=modes[(pos-1+delta)%#modes+1]
  elseif key=="rec_gap" then self.gap_frames=math.max(0,math.min(600,self.gap_frames+delta))
  elseif key=="rec_record" then return self:start_record(self.selected)
  elseif key=="rec_play" then local ok,message=self:start_playback();self.last_error=message;return ok,message
  elseif key=="rec_stop" then return self:stop()
  elseif key=="rec_clear" then return self:clear(self.selected)
  else return false,"Unknown recorder setting" end
  return true
end
return R
