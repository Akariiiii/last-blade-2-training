-- Render-only reductions. Measurement boxes/timelines remain complete and untouched.
local U=require('lb2.util')
local D={}
local kinds={attack=1,hurt=2,push=3,unknown=4}
function D.boxes(gui,boxes,width,height,colors,filled)
 local seen={};local rendered=0
 for _,b in ipairs(boxes)do
  if b.right>=0 and b.left<width and b.bottom>=0 and b.top<height then
   local x1,x2=math.floor(U.clamp(b.left,0,width-1)),math.floor(U.clamp(b.right,0,width-1))
   local y1,y2=math.floor(U.clamp(b.top,0,height-1)),math.floor(U.clamp(b.bottom,0,height-1))
   local kind=kinds[b.kind]or 4
   -- Exact integer key for native framebuffer dimensions; identical screen
   -- geometry/color needs one draw even when several native tests report it.
   local key=((((x1*width+x2)*height+y1)*height+y2)*4+kind)
   if not seen[key]then
    seen[key]=true;rendered=rendered+1;local c=colors[b.kind]or colors.unknown
    -- One native call is cheaper than four Lua->C line calls on FBNeo.
    -- Transparent interiors still scan in C, but avoid painting/compositing a
    -- large translucent area; never simulate this by skipping measured frames.
    gui.box(x1,y1,x2,y2,filled and c-c%256+24 or 0x00000000,c)
   end
  end
 end
 return rendered
end
function D.timeline(gui,timeline,count,x,y,colors)
 count=math.min(count,#timeline);local first=#timeline-count
 local run,color
 local function flush(last)
  if run then gui.box(x+run,y,x+last,y+5,color,color)end
 end
 for n=1,count do
  local c=colors[timeline[first+n].phase]or 0xffffffff
  if c~=color then flush(n-1);run=n;color=c end
 end
 flush(count)
 -- Contacts are drawn last; each occupied x is independent, preserving pixels.
 for n=1,count do if timeline[first+n].contact then gui.line(x+n,y-2,x+n,y+6,0xffffffff)end end
end
return D
