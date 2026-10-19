-- Input-only dummy policy. No actor state or outcomes are written here.
local D={};D.__index=D
D.guard_names={"None","Hold stand","Hold crouch","Release stand","Release crouch","Switch stand","Switch crouch","Random guard","Deflect D","Switch -> 4A"}
D.counter_names={"Off","After hit","After block","Hit / block","After wakeup"}
D.commands={"4A","5A","2A","5B","2B","5C","2C","D","2D","236A","623A","214A","Jump","5AB","5AC","5BC","5BCD","3B","6A","4B"}
function D.new(random)
 return setmetatable({random=random or math.random,quiet=0},D)
end
function D:reset()
 self.previous=nil;self.contact=nil;self.pending=nil;self.sequence=nil;self.switched=nil
 self.random_block=nil;self.random_crouch=nil;self.deflect_at=nil;self.quiet=0;self.counter_done=nil;self.was_down=nil
end
function D:interaction()
 self.contact=nil;self.switched=nil;self.pending=nil;self.sequence=nil;self.counter_done=nil
 self.deflect_at=nil
 self.random_block=self.random(2)==1;self.random_crouch=self.random(2)==1
end
function D:after(frame,options)
 local p,q=frame.players[1],frame.players[2];local prev=self.previous
 local admitted=false
 for _,e in ipairs(frame.entries or {}) do if e.actor==p.address then admitted=true end end
 if not self.contact and (admitted or (prev and prev.pready and not p.ready)) then self:interaction() end
 local hit,block=false,false
 if frame.contacts then
  for _,e in ipairs(frame.contacts)do
   if e.target==q.address then hit=hit or e.kind=='hit';block=block or e.kind=='block' end
  end
 else -- Adapter-only fallback for fixtures without an observer.
  hit=prev and q.hp<prev.hp and not q.guard
  block=q.guard and (not prev or not prev.guard or q.hp<prev.hp)
 end
 if hit or block then
  self.contact=frame.engine;self.switched=true
  self.sequence=nil;self.pending=nil;self.counter_done=nil
  local trigger=options.counter or 1
  if trigger==4 or (hit and trigger==2) or (block and (trigger==3 or options.guard==10)) then
   self.pending={at=frame.engine,kind=hit and "hit" or "block"}
  end
 end
 -- Wakeup is deliberately gated by a verified field supplied by the game adapter.
 -- Absence of knockdown classification must never turn ordinary recovery into wakeup.
 if q.knockdown then self.was_down=true end
 if self.was_down and not q.knockdown and q.ready then
  if options.counter==5 then self.pending={at=frame.engine,kind="wakeup"} end
  self.was_down=nil
 end
 if self.sequence then
  local steps=self.sequence.steps
  if steps and #steps==1 and steps[1].direction=='8'and q.height and q.height>0 then
   self.sequence=nil;self.pending=nil;self.counter_done=true
  end
  for _,e in ipairs(frame.entries or {}) do
   if e.actor==q.address then self.sequence=nil;self.pending=nil;self.counter_done=true end
  end
 end
 local quiet=p.ready and q.ready
 for _,box in ipairs(frame.boxes or {}) do if box.kind=="attack" then quiet=false;break end end
 self.quiet=quiet and self.quiet+1 or 0
 if self.quiet>=30 and not self.sequence and not self.pending then
  self.contact=nil;self.switched=nil;self.counter_done=nil;self.random_block=nil;self.random_crouch=nil;self.deflect_at=nil
 end
 self.previous={hp=q.hp,guard=q.guard,pready=p.ready}
end
local function command_sequence(command)
 if command=="Jump" then return {{direction="8",buttons={}}} end
 local direction,buttons=command:match("^(%d*)([ABCD]+)$")
 local sequence={};direction=direction~="" and direction or "5"
 for i=1,#direction do sequence[#sequence+1]={direction=direction:sub(i,i),buttons={}} end
 for b in buttons:gmatch(".") do sequence[#sequence].buttons[b]=true end
 return sequence
end
function D:request(frame,options)
 local p,q=frame.players[1],frame.players[2];local guard=options.guard or 1
 local d=(guard==3 or guard==5 or guard==7) and "1" or "4"
 if guard==1 then d="5" end
 if guard==8 then
  if self.random_block==nil then
    self.deflect_at=nil
    self.random_block=self.random(2)==1;self.random_crouch=self.random(2)==1
  end
  d=self.random_block and (self.random_crouch and "1" or "4") or "5"
 end
 if self.switched then
  if guard==4 or guard==5 then d="5" end
  if guard==6 or guard==7 or guard==10 then d=d=="1" and "4" or "1" end
 end
 local buttons={}
 if guard==9 then
  d="5"
  if not p.ready and not self.counter_done then
   self.deflect_at=self.deflect_at or frame.engine
   -- One held pulse per interaction, then release. Repeated D edges after a
   -- successful deflect can select its native follow-up without user consent.
   buttons.D=frame.engine-self.deflect_at<2
  end
 end
 -- Early switch admission is not the same as grounded control==1. Offer real
 -- edges until the native initializer confirms the response, then stop.
 -- A new resolved contact re-arms the attempt without a neutral-time cooldown.
 local pending=self.pending
 if pending and not pending.steps then
  pending.steps=command_sequence(guard==10 and '4A'or D.commands[options.counter_command or 1])
 end
 local switch=pending and pending.kind=='block'and
  (options.counter_switch or guard==6 or guard==7 or guard==10)
 if switch and guard~=6 and guard~=7 and guard~=10 then d=d=='1'and '4'or '1' end
 if pending and frame.engine-pending.at>180 then
  self.pending=nil;self.sequence=nil;self.counter_done=true;pending=nil
 end
 local eligible=pending and q.hitpause==0 and
  (pending.kind=='block'and #pending.steps==1 and (options.counter_delay or 0)==0 or q.ready)and
  (not switch or frame.engine>pending.at)
 if pending and not self.sequence and eligible then
  self.sequence={steps=pending.steps,finite=#pending.steps>1,
   block=pending.kind=='block',start=frame.engine+math.max(options.counter_delay or 0,pending.kind=='block'and 1 or 0)}
 end
 local seq=self.sequence
 if seq then
  local age=frame.engine-seq.start
  -- Apply the requested stance without an attack edge first. Otherwise a4A/5A
  -- edge on the crouch-switch frame can be admitted as2A by the native matcher.
  local prepare=seq.steps[1].direction
  if seq.block and prepare=='5'then prepare='4' end
  if age<0 then return {direction=prepare,buttons={}} end
  local step_frames=#seq.steps==1 and 1 or 2
  local cycle=#seq.steps*step_frames+1 -- Guaranteed release between retries.
  local index=math.floor((seq.finite and age or age%cycle)/step_frames)+1
  if index<=#seq.steps then return seq.steps[index] end
  -- Repeating236 creates623 between cycles and can select a DP instead.
  -- Motions therefore get one complete ready-gated attempt, then release.
  if seq.finite then
   self.sequence=nil;self.pending=nil;self.counter_done=true
   return {direction='5',buttons={}}
  end
  -- Keep the command stance on release. Returning to the switched guard every
  -- other tick would alternate stand/crouch and admit4A as2A.
  local release=seq.steps[#seq.steps].direction
  return {direction=release,buttons={}}
 end
 return {direction=d,buttons=buttons}
end
function D.apply(keys,prefix,request,facing)
 local d=request.direction or "5";local back=facing==1 and "Left" or "Right"
 local forward=facing==1 and "Right" or "Left"
 for _,name in ipairs({"Up","Down","Left","Right","Button A","Button B","Button C","Button D","Start","Coin"}) do keys[prefix.." "..name]=false end
 if d=="7" or d=="8" or d=="9" then keys[prefix.." Up"]=true end
 if d=="1" or d=="2" or d=="3" then keys[prefix.." Down"]=true end
 if d=="1" or d=="4" or d=="7" then keys[prefix.." "..back]=true end
 if d=="3" or d=="6" or d=="9" then keys[prefix.." "..forward]=true end
 for button,on in pairs(request.buttons or {}) do if on and button:match("^[ABCD]$") then keys[prefix.." Button "..button]=true end end
 return keys
end
return D
