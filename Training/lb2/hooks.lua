local U,P=require("lb2.util"),require("lb2.profile")
local H={};H.__index=H
function H.new(game,api)
  return setmetatable({game=game,m=api.memory,emu=api.emu,installed={},pending={},stun={},recent_entries={},stats={rectangles=0,overlaps=0,grabs=0,stuns=0,entries=0,responses=0,dropped=0}},H)
end
function H:event(kind,data)
  local engine=self.emu.framecount()
  if self.pending.engine~=engine then self.pending={engine=engine,boxes={},entries={},overlaps={},grabs={},stuns={}} end
  local list=self.pending[kind]
  if #list>=192 then self.stats.dropped=self.stats.dropped+1;return end
  list[#list+1]=data
end
function H:players()
  local p=self.m.readdword(P.ram.p1);local q=self.m.readdword(P.ram.p2)
  if self.m.readbyte(P.ram.phase)==0 and U.valid(p) and U.valid(q) and p~=q then return p,q end
end
function H:reg(name) return self.m.getregister("m68000."..name) end
function H:install(width)
  local function hook(label,callback)
    local address=P.hooks[label]
    self.m.registerexec(address,callback);self.installed[#self.installed+1]=address
  end
  hook("entry",function()
    local p,q=self:players();if not p then return end
    local a=self:reg("a4");local script=self:reg("d1")%512
    if (a==p or a==q) and script>=0x30 and script<0x100 then
      local stack=self:reg("a7");local caller=stack>=0x100000 and stack<=0x10fffc and self.m.readdword(stack) or 0
      local control=self.m.readbyte(a+0x152);local input=self.m.readword(a+0x150)
      -- 037DB0 and other collision-response callers initialize scripts too,
      -- including weapon rebound82. Guard-switch48 is a response, not an attack.
      local response=(caller>=0x37000 and caller<0x40000) or
        (control==5 and (script==0x47 or script==0x48))
      local e={actor=a,script=script,caller=caller,old_control=control,input=input,response=response,engine=self.emu.framecount()}
      U.push(self.recent_entries,e,32)
      if response then self.stats.responses=self.stats.responses+1;return end
      self:event("entries",e);self.stats.entries=self.stats.entries+1
    end
  end)
  hook("rectangle",function()
    local p,q=self:players();if not p then return end
    local a,slot,rect=self:reg("a0"),self:reg("a1"),self:reg("a2")
    if not U.valid(a) or slot<a+0x100 or slot>a+0x146 or (slot-a-0x100)%10~=0 or not U.valid(rect) then return end
    local root=self.game:root(a,p,q);if not root then return end
    local profile=self.m.readbyte(slot);if profile==0 then return end
    local flags=self.game:flags(self.m.readword(a+0x60),profile);if not flags then return end
    local l,r,t,b=self.m.readword(rect),self.m.readword(rect+2),self.m.readword(rect+4),self.m.readword(rect+6)
    if l==r or t==b then return end
    local transform=self.game:transform(a,width())
    local x1,y1=self.game.point(l,-U.s16(t),transform);local x2,y2=self.game.point(r,-U.s16(b),transform)
    self:event("boxes",{actor=a,owner=root,slot=slot,profile=profile,native=true,
      kind=U.bit(flags,1) and "hurt" or "attack",left=math.min(x1,x2),right=math.max(x1,x2),top=math.min(y1,y2),bottom=math.max(y1,y2)})
    self.stats.rectangles=self.stats.rectangles+1
  end)
  hook("overlap",function()
    local p,q=self:players();if not p then return end
    local source,target,workspace=self:reg("a0"),self:reg("a2"),self:reg("a4")
    if not U.valid(source) or not U.valid(target) or not U.valid(workspace) then return end
    local owner=self.game:root(source,p,q);if not owner then return end
    self:event("overlaps",{source=source,owner=owner,target=target,response=self.m.readword(workspace+0xf6)})
    self.stats.overlaps=self.stats.overlaps+1
  end)
  hook("grab",function()
    local p,q=self:players();if not p then return end
    local source=self:reg("a4");if source~=p and source~=q then return end
    local target=self.m.readdword(source+0x174);if target~=p and target~=q then return end
    if self:reg("d2")%65536==1 then
      self:event("grabs",{source=source,target=target,script=self:reg("d0")%65536});self.stats.grabs=self.stats.grabs+1
    end
  end)
  hook("stun_pre",function()
    local p,q=self:players();if not p then return end
    local a,d=self:reg("a0"),self:reg("a2");if d~=p and d~=q then return end
    local key=tostring(self:reg("a7"))..":"..a..":"..d
    self.stun[key]={source=a,target=d,before=self.m.readbyte(d+0x188),operand=self:reg("d0")%256}
  end)
  hook("stun_post",function()
    local a,d=self:reg("a0"),self:reg("a2");local key=tostring(self:reg("a7"))..":"..a..":"..d
    local e=self.stun[key];if not e then return end
    self.stun[key]=nil;e.after=self.m.readbyte(d+0x188);e.loss=math.max(0,e.before-e.after)
    self:event("stuns",e);self.stats.stuns=self.stats.stuns+1
  end)
end
function H:take(engine)
  local data=self.pending
  self.pending={}
  if data.engine~=engine then return {boxes={},entries={},overlaps={},grabs={},stuns={}} end
  return data
end
function H:reset() self.pending={};self.stun={} end
function H:stop()
  for _,address in ipairs(self.installed) do self.m.registerexec(address,nil) end
  self.installed={};self:reset()
end
return H
