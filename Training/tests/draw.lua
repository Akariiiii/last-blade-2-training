package.path='Training/?.lua;'..package.path
local D=require('lb2.draw');local tests=0
local function eq(a,b,name)assert(a==b,(name or 'value')..': '..tostring(a)..' != '..tostring(b));tests=tests+1 end
local colors={attack=0xff655aff,hurt=0x60db9aff,push=0x62bfffff,unknown=0xf7cd72ff,startup=1,active=2,recovery=3,freeze=4}
local boxes={{left=1,right=10,top=2,bottom=20,kind='attack',actor=1},
 {left=1,right=10,top=2,bottom=20,kind='attack',actor=2},
 {left=1,right=10,top=2,bottom=20,kind='hurt'}, {left=-4,right=0,top=2,bottom=20,kind='attack'},
 {left=-10,right=-1,top=0,bottom=2,kind='attack'}}
local count,filled=0,0
local gui={line=function()count=count+1 end,box=function(x1,y1,x2,y2,fill)count=count+1;if fill%256~=0 then filled=filled+1 end end}
eq(D.boxes(gui,boxes,320,224,colors,false),3,'draw distinct color/geometry once');eq(count,3);eq(filled,0,'transparent interiors')
eq(#boxes,5,'measurement retained');eq(boxes[1].actor,1);eq(boxes[2].actor,2)
eq(D.boxes(gui,boxes,320,224,colors,true),3);eq(filled,3)
-- Pixel-equivalence of run-compressed timeline including cropped tails/contacts.
local function raster()
 local pixels={};local calls=0;local api={}
 api.line=function(x1,y1,x2,y2,c)
  calls=calls+1
  for x=math.min(x1,x2),math.max(x1,x2)do for y=math.min(y1,y2),math.max(y1,y2)do pixels[x..','..y]=c end end
 end
 api.box=api.line
 return api,pixels,function()return calls end
end
local timeline={};for n=1,600 do timeline[n]={phase=({'startup','active','freeze','recovery'})[math.floor(n/40)%4+1],contact=n%23==0}end
for _,size in ipairs({0,1,40,304,600})do
 local a,p,ac=raster();local b,q,bc=raster();local first=#timeline-size
 for n=1,size do local t=timeline[first+n];a.line(12+n,100,12+n,105,colors[t.phase]);if t.contact then a.line(12+n,98,12+n,106,0xffffffff)end end
 D.timeline(b,timeline,size,12,100,colors)
 for k,v in pairs(p)do assert(q[k]==v,'missing/different pixel '..k)end
 for k,v in pairs(q)do assert(p[k]==v,'extra pixel '..k)end
 tests=tests+1
 if size>1 then eq(bc()<ac(),true,'fewer native draw calls')end
end
print('PASS Draw: '..tests..' assertions')
