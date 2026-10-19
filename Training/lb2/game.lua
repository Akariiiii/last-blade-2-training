local U,P=require("lb2.util"),require("lb2.profile")
local G={}; G.__index=G
function G.new(api) return setmetatable({m=api.memory,emu=api.emu,flag_cache={}},G) end
function G:compatible()
  local name=self.emu.romname and self.emu.romname() or ""
  if name~="lastbld2" then return false,"Load lastbld2 (current: "..name..")" end
  for _,sig in ipairs(P.signatures) do
    for i,word in ipairs(sig[2]) do
      if self.m.readword(sig[1]+2*(i-1))~=word then
        return false,string.format("Unsupported code at %06X; hooks disabled",sig[1])
      end
    end
  end
  return true,"Compatible instruction contracts; ROM variant unchecked"
end
function G:flags(character,profile)
  local key=(character%32)*256+profile
  if self.flag_cache[key] then return self.flag_cache[key] end
  local flags=self.m.readword(0x70270+2*profile)
  if U.bit(flags,0x100) then
    local ptr=self.m.readdword(0x701f0+(character%32)*4)
    if ptr<0 or ptr>0x0ffffe or profile<0xa0 then return nil end
    flags=self.m.readword(ptr+2*(profile-0xa0))
  end
  self.flag_cache[key]=flags
  return flags
end
function G:transform(a,width)
  local m=self.m; local raw=m.readbyte(a+0x67); local layer=raw%16
  local sx,sy,ox,oy=256,256,0,0
  if raw<128 and m.readbyte(0x108566+layer)==2 then
    sx=m.readbyte(0x108f4c+16*layer)+1; sy=m.readbyte(0x108f4d+16*layer)+1
    ox=U.s16(m.readword(0x1090e4+4*layer)); oy=U.s16(m.readword(0x1090e6+4*layer))
  end
  return {sx=sx,sy=sy,ox=ox-(width==304 and 8 or 0),oy=oy-16}
end
function G.point(x,y,t)
  return math.floor(U.s16(x)*t.sx/256)+t.ox,math.floor(U.s16(y)*t.sy/256)+t.oy
end
function G:actor(a,width)
  if not U.valid(a) then return nil end
  local m=self.m; local char=m.readword(a+0x60)
  if char>31 then return nil end
  local p={address=a,character=char,name=P.names[char] or "?",mode=m.readbyte(a+0x17a),
    state=m.readword(a+0x72),script=m.readword(a+0x74),input=m.readword(a+0x150),
    control=m.readbyte(a+0x152),hitpause=m.readbyte(a+0x15a),
    hp=m.readword(a+0x17e),meter=m.readbyte(a+0x17d),
    stun=m.readbyte(a+0x188),stun_capacity=m.readbyte(a+0x189),
    stun_recharge=m.readbyte(a+0x18a),stun_prime=m.readbyte(a+0x18d),dizzy=m.readword(a+0x18e),
    x=U.s16(m.readword(a+0x80)),height=U.s16(m.readword(a+0x88)),
    ground=U.s16(m.readword(a+0x84)),facing=m.readbyte(a+0x41),
    pose=m.readword(a+0xc6),cursor=m.readdword(a+0x7c),duration=m.readbyte(a+0xb6),
    wait=m.readword(a+0xc8),contact_initial=m.readbyte(a+0x156),contact_remaining=m.readbyte(a+0x157),
    transform=self:transform(a,width)}
  p.ready=p.control==1 and p.height==0 and p.hitpause==0
  -- Native borrow resets remaining to capacity and arms18D; it is not a clear
  -- stun gauge. Exact zero alone is not primed. Timer residue after115 must not
  -- keep the defender marked dizzy (CLR.B18E can leave the low byteFF).
  p.stun_stage=(p.state==0x112 or p.state==0x113 or p.state==0x114)and 'dizzy'or
    p.stun_prime>0 and 'primed'or 'normal'
  p.stun_used=(p.stun_stage~='normal')and p.stun_capacity or U.clamp(p.stun_capacity-p.stun,0,p.stun_capacity)
  -- Scoped grounded OTG/down states, documented in the native reset predicate.
  p.knockdown=p.height==0 and not p.ready and (p.input==0x23 or p.input==0x24)
  p.guard=(p.control==2 or p.control==5) and
    ((p.script>=0x120 and p.script<0x12c) or (p.state>=0x120 and p.state<0x12c) or
      ((p.state==0x136 or p.state==0x137) and (p.input==0x19 or p.input==0x1a)))
  p.sx,p.sy=G.point(p.x,p.ground-p.height,p.transform)
  p.gx,p.gy=G.point(p.x,p.ground,p.transform)
  p.progress=table.concat({p.state,p.script,p.cursor,p.duration,p.wait,p.pose},":")
  return p
end
function G:root(a,p,q)
  if a==p or a==q then return a end
  local seen={};local depth=0
  while U.valid(a) and not seen[a] and depth<8 do
    seen[a]=true;a=self.m.readdword(a+0x18);depth=depth+1
    if a==p or a==q then return a end
  end
end
function G:objects(p,q,width)
  local m=self.m;local manager=m.readdword(P.ram.manager);local out={}
  if not U.valid(manager) then return out end
  for i=0,math.min(m.readword(manager+0x40),14)-1 do
    local a=m.readdword(manager+0x42+4*i)
    if a~=p and a~=q and U.valid(a) then
      local root=self:root(a,p,q)
      if root then local obj=self:actor(a,width);if obj then obj.owner=root;out[#out+1]=obj end end
    end
  end
  return out
end
function G:boxes(p,object)
  local m=self.m;local out={}
  for i=0,7 do
    local slot=p.address+0x100+10*i;local profile=m.readbyte(slot)
    if profile~=0 and (not object or m.readbyte(slot+1)~=0) then
      local flags=self:flags(p.character,profile);local shape=m.readbyte(slot+2)
      local kind=flags and (U.bit(flags,1) and "hurt" or "attack") or "unknown"
      local x1,x2,y1,y2
      if shape<8 then
        local scale=2^shape
        x1=U.s8(m.readbyte(slot+3))*scale;x2=U.s8(m.readbyte(slot+4))*scale
        if p.facing~=0 then x1,x2=-x2,-x1 end
        x1,x2=U.s16(p.x+x1),U.s16(p.x+x2)
        y1=U.s16(U.s8(m.readbyte(slot+5))*scale-p.height)
        y2=U.s16(U.s8(m.readbyte(slot+6))*scale-p.height)
      elseif shape%8==0 then
        x1=U.s16(m.readword(0x10e56c));x2=U.s16(m.readword(0x10e56e));y1,y2=-1,0
      end
      if x1 and x1~=x2 and y1~=y2 then
        local ax,ay=G.point(x1,y1,p.transform);local bx,by=G.point(x2,y2,p.transform)
        out[#out+1]={left=math.min(ax,bx),right=math.max(ax,bx),top=math.min(ay,by),bottom=math.max(ay,by),
          kind=kind,actor=p.address,owner=p.owner or p.address,profile=profile,slot=slot,native=false}
      end
    end
  end
  if not object and m.readbyte(p.address+0xf2)~=0 then
    local scale=2^(m.readword(p.address+0xf4)%8)
    local x1=U.s16(m.readword(p.address+0xf6))*scale;local x2=U.s16(m.readword(p.address+0xf8))*scale
    if p.facing~=0 then x1,x2=-x2,-x1 end
    local ax,ay=G.point(p.x+x1,U.s16(m.readword(p.address+0xfa))*scale-p.height,p.transform)
    local bx,by=G.point(p.x+x2,U.s16(m.readword(p.address+0xfc))*scale-p.height,p.transform)
    out[#out+1]={left=math.min(ax,bx),right=math.max(ax,bx),top=math.min(ay,by),bottom=math.max(ay,by),
      kind="push",actor=p.address,owner=p.address}
  end
  return out
end
function G:sample(width)
  local m=self.m;local p=m.readdword(P.ram.p1);local q=m.readdword(P.ram.p2)
  if m.readbyte(P.ram.phase)~=0 or p==q then return nil end
  local a,b=self:actor(p,width),self:actor(q,width)
  if not a or not b then return nil end
  local frame={engine=self.emu.framecount(),native_counter=m.readword(P.ram.native_counter),players={a,b},boxes={},objects=self:objects(p,q,width)}
  for _,obj in ipairs({a,b}) do for _,box in ipairs(self:boxes(obj,false)) do frame.boxes[#frame.boxes+1]=box end end
  for _,obj in ipairs(frame.objects) do for _,box in ipairs(self:boxes(obj,true)) do frame.boxes[#frame.boxes+1]=box end end
  return frame
end
function G:range(source,target,command)
  local limits=command and P.grabs[source.character] or {P.normal_throw,P.normal_throw}
  if not limits then return nil end
  local base=limits[source.mode==0 and 1 or 2]
  local allowance=self.m.readword(0x304a6+(target.character%32)*2)
  for _,pose in ipairs(P.pose_allowance[target.character] or {}) do if pose==target.pose then allowance=allowance+16;break end end
  local distance=math.abs(source.x-target.x)
  return {base=base,allowance=allowance,limit=base+allowance,distance=distance,
    adjusted=math.max(0,distance-allowance),within=math.max(0,distance-allowance)<=base}
end
return G
