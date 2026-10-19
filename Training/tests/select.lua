package.path='Training/?.lua;'..package.path
local Select=require('lb2.select')
local words,bytes,dwords,hooks={},{},{},{};local checks=0
local function equal(a,b,message)assert(a==b,(message or 'value')..': '..tostring(a)..' != '..tostring(b));checks=checks+1 end
for _,c in ipairs({{0x293c,{0x08ad,0,0x501,0x426d,0x560,0x4eb9}},
 {0x1a03a,{0x3b7c,0xffff,0x3d58,0x422d,0x3d62,0x4e75}},
 {0x1b05c,{0x4a2d,0x7d82,0x6602,0x4e75,0x4a2c,0x100}}})do
 for i,w in ipairs(c[2])do words[c[1]+(i-1)*2]=w end
end
local m={readword=function(a)return words[a]or 0 end,readbyte=function(a)return bytes[a]or 0 end,
 readdword=function(a)return dwords[a]or 0 end,writeword=function(a,v)words[a]=v end,
 writebyte=function(a,v)bytes[a]=v end,writedword=function(a,v)dwords[a]=v end,
 registerexec=function(a,fn)hooks[a]=fn end,getregister=function()return 0x100a00 end}
local flow=Select.new({memory=m});equal(flow:request(),true)
dwords[0x108530]=0x100000;dwords[0x100000]=0x42ee
local keys=flow:before({['P1 Button A']=true,['P2 Button A']=true})
equal(dwords[0x100000],0x293c);equal(words[0x1082c6],0x101);equal(keys['P2 Button A'],false)
words[0x10bd58]=0xffff;words[0x10bd5a]=0xffff;dwords[0x100000]=0x2b9c
flow:after(nil);equal(flow.stage,'char1')
keys=flow:before({['P1 Button A']=true});equal(keys['P1 Button A'],false,'release barrier')
flow:before({});keys=flow:before({['P1 Button A']=true});equal(keys['P1 Button A'],true);equal(keys['P2 Button A'],false)
words[0x10bd58]=1;flow:after(nil);equal(flow.stage,'char2')
keys=flow:before({['P1 Button A']=true});equal(keys['P2 Button A'],false,'P1 confirm cannot select P2')
flow:before({});keys=flow:before({['P1 Down']=true,['P1 Button A']=true,['P2 Right']=true})
equal(keys['P1 Down'],false);equal(keys['P1 Button A'],false);equal(keys['P2 Down'],true);equal(keys['P2 Right'],false);equal(keys['P2 Button A'],true)
words[0x10bd5a]=9;flow:after(nil);equal(flow.stage,'mode1')
bytes[0x10bd62]=2;flow:after(nil);equal(flow.stage,'mode2')
bytes[0x10bd63]=1;flow:after(nil);equal(flow.stage,'intro')
dwords[0x100000]=0x42ee
local frame={players={{ready=true,script=0},{ready=true,script=0}}}
bytes[0x108501]=2;flow:after(frame);equal(flow.stable,0,'presentation semaphore')
bytes[0x108501]=64;flow:after(frame);equal(flow.stable,0,'battle setup lock')
bytes[0x108501]=0
bytes[0x10bd80]=1;flow:after(frame);equal(flow.stable,0,'intro global lock')
bytes[0x10bd80]=0;dwords[0x10853e]=1;flow:after(frame);equal(flow.stable,0,'lock history')
dwords[0x10853e]=0
flow:after(frame);flow:after(frame);equal(flow.active,true);flow:after(frame);equal(flow.active,false);equal(flow.finished,true)
flow:install();hooks[0x1b05c]();equal(bytes[0x100b00],nil,'inactive menu cannot write timer')
flow:request();hooks[0x1b05c]();equal(bytes[0x100b00],0x21);equal(bytes[0x100b01],60)
flow:stop();equal(hooks[0x1b05c],nil)
words[0x293c]=0;equal(flow:request(),false);equal(flow.active,false)
-- Fast transitions own only returning/intro, never interactive selection/fight.
local speed={};local flow2=Select.new({memory=m,emu={speedmode=function(mode)speed[#speed+1]=mode end}})
words[0x293c]=0x08ad
equal(flow2:request(),true);equal(speed[#speed],'turbo');equal(flow2.fast_active,true)
flow2:transition('char1');equal(speed[#speed],'normal');equal(flow2.fast_active,false)
flow2:transition('char2');equal(#speed,2,'no repeated speed calls in interactive menus')
flow2:transition('intro');equal(speed[#speed],'turbo');flow2:cancel();equal(speed[#speed],'normal')
flow2:request();flow2:stop();equal(speed[#speed],'normal','stop restores')
flow2.fast_transitions=false;flow2:request();equal(flow2.fast_active,false,'opt out')
flow2.fast_transitions=true;flow2:request();flow2.ticks=7201;flow2:after(nil)
equal(flow2.active,false);equal(flow2.fast_active,false);equal(speed[#speed],'normal','timeout restores')
print('PASS Select: '..checks..' assertions')
