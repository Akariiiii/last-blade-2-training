local U,P,I=require("lb2.util"),require("lb2.profile"),require("lb2.input_display")
local Draw=require('lb2.draw')
local D={};D.__index=D
local color={attack=0xff655aff,hurt=0x60db9aff,push=0x62bfffff,unknown=0xf7cd72ff,
  startup=0xffce6aff,active=0xff655aff,projectile=0xd59bffff,recovery=0x78aaffff,
  ready=0x60db9aff,freeze=0xb8b8b8ff,interrupted=0x815761ff}
function D.new(gui) return setmetatable({gui=gui,alpha=80},D) end
function D:text(x,y,text,c) self.gui.text(x,y,tostring(text),c or 0xffffffff,self.alpha) end
function D:panel(x,y,w,h) self.gui.box(x,y,x+w,y+h,0x08121a8c,0x8aa5bb66) end
function D:warning(message,width)
  self.alpha=176;self:panel(4,38,width-9,32);self:text(8,41,"LAST BLADE 2 LIVE TRAINING",0xffce6aff)
  self:text(8,53,message,0xff897aff)
end
local function short(text,n)
  text=tostring(text or "")
  return #text>n and text:sub(1,n-1).."~" or text
end
function D:menu(control,width)
  local x=math.floor((width-300)/2);local old_alpha=self.alpha;self.alpha=0x00000000
  self.gui.box(x,35,x+300,202,0x08121af0,0x8aa5bbcc)
  self:text(x+7,40,"LAST BLADE 2 TRAINING  "..P.revision,0xf7cd72ff)
  local tabs=control.tabs and control:tabs() or {"Settings"};local tab=control.tab or 1
  -- A fixed tab width keeps the menu inside the 320px native framebuffer.
  local tw=math.floor(286/#tabs)
  for n,t in ipairs(tabs) do
    local label=type(t)=="table" and (t.label or t[1]) or t
    if n==tab then self.gui.box(x+7+(n-1)*tw,52,x+6+n*tw,63,0x466077b0,control.row==0 and 0xffe280ff or 0x8aa5bbcc) end
    self:text(x+10+(n-1)*tw,54,short(label,math.floor(tw/4)-1),n==tab and 0xffe280ff or 0xa9bfceff)
  end
  local items=control:items();local row=U.clamp(control.row or 0,0,math.max(1,#items))
  local visible=10;local first=math.max(1,row-visible+1);first=math.min(first,math.max(1,#items-visible+1))
  for n=first,math.min(#items,first+visible-1) do
    local item=items[n];local y=69+(n-first)*11;local selected=n==row
    if selected then self.gui.box(x+5,y-1,x+294,y+8,0x40536a90,0x40536a00) end
    local c=selected and 0xffe280ff or 0xd9e2eaff
    self:text(x+8,y,(selected and "> " or "  ")..short(item.label or item[1],39),c)
    self:text(x+183,y,short(item.value or item[2],26),c)
  end
  if #items>visible then self:text(x+256,181,string.format("%d/%d",row,#items),0xa9bfceff) end
  self:text(x+7,181,row==0 and "TAB: Left/Right/A change | Down options" or "Up to tabs | Left/Right/A change | B close",0xa9bfceff)
  local error=control.recorder and control.recorder.last_error
  self:text(x+7,191,error and short(error,70) or "B close   Alt+1 select   Alt+2 menu   Alt+3 boxes",error and 0xff897aff or 0xa9bfceff)
  self.alpha=old_alpha
end
function D:stun_bar(p,index,width)
  local w=96;local x=index==1 and 14 or width-14-w;local y=29
  local capacity=math.max(1,p.stun_capacity or 1)
  local stage=p.stun_stage or ((p.stun_prime or 0)>0 and 'primed'or 'normal')
  local used=stage~='normal'and capacity or U.clamp(capacity-(p.stun or capacity),0,capacity)
  local filled=math.floor(used/capacity*(w-2))
  self.gui.box(x,y,x+w-1,y+3,0x121720c0,0xb5c4d0cc)
  if filled>0 then
    local c=stage=='dizzy'and 0xff655aff or stage=='primed'and 0xffa040ff or used/capacity>=0.8 and 0xff655aff or 0xffce6aff
    -- Symmetric bars fill from the outside toward the center.
    local left=index==1 and x+1 or x+w-1-filled
    self.gui.box(left,y+1,left+filled-1,y+2,c,c)
  end
  local label=stage=='dizzy'and 'STUN: DIZZY'or stage=='primed'and 'STUN: PRIMED'or string.format("STUN %d/%d",used,capacity)
  self:text(x+2,y+5,label,stage=='dizzy'and 0xff655aff or 0xffce6aff)
end
local function start_text(m)
  local bound=m.startup_bound or m.contact and m.first_active and m.contact<m.first_active and m.contact-m.start
  local startup=m.startup or m.first_active_tick
  return bound and "<="..bound.."f" or U.frames(startup)
end
function D:attempt(index,p,m,x,y,detail)
  local mode=({[0]="P",[1]="S",[3]="EX"})[p.mode] or "?"
  self:text(x,y,string.format("P%d %s %s",index,short(p.name,15),mode),0xf7cd72ff)
  if not m then self:text(x,y+10,"Perform a move");return end
  self:text(x,y+10,"Startup: "..start_text(m))
  -- Hit frame is an inclusive emulated-frame offset, not a source-tick startup.
  local hit=m.contact and tostring(m.contact-m.start+1).."e" or "--"
  self:text(x,y+20,"Hit frame: "..hit.."  "..short(m.outcome,6))
  if m.grab_frame then
    self:text(x,y+30,string.format("Grab gate: +%de",m.grab_frame-m.start),0xd5b8ffff)
  else
    local active=m.first_active and tostring(m.body_active).."b"..(m.projectile_active>0 and "/"..m.projectile_active.."o" or "") or "--"
    self:text(x,y+30,"Active: "..active.." Rec: "..U.frames(m.recovery))
  end
  local adv_color=m.advantage and (m.advantage>=0 and 0x60db9aff or 0xff897aff) or 0xc5d0dbff
  self:text(x,y+40,"Adv(ctrl): "..U.signed(m.advantage),adv_color)
  self:text(x,y+50,string.format("Damage: %d  Chip: %d",m.damage or 0,m.chip or 0))
  -- Remaining stun can refill on native borrow; its clamped delta would report
  -- zero for the very hit that primes dizziness. Display the selected operand.
  self:text(x,y+60,string.format("Stun: %d  Meter: +%d",m.stun_operand or m.stun or 0,m.meter_gain or 0))
  local note=m.interrupted and "Interrupted; no advantage" or m.defender_acted and "Defender acted; adv unknown" or (m.status=="complete" and "Complete / "..(m.guard_policy or "manual") or m.status)
  self:text(x,y+70,short(note,34),m.status=="complete" and 0x86dfafff or 0xffce6aff)
  if detail then
    local losses,gaps={},{}
    for n=math.max(1,#m.contacts-3),#m.contacts do
      local c=m.contacts[n];losses[#losses+1]=tostring(c.damage)
      if n>1 then gaps[#gaps+1]=tostring(c.frame-m.contacts[n-1].frame) end
    end
    self:text(x,y+80,"Hits: "..(#losses>0 and table.concat(losses,"+") or "--"),0xc5d0dbff)
    self:text(x,y+90,"Gaps(e): "..(#gaps>0 and table.concat(gaps,"/") or "--"),0xc5d0dbff)
  end
end
function D:draw(frame,observe,control,game,width,height,stats)
  self.alpha=U.clamp(control.hud_alpha or 80,0,255)
  if control.menu then self:menu(control,width);return end
  local gui=self.gui
  if control.show_boxes then
    Draw.boxes(gui,frame.boxes,width,height,color,control.box_fill)
  end
  local p,q=frame.players[1],frame.players[2]
  if control.show_distance then
    local y=U.clamp(math.max(p.gy,q.gy)-4,80,height-28)
    gui.line(p.gx,y,q.gx,y,0xf7cd72dd);gui.line(p.gx,y-3,p.gx,y+3,0xf7cd72ff);gui.line(q.gx,y-3,q.gx,y+3,0xf7cd72ff)
    self:text(U.clamp((p.gx+q.gx)/2-12,0,width-25),y-10,string.format("%du",math.abs(p.x-q.x)),0xf7cd72ff)
    local range=p.height==0 and q.height==0 and game:range(p,q,true) or nil
    if range then
      local sign=q.x>=p.x and 1 or -1
      local endpoint=p.gx+sign*range.limit*p.transform.sx/256
      for x=math.min(p.gx,endpoint),math.max(p.gx,endpoint),6 do
        gui.line(U.clamp(x,0,width-1),y-2,U.clamp(x+2,0,width-1),y-2,0xba97ffcc)
      end
      self:text(6,height-25,string.format("Grab ref %du | %s*",range.limit,range.within and "distance OK" or "out"),0xd5b8ffff)
    end
  end
  if control.training_mode and control.infinite_time and control.timer_supported then self:text(math.floor(width/2)-6,30,"INF",0xffce6aff)end
  if control.show_stun~=false then for i,a in ipairs(frame.players) do self:stun_bar(a,i,width) end end
  local dx,dy=control.hud_x or 0,control.hud_y or 0
  if control.show_hud then
    for i,a in ipairs(frame.players) do
      local x=U.clamp((i==1 and 6 or math.floor(width/2)+4)+dx,0,width-142)
      local y=U.clamp(46+dy,40,height-120)
      self:attempt(i,a,observe.current[i] or observe.last[i],x,y,control.hud_detail)
    end
  end
  if control.show_timeline then
    local top=height-45
    for i=1,2 do
      local m=observe.current[i] or observe.last[i]
      if m then
        local timeline=m.timeline;local count=math.min(#timeline,width-16)
        self:text(3,top-9+(i-1)*13,"P"..i,0xf7cd72ff)
        Draw.timeline(gui,timeline,count,12,top+(i-1)*8,color)
      end
    end
  end
  if control.show_inputs then
    local rows=control.input_history_rows or 6
    for i=1,2 do
      local x=U.clamp((i==1 and 4 or width-60)+dx,0,width-58)
      local y=U.clamp((control.hud_detail and 148 or 130)+dy,110,height-29-rows*9)
      I.draw(gui,observe.history[i],x,y,rows,self.alpha)
    end
  end
  local recorder=control.recorder
  local transport=recorder and (control.transport and control.transport.state=='waiting'and 'REC WAIT: P1 controls P2 | Coin: record'or
    recorder.recording and string.format("REC %d: %df | Coin: stop",recorder.recording_slot,#recorder.slots[recorder.recording_slot].frames) or
    recorder.playing and string.format("PLAY %d | Coin: stop",recorder.current_slot))
  self:text(5,height-12,transport or "Start: menu | Coin: play | Coin x2: record",transport and 0xffce6aff or 0xc5d0dbff)
  if stats and stats.dropped>0 then self:text(5,22,"Hook limit: measurements need review",0xff897aff) end
end
return D
