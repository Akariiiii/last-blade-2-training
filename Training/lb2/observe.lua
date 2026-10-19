-- Pure bounded state machine. No emulator API, memory writes, disk I/O or predictions.
local U=require("lb2.util")
local O={};O.__index=O
function O.new() return setmetatable({current={},last={},history={{},{}},previous=nil,limit=600},O) end
function O:reset() self.current={};self.last={};self.history={{},{}};self.previous=nil end
local function active(frame,actor,owner)
  for _,b in ipairs(frame.boxes) do
    if b.kind=="attack" and (owner and b.owner==actor or not owner and b.actor==actor) then return true end
  end
  return false
end
local function advances(p,prev)
  return not (prev and prev.hitpause~=0 and (p.hitpause~=0 or p.progress==prev.progress))
end
local function new_attempt(frame,index,entry,previous)
  local a,d=frame.players[index],frame.players[3-index]
  return {actor=a.address,target=d.address,character=a.character,script=entry.script,start=frame.engine,
    elapsed=0,source_ticks=0,active_frames=0,body_active=0,projectile_active=0,contacts={},timeline={},
    damage=0,chip=0,stun=0,stun_operand=0,meter_gain=0,meter_spent=0,
    initial_meter=previous and previous.players[index].meter or a.meter,
    outcome="whiff",status="measuring",guard_policy=frame.guard_policy or "manual",
    ground_only=a.height==0,has_landed=false,last_height=a.height}
end
function O:finish(index,status)
  local a=self.current[index];if not a then return end
  a.status=status or "complete"
  if status==nil or status=="complete" then
    if a.contact and a.attacker_ready and a.defender_ready and not a.interrupted and not a.defender_acted then a.advantage=a.defender_ready-a.attacker_ready end
    if a.first_active and a.attacker_ready and a.last_active<a.attacker_ready and not a.interrupted then
      a.recovery=a.ready_source_ticks-(a.last_active_tick or a.ready_source_ticks)
    end
    if a.first_active then
      if a.contact and a.contact<a.first_active then a.startup_bound=a.contact-a.start
      else a.startup=a.first_active_tick end
    elseif a.contact then a.startup_bound=a.contact-a.start end
  end
  self.last[index]=a;self.current[index]=nil
end
function O:update(frame,events)
  frame.contacts={} -- Resolved contacts for the input-only dummy policy.
  if self.previous and (frame.engine~=self.previous.engine+1 or
      frame.players[1].address~=self.previous.players[1].address or frame.players[2].address~=self.previous.players[2].address or
      frame.players[1].character~=self.previous.players[1].character or frame.players[2].character~=self.previous.players[2].character or
      frame.players[1].mode~=self.previous.players[1].mode or frame.players[2].mode~=self.previous.players[2].mode) then self:reset() end
  local previous=self.previous
  for i,p in ipairs(frame.players) do
    local prev=previous and previous.players[i]
    -- Fresh native initializer, not a retained script ID, identifies entry.
    local entry
    for _,e in ipairs(events.entries or {}) do if e.actor==p.address then entry=e;break end end
    if entry then
      if self.current[i] then self:finish(i,"superseded / cancel") end
      self.current[i]=new_attempt(frame,i,entry,previous)
    end
    local a=self.current[i];local d=frame.players[3-i];local old_d=previous and previous.players[3-i]
    if a then
      a.elapsed=frame.engine-a.start
      local tick_advances=advances(p,prev)
      local body=active(frame,p.address,false);local owned=active(frame,p.address,true)
      local projectile=false
      for _,box in ipairs(frame.boxes) do if box.kind=="attack" and box.owner==p.address and box.actor~=p.address then projectile=true;break end end
      if body or projectile then
        if not a.first_active then a.first_active=frame.engine;a.first_active_tick=a.source_ticks end
        a.last_active=frame.engine
        if body and tick_advances then a.body_active=a.body_active+1 end
        if projectile then a.projectile_active=a.projectile_active+1 end
        if body and tick_advances or projectile then a.active_frames=a.active_frames+1 end
        a.last_active_tick=a.source_ticks
      end
      local loss=old_d and math.max(0,old_d.hp-d.hp) or 0
      local guard_entry=d.guard and old_d and (not old_d.guard or
        (old_d.control~=2 and d.control==2) or d.script~=old_d.script)
      local overlap=false
      for _,e in ipairs(events.overlaps or {}) do if e.owner==p.address and e.target==d.address then overlap=true;break end end
      local grab=false
      for _,e in ipairs(events.grabs or {}) do if e.source==p.address and e.target==d.address then grab=true;a.grab_frame=frame.engine end end
      -- Overlap alone may be clash/invulnerability. It never commits a contact.
      local contact=loss>0 or (guard_entry and overlap) or grab
      if contact then
        local kind=(grab or a.grab_frame) and "grab" or d.guard and "block" or "hit"
        if a.contact and a.defender_ready then a.inter_hit_ready=true end
        a.contact=a.contact or frame.engine;a.last_contact=frame.engine;a.defender_ready=nil
        a.outcome=a.outcome=="whiff" and kind or a.outcome==kind and kind or "mixed"
        if kind=="block" then a.chip=a.chip+loss else a.damage=a.damage+loss end
        U.push(a.contacts,{frame=frame.engine-a.start,damage=loss,kind=kind,stun=0},64)
        frame.contacts[#frame.contacts+1]={source=p.address,target=d.address,kind=kind}
      end
      -- Confirm the scoped standing deflect from BOTH native reactions. D input,
      -- zero chip or the guard predicate alone cannot establish success.
      local deflected=(d.state==0x125 or d.state==0x126) and (p.state==0x52 or p.state==0x53)
      local last=a.contacts[#a.contacts]
      if deflected and last and last.kind=="block" and last.damage==0 and a.chip==0 then
        last.kind="deflect";a.outcome=#a.contacts==1 and "deflect" or "mixed";a.deflect_confirmed=true
        local resolved=frame.contacts[#frame.contacts]
        if resolved and resolved.source==p.address then resolved.kind="deflect" end
      end
      for _,e in ipairs(events.stuns or {}) do
        if e.target==d.address then
          a.stun=a.stun+e.loss;a.stun_operand=a.stun_operand+e.operand
          local last=a.contacts[#a.contacts];if last and last.frame==frame.engine-a.start then last.stun=last.stun+e.loss end
        end
      end
      if prev then
        local gain=p.meter-prev.meter
        if gain>0 then a.meter_gain=a.meter_gain+gain else a.meter_spent=a.meter_spent-gain end
        if p.hp<prev.hp then a.interrupted=true;a.advantage=nil end
      end
      if a.last_height>0 and p.height==0 then a.landing_frame=frame.engine;a.has_landed=true end
      a.last_height=p.height
      if p.ready and frame.engine>a.start and not a.attacker_ready then a.attacker_ready=frame.engine;a.ready_source_ticks=a.source_ticks end
      if a.last_contact and frame.engine>a.last_contact and d.ready and not a.defender_ready then a.defender_ready=frame.engine end
      if a.last_contact and not a.defender_ready then
        for _,e in ipairs(events.entries or {}) do
          if e.actor==d.address then a.defender_acted=true;a.defender_admission=a.defender_admission or frame.engine end
        end
      end
      local phase=a.interrupted and "interrupted" or p.hitpause~=0 and "freeze" or body and "active" or projectile and "projectile" or p.ready and "ready" or a.first_active and "recovery" or "startup"
      U.push(a.timeline,{phase=phase,contact=contact,engine=frame.engine},self.limit)
      if tick_advances then a.source_ticks=a.source_ticks+1 end
      if a.attacker_ready and not owned and (not a.contact or a.defender_ready) then
        self:finish(i)
      elseif a.elapsed>=self.limit then self:finish(i,"limit reached") end
    end
  end
  self.previous=frame
end
return O
