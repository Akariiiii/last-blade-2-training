local U = {}
function U.bit(n, mask) return math.floor(n / mask) % 2 == 1 end
function U.s16(n) n=n%65536; return n>=32768 and n-65536 or n end
function U.s8(n) return n>=128 and n-256 or n end
function U.valid(a) return type(a)=="number" and a>=0x100200 and a<=0x10fe00 and a%2==0 end
function U.copy(t) local r={}; for k,v in pairs(t) do r[k]=v end; return r end
function U.clamp(n,lo,hi) return math.min(hi,math.max(lo,n)) end
function U.push(t,v,limit) t[#t+1]=v; if #t>limit then table.remove(t,1) end end
function U.signed(n) return n==nil and "--" or string.format("%+d",n) end
function U.frames(n) return n==nil and "--" or tostring(n).."f" end
return U
