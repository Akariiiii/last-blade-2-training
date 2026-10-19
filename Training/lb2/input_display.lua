-- Draw input history with native primitives: no image/font assets or Unicode dependency.
local I={}
local white=0xe8eef5ff
local colors={A=0xff695fff,B=0x6caeffff,C=0xffce64ff,D=0x7bdf98ff}
function I.direction(entry)
  if entry.direction then return entry.direction end
  -- Compatibility only: old strings cannot distinguish Down and button D.
  local s=entry.text or ""
  return {up=s:find("U",1,true)~=nil,down=s:find("D",1,true)~=nil,left=s:find("L",1,true)~=nil,right=s:find("R",1,true)~=nil}
end
function I.arrow(gui,x,y,d)
  local dx=(d.right and 1 or 0)-(d.left and 1 or 0)
  local dy=(d.down and 1 or 0)-(d.up and 1 or 0)
  if dx==0 and dy==0 then gui.box(x-1,y-1,x+1,y+1,0x74829580,white);return end
  local tipx,tipy=x+dx*3,y+dy*3
  gui.line(x-dx*2,y-dy*2,tipx,tipy,white)
  -- Perpendicular wings point backwards along the shaft.
  local basex,basey=tipx-dx*2,tipy-dy*2
  gui.line(tipx,tipy,basex-dy*2,basey+dx*2,white)
  gui.line(tipx,tipy,basex+dy*2,basey-dx*2,white)
end
local function button(gui,x,y,name)
  local c=colors[name]
  -- 7px circular silhouette built from scan lines; works on stock FBNeo GUI.
  for row=-3,3 do
    local half=math.abs(row)==3 and 1 or math.abs(row)==2 and 2 or 3
    gui.line(x-half,y+row,x+half,y+row,c)
  end
  gui.text(x-1,y-3,name,0x10141aff,0x00000000)
end
function I.draw(gui,history,x,y,rows,alpha)
  rows=math.max(1,math.min(12,rows or 6))
  local first=math.max(1,#history-rows+1)
  for n=first,#history do
    local entry=history[n];local rowy=y+(n-first)*9
    gui.text(x,rowy-3,tostring(math.min(entry.frames or 1,999)),white,alpha or 0x00000050)
    I.arrow(gui,x+18,rowy,I.direction(entry))
    local buttons=entry.buttons
    for k,name in ipairs({"A","B","C","D"}) do
      local pressed=buttons and buttons[name]
      if not buttons and name~="D" then pressed=(entry.text or ""):find(name,1,true)~=nil end
      if pressed then button(gui,x+26+(k-1)*8,rowy,name) end
    end
  end
end
return I
