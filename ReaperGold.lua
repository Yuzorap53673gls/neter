--// REAPER GOLD HUB v1
local P=game:GetService("Players")
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local L=game:GetService("Lighting")
local TPS=game:GetService("TeleportService")
local LP=P.LocalPlayer
if not LP then return end
local U2=UDim2.new local UD=UDim.new local C=Color3.fromRGB
local F=Enum.Font local EIT=Enum.UserInputType

local AC=C(226,54,74)
local GD=C(255,199,64)
local GR=C(46,204,113)
local BG=C(21,18,25)
local PN=C(15,13,19)
local RW=C(32,28,37)
local RV=C(42,36,48)
local TX=C(240,236,241)
local MU=C(152,144,154)

local CFG={
Hud=true,Scale=100,Notify=true,
AutoDig=true,AutoSmelt=true,AutoUpgrade=true,AutoNpc=true,AutoMuseum=false,AutoNugget=true,Partner=true,AutoExec=true,AutoMission=true,Mission=1,WaitMode=1,DeliverFirst=true,
SmeltAt=10,Delay=1.2,TpSpot=true,
NuggetNeed=15,NuggetStep=2,
Esp=false,EspName=true,Fog=false,Full=false,AntiLag=false,
Speed=16,Jump=50,InfJump=false,Noclip=false,
NoobSize=100,Trails=false,Avatar=false,TpOn=true,
}

local ST={esp={},logs={},idx=1,target=LP,dest=nil,status="Pronto",
ores=0,bars=0,bp=0,spots=0,session=0,cd={},acc=nil,bc=nil,trail=nil,lastSpot=nil,noobs=0,
home=nil,nug=nil,got=0,need=15,phase="parado",mphase="check",midx=1,mwait=0}

local hud
local function mk(c,p,t)
  local o=Instance.new(c)
  if o:IsA("GuiObject") then o.BorderSizePixel=0 end
  if c=="TextLabel" then o.BackgroundTransparency=1 o.Text="" o.TextXAlignment=Enum.TextXAlignment.Left o.TextTruncate=Enum.TextTruncate.AtEnd o.Font=Enum.Font.GothamBold
  elseif c=="TextButton" then o.Text="" o.AutoButtonColor=false o.Font=Enum.Font.GothamBold end
  if t then
    for k,v in pairs(t) do
      if not pcall(function() o[k]=v end) then warn("[Reaper] prop "..tostring(k)) end
    end
  end
  if p then o.Parent=p end
  return o
end

local function toast(a,b,d)
  if not CFG.Notify then return end
  pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title=tostring(a),Text=tostring(b),Duration=d or 4}) end)
end

--// JANELA
local gui=mk("ScreenGui",nil,{Name="ReaperGold",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9999})
local okp=pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not okp or not gui.Parent then pcall(function() gui.Parent=LP:WaitForChild("PlayerGui",10) end) end
if not gui.Parent then gui:Destroy() toast("Reaper Gold","Executor bloqueou a interface.",6) return end

local VPS=workspace.CurrentCamera.ViewportSize
local WW=math.min(540,VPS.X-24)
local WH=math.min(510,math.max(300,VPS.Y-90))
local SW=WW<430 and 118 or 148

local win=mk("Frame",gui,{Size=U2(0,WW,0,WH),Position=U2(0,math.max(8,(VPS.X-WW)/2),0,64),BackgroundColor3=BG,Active=true,ClipsDescendants=true})
mk("UICorner",win,{CornerRadius=UD(0,11)})
mk("UIStroke",win,{Color=C(58,44,52),Thickness=1})
local uisc=mk("UIScale",win,{Scale=1})

local bar=mk("Frame",win,{Size=U2(1,0,0,42),BackgroundColor3=PN,Active=true})
mk("UICorner",bar,{CornerRadius=UD(0,11)})
mk("Frame",bar,{Size=U2(1,0,0,14),Position=U2(0,0,1,-14),BackgroundColor3=PN})
local dot=mk("Frame",bar,{Size=U2(0,9,0,9),Position=U2(0,14,.5,-4.5),BackgroundColor3=GD})
mk("UICorner",dot,{CornerRadius=UD(1,0)})
mk("TextLabel",bar,{Size=U2(0,250,0,16),Position=U2(0,30,0,6),Text="Reaper Gold",Font=F.GothamBold,TextSize=13,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left})
mk("TextLabel",bar,{Size=U2(0,250,0,12),Position=U2(0,30,0,23),Text="Gold Hunters 2.0  •  modo parceiro",Font=F.Gotham,TextSize=9,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left})

local function barBtn(txt,x)
  local b=mk("TextButton",bar,{Size=U2(0,28,0,26),Position=U2(1,x,.5,-13),BackgroundTransparency=1,Text=txt,Font=F.GothamBold,TextSize=13,TextColor3=MU,ZIndex=4})
  mk("UICorner",b,{CornerRadius=UD(0,6)})
  b.MouseEnter:Connect(function() b.TextColor3=TX b.BackgroundTransparency=.4 end)
  b.MouseLeave:Connect(function() b.TextColor3=MU b.BackgroundTransparency=1 end)
  return b
end
local bMin=barBtn("-",-96) local bMax=barBtn("o",-64) local bClose=barBtn("X",-32)

local mini=mk("TextButton",gui,{Size=U2(0,58,0,58),Position=U2(0,16,0,110),BackgroundColor3=AC,Visible=false,ZIndex=20})
mk("UICorner",mini,{CornerRadius=UD(1,0)})
mk("UIStroke",mini,{Color=C(255,140,160),Thickness=2})
mk("TextLabel",mini,{Size=U2(1,0,0,18),Position=U2(0,0,0,13),Text="R",Font=F.GothamBold,TextSize=20,TextColor3=C(255,255,255),TextXAlignment=Enum.TextXAlignment.Center})
mk("TextLabel",mini,{Size=U2(1,0,0,12),Position=U2(0,0,0,33),Text="Gold",Font=F.GothamBold,TextSize=8,TextColor3=C(255,240,240),TextXAlignment=Enum.TextXAlignment.Center})
local function setMini(on) win.Visible=not on mini.Visible=on end

local drag,dS,dP=false,nil,nil
local mDrag,mS,mP,mM=false,nil,nil,0
local function startDrag(i,isMini)
  if isMini then mDrag=true mS=i.Position mP=mini.Position mM=0
  else drag=true dS=i.Position dP=win.Position end
  i.Changed:Connect(function()
    if i.UserInputState~=Enum.UserInputState.End then return end
    if isMini then mDrag=false if mM<8 then setMini(false) end else drag=false end
  end)
end
bar.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,false) end end)
mini.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,true) end end)
UIS.InputChanged:Connect(function(i)
  if i.UserInputType~=EIT.MouseMovement and i.UserInputType~=EIT.Touch then return end
  if drag and dS then
    local o=i.Position-dS
    win.Position=U2(dP.X.Scale,dP.X.Offset+o.X,dP.Y.Scale,dP.Y.Offset+o.Y)
  elseif mDrag and mS then
    local o=i.Position-mS mM=math.max(mM,o.Magnitude)
    mini.Position=U2(mP.X.Scale,mP.X.Offset+o.X,mP.Y.Scale,mP.Y.Offset+o.Y)
  end
end)

local zoom=false
bMax.MouseButton1Click:Connect(function()
  zoom=not zoom
  if zoom then win.Position=U2(0,6,0,6) win.Size=U2(1,-12,1,-12)
  else win.Position=U2(0,math.max(8,(VPS.X-WW)/2),0,64) win.Size=U2(0,WW,0,WH) end
end)

--// PAGINAS
local side=mk("Frame",win,{Size=U2(0,SW,1,-42),Position=U2(0,0,0,42),BackgroundColor3=PN})
mk("UICorner",side,{CornerRadius=UD(0,10)})
local cont=mk("Frame",win,{Size=U2(1,-SW,1,-42),Position=U2(0,SW,0,42),BackgroundColor3=BG})
local pages,navs={},{}
local NAV={{"Novidades","!"},{"Info","?"},{"Home","#"},{"Automacao","$"},{"TP Hub","@"},{"Personagem","+"},{"Visual","*"},{"Config","="},{"Creditos","i"}}
local ord=0

local function mkScroll(par,size,pos)
  local p=mk("ScrollingFrame",par,{Size=size,Position=pos,BackgroundTransparency=1,ScrollBarThickness=5,ScrollBarImageColor3=C(120,96,120),CanvasSize=U2(0,0,0,0)})
  local ly=mk("UIListLayout",p,{Padding=UD(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
  mk("UIPadding",p,{PaddingTop=UD(0,2),PaddingBottom=UD(0,18),PaddingLeft=UD(0,4),PaddingRight=UD(0,9)})
  local function fit() pcall(function() p.CanvasSize=U2(0,0,0,ly.AbsoluteContentSize.Y+20) end) end
  pcall(function() ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit) end)
  task.spawn(function() for _=1,60 do fit() task.wait(0.1) end end)
  return p
end

local function newPage(k)
  local p=mkScroll(cont,U2(1,-16,1,-16),U2(0,8,0,8))
  p.Visible=false
  pages[k]=p
  return p
end

local function show(k)
  for n,p in pairs(pages) do p.Visible=(n==k) end
  for n,v in pairs(navs) do
    local on=(n==k)
    v.bg.BackgroundColor3=on and C(48,34,42) or PN
    v.bar.Visible=on
    v.txt.TextColor3=on and TX or MU
    v.gl.TextColor3=on and GD or MU
  end
end

local navH=math.clamp(math.floor(((WH-42)-56)/#NAV),22,32)
local navFS=navH<26 and 10 or 12
for i,it in ipairs(NAV) do
  local b=mk("TextButton",side,{Size=U2(1,-14,0,navH),Position=U2(0,7,0,6+(i-1)*(navH+3)),BackgroundColor3=PN})
  mk("UICorner",b,{CornerRadius=UD(0,7)})
  local bar0=mk("Frame",b,{Size=U2(0,3,0,math.min(16,navH-8)),Position=U2(0,-7,.5,-math.min(16,navH-8)/2),BackgroundColor3=GD,Visible=false})
  mk("UICorner",bar0,{CornerRadius=UD(1,0)})
  local gl=mk("TextLabel",b,{Size=U2(0,18,1,0),Position=U2(0,10,0,0),Text=it[2],Font=F.GothamBold,TextSize=navFS,TextColor3=MU})
  local tx=mk("TextLabel",b,{Size=U2(1,-34,1,0),Position=U2(0,32,0,0),Text=it[1],Font=F.GothamMedium,TextSize=navFS,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
  navs[it[1]]={bg=b,bar=bar0,gl=gl,txt=tx}
  b.MouseButton1Click:Connect(function() show(it[1]) end)
  if it[1]~="Automacao" then pcall(newPage,it[1]) end
end

local chip=mk("Frame",side,{Size=U2(1,-14,0,34),Position=U2(0,7,1,-42),BackgroundTransparency=1})
local av=mk("Frame",chip,{Size=U2(0,24,0,24),Position=U2(0,4,.5,-12),BackgroundColor3=GD})
mk("UICorner",av,{CornerRadius=UD(1,0)})
mk("TextLabel",av,{Size=U2(1,0,1,0),Text=string.sub(LP.Name,1,1):upper(),Font=F.GothamBold,TextSize=12,TextColor3=C(28,22,10),TextXAlignment=Enum.TextXAlignment.Center})
mk("TextLabel",chip,{Size=U2(1,-44,1,0),Position=U2(0,36,0,0),Text=LP.Name,Font=F.GothamMedium,TextSize=11,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})

--// COMPONENTES
local function sect(par,t)
  ord=ord+1
  return mk("TextLabel",par,{Size=U2(1,0,0,20),Text=string.upper(t),Font=F.GothamBold,TextSize=10,TextColor3=GD,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord})
end

local function row(par,h)
  ord=ord+1
  local r=mk("TextButton",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,LayoutOrder=ord})
  mk("UICorner",r,{CornerRadius=UD(0,8)})
  r.MouseEnter:Connect(function() r.BackgroundColor3=RV end)
  r.MouseLeave:Connect(function() r.BackgroundColor3=RW end)
  return r
end

local function tlab(r,t)
  return mk("TextLabel",r,{Size=U2(1,-76,1,0),Position=U2(0,12,0,0),Text=t,Font=F.GothamMedium,TextSize=12,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
end

local function tog(par,t,k,cb)
  local r=row(par,30)
  tlab(r,t)
  local pill=mk("Frame",r,{Size=U2(0,44,0,22),Position=U2(1,-54,.5,-11),BackgroundColor3=C(70,64,74)})
  mk("UICorner",pill,{CornerRadius=UD(1,0)})
  local tx=mk("TextLabel",pill,{Size=U2(1,0,1,0),Text="OFF",Font=F.GothamBold,TextSize=10,TextColor3=C(240,236,241),TextXAlignment=Enum.TextXAlignment.Center})
  local function paint()
    local on=CFG[k] and true or false
    pill.BackgroundColor3=on and GR or C(70,64,74)
    tx.Text=on and "ON" or "OFF"
  end
  r.MouseButton1Click:Connect(function() CFG[k]=not CFG[k] paint() if cb then pcall(cb,CFG[k]) end end)
  paint()
  return r
end

local function card(par,t,d,k,cb)
  local r=mk("TextButton",par,{Size=U2(1,0,0,54),BackgroundColor3=RW,LayoutOrder=ord+1})
  ord=ord+1
  mk("UICorner",r,{CornerRadius=UD(0,9)})
  mk("UIStroke",r,{Color=C(62,52,64),Thickness=1,Transparency=.5})
  mk("TextLabel",r,{Size=U2(1,-104,0,15),Position=U2(0,11,0,8),Text=t,Font=F.GothamBold,TextSize=12,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
  mk("TextLabel",r,{Size=U2(1,-104,0,26),Position=U2(0,11,0,25),Text=d,Font=F.Gotham,TextSize=10,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.AtEnd})
  local pill=mk("Frame",r,{Size=U2(0,58,0,23),Position=U2(1,-70,.5,-11.5),BackgroundColor3=C(70,64,74)})
  mk("UICorner",pill,{CornerRadius=UD(1,0)})
  local tx=mk("TextLabel",pill,{Size=U2(1,0,1,0),Text="OFF",Font=F.GothamBold,TextSize=10,TextColor3=C(240,236,241),TextXAlignment=Enum.TextXAlignment.Center})
  local function paint()
    local on=CFG[k] and true or false
    pill.BackgroundColor3=on and GR or C(70,64,74)
    tx.Text=on and "ON" or "OFF"
  end
  r.MouseButton1Click:Connect(function() CFG[k]=not CFG[k] paint() if cb then pcall(cb,CFG[k]) end end)
  paint()
  return r
end

local function step(par,t,k,st,mn,mx,cb)
  local r=row(par,30)
  tlab(r,t)
  local val=mk("TextLabel",r,{Size=U2(0,46,0,18),Position=U2(1,-104,.5,-9),Text=tostring(CFG[k]),Font=F.GothamBold,TextSize=12,TextColor3=GD,ZIndex=3})
  local function sb(txt,x,dir)
    local b=mk("TextButton",r,{Size=U2(0,24,0,24),Position=U2(1,x,.5,-12),BackgroundColor3=C(54,43,50),Text=txt,Font=F.GothamBold,TextSize=13,TextColor3=TX})
    mk("UICorner",b,{CornerRadius=UD(0,6)})
    b.MouseButton1Click:Connect(function() CFG[k]=math.clamp(CFG[k]+dir*st,mn,mx) val.Text=tostring(CFG[k]) if cb then pcall(cb,CFG[k]) end end)
  end
  sb("-",-58,-1) sb("+",-28,1)
end

local function btn(par,t,fn)
  local r=row(par,30)
  tlab(r,t)
  mk("TextLabel",r,{Size=U2(0,16,1,0),Position=U2(1,-24,0,0),Text=">",Font=F.GothamBold,TextSize=12,TextColor3=MU})
  r.MouseButton1Click:Connect(function() local ok,e=pcall(fn) if not ok then warn("[Reaper] "..tostring(e)) end end)
end

local function note(par,t,h)
  local l=mk("TextLabel",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,BackgroundTransparency=0,Text=t,Font=F.Gotham,TextSize=10.5,TextColor3=MU,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=ord+1})
  mk("UICorner",l,{CornerRadius=UD(0,8)})
  mk("UIPadding",l,{PaddingLeft=UD(0,10),PaddingRight=UD(0,8),PaddingTop=UD(0,8)})
  ord=ord+1
  return l
end

--// PERSONAGEM
local function chr() return LP.Character end
local function hrp() local c=chr() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=chr() return c and c:FindFirstChildOfClass("Humanoid") end

local function applyChar()
  local h=hum()
  if not h then return end
  pcall(function() h.WalkSpeed=CFG.Speed if h.UseJumpPower then h.JumpPower=CFG.Jump end end)
end

local function infJump()
  if not CFG.InfJump then return end
  local h=hum()
  if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end
UIS.JumpRequest:Connect(infJump)

RS.Stepped:Connect(function()
  if not gui.Parent then return end
  applyChar()
  if not CFG.Noclip then return end
  local c=chr()
  if not c then return end
  for _,d in ipairs(c:GetDescendants()) do
    if d:IsA("BasePart") and d.CanCollide then pcall(function() d.CanCollide=false end) end
  end
end)

local function setSize(pct)
  CFG.NoobSize=pct
  local c=chr()
  if not c then return end
  local ok=pcall(function() c:ScaleTo(pct/100) end)
  if not ok then
    local h=hum()
    if h then
      pcall(function()
        h.BodyHeightScale=pct/100 h.BodyWidthScale=pct/100
        h.BodyDepthScale=pct/100 h.HeadScale=pct/100
      end)
    end
  end
end

local function trail(on)
  local r=hrp()
  if ST.trail then pcall(function() ST.trail:Destroy() end) ST.trail=nil end
  if not on or not r then return end
  pcall(function()
    local a0=Instance.new("Attachment") a0.Position=Vector3.new(0,.7,0) a0.Parent=r
    local a1=Instance.new("Attachment") a1.Position=Vector3.new(0,-.7,0) a1.Parent=r
    local t=Instance.new("Trail")
    t.Attachment0=a0 t.Attachment1=a1 t.Lifetime=.7 t.MinLength=.05
    t.Color=ColorSequence.new(GD)
    t.Transparency=NumberSequence.new(.15,1)
    t.LightEmission=.4 t.Parent=r
    ST.trail=t
  end)
end

local function avatarNoob(on)
  local c=chr()
  if not c then return end
  if on then
    local acc={}
    for _,d in ipairs(c:GetDescendants()) do
      if d:IsA("Accessory") or d:IsA("Hat") then acc[d]=d.Parent pcall(function() d.Parent=nil end) end
    end
    ST.acc=acc
    local bc=c:FindFirstChildOfClass("BodyColors")
    if bc then
      ST.bc={bc.HeadColor3,bc.TorsoColor3,bc.LeftArmColor3,bc.RightArmColor3,bc.LeftLegColor3,bc.RightLegColor3}
      pcall(function()
        bc.HeadColor3=C(255,204,51) bc.TorsoColor3=C(255,204,51)
        bc.LeftArmColor3=C(255,204,51) bc.RightArmColor3=C(255,204,51)
        bc.LeftLegColor3=C(46,140,64) bc.RightLegColor3=C(46,140,64)
      end)
    end
    toast("Avatar","Modo noob ligado.",3)
  else
    if ST.bc then
      local s=ST.bc
      local bc=c:FindFirstChildOfClass("BodyColors")
      if bc then
        pcall(function()
          bc.HeadColor3=s[1] bc.TorsoColor3=s[2] bc.LeftArmColor3=s[3]
          bc.RightArmColor3=s[4] bc.LeftLegColor3=s[5] bc.RightLegColor3=s[6]
        end)
      end
      ST.bc=nil
    end
    for d,par in pairs(ST.acc or {}) do pcall(function() d.Parent=par or c end) end
    ST.acc=nil
    toast("Avatar","Avatar original.",3)
  end
end

--// SISTEMA DE PROMPTS
local KEY={
dig={"dig","cav","escav","miner","mine","minera","escava","picareta","shovel","drill"},
smelt={"fund","smelt","forge","process","usina"},
deliver={"deposit","deliver","entreg","depos","vender","sell","process","usina","maquina","máquina","fundidor","smelt"},
up={"melhor","upgrad","equip","aument"},
quiz={"quiz","pergunt","answer","respost","trivia","escolh","option"},
nug={"nugget","pepita","collect","colet","ouro","gold"},
hub={"hub","fundidora","smelt","usina","loja","shop","lobby"},
}
local NUG={"nugget","pepita","goldore","gold_ore","gold ore","minerio","minério","collectible","pickup","goldnugget","gold bar","barra de ouro"}

local function has(s,list)
  s=string.lower(s or "")
  for _,w in ipairs(list) do if string.find(s,w,1,true) then return true end end
  return false
end

local pcache={t=0,list={}}
local function prompts()
  local n=os.clock()
  if n-pcache.t<1.6 then return pcache.list end
  pcache.t=n
  local out={}
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("ProximityPrompt") and d.Enabled then table.insert(out,d) end
  end
  pcache.list=out
  return out
end

local function findP(list,limit)
  local out={}
  for _,p in ipairs(prompts()) do
    local par=p.Parent
    local s=(p.ActionText or "").." "..(p.ObjectText or "").." "..(par and par.Name or "")
    if has(s,list) then
      table.insert(out,p)
      if #out>=(limit or 5) then break end
    end
  end
  return out
end

local function tpNear(obj,dist)
  local r=hrp()
  if not r or not obj then return false end
  local base=nil
  if obj:IsA("BasePart") then base=obj
  else base=obj:FindFirstChildWhichIsA("BasePart",true) end
  if not base and obj.Parent then base=obj.Parent:FindFirstChildWhichIsA("BasePart",true) end
  if not base then return false end
  local p=base.Position
  local sz=base.Size
  local d=math.max(dist or 4,math.max(sz.X,sz.Z)*.5+1.5)
  pcall(function()
    r.CFrame=CFrame.new(p+Vector3.new(0,math.max(2,sz.Y*.5+1),d),p)
  end)
  return true
end

local function fireP(p,hold)
  if not p or not p.Parent then return false end
  local ok=false
  local h=hold or p.HoldDuration or 0
  if fireproximityprompt then
    ok=pcall(fireproximityprompt,p,h)
    if ok then
      if h>0 then task.wait(math.min(h+.05,.8)) end
      return true
    end
  end
  ok=pcall(function()
    p:InputHoldBegin()
    task.wait(math.clamp(h+.12,.12,1.2))
    p:InputHoldEnd()
  end)
  if not ok then ok=pcall(function() p:InputHoldBegin() p:InputHoldEnd() end) end
  return ok
end

local function ready(k,sec)
  local n=os.clock()
  if (ST.cd[k] or 0)>n then return false end
  ST.cd[k]=n+sec
  return true
end

--// LEADERSTATS
local function stats()
  local out={}
  local ls=LP:FindFirstChild("leaderstats")
  if ls then
    for _,v in ipairs(ls:GetChildren()) do
      if v:IsA("ValueBase") then out[v.Name]=v.Value end
    end
  end
  return out
end

local function num(list)
  for n,v in pairs(stats()) do
    if has(n,list) and tonumber(v) then return tonumber(v) end
  end
  return nil
end

local ORE={"ore","miner","minério","minerio"}
local BAR={"bar","barr"}
local PLAN={"plan","blueprint","projeto"}

local function lsLine()
  local out={}
  for n,v in pairs(stats()) do
    table.insert(out,tostring(n)..": "..tostring(v))
    if #out>=4 then break end
  end
  if #out==0 then return "sem leaderstats neste jogo" end
  return table.concat(out,"   |   ")
end

--// PEPITAS: mina -> coleta -> inicio -> entrega
local ncache={t=0,list={}}
local function nuggets()
  local n=os.clock()
  if n-ncache.t<.7 then return ncache.list end
  ncache.t=n
  local out,seen={},{}
  local c=chr()
  local function add(o)
    if o and o.Parent and not seen[o] then seen[o]=true table.insert(out,o) end
  end
  for _,root in ipairs(workspace:GetChildren()) do
    if root~=workspace.CurrentCamera and not (c and root==c) then
      if root:IsA("BasePart") and has(root.Name,NUG) then add(root) end
      for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") and has(d.Name,NUG) then add(d)
        elseif d:IsA("ProximityPrompt") and d.Enabled and has((d.ActionText or "").." "..(d.ObjectText or "").." "..(d.Parent and d.Parent.Name or ""),NUG) then add(d.Parent)
        elseif d:IsA("ClickDetector") and has(d.Parent and d.Parent.Name or "",NUG) then add(d.Parent) end
      end
    end
  end
  for _,p in ipairs(prompts()) do
    if p.Enabled and has((p.ActionText or "").." "..(p.ObjectText or ""),{"colet","collect","pegar","pick"}) then add(p.Parent) end
  end
  ncache.list=out
  return out
end

local function touchPart(o)
  local r=hrp()
  if not r or not o then return false end
  if o:IsA("ProximityPrompt") then return fireP(o) end
  if o:IsA("ClickDetector") then return pcall(function() fireclickdetector(o) end) end
  local base=o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart",true)
  if not base and o.Parent then base=o.Parent:FindFirstChildWhichIsA("BasePart",true) end
  if not base then return false end
  local p=base.Position
  local up={1.5,0,3}
  for i=1,#up do
    pcall(function() r.CFrame=CFrame.new(p+Vector3.new(0,up[i],0)) end)
    pcall(function()
      if firetouchinterest then firetouchinterest(r,base,0) firetouchinterest(r,base,1) end
    end)
    task.wait(.06)
  end
  local par=base.Parent
  if par and par:IsA("Tool") then
    local h=hum()
    if h then pcall(function() h:EquipTool(par) end) end
  end
  for _,d in ipairs(base:GetChildren()) do
    if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end
    if d:IsA("ProximityPrompt") then fireP(d) end
  end
  return true
end

local function quota()
  local cap=num({"max","capac","cap","limite","slot","space","espa"})
  if cap and cap>0 then return math.floor(cap) end
  local q=num({"need","required","requis","quota","meta","objetivo","necessar","target","requer"})
  if q and q>0 then return math.floor(q) end
  local prog=num({"level","nivel","rank","prestig"}) or num(BAR) or 0
  return math.max(1,math.floor(CFG.NuggetNeed+prog*CFG.NuggetStep))
end

local function baseCF()
  if ST.home then return ST.home end
  local s=workspace:FindFirstChildOfClass("SpawnLocation")
  if s then return s.CFrame*CFrame.new(0,3,0) end
  local r=hrp()
  if r then ST.home=r.CFrame return ST.home end
end

local function goHome()
  local cf=baseCF()
  local r=hrp()
  if not cf or not r then return false end
  pcall(function() r.CFrame=cf end)
  task.wait(.35)
  return true
end

local function deliver()
  local list=findP(KEY.deliver,4)
  if #list==0 then list=findP(KEY.smelt,2) end
  if #list==0 then list=findP(KEY.hub,2) end
  for _,p in ipairs(list) do
    if CFG.TpSpot then tpNear(p,4) task.wait(.15) end
    if fireP(p) then return true end
  end
  local cf=baseCF()
  local hp=cf and cf.Position
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("BasePart") and has(d.Name,{"entreg","deposit","deliver","usina","machine","maquina","máquina","fundid","process"}) then
      if not hp or (d.Position-hp).Magnitude<180 then touchPart(d) return true end
    end
  end
  return false
end

local function equipDig()
  local bp=LP:FindFirstChild("Backpack")
  local h=hum()
  if not bp or not h then return false end
  for _,t in ipairs(bp:GetChildren()) do
    if t:IsA("Tool") and has(t.Name,KEY.dig) then
      if pcall(function() h:EquipTool(t) end) then return true end
    end
  end
  return false
end

local function rideDigger()
  local h=hum()
  local r=hrp()
  if not h or not r then return false end
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("VehicleSeat") and has(d.Name,{"escav","miner","dig","drill","trator"}) then
      pcall(function() r.CFrame=d.CFrame*CFrame.new(0,3,0) end)
      task.wait(.12)
      if pcall(function() d:Sit(h) end) then return true end
    end
  end
  return false
end

--// AUTOMACAO
local function autoDig()
  local sp=findP(KEY.dig,3)
  ST.spots=#sp
  if #sp==0 then ST.status="Nenhum ponto de escavação por perto" return end
  local p=sp[1]
  local base=p.Parent
  if CFG.TpSpot then tpNear(p,3.5) task.wait(.12) end
  equipDig()
  if fireP(p) then
    ST.status="Cavando: "..(base and base.Name or "?")
    ST.lastSpot=base
    ST.ores=ST.ores+1
    ST.session=ST.session+1
    ncache.t=0
  elseif ready("ride",2) and rideDigger() then
    ST.status="Usando a escavadeira"
  else
    ST.status="Prompt recusado: "..(base and base.Name or "?")
  end
end

local function autoSmelt()
  local sp=findP(KEY.smelt,3)
  if #sp==0 then ST.status="Fundidora não encontrada" return end
  local p=sp[1]
  if CFG.TpSpot then tpNear(p,5) task.wait(.15) end
  if fireP(p) then
    ST.status="Fundindo barras"
    ST.bars=ST.bars+1
  end
end

local function autoUpgrade()
  local sp=findP(KEY.up,2)
  if #sp==0 then return end
  local p=sp[1]
  if CFG.TpSpot then tpNear(p,5) task.wait(.15) end
  if fireP(p) then ST.status="Melhorando equipamento" end
end

local function autoQuiz()
  local sp=findP(KEY.quiz,4)
  if #sp==0 then ST.status="Nenhum quiz por perto" return end
  local p=sp[1]
  if CFG.TpSpot then tpNear(p,5) task.wait(.12) end
  fireP(p)
  ST.status="Respondendo quiz"
end

local function autoMuseum()
  local hub=findP(KEY.hub,1)
  if #hub>0 and CFG.TpSpot then tpNear(hub[1],6) task.wait(.2) end
  autoQuiz()
  ST.status="Museu: respondendo quizzes (UGC)"
end

local function nugTick()
  local s=ST.nug
  if not s then
    s={phase="mine",got=0,need=quota(),base=num(ORE) or 0}
    ST.nug=s ST.got=0 ST.need=s.need
  end
  ST.phase=s.phase
  local cur=num(ORE)
  if cur and s.base then s.got=math.max(s.got,cur-s.base) end
  if s.got<0 then s.got=0 end
  ST.got=s.got

  if s.phase=="mine" then
    local sp=findP(KEY.dig,3)
    ST.spots=#sp
    if #sp>0 then
      local p=sp[1]
      if CFG.TpSpot then tpNear(p,3.5) task.wait(.1) end
      equipDig()
      if fireP(p) then
        ST.lastSpot=p.Parent ncache.t=0
        ST.status="Escavando ("..s.got.."/"..s.need..")"
        ST.session=ST.session+1
      elseif ready("ride",2) and rideDigger() then
        ST.status="Usando a escavadeira"
      end
    elseif ready("ride",2) and rideDigger() then
      ST.status="Usando a escavadeira"
    end
    task.wait(.3)
    if #nuggets()>0 then s.phase="take"
    else ST.status="Procurando mina/pepitas ("..s.got.."/"..s.need..")" end

  elseif s.phase=="take" then
    local nl=nuggets()
    if #nl==0 then
      s.phase=(s.got>=s.need) and "home" or "mine"
      return
    end
    for i=1,math.min(#nl,5) do
      local o=nl[i]
      if o and o.Parent then
        touchPart(o)
        s.got=s.got+1
        local now=num(ORE)
        if now and s.base then s.got=math.max(s.got,now-s.base) end
        ST.got=s.got
        ST.status="Coletando pepita "..s.got.."/"..s.need
        task.wait(.1)
      end
    end
    ncache.t=0
    if s.got>=s.need then s.phase="home" end

  elseif s.phase=="home" then
    ST.status="Voltando ao início ("..s.got.."/"..s.need..")"
    goHome()
    s.phase="deliver"

  elseif s.phase=="deliver" then
    ST.status="Entregando "..s.got.." pepitas na máquina"
    local ok=deliver()
    task.wait(.4)
    if ok then
      s.got=0 ST.got=0
      s.base=num(ORE) or 0
      s.need=quota() ST.need=s.need
      s.phase="mine"
      ST.status="Entrega feita. Nova cota: "..s.need
      toast("Reaper Gold","Pepitas entregues. Nova cota: "..s.need..".",3)
      if CFG.AutoSmelt then autoSmelt() end
      if CFG.AutoUpgrade then autoUpgrade() end
    else
      s.phase="mine"
      ST.status="Máquina não achada — voltando à mina"
    end
  end
end

task.spawn(function()
  while gui.Parent do
    task.wait(.25)
    pcall(function()
      local ore=num(ORE) or ST.ores
      if CFG.Partner and CFG.AutoDig and ore>=CFG.SmeltAt and ready("partner",3) then
        ST.status="Saco cheio: voltando ao hub"
        local back=ST.lastSpot
        CFG.AutoDig=false
        local hub=findP(KEY.hub,1)
        if #hub>0 then tpNear(hub[1],6) task.wait(1) end
        autoSmelt() task.wait(1) autoUpgrade() task.wait(.6)
        if back and back.Parent then tpNear(back,5) end
        CFG.AutoDig=true
        ST.status="Voltando a cavar"
        return
      end
      if CFG.AutoDig and ready("dig",CFG.Delay) then autoDig() return end
      if CFG.AutoSmelt and ready("smelt",2.2) then
        local ore2=num(ORE) or ST.ores
        if ore2>=CFG.SmeltAt then autoSmelt() else ST.status="Aguardando "..CFG.SmeltAt.." minérios" end
        return
      end
      if CFG.AutoUpgrade and ready("up",6) then autoUpgrade() return end
      if CFG.AutoMission then return end
      if CFG.AutoNugget then
        if ready("nugtick",.35) then nugTick() end
        return
      end
      ST.nug=nil ST.phase="parado"
      if CFG.AutoNpc and ready("npc",5) then autoQuiz() return end
      if CFG.AutoMuseum and ready("mus",7) then autoMuseum() return end
    end)
  end
end)

--// ESP
local function headOf(c) return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") end
local function clearESP(c)
  local d=ST.esp[c]
  if not d then return end
  ST.esp[c]=nil
  if d.hl then d.hl:Destroy() end
  if d.bb then d.bb:Destroy() end
end
local function clearAll()
  for c in pairs(ST.esp) do clearESP(c) end
end
local function applyESP(c)
  if not c or c==chr() or ST.esp[c] then return end
  local h=c:FindFirstChildOfClass("Humanoid")
  if not h or h.Health<=0 then return end
  local pl=P:GetPlayerFromCharacter(c)
  if not pl then return end
  local hl=mk("Highlight",c,{Name="RGhl",Adornee=c,FillColor=GD,FillTransparency=.7,OutlineColor=C(255,255,255),OutlineTransparency=.35})
  local bb=mk("BillboardGui",c,{Name="RGbb",Adornee=c,Size=U2(0,150,0,22),StudsOffset=Vector3.new(0,3,0),AlwaysOnTop=true,MaxDistance=0,LightInfluence=0})
  local nm=mk("TextLabel",bb,{Size=U2(1,0,1,0),Text=pl.Name,Font=F.GothamBold,TextSize=12,TextColor3=GD,TextStrokeTransparency=.5})
  ST.esp[c]={hl=hl,bb=bb,nm=nm}
end
task.spawn(function()
  while gui.Parent do
    task.wait(.4)
    if CFG.Esp then
      for _,p in ipairs(P:GetPlayers()) do
        if p~=LP then applyESP(p.Character) end
      end
      for c,d in pairs(ST.esp) do
        local h=c:FindFirstChildOfClass("Humanoid")
        if not c.Parent or not h or h.Health<=0 then
          clearESP(c)
        else
          d.nm.Visible=CFG.EspName
        end
      end
    elseif next(ST.esp) then
      clearAll()
    end
  end
end)

--// AMBIENTE
local fogS={L.FogStart,L.FogEnd,L.FogColor}
local ligS={L.Brightness,L.OutdoorAmbient,L.GlobalShadows}
local function setFog(on)
  pcall(function()
    if on then L.FogStart=0 L.FogEnd=1000000 L.FogColor=C(200,200,200)
    else L.FogStart=fogS[1] L.FogEnd=fogS[2] L.FogColor=fogS[3] end
  end)
end
local function setFull(on)
  pcall(function()
    if on then L.Brightness=3 L.OutdoorAmbient=C(200,200,200) L.GlobalShadows=false
    else L.Brightness=ligS[1] L.OutdoorAmbient=ligS[2] L.GlobalShadows=ligS[3] end
  end)
end
local fxS={}
local function setLag(on)
  pcall(function()
    if on then
      for _,o in ipairs(L:GetChildren()) do
        if o:IsA("BloomEffect") or o:IsA("BlurEffect") or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") then
          if fxS[o]==nil then fxS[o]=o.Enabled end
          o.Enabled=false
        end
      end
    else
      for o,w in pairs(fxS) do if o.Parent then o.Enabled=w end end
      fxS={}
    end
  end)
end

--// TP HUB
local Store=(typeof(getgenv)=="function" and getgenv()) or _G
if type(Store.RG_TP_Logs)~="table" then Store.RG_TP_Logs={} end
ST.logs=Store.RG_TP_Logs

--// AUTO-EXECUTE (reenvia o script ao teleportar / trocar de servidor)
local SCRIPT_URL="https://raw.githubusercontent.com/Yuzorap53673gls/neter/main/ReaperGold.min.lua"
local LOADER='loadstring(game:HttpGet("'..SCRIPT_URL..'"))()'
local qtp=(syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queue_on_teleport or Store.queue_on_teleport

local function autoExec(on)
  CFG.AutoExec=on and true or false
  if not on then
    if qtp then pcall(qtp,"") end
    Store.RG_AUTO=nil
    return false
  end
  Store.RG_AUTO=LOADER
  if qtp then pcall(qtp,LOADER) end
  return true
end

--// MISSOES: Trem de Noobs / Chao e Lava (loop automatico)
local MISS={{n="Trem de Noobs",w={"noob","trem","train","nobb"}},
            {n="Chão e Lava",w={"lava","chao","chão","floor","ground"}}}
local BTP={"teletransport","teleport","entrar","start","jogar","play"}
local SMW={"fundir","fundição","fundicao","smelt","processar"}

local function uiBtns(words)
  local out={}
  local function scan(g)
    if not g then return end
    for _,d in ipairs(g:GetDescendants()) do
      if d:IsA("GuiButton") and d.Visible and has(d.Text or "",words) then out[#out+1]=d end
    end
  end
  pcall(function() scan(game:GetService("CoreGui")) end)
  pcall(function() scan(LP:FindFirstChild("PlayerGui")) end)
  if gethui then pcall(function() scan(gethui()) end) end
  return out
end

local function clickText(words)
  for _,b in ipairs(uiBtns(words)) do
    local ok=false
    if firesignal then ok=pcall(firesignal,b.MouseButton1Click) end
    if not ok then ok=pcall(function() b.MouseButton1Click:Fire() end) end
    if ok then return true end
  end
  return false
end

local function tpPart(p)
  local r=hrp()
  if not r or not p or not p:IsA("BasePart") then return false end
  local pos=p.Position
  pcall(function() r.CFrame=CFrame.new(pos+Vector3.new(0,3,0),pos) end)
  return true
end

local function namedParts(words)
  local out={}
  for _,root in ipairs(workspace:GetChildren()) do
    if has(root.Name,words) then
      local b=root:IsA("BasePart") and root or root:FindFirstChildWhichIsA("BasePart",true)
      if b then out[#out+1]=b end
    end
  end
  return out
end

local function mPhase(p)
  ST.mphase=p
  Store.RG_MISSION={phase=p,mission=CFG.Mission,waitmode=CFG.WaitMode,idx=ST.midx}
end

if type(Store.RG_MISSION)=="table" then
  CFG.Mission=Store.RG_MISSION.mission or CFG.Mission
  CFG.WaitMode=Store.RG_MISSION.waitmode or CFG.WaitMode
  ST.midx=Store.RG_MISSION.idx or 1
  if Store.RG_MISSION.phase=="dig" or Store.RG_MISSION.phase=="smelt" then
    ST.mphase=Store.RG_MISSION.phase
  end
end

pcall(function()
  LP.OnTeleport:Connect(function(state)
    if state~=Enum.TeleportState.Started then return end
    if ST.mphase=="enter" then Store.RG_MISSION={phase="dig",mission=CFG.Mission,waitmode=CFG.WaitMode,idx=1} end
    if ST.mphase=="portal" then Store.RG_MISSION={phase="smelt",mission=CFG.Mission,waitmode=CFG.WaitMode,idx=1} end
  end)
end)

local function missionTick()
  local ph=ST.mphase
  if ph=="check" then
    local pend=num(ORE) or 0
    if CFG.DeliverFirst and (pend>0 or ST.got>0) then
      ST.status="Entregando ouro pendente ("..pend..") antes das missões"
      local sp=findP(KEY.deliver,4)
      if #sp==0 then sp=findP(KEY.smelt,3) end
      if #sp>0 and CFG.TpSpot then tpNear(sp[1],4) end
      clickText(SMW)
      clickText({"entregar","depositar","deliver","deposit"})
      task.wait(2)
      ST.got=0
      if ST.nug then ST.nug.got=0 ST.nug.base=num(ORE) or 0 end
      ST.status="Entrega concluída. Iniciando missão"
    end
    mPhase("enter")

  elseif ph=="enter" then
    local m=MISS[CFG.Mission] or MISS[1]
    ST.status="Entrando: "..m.n
    local c=namedParts(m.w)
    if #c>0 then tpPart(c[1]) task.wait(.1) end
    if CFG.WaitMode==2 then clickText(m.w) end
    Store.RG_MISSION={phase="dig",mission=CFG.Mission,waitmode=CFG.WaitMode,idx=1}
    clickText(BTP)
    autoExec(true)
    mPhase("dig")

  elseif ph=="dig" then
    local sp=findP(KEY.dig,10)
    if #sp==0 then
      ST.status="Fim da escavação — indo ao portal"
      mPhase("portal")
      return
    end
    if ST.midx>#sp then ST.midx=1 end
    local t=sp[ST.midx]
    if CFG.TpSpot then tpNear(t,3) end
    equipDig()
    fireP(t)
    ST.midx=ST.midx+1
    ST.spots=#sp
    ST.status="WGC Gold Hunters: "..(ST.midx-1).."/"..#sp

  elseif ph=="portal" then
    ST.status="Portal Caçadores de Ouro 2.0"
    local c=namedParts({"portal","caçad","cacad","hunter","goldhunter","2.0","lobby"})
    if #c>0 then tpPart(c[1]) task.wait(.1) end
    Store.RG_MISSION={phase="smelt",mission=CFG.Mission,waitmode=CFG.WaitMode,idx=1}
    clickText(BTP)
    autoExec(true)
    mPhase("smelt")

  elseif ph=="smelt" then
    ST.status="Area de fundir ouro"
    local sp=findP(KEY.smelt,3)
    if #sp>0 and CFG.TpSpot then tpNear(sp[1],4) end
    clickText(SMW)
    task.wait(2)
    ST.mwait=os.clock()
    mPhase("wait")

  elseif ph=="wait" then
    if CFG.WaitMode==1 then
      local left=10-(os.clock()-ST.mwait)
      if left<=0 then
        ST.status="10s: reentrando na missão"
        clickText(BTP)
        mPhase("enter")
      else
        ST.status="Verificando/entregando barras: "..math.ceil(left).."s"
      end
    else
      local m=MISS[CFG.Mission] or MISS[1]
      if clickText(m.w) then
        ST.status="Botão da missão acionado"
        mPhase("enter")
      else
        ST.status="Botão da missão não encontrado"
        task.wait(1)
      end
    end
  end
end

task.spawn(function()
  while gui.Parent do
    task.wait(.3)
    pcall(function() if CFG.AutoMission and ready("mission",.5) then missionTick() end end)
  end
end)

local logScroll
local function renderLogs()
  if not logScroll then return end
  for _,c in ipairs(logScroll:GetChildren()) do
    if c:IsA("TextLabel") then c:Destroy() end
  end
  for i,it in ipairs(ST.logs) do
    mk("TextLabel",logScroll,{Size=U2(1,-6,0,14),Position=U2(0,3,0,(i-1)*15),Text="["..it.t.."] "..it.n.." ("..it.c..")",Font=F.Gotham,TextSize=9,TextColor3=C(150,245,175),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
  end
  pcall(function() logScroll.CanvasSize=U2(0,0,0,math.max(44,#ST.logs*15+6)) end)
end

local function addLog(plr,cf)
  local n=(typeof(plr)=="Instance" and plr.Name) or tostring(plr or "?")
  local p=(typeof(cf)=="CFrame" and cf.Position) or cf
  table.insert(ST.logs,1,{t=os.date("%H:%M:%S"),n=n,c=string.format("%.0f,%.0f,%.0f",p.X,p.Y,p.Z)})
  while #ST.logs>80 do table.remove(ST.logs) end
  renderLogs()
end

local function refreshTarget()
  local list=P:GetPlayers()
  if #list==0 then ST.target=LP return end
  if ST.idx>#list then ST.idx=1 end
  ST.target=list[ST.idx]
end

local function tpTo(plr)
  if not CFG.TpOn then ST.status="Sistema TP desligado" return end
  if not ST.dest then ST.status="Salve um destino primeiro" return end
  if not plr or not plr.Parent then refreshTarget() ST.status="Sem alvo" return end
  local r=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
  if not r then ST.status="Alvo sem personagem" return end
  local dest=ST.dest+Vector3.new(0,3,0)
  pcall(function() r.CFrame=dest end)
  addLog(plr,dest)
  ST.status="TP: "..plr.Name
end

local function saveDest()
  local r=hrp()
  if not r then return end
  ST.dest=r.CFrame
  toast("TP Hub","Destino salvo.",3)
end

--// PAGINAS: conteudo
local home=pages.Home
sect(home,"Jogador")
local homeName=mk("TextLabel",home,{Size=U2(1,0,0,32),BackgroundColor3=RW,BackgroundTransparency=0,Font=F.GothamBold,TextSize=12,TextColor3=TX,LayoutOrder=ord+1})
mk("UICorner",homeName,{CornerRadius=UD(0,8)})
ord=ord+1
sect(home,"Atalhos")
btn(home,"Abrir Automação",function() show("Automacao") end)
btn(home,"Abrir TP Hub",function() show("TP Hub") end)
btn(home,"Abrir Info (tutorial)",function() show("Info") end)
sect(home,"Ao vivo")
local homeLive=note(home,"",62)
homeLive.Font=F.Code

--// AUTOMACAO
local host=mk("Frame",cont,{Size=U2(1,-16,1,-16),Position=U2(0,8,0,8),BackgroundTransparency=1,Visible=false})
pages.Automacao=host
local SEG={"Automação","Painel","Ajustes"}
local segP,segB={},{}
for i,n in ipairs(SEG) do
  local b=mk("TextButton",host,{Size=U2(1/3,-6,0,30),Position=U2((i-1)/3,4,0,0),BackgroundColor3=RW,Text=n,Font=F.GothamBold,TextSize=10,TextColor3=MU})
  mk("UICorner",b,{CornerRadius=UD(0,8)})
  local p=mkScroll(host,U2(1,0,1,-40),U2(0,0,0,40))
  p.Visible=(i==1)
  segP[n]=p segB[n]=b
  b.MouseButton1Click:Connect(function()
    for m,q in pairs(segP) do q.Visible=(m==n) end
    for m,q in pairs(segB) do
      local on=(m==n)
      q.BackgroundColor3=on and GD or RW
      q.TextColor3=on and C(30,23,10) or MU
    end
  end)
end
for m,q in pairs(segB) do
  local on=(m=="Automação")
  q.BackgroundColor3=on and GD or RW
  q.TextColor3=on and C(30,23,10) or MU
end

local au=segP["Automação"]
sect(au,"LOOP DE MISSÃO (principal)")
local m1,m2,wb
local function paintMission()
  if m1 then m1:FindFirstChildWhichIsA("TextLabel").Text=(CFG.Mission==1 and "> " or "   ").."Missão: Trem de Noobs" end
  if m2 then m2:FindFirstChildWhichIsA("TextLabel").Text=(CFG.Mission==2 and "> " or "   ").."Missão: Chão e Lava" end
  if wb then wb:FindFirstChildWhichIsA("TextLabel").Text="Entrega: "..(CFG.WaitMode==1 and "esperar 10 segundos" or "clicar no botão da missão") end
end
m1=btn(au,"Missão: Trem de Noobs",function() CFG.Mission=1 paintMission() end)
m2=btn(au,"Missão: Chão e Lava",function() CFG.Mission=2 paintMission() end)
wb=btn(au,"Entrega: esperar 10 segundos",function() CFG.WaitMode=CFG.WaitMode==1 and 2 or 1 paintMission() end)
paintMission()
card(au,"Auto Missão (loop)","Entra na missão, escava no WGC, vai ao portal, funde e repete","AutoMission")
card(au,"Auto-Execute","Reexecuta sozinho ao teleportar/sair do servidor","AutoExec",function(v) autoExec(v) end)
tog(au,"Entregar ouro antes das missões","DeliverFirst")
sect(au,"Automação do jogo")
card(au,"Auto Cavar","Equipa a escavadeira e escava nos pontos de minério","AutoDig")
card(au,"Auto Fundir Barras","Smelta quando tiver 10+ minérios de ouro","AutoSmelt")
card(au,"Auto Melhorar","Usa a fundidora/equipamento para melhorar sozinho","AutoUpgrade")
card(au,"Auto NPC Quiz (+1 barra)","Responde o quiz do NPC a cada 2 horas","AutoNpc")
card(au,"Auto Museu (UGC)","Resolve os 6 quizzes do museu para liberar UGC","AutoMuseum")
card(au,"Auto Coletar Pepitas","Vai à mina, escava, pega a cota e entrega na máquina","AutoNugget")
card(au,"Modo Parceiro","Cava e, ao encher o saco, volta ao hub para fundir e melhorar","Partner")
sect(au,"Ajustes rápidos")
step(au,"Cota base de pepitas","NuggetNeed",1,1,99)
step(au,"Aumento da cota por progresso","NuggetStep",1,0,10)
step(au,"Fundir a partir de (minério)","SmeltAt",1,1,99)
step(au,"Intervalo do cavar (s)","Delay",0.2,0.4,6)
tog(au,"Teleportar até o ponto","TpSpot")

local pa=segP["Painel"]
sect(pa,"Telemetria ao vivo")
local tele=note(pa,"",66)
tele.Font=F.Code
sect(pa,"Status da automação")
local stat=note(pa,"",44)
sect(pa,"Leitura do jogo")
local lsl=note(pa,"",44)
lsl.Font=F.Code
btn(pa,"Escanear prompts do mapa",function()
  local n=#prompts()
  ST.status="Prompts encontrados: "..n.."  |  pontos de escavação: "..#findP(KEY.dig,9)
end)
btn(pa,"Zerar contadores da sessão",function() ST.session=0 ST.ores=0 ST.bars=0 ST.status="Contadores zerados" end)

local aj=segP["Ajustes"]
sect(aj,"Comportamento")
tog(aj,"Notificações do sistema","Notify")
tog(aj,"Sistema TP ativo","TpOn")
step(aj,"Escala da interface %","Scale",10,60,180,function(v) uisc.Scale=v/100 end)
sect(aj,"Manutenção")
btn(aj,"Resetar toda a configuração",function()
  CFG.AutoDig=false CFG.AutoSmelt=false CFG.AutoUpgrade=false CFG.AutoNpc=false
  CFG.AutoMuseum=false CFG.AutoNugget=false CFG.Partner=false CFG.AutoMission=false CFG.AutoExec=false CFG.DeliverFirst=false
  CFG.Esp=false CFG.Fog=false CFG.Full=false CFG.AntiLag=false
  CFG.Speed=16 CFG.Jump=50 CFG.InfJump=false CFG.Noclip=false
  CFG.SmeltAt=10 CFG.Delay=1.2 CFG.TpSpot=true
  setFog(false) setFull(false) setLag(false) clearAll() trail(false)
  toast("Reaper Gold","Configuração resetada.",3)
end)

--// TP HUB
local tp=pages["TP Hub"]
sect(tp,"Alvo")
refreshTarget()
local function tgtTxt() return "Alvo: "..(ST.target and ST.target.Name or "?")..(ST.target==LP and " (você)" or "").."  v" end
local tgtBtn=mk("TextButton",tp,{Size=U2(1,0,0,32),BackgroundColor3=C(36,28,52),Font=F.GothamBold,TextSize=11,TextColor3=TX,Text=tgtTxt(),LayoutOrder=ord+1})
mk("UICorner",tgtBtn,{CornerRadius=UD(0,8)})
ord=ord+1
tgtBtn.MouseButton1Click:Connect(function()
  local list=P:GetPlayers()
  if #list==0 then return end
  ST.idx=(ST.idx%#list)+1
  ST.target=list[ST.idx]
  tgtBtn.Text=tgtTxt()
end)
sect(tp,"Destino")
btn(tp,"Salvar destino (minha posição agora)",saveDest)
btn(tp,"Teleportar em mim",function() tpTo(LP) end)
btn(tp,"Mandar alvo para o destino",function() tpTo(ST.target) end)
sect(tp,"Sistema")
tog(tp,"Sistema de TP ligado","TpOn")
sect(tp,"Logs (permanentes)")
logScroll=mk("ScrollingFrame",tp,{Size=U2(1,0,0,96),BackgroundColor3=PN,ScrollBarThickness=3,ScrollBarImageColor3=C(120,96,120),CanvasSize=U2(0,0,0,0),LayoutOrder=ord+1})
mk("UICorner",logScroll,{CornerRadius=UD(0,8)})
ord=ord+1
renderLogs()
btn(tp,"Limpar logs",function() table.clear(ST.logs) renderLogs() end)
note(tp,"Salve um destino antes de teleportar. O alvo é o jogador escolhido no botão acima. Logs ficam salvos entre execuções.",44)

--// PERSONAGEM
local chp=pages["Personagem"]
sect(chp,"Movimento")
step(chp,"Walk Speed","Speed",1,8,300,applyChar)
step(chp,"Jump Power","Jump",5,20,400,applyChar)
tog(chp,"Pulo infinito","InfJump")
tog(chp,"Sem colisão (noclip)","Noclip")
sect(chp,"Aparência")
tog(chp,"Trail no personagem","Trails",function(v) trail(v) end)
tog(chp,"Avatar noob","Avatar",function(v) avatarNoob(v) end)
step(chp,"Tamanho do noob %","NoobSize",10,30,200,function(v) setSize(v) end)
btn(chp,"Restaurar tamanho (100%)",function() setSize(100) end)

--// VISUAL
local vs=pages.Visual
sect(vs,"Jogadores")
tog(vs,"ESP (destaque + nome)","Esp",function(v) if not v then clearAll() end end)
tog(vs,"Mostrar nome","EspName")
sect(vs,"Ambiente")
tog(vs,"Remover neblina","Fog",function(v) setFog(v) end)
tog(vs,"Fullbright","Full",function(v) setFull(v) end)
tog(vs,"Anti-lag","AntiLag",function(v) setLag(v) end)
note(vs,"Destaque dourado nos jogadores visíveis. Nome em cima da cabeça.",40)

--// CONFIG
local cfgP=pages.Config
sect(cfgP,"Interface")
tog(cfgP,"Mostrar HUD no jogo","Hud",function(v) hud.Visible=v end)
step(cfgP,"Escala da interface %","Scale",10,60,180,function(v) uisc.Scale=v/100 end)
btn(cfgP,"Centralizar janela",function()
  local v=workspace.CurrentCamera.ViewportSize
  win.Position=U2(0,math.max(8,(v.X-WW)/2),0,64)
  win.Size=U2(0,WW,0,WH)
end)
sect(cfgP,"Servidor")
btn(cfgP,"Copiar JobId",function() if setclipboard then setclipboard(game.JobId) end toast("Reaper Gold","JobId copiado.",3) end)
btn(cfgP,"Reconectar neste servidor",function() pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end) end)

--// INFO
local inf=pages.Info
sect(inf,"Como usar")
note(inf,"1. Abra Automação e ligue o que quiser.\n2. O status aparece no rodapé do painel.\n3. Dúvida de alguma função? Está tudo aqui embaixo.",62)
sect(inf,"Cada função")
note(inf,[[
LOOP DE MISSÃO: ao entrar no jogo, entrega o ouro pendente, TP na missão escolhida
(Trem de Noobs OU Chão e Lava) e aperta o botão Teletransportar.
Auto-executa, escava todos os pontos WGC Gold Hunters, TP no portal
Caçadores de Ouro 2.0, volta ao início, TP na área de fundir, clica Fundir,
espera 2s e espera 10s (ou clica o botão da missão — opção para testar).
Repete infinito até desligar. TP é instantâneo.
AUTO CAVAR: equipa a escavadeira, vai ao ponto e aciona o prompt (hold).
AUTO FUNDIR: com X minérios, vai à fundidora e transforma em barras.
AUTO MELHORAR: procura prompts de melhoria e aciona sozinho.
AUTO NPC QUIZ: responde o quiz do NPC (+1 barra a cada 2h).
AUTO MUSEU: resolve os 6 quizzes do museu (tiers de UGC).
AUTO PEPITAS: vai à mina, escava, coleta a cota (que cresce com o progresso),
volta ao início e entrega as pepitas na máquina.
AUTO-EXECUTE: reexecuta o script ao teleportar/sair do servidor.
]],296)
sect(inf,"TP HUB")
note(inf,[[
Salvar destino: guarda onde você está agora.
TP em mim: leva você para o destino salvo.
Mandar alvo: leva o jogador escolhido para o destino.
Logs: histórico de quem foi teleportado, com hora e coordenadas.
]],86)
sect(inf,"Atalhos da HUD")
note(inf,[[
Informação: abre esta aba (botão da HUD).
UGC: liga o auto museu.
Noob Size: muda o tamanho do personagem.
Avatar: alterna o visual noob.
Trails: rastro dourado.
Settings: abre Config.
]],110)

--// NOVIDADES
local nv=pages.Novidades
sect(nv,"v1 - inicial")
note(nv,[[
* Base visual do Reaper Aim.
* Automação: cavar, fundir, melhorar,
  NPC quiz, museu UGC e pepitas.
* Modo parceiro (cava + funde + volta).
* Painel de telemetria e status.
* HUD: Barras, Mina, Planos + dock.
* Noob Size, Avatar, Trails.
* TP Hub com alvo, destino e logs.
* Aba Info explicando cada função.
]],168)

--// CREDITOS
local cd=pages.Creditos
sect(cd,"Sobre")
note(cd,"Reaper Gold Hub v1\nEstilo: Reaper Aim\nFeito para PC e celular.\nSem tecla de atalho.",74)

--// HUD
hud=mk("Frame",gui,{Size=U2(1,0,1,0),BackgroundTransparency=1,Visible=CFG.Hud})
local function statCard(y,title)
  local f=mk("Frame",hud,{Size=U2(0,112,0,40),Position=U2(0,12,0,y),BackgroundColor3=C(26,22,30),BackgroundTransparency=.15})
  mk("UICorner",f,{CornerRadius=UD(0,8)})
  mk("UIStroke",f,{Color=C(92,74,92),Thickness=1,Transparency=.5})
  mk("TextLabel",f,{Size=U2(1,0,0,13),Position=U2(0,0,0,4),Text=title,Font=F.GothamBold,TextSize=10,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Center})
  local v=mk("TextLabel",f,{Size=U2(1,0,0,18),Position=U2(0,0,0,17),Text="0",Font=F.GothamBold,TextSize=15,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Center})
  return v
end
local vBars=statCard(58,"Barras de Ouro")
local vOre=statCard(102,"Mina de Ouro")
local vPlan=statCard(146,"Planos")

local infoB=mk("TextButton",hud,{Size=U2(0,104,0,28),Position=U2(0,150,0,14),BackgroundColor3=C(24,21,30),Text="Informação",Font=F.GothamBold,TextSize=11,TextColor3=TX})
mk("UICorner",infoB,{CornerRadius=UD(1,0)})
mk("UIStroke",infoB,{Color=C(92,74,92),Thickness=1,Transparency=.5})
infoB.MouseButton1Click:Connect(function() setMini(false) show("Info") end)

local sizes={100,70,130}
local si=1
local function dockBtn(i,txt,fn)
  local b=mk("TextButton",hud,{Size=U2(0,112,0,28),Position=U2(1,-122,0,58+(i-1)*32),BackgroundColor3=C(24,21,30),BackgroundTransparency=.12,Text=txt,Font=F.GothamBold,TextSize=11,TextColor3=TX})
  mk("UICorner",b,{CornerRadius=UD(0,7)})
  mk("UIStroke",b,{Color=C(92,74,92),Thickness=1,Transparency=.5})
  b.MouseButton1Click:Connect(function() local ok,e=pcall(fn) if not ok then warn("[Reaper] "..tostring(e)) end end)
  return b
end
dockBtn(1,"UGC",function() CFG.AutoMuseum=not CFG.AutoMuseum show("Automacao") toast("Reaper Gold",CFG.AutoMuseum and "Auto museu ligado." or "Auto museu desligado.",3) end)
dockBtn(2,"Noob Size",function() si=(si%#sizes)+1 setSize(sizes[si]) toast("Reaper Gold","Tamanho: "..sizes[si].."%",2) end)
dockBtn(3,"Avatar Toggle",function() CFG.Avatar=not CFG.Avatar avatarNoob(CFG.Avatar) end)
dockBtn(4,"Trails",function() CFG.Trails=not CFG.Trails trail(CFG.Trails) toast("Reaper Gold",CFG.Trails and "Trail ligado." or "Trail desligado.",2) end)
dockBtn(5,"Settings",function() setMini(false) show("Config") end)

--// LOOPS

task.spawn(function()
  while gui.Parent do
    task.wait(1)
    pcall(function()
      vBars.Text=tostring(num(BAR) or ST.bars)
      vOre.Text=tostring(num(ORE) or ST.ores)
      vPlan.Text=tostring(num(PLAN) or ST.bp)
    end)
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(.6)
    pcall(function()
      local ore=num(ORE) or ST.ores
      local bar=num(BAR) or ST.bars
      tele.Text=string.format("Barras: %s\nMinério: %s / %d\nPepitas: %d / %d (%s)\nMissão: %s  |  fase: %s\nSessão: +%d minérios   Pontos: %d",
        tostring(bar or "-"),tostring(ore or "-"),CFG.SmeltAt,ST.got,ST.need,ST.phase,
        MISS[CFG.Mission] and MISS[CFG.Mission].n or "?",ST.mphase,ST.session,ST.spots)
      stat.Text="Status: "..ST.status
      lsl.Text=lsLine()
    end)
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(2)
    pcall(function()
      if pages.Home.Visible then
        local h=hum()
        homeName.Text="   "..LP.Name..(h and ("    |    HP "..math.floor(h.Health)) or "")
        homeLive.Text=string.format("Missão: %s   Loop: %s\nPepitas: %d/%d   AutoExec: %s\nStatus: %s",
          MISS[CFG.Mission] and MISS[CFG.Mission].n or "?",CFG.AutoMission and "ON" or "OFF",
          ST.got,ST.need,CFG.AutoExec and "ON" or "OFF",ST.status)
      end
      local ls=LP:FindFirstChild("leaderstats")
      if ls then
        for _,v in ipairs(ls:GetChildren()) do
          if v:IsA("ValueBase") then
            if has(v.Name,ORE) then ST.ores=tonumber(v.Value) or ST.ores end
            if has(v.Name,BAR) then ST.bars=tonumber(v.Value) or ST.bars end
          end
        end
      end
    end)
  end
end)

bClose.MouseButton1Click:Connect(function()
  pcall(function() clearAll() end)
  pcall(trail,false)
  pcall(setFog,false) pcall(setFull,false) pcall(setLag,false)
  pcall(function()
    local h=hum()
    if h then h.WalkSpeed=16 if h.UseJumpPower then h.JumpPower=50 end end
  end)
  CFG.AutoDig=false CFG.AutoSmelt=false CFG.AutoUpgrade=false
  CFG.AutoNpc=false CFG.AutoMuseum=false CFG.AutoNugget=false CFG.Partner=false
  CFG.AutoMission=false CFG.AutoExec=false CFG.DeliverFirst=false
  if qtp then pcall(qtp,"") end
  Store.RG_AUTO=nil Store.RG_MISSION=nil
  gui:Destroy()
  toast("Reaper Gold","Fechado e automações desligadas.",3)
end)
bMin.MouseButton1Click:Connect(function() setMini(true) end)

refreshTarget()
renderLogs()
show("Home")
task.spawn(function() for _=1,40 do pcall(function() applyChar() end) task.wait(.4) end end)
if CFG.AutoExec then autoExec(true) end
toast("Reaper Gold v1","Missão "..MISS[CFG.Mission].n.." | auto-execute ligado.",5)
