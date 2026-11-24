--// REAPER AIM | v21  (PC + celular)
local P=game:GetService("Players")
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local L=game:GetService("Lighting")
local TPS=game:GetService("TeleportService")
local LP=P.LocalPlayer
local U2=UDim2.new local UD=UDim.new local C=Color3.fromRGB
local F=Enum.Font local EIT=Enum.UserInputType local KC=Enum.KeyCode

local AC=C(255,66,96) local GR=C(38,199,122) local BG=C(26,20,24)
local PN=C(20,15,19) local RW=C(34,27,32) local RV=C(43,34,40)
local TX=C(238,233,237) local MU=C(146,136,145)

local CFG={Aimbot=false,ToggleMode=false,TeamCheck=false,WallCheck=true,
Prediction=false,AutoFire=false,Mode="Camera",FOV=140,Smooth=100,
ESP=false,Antenna=false,LootESP=false,NoFog=false,Fullbright=false,
AntiLag=false,Fly=false,FlySpeed=60,WalkSpeed=16,JumpPower=50,
AutoMed=false,MedAt=60}

local ST={firing=false,fireUntil=0,flyUp=false,flyDown=false,lock=nil,
esp={},loot={},bots={},lastMed=0}

local function mk(c,p,t)
  local o=Instance.new(c)
  if t then for k,v in pairs(t) do o[k]=v end end
  if p then o.Parent=p end
  return o
end

local function toast(a,b,d)
  pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification",
      {Title=tostring(a),Text=tostring(b),Duration=d or 4})
  end)
end

--// JANELA
local gui=mk("ScreenGui",nil,{Name="ReaperAim",ResetOnSpawn=false,
IgnoreGuiInset=true,DisplayOrder=9999})
local okp=pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not okp or not gui.Parent then
  pcall(function() gui.Parent=LP:WaitForChild("PlayerGui",10) end)
end
if not gui.Parent then gui:Destroy() toast("Reaper Aim","Executor bloqueou a interface.",6) return end

local VPS=workspace.CurrentCamera.ViewportSize
local WW=math.min(520,VPS.X-24)
local WH=math.min(432,VPS.Y-120)
local SW=WW<420 and 118 or 148

local win=mk("Frame",gui,{Size=U2(0,WW,0,WH),
Position=U2(0,math.max(8,(VPS.X-WW)/2),0,70),BackgroundColor3=BG,
BorderSizePixel=0,Active=true,ClipsDescendants=true})
mk("UICorner",win,{CornerRadius=UD(0,10)})
mk("UIStroke",win,{Color=C(52,40,48),Thickness=1})

local bar=mk("Frame",win,{Size=U2(1,0,0,40),BackgroundColor3=PN,BorderSizePixel=0,Active=true})
mk("UICorner",bar,{CornerRadius=UD(0,10)})
mk("Frame",bar,{Size=U2(1,0,0,14),Position=U2(0,0,1,-14),BackgroundColor3=PN,BorderSizePixel=0})

local dot=mk("Frame",bar,{Size=U2(0,9,0,9),Position=U2(0,14,.5,-4.5),
BackgroundColor3=AC,BorderSizePixel=0})
mk("UICorner",dot,{CornerRadius=UD(1,0)})

mk("TextLabel",bar,{Size=U2(0,200,1,0),Position=U2(0,30,0,0),
BackgroundTransparency=1,Text="Reaper Aim",Font=F.GothamSemibold,TextSize=13,
TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left})

local function bb(txt,x)
  local b=mk("TextButton",bar,{Size=U2(0,28,0,26),Position=U2(1,x,.5,-13),
  BackgroundTransparency=1,BorderSizePixel=0,Text=txt,Font=F.GothamBold,
  TextSize=13,TextColor3=MU,AutoButtonColor=false,ZIndex=4})
  mk("UICorner",b,{CornerRadius=UD(0,6)})
  b.MouseEnter:Connect(function() b.TextColor3=TX b.BackgroundTransparency=.4 end)
  b.MouseLeave:Connect(function() b.TextColor3=MU b.BackgroundTransparency=1 end)
  return b
end
local bMin=bb("-",-96) local bMax=bb("o",-64) local bClose=bb("X",-32)

local drag,dS,dP=false,nil,nil
bar.InputBegan:Connect(function(i)
  if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then
    drag=true dS=i.Position dP=win.Position
    i.Changed:Connect(function()
      if i.UserInputState==Enum.UserInputState.End then drag=false end
    end)
  end
end)
UIS.InputChanged:Connect(function(i)
  if not drag then return end
  if i.UserInputType==EIT.MouseMovement or i.UserInputType==EIT.Touch then
    local d=i.Position-dS
    win.Position=U2(dP.X.Scale,dP.X.Offset+d.X,dP.Y.Scale,dP.Y.Offset+d.Y)
  end
end)

local col=false
bMin.MouseButton1Click:Connect(function()
  col=not col
  win.Size=col and U2(0,WW,0,40) or U2(0,WW,0,WH)
end)
local zoom=false
bMax.MouseButton1Click:Connect(function()
  zoom=not zoom
  if zoom then
    win.Position=U2(0,6,0,6) win.Size=U2(1,-12,1,-12)
  else
    win.Position=U2(0,math.max(8,(VPS.X-WW)/2),0,70) win.Size=U2(0,WW,0,WH)
  end
end)
bClose.MouseButton1Click:Connect(function()
  gui:Destroy() toast("Reaper Aim","Fechado. Execute de novo.",3)
end)

local side=mk("Frame",win,{Size=U2(0,SW,1,-40),Position=U2(0,0,0,40),
BackgroundColor3=PN,BorderSizePixel=0})
local cont=mk("Frame",win,{Size=U2(1,-SW,1,-40),Position=U2(0,SW,0,40),
BackgroundColor3=BG,BorderSizePixel=0})

local pages,navs={},{}
local NAV={{"Home","#"},{"Visuals","*"},{"Aimbot","@"},{"FPS","%"},
{"Character","+"},{"Config","="},{"Creditos","i"}}

local ord=0
local function newPage(k)
  local p=mk("ScrollingFrame",cont,{Size=U2(1,-16,1,-16),Position=U2(0,8,0,8),
  BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
  ScrollBarImageColor3=C(70,58,66),CanvasSize=U2(0,0,0,0),Visible=false})
  local ly=mk("UIListLayout",p,{Padding=UD(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
  ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    p.CanvasSize=U2(0,0,0,ly.AbsoluteContentSize.Y+10)
  end)
  pages[k]=p
  return p
end

local function show(k)
  for n,p in pairs(pages) do p.Visible=(n==k) end
  for n,v in pairs(navs) do
    local on=(n==k)
    v.bg.BackgroundColor3=on and C(46,33,40) or PN
    v.bar.Visible=on
    v.txt.TextColor3=on and TX or MU
    v.gl.TextColor3=on and AC or MU
  end
end

for i,it in ipairs(NAV) do
  local b=mk("TextButton",side,{Size=U2(1,-16,0,34),Position=U2(0,8,0,8+(i-1)*38),
  BackgroundColor3=PN,BorderSizePixel=0,Text="",AutoButtonColor=false})
  mk("UICorner",b,{CornerRadius=UD(0,7)})
  local bar0=mk("Frame",b,{Size=U2(0,3,0,16),Position=U2(0,-8,.5,-8),
  BackgroundColor3=AC,BorderSizePixel=0,Visible=false})
  mk("UICorner",bar0,{CornerRadius=UD(1,0)})
  local gl=mk("TextLabel",b,{Size=U2(0,18,1,0),Position=U2(0,10,0,0),
  BackgroundTransparency=1,Text=it[2],Font=F.GothamBold,TextSize=13,TextColor3=MU})
  local tx=mk("TextLabel",b,{Size=U2(1,-34,1,0),Position=U2(0,32,0,0),
  BackgroundTransparency=1,Text=it[1],Font=F.GothamMedium,TextSize=12,
  TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left})
  navs[it[1]]={bg=b,bar=bar0,gl=gl,txt=tx}
  b.MouseButton1Click:Connect(function() show(it[1]) end)
  newPage(it[1])
end

local chip=mk("Frame",side,{Size=U2(1,-16,0,34),Position=U2(0,8,1,-42),
BackgroundTransparency=1})
local av=mk("Frame",chip,{Size=U2(0,24,0,24),Position=U2(0,4,.5,-12),
BackgroundColor3=AC,BorderSizePixel=0})
mk("UICorner",av,{CornerRadius=UD(1,0)})
mk("TextLabel",av,{Size=U2(1,0,1,0),BackgroundTransparency=1,
Text=string.sub(LP.Name,1,1):upper(),Font=F.GothamBold,TextSize=12,
TextColor3=C(255,255,255)})
mk("TextLabel",chip,{Size=U2(1,-44,1,0),Position=U2(0,36,0,0),
BackgroundTransparency=1,Text=LP.Name,Font=F.GothamMedium,TextSize=11,
TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,
TextTruncate=Enum.TextTruncate.AtEnd})

--// LINHAS
local function sect(par,t)
  ord=ord+1
  return mk("TextLabel",par,{Size=U2(1,0,0,26),BackgroundTransparency=1,
  Text=string.upper(t),Font=F.GothamBold,TextSize=10,TextColor3=MU,
  TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord})
end

local function row(par,h)
  ord=ord+1
  local r=mk("TextButton",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,
  BorderSizePixel=0,Text="",AutoButtonColor=false,LayoutOrder=ord})
  mk("UICorner",r,{CornerRadius=UD(0,7)})
  r.MouseEnter:Connect(function() r.BackgroundColor3=RV end)
  r.MouseLeave:Connect(function() r.BackgroundColor3=RW end)
  return r
end

local function rlab(r,t)
  return mk("TextLabel",r,{Size=U2(1,-70,1,0),Position=U2(0,12,0,0),
  BackgroundTransparency=1,Text=t,Font=F.GothamMedium,TextSize=12,
  TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left,
  TextTruncate=Enum.TextTruncate.AtEnd})
end

local function tog(par,t,k,cb)
  local r=row(par,34)
  rlab(r,t)
  local pill=mk("Frame",r,{Size=U2(0,40,0,19),Position=U2(1,-50,.5,-9.5),
  BackgroundColor3=C(62,52,58),BorderSizePixel=0})
  mk("UICorner",pill,{CornerRadius=UD(1,0)})
  local kn=mk("Frame",pill,{Size=U2(0,15,0,15),
  BackgroundColor3=C(245,240,244),BorderSizePixel=0})
  mk("UICorner",kn,{CornerRadius=UD(1,0)})
  local function paint()
    local on=CFG[k] and true or false
    kn.Position=on and U2(1,-17,.5,-7.5) or U2(0,2,.5,-7.5)
    pill.BackgroundColor3=on and GR or C(62,52,58)
  end
  r.MouseButton1Click:Connect(function()
    CFG[k]=not CFG[k] paint()
    if cb then pcall(cb,CFG[k]) end
  end)
  paint()
end

local function step(par,t,k,st,mn,mx,cb)
  local r=row(par,34)
  rlab(r,t)
  local val=mk("TextLabel",r,{Size=U2(0,40,0,20),Position=U2(1,-100,.5,-10),
  BackgroundTransparency=1,Text=tostring(CFG[k]),Font=F.GothamBold,
  TextSize=12,TextColor3=AC})
  local function sb(txt,x,dir)
    local b=mk("TextButton",r,{Size=U2(0,22,0,22),Position=U2(1,x,.5,-11),
    BackgroundColor3=C(52,41,48),BorderSizePixel=0,Text=txt,Font=F.GothamBold,
    TextSize=13,TextColor3=TX,AutoButtonColor=false})
    mk("UICorner",b,{CornerRadius=UD(0,5)})
    b.MouseButton1Click:Connect(function()
      CFG[k]=math.clamp(CFG[k]+dir*st,mn,mx)
      val.Text=tostring(CFG[k])
      if cb then pcall(cb) end
    end)
  end
  sb("-",-56,-1) sb("+",-28,1)
end

local function radio(par,k,opts)
  local list={}
  local function paint()
    for _,e in ipairs(list) do
      local on=(CFG[k]==e.v)
      e.dot.Visible=on
      e.sk.Color=on and AC or C(96,84,92)
    end
  end
  for _,o in ipairs(opts) do
    local r=row(par,34)
    rlab(r,o.t)
    local rg=mk("Frame",r,{Size=U2(0,17,0,17),Position=U2(1,-30,.5,-8.5),
    BackgroundTransparency=1})
    mk("UICorner",rg,{CornerRadius=UD(1,0)})
    local sk=mk("UIStroke",rg,{Color=C(96,84,92),Thickness=1.5})
    local dt=mk("Frame",rg,{Size=U2(0,7,0,7),Position=U2(.5,-3.5,.5,-3.5),
    BackgroundColor3=AC,BorderSizePixel=0,Visible=false})
    mk("UICorner",dt,{CornerRadius=UD(1,0)})
    table.insert(list,{v=o.v,dot=dt,sk=sk})
    r.MouseButton1Click:Connect(function()
      CFG[k]=o.v paint()
      if o.cb then pcall(o.cb) end
    end)
  end
  paint()
end

local function btn(par,t,fn)
  local r=row(par,34)
  rlab(r,t)
  r.MouseButton1Click:Connect(function()
    local ok,e=pcall(fn)
    if not ok then warn("[Reaper] "..tostring(e)) end
  end)
end

--// ESP
local function clearESP(ch)
  local d=ST.esp[ch]
  if not d then return end
  ST.esp[ch]=nil
  if d.hl then d.hl:Destroy() end
  if d.bb then d.bb:Destroy() end
end
local function clearAllESP()
  for c in pairs(ST.esp) do clearESP(c) end
end

local function aimPart(ch)
  return ch:FindFirstChild("Head") or ch:FindFirstChild("UpperTorso")
    or ch:FindFirstChild("Torso") or ch:FindFirstChild("HumanoidRootPart")
end

local function applyESP(ch)
  if not ch or ch==LP.Character or ST.esp[ch] then return end
  local hum=ch:FindFirstChildOfClass("Humanoid")
  local hp=aimPart(ch)
  if not hum or not hp or hum.Health<=0 then return end
  local isP=P:GetPlayerFromCharacter(ch)~=nil
  local col=isP and C(255,72,96) or C(255,176,60)
  local hl=mk("Highlight",ch,{Name="ReaperHL",Adornee=ch,FillColor=col,
  FillTransparency=.6,OutlineColor=C(255,255,255),OutlineTransparency=.3})
  local bb2=mk("BillboardGui",ch,{Name="ReaperBB",Adornee=hp,
  Size=U2(0,170,0,34),StudsOffset=Vector3.new(0,2.3,0),AlwaysOnTop=true})
  local lb=mk("TextLabel",bb2,{Size=U2(1,0,1,0),BackgroundTransparency=1,
  Text=isP and ch.Name or "BOT",Font=F.GothamBold,TextSize=12,
  TextColor3=col,TextStrokeTransparency=.5})
  local sp=mk("Frame",bb2,{Size=U2(0,3,0,44),Position=U2(.5,-1.5,0,-44),
  BackgroundColor3=col,BorderSizePixel=0,Visible=CFG.Antenna})
  ST.esp[ch]={hl=hl,bb=bb2,label=lb,spike=sp,hum=hum,name=isP and ch.Name or "BOT"}
end

--// LOOT
local WORDS={"cash","money","coin","gem","diamond","jewel","gold","bar",
"key","crate","safe","bag","briefcase","vault","atm","register","chest",
"loot","artifact","relic","prize"}
local function isLoot(n)
  n=n:lower()
  for _,w in ipairs(WORDS) do if n:find(w,1,true) then return true end end
  return false
end
local function clearLoot()
  for o,b in pairs(ST.loot) do
    if b then pcall(function() b:Destroy() end) end
    ST.loot[o]=nil
  end
end
local function scanLoot()
  if not CFG.LootESP then return end
  local me=LP.Character local n=0
  for _,d in ipairs(workspace:GetDescendants()) do
    if n>=120 then break end
    if not ST.loot[d] and (d:IsA("BasePart") or d:IsA("Model")) then
      local skip=false
      if me and (d==me or d:IsDescendantOf(me)) then skip=true end
      if not skip and not P:GetPlayerFromCharacter(d) and isLoot(d.Name) then
        local pt=d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart",true)
        if pt then
          local b=mk("BillboardGui",pt,{Name="ReaperLoot",Adornee=pt,
          Size=U2(0,130,0,22),StudsOffset=Vector3.new(0,1.8,0),AlwaysOnTop=true})
          mk("TextLabel",b,{Size=U2(1,0,1,0),BackgroundTransparency=1,
          Text=d.Name,Font=F.GothamBold,TextSize=11,
          TextColor3=C(120,255,170),TextStrokeTransparency=.45})
          ST.loot[d]=b n=n+1
        end
      end
    end
  end
end

--// MIRA
local function isMate(ch)
  if not CFG.TeamCheck then return false end
  local pl=P:GetPlayerFromCharacter(ch)
  if not pl or not LP.Team then return false end
  return pl.Team==LP.Team
end

local function canSee(ch,pt)
  if not CFG.WallCheck or CFG.Mode=="Silent" then return true end
  local cam=workspace.CurrentCamera
  if not cam then return false end
  local rp=RaycastParams.new()
  rp.FilterType=Enum.RaycastFilterType.Exclude
  local ig={cam}
  if LP.Character then table.insert(ig,LP.Character) end
  rp.FilterDescendantsInstances=ig rp.IgnoreWater=true
  local o=cam.CFrame.Position
  local r=workspace:Raycast(o,pt.Position-o,rp)
  if not r then return true end
  return r.Instance:IsDescendantOf(ch)
end

local function sdist(pt)
  local cam=workspace.CurrentCamera
  if not cam then return math.huge end
  local v,on=cam:WorldToViewportPoint(pt.Position)
  if not on or v.Z<=0 then return math.huge end
  local ce=cam.ViewportSize/2
  return (Vector2.new(v.X,v.Y)-ce).Magnitude
end

local function pick()
  local best=nil
  local function go(ch)
    if not ch or ch==LP.Character or isMate(ch) then return end
    local h=ch:FindFirstChildOfClass("Humanoid")
    if not h or h.Health<=0 then return end
    local pt=aimPart(ch)
    if not pt then return end
    local d=sdist(pt)
    if d>CFG.FOV then return end
    if not canSee(ch,pt) then return end
    if not best or d<best.d then best={char=ch,part=pt,d=d} end
  end
  for _,p in ipairs(P:GetPlayers()) do if p~=LP then go(p.Character) end end
  for _,b in ipairs(ST.bots) do
    if b.char.Parent and b.part.Parent then
      local d=sdist(b.part)
      if d<=CFG.FOV and canSee(b.char,b.part) then
        if not best or d<best.d then best={char=b.char,part=b.part,d=d} end
      end
    end
  end
  return best
end

local function alive(t)
  if not t then return false end
  local c=t.char
  if not c or not c.Parent then return false end
  local h=c:FindFirstChildOfClass("Humanoid")
  if not h or h.Health<=0 then return false end
  return t.part and t.part.Parent~=nil
end

local function getTarget()
  if alive(ST.lock) then
    if sdist(ST.lock.part)<=CFG.FOV+30 and canSee(ST.lock.char,ST.lock.part) then
      return ST.lock
    end
  end
  ST.lock=pick()
  return ST.lock
end

local function aimPos(t)
  local p=t.part.Position
  if CFG.Prediction then
    local v=t.part.AssemblyLinearVelocity
    if v then p=p+v*0.14 end
  end
  return p
end

local function camTo(p)
  local cam=workspace.CurrentCamera
  if not cam then return end
  local goal=CFrame.new(cam.CFrame.Position,p)
  if CFG.Smooth>=100 then
    cam.CFrame=goal
  else
    cam.CFrame=cam.CFrame:Lerp(goal,math.clamp(CFG.Smooth/100,0.05,1))
  end
end

local function mouseTo(p)
  local cam=workspace.CurrentCamera
  if not cam then return end
  local v,on=cam:WorldToViewportPoint(p)
  if not on then return end
  local ce=cam.ViewportSize/2
  local sx=math.max(UIS.MouseDeltaSensitivity or 1,0.1)
  if mousemoverel then
    pcall(mousemoverel,(v.X-ce.X)/sx,(v.Y-ce.Y)/sx)
  elseif mousemoveabs then
    pcall(mousemoveabs,v.X,v.Y)
  end
end

local function applyAim(t)
  local p=aimPos(t)
  if CFG.Mode=="Mouse" then
    mouseTo(p)
  elseif CFG.Mode=="Silent" then
    local cam=workspace.CurrentCamera
    if cam then cam.CFrame=CFrame.new(cam.CFrame.Position,p) end
  else
    camTo(p)
  end
end

local function fireWeapon()
  local ch=LP.Character
  if not ch then return end
  for _,t in ipairs(ch:GetChildren()) do
    if t:IsA("Tool") then pcall(function() t:Activate() end) end
  end
end

local function stopFly()
  local ch=LP.Character
  local h=ch and ch:FindFirstChildOfClass("Humanoid")
  if h then h.PlatformStand=false end
  local r=ch and ch:FindFirstChild("HumanoidRootPart")
  if r then r.AssemblyLinearVelocity=Vector3.zero end
end

local function applyChar()
  local ch=LP.Character
  local h=ch and ch:FindFirstChildOfClass("Humanoid")
  if not h then return end
  pcall(function()
    h.WalkSpeed=CFG.WalkSpeed
    if h.UseJumpPower then h.JumpPower=CFG.JumpPower end
  end)
end

--// LUZ
local fogS={L.FogStart,L.FogEnd,L.FogColor}
local ligS={L.Brightness,L.OutdoorAmbient,L.EnvironmentDiffuseScale,
L.EnvironmentSpecularScale,L.GlobalShadows}
local fxS={}

local function setFog(on)
  pcall(function()
    if on then
      L.FogStart=0 L.FogEnd=1000000 L.FogColor=C(200,200,200)
    else
      L.FogStart=fogS[1] L.FogEnd=fogS[2] L.FogColor=fogS[3]
    end
  end)
end

local function setBright(on)
  pcall(function()
    if on then
      L.Brightness=3 L.OutdoorAmbient=C(200,200,200)
      L.EnvironmentDiffuseScale=1 L.GlobalShadows=false
    else
      L.Brightness=ligS[1] L.OutdoorAmbient=ligS[2]
      L.EnvironmentDiffuseScale=ligS[3] L.GlobalShadows=ligS[5]
    end
  end)
end

local function setLag(on)
  pcall(function()
    L.EnvironmentSpecularScale=on and 0 or ligS[4]
    L.GlobalShadows=not on
    if on then
      for _,o in ipairs(L:GetChildren()) do
        if o:IsA("BloomEffect") or o:IsA("BlurEffect")
          or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") then
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

--// CIRCULO
local circ=mk("Frame",gui,{Name="ReaperFOV",
Size=U2(0,CFG.FOV*2,0,CFG.FOV*2),Position=U2(.5,-CFG.FOV,.5,-CFG.FOV),
BackgroundTransparency=1,BorderSizePixel=0,Visible=false})
mk("UICorner",circ,{CornerRadius=UD(1,0)})
mk("UIStroke",circ,{Color=AC,Thickness=1.5,Transparency=.3})
local function reCircle()
  circ.Size=U2(0,CFG.FOV*2,0,CFG.FOV*2)
  circ.Position=U2(.5,-CFG.FOV,.5,-CFG.FOV)
end

--// PAGINAS
local home=pages.Home
sect(home,"Jogador")
local homeName=mk("TextLabel",home,{Size=U2(1,0,0,34),BackgroundColor3=RW,
BorderSizePixel=0,Text="",Font=F.GothamBold,TextSize=12,TextColor3=TX,
LayoutOrder=ord+1})
mk("UICorner",homeName,{CornerRadius=UD(0,7)})

sect(home,"Atalhos")
tog(home,"Enable Aimbot","Aimbot",function(v) circ.Visible=v end)
tog(home,"ESP","ESP",function(v) if not v then clearAllESP() end end)
tog(home,"Voar","Fly",function(v)
  if not v then stopFly() end
  if upBtn then upBtn.Visible=v downBtn.Visible=v end
end)
tog(home,"Kit medico automatico","AutoMed")

sect(home,"Status")
local stLbl=mk("TextLabel",home,{Size=U2(1,0,0,62),BackgroundColor3=RW,
BorderSizePixel=0,Text="",Font=F.Code,TextSize=11,TextColor3=MU,
TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
TextWrapped=true,LayoutOrder=ord+1})
mk("UICorner",stLbl,{CornerRadius=UD(0,7)})
mk("UIPadding",stLbl,{PaddingLeft=UD(0,10),PaddingTop=UD(0,8)})

local vis=pages.Visuals
sect(vis,"ESP")
tog(vis,"ESP Jogadores e Bots","ESP",function(v) if not v then clearAllESP() end end)
tog(vis,"Antena","Antenna")
tog(vis,"ESP de Loot","LootESP",function(v)
  if not v then clearLoot() else task.spawn(scanLoot) end
end)
sect(vis,"Ambiente")
tog(vis,"Remover neblina","NoFog",function(v) setFog(v) end)
tog(vis,"Fullbright","Fullbright",function(v) setBright(v) end)

local ap=pages.Aimbot
sect(ap,"Controle")
tog(ap,"Enable Aimbot","Aimbot",function(v) circ.Visible=v end)
tog(ap,"Toggle Mode (Mobile Friendly)","ToggleMode",function(v)
  if not v then ST.firing=false end
end)
tog(ap,"Team Check","TeamCheck")
tog(ap,"Visible Check (Wall Check)","WallCheck")
tog(ap,"Prediction","Prediction")
tog(ap,"Atirar automatico","AutoFire")

sect(ap,"Modo")
radio(ap,"Mode",{{t="Camera",v="Camera"},{t="Mouse",v="Mouse"},
{t="Silent",v="Silent"}})

sect(ap,"Ajustes")
step(ap,"FOV","FOV",10,40,500,reCircle)
step(ap,"Velocidade da mira","Smooth",10,20,100)

local fp=pages.FPS
sect(fp,"Desempenho")
tog(fp,"Anti-Lag","AntiLag",function(v) setLag(v) end)
tog(fp,"Remover neblina","NoFog",function(v) setFog(v) end)
tog(fp,"Fullbright","Fullbright",function(v) setBright(v) end)
step(fp,"FOV da mira","FOV",10,40,500,reCircle)

local cr=pages.Character
sect(cr,"Movimento")
tog(cr,"Voar","Fly",function(v)
  if not v then stopFly() end
  if upBtn then upBtn.Visible=v downBtn.Visible=v end
end)
step(cr,"Velocidade do voo","FlySpeed",10,20,300)
step(cr,"WalkSpeed","WalkSpeed",2,8,200,applyChar)
step(cr,"JumpPower","JumpPower",5,20,300,applyChar)

sect(cr,"Vida")
tog(cr,"Kit medico automatico","AutoMed",function(v)
  if v then ST.lastMed=0 end
end)
step(cr,"Curar abaixo de","MedAt",5,10,95)

local cg=pages.Config
sect(cg,"Servidor")
btn(cg,"Copiar JobId",function()
  if setclipboard then setclipboard(game.JobId) end
  toast("Reaper Aim","JobId copiado.",3)
end)
btn(cg,"Reconectar neste servidor",function()
  TPS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP)
end)

sect(cg,"Geral")
btn(cg,"Resetar tudo",function()
  for k,v in pairs(CFG) do if type(v)=="boolean" then CFG[k]=false end end
  CFG.FOV=140 CFG.Smooth=100 CFG.MedAt=60 CFG.FlySpeed=60
  CFG.WalkSpeed=16 CFG.JumpPower=50
  clearAllESP() clearLoot() stopFly() circ.Visible=false reCircle()
  if upBtn then upBtn.Visible=false downBtn.Visible=false end
  setLag(false) setFog(false) setBright(false) applyChar()
  toast("Reaper Aim","Tudo resetado.",3)
end)

local cd=pages.Creditos
sect(cd,"Sobre")
local ab=mk("TextLabel",cd,{Size=U2(1,0,0,130),BackgroundColor3=RW,
BorderSizePixel=0,Text="Reaper Aim  v21\n\nAimbot Camera / Mouse / Silent,\nESP, loot, voo, kit medico e otimizacao.\n\nPC: segure (ou clique) o botao de atirar.\nCelular: toque no botao de atirar,\nuse AIM para segurar e FIRE para disparar.",
Font=F.Gotham,TextSize=11,TextColor3=MU,TextWrapped=true,
TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
LayoutOrder=ord+1})
mk("UICorner",ab,{CornerRadius=UD(0,7)})
mk("UIPadding",ab,{PaddingLeft=UD(0,10),PaddingTop=UD(0,8)})

show("Home")

--// TOQUE
local tGui,aimBtn,fireBtn,upBtn,downBtn
if UIS.TouchEnabled then
  local root=nil
  pcall(function() root=(gethui and gethui()) or game:GetService("CoreGui") end)
  if not root then pcall(function() root=LP:WaitForChild("PlayerGui",5) end) end
  if root then
    tGui=mk("ScreenGui",root,{Name="ReaperTouch",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=99999})
    local function tb(t,x,y,s)
      local b=mk("TextButton",tGui,{Size=U2(0,s,0,s),Position=U2(1,x,1,y),
      BackgroundColor3=C(28,20,24),BackgroundTransparency=.2,BorderSizePixel=0,
      Text=t,Font=F.GothamBold,TextSize=14,TextColor3=TX,AutoButtonColor=false})
      mk("UICorner",b,{CornerRadius=UD(1,0)})
      mk("UIStroke",b,{Color=AC,Transparency=.5,Thickness=1.5})
      return b
    end
    aimBtn=tb("AIM",-92,-116,74)
    fireBtn=tb("FIRE",-92,-206,58)
    upBtn=tb("^",-184,-168,54)
    downBtn=tb("v",-184,-96,54)
    upBtn.Visible=false downBtn.Visible=false
    local function pr(b,on)
      b.BackgroundColor3=on and C(120,25,45) or C(28,20,24)
    end
    aimBtn.MouseButton1Down:Connect(function()
      if CFG.ToggleMode then ST.firing=not ST.firing else ST.firing=true end
      pr(aimBtn,ST.firing)
    end)
    aimBtn.MouseButton1Up:Connect(function()
      if not CFG.ToggleMode then ST.firing=false pr(aimBtn,false) end
    end)
    fireBtn.MouseButton1Down:Connect(function()
      ST.fireUntil=os.clock()+1
      pr(fireBtn,true)
      fireWeapon()
    end)
    fireBtn.MouseButton1Up:Connect(function() pr(fireBtn,false) end)
    upBtn.MouseButton1Down:Connect(function() ST.flyUp=true pr(upBtn,true) end)
    upBtn.MouseButton1Up:Connect(function() ST.flyUp=false pr(upBtn,false) end)
    downBtn.MouseButton1Down:Connect(function() ST.flyDown=true pr(downBtn,true) end)
    downBtn.MouseButton1Up:Connect(function() ST.flyDown=false pr(downBtn,false) end)
  end
end

--// ENTRADA
local function overPanel()
  if not gui.Parent then return false end
  local m=UIS:GetMouseLocation()
  local p=win.AbsolutePosition
  local s=win.AbsoluteSize
  return m.X>=p.X and m.X<=p.X+s.X and m.Y>=p.Y and m.Y<=p.Y+s.Y
end

local function pulse() ST.fireUntil=os.clock()+0.5 end

local function holding()
  if os.clock()<(ST.fireUntil or 0) then return true end
  if ST.firing then return true end
  if UIS:IsMouseButtonPressed(EIT.MouseButton1) then return true end
  if UIS:IsKeyDown(KC.ButtonR2) then return true end
  return false
end

UIS.InputBegan:Connect(function(i)
  if overPanel() then return end
  local t=i.UserInputType
  if t==EIT.MouseButton1 or i.KeyCode==KC.ButtonR2 then
    if CFG.ToggleMode then ST.firing=not ST.firing else ST.firing=true end
    pulse()
  elseif t==EIT.Touch then
    local v=workspace.CurrentCamera.ViewportSize
    if i.Position.X>v.X*0.55 and i.Position.Y>v.Y*0.35 then pulse() end
  end
end)

UIS.InputEnded:Connect(function(i)
  if i.UserInputType==EIT.MouseButton1 or i.KeyCode==KC.ButtonR2 then
    if not CFG.ToggleMode then ST.firing=false end
  end
end)

--// LOOPS
local function refreshBots()
  if not (CFG.ESP or CFG.Aimbot) then return end
  local out={}
  for _,d in ipairs(workspace:GetDescendants()) do
    if d:IsA("Humanoid") and d.Health>0 then
      local c=d.Parent
      if c and not P:GetPlayerFromCharacter(c) then
        local pt=aimPart(c)
        if pt then table.insert(out,{char=c,part=pt}) end
      end
    end
  end
  ST.bots=out
end

task.spawn(function()
  while gui.Parent do
    task.wait(1)
    pcall(refreshBots)
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(0.2)
    if CFG.ESP then
      for _,p in ipairs(P:GetPlayers()) do
        if p~=LP then applyESP(p.Character) end
      end
      for _,b in ipairs(ST.bots) do applyESP(b.char) end
      for ch,d in pairs(ST.esp) do
        if not ch.Parent then
          clearESP(ch)
        else
          if d.hum and d.label then
            d.label.Text=d.name.."  "..math.floor(d.hum.Health).."hp"
          end
          if d.spike then d.spike.Visible=CFG.Antenna end
        end
      end
    elseif next(ST.esp) then
      clearAllESP()
    end
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(3)
    if CFG.LootESP then pcall(scanLoot) elseif next(ST.loot) then clearLoot() end
  end
end)

local function isMed(t)
  if not t or not t:IsA("Tool") then return false end
  local n=t.Name:lower()
  return n:find("med",1,true) or n:find("kit",1,true)
    or n:find("heal",1,true) or n:find("band",1,true)
    or n:find("curar",1,true) or n:find("vida",1,true)
end

local function findMed(ch)
  for _,t in ipairs(ch:GetChildren()) do if isMed(t) then return t end end
  local bp=LP:FindFirstChildOfClass("Backpack")
  if bp then
    for _,t in ipairs(bp:GetChildren()) do if isMed(t) then return t end end
  end
  return nil
end

task.spawn(function()
  while gui.Parent do
    task.wait(0.5)
    if CFG.AutoMed then
      local ch=LP.Character
      local h=ch and ch:FindFirstChildOfClass("Humanoid")
      if h and h.Health>0 and h.Health<=CFG.MedAt
        and h.MoveDirection.Magnitude<0.1
        and os.clock()-ST.lastMed>1.8 then
        ST.lastMed=os.clock()
        local t=findMed(ch)
        if t then
          if t.Parent~=ch then
            pcall(function() h:EquipTool(t) end)
            task.wait(0.3)
          end
          if t.Parent==ch then
            pcall(function() t:Activate() end)
            task.wait(0.15)
            pcall(function() t:Activate() end)
          end
        end
      end
    end
  end
end)

task.spawn(function()
  while gui.Parent do
    task.wait(2)
    if pages.Home.Visible then
      local ch=LP.Character
      local h=ch and ch:FindFirstChildOfClass("Humanoid")
      homeName.Text="  "..LP.Name..(h and ("   |   HP "..math.floor(h.Health)) or "")
      stLbl.Text=string.format("Aimbot: %s   Modo: %s\nFOV: %d   Mira: %s\nESP: %s   Voar: %s",
        CFG.Aimbot and "ON" or "OFF",CFG.Mode,CFG.FOV,
        holding() and "ATIVA" or "espera",
        CFG.ESP and "ON" or "OFF",CFG.Fly and "ON" or "OFF")
    end
  end
end)

RS.Heartbeat:Connect(function()
  if not gui.Parent then return end
  if CFG.Fly then
    local ch=LP.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    local r=ch and ch:FindFirstChild("HumanoidRootPart")
    if h and r then
      h.PlatformStand=true
      local d=Vector3.zero
      local mv=h.MoveDirection
      if mv.Magnitude>0.05 then
        d=Vector3.new(mv.X,0,mv.Z).Unit*CFG.FlySpeed
      end
      if UIS:IsKeyDown(KC.Space) or ST.flyUp then
        d=d+Vector3.new(0,CFG.FlySpeed,0)
      end
      if UIS:IsKeyDown(KC.LeftShift) or ST.flyDown then
        d=d-Vector3.new(0,CFG.FlySpeed,0)
      end
      r.AssemblyLinearVelocity=d
    end
  else
    applyChar()
  end
end)

RS:BindToRenderStep("ReaperAim",Enum.RenderPriority.Camera.Value+1,function()
  if not gui.Parent then return end
  circ.Visible=CFG.Aimbot
  if not CFG.Aimbot then ST.lock=nil return end
  if not holding() or overPanel() then return end
  local ch=LP.Character
  local h=ch and ch:FindFirstChildOfClass("Humanoid")
  if not h or h.Health<=0 then return end
  local t=getTarget()
  if t and t.part and t.part.Parent then
    applyAim(t)
    if CFG.AutoFire then fireWeapon() end
  else
    ST.lock=nil
  end
end)

toast("Reaper Aim","Carregado. Clique ou segure para mirar.",5)
