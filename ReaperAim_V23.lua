local P=game:GetService("Players")
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local L=game:GetService("Lighting")
local TPS=game:GetService("TeleportService")
local LP=P.LocalPlayer
local U2=UDim2.new local UD=UDim.new local C=Color3.fromRGB
local F=Enum.Font local EIT=Enum.UserInputType local KC=Enum.KeyCode
local AC=C(255,66,96) local GR=C(38,199,122) local BG=C(24,19,23)
local PN=C(18,14,18) local RW=C(33,26,31) local RV=C(42,33,39)
local TX=C(238,233,237) local MU=C(146,136,145)
local CV=C(255,72,96) local CB=C(150,110,255)
local BV=C(255,176,60) local BB=C(110,150,255)
local CFG={Aimbot=false,ToggleMode=false,TeamCheck=false,WallCheck=true,Prediction=false,Sticky=true,AutoFire=false,Mode="Camera",FOV=70,Smooth=45,MaxAngle=30,TargetPart="Head",MaxDist=180,Scale=100,ShowBtns=false,ESP=false,Antenna=false,LootESP=false,Danger=false,DangerDist=80,NoFog=false,Fullbright=false,AntiLag=false,Fly=false,FlySpeed=60,WalkSpeed=16,JumpPower=50,AutoMed=false,MedAt=60}
local ST={firing=false,fireUntil=0,flyUp=false,flyDown=false,lock=nil,esp={},loot={},bots={},lastMed=0}
local tGui,upBtn,downBtn
local function mk(c,p,t)
  local o=Instance.new(c)
  if o:IsA("GuiObject") then o.BorderSizePixel=0 end
  if c=="TextLabel" then o.BackgroundTransparency=1 o.Text=""
  elseif c=="TextButton" then o.Text="" o.AutoButtonColor=false end
  if t then
    for k,v in pairs(t) do
      local ok=false
      ok=pcall(function() o[k]=v end)
      if not ok then warn("[Reaper] prop "..tostring(k).." em "..tostring(c)) end
    end
  end
  if p then o.Parent=p end
  return o
end
local function cr(o,a,b) mk("UICorner",o,{CornerRadius=b and UD(a,b) or UD(1,0)}) end
local function toast(a,b,d)
 pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title=tostring(a),Text=tostring(b),Duration=d or 4}) end)
end
local gui=mk("ScreenGui",nil,{Name="ReaperAim",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9999})
local okp=pcall(function() gui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not okp or not gui.Parent then
 pcall(function() gui.Parent=LP:WaitForChild("PlayerGui",10) end)
end
if not gui.Parent then gui:Destroy() toast("Reaper Aim","Executor bloqueou a interface.",6) return end
local VPS=workspace.CurrentCamera.ViewportSize
local WW=math.min(540,VPS.X-24)
local WH=math.min(500,math.max(300,VPS.Y-90))
local SW=WW<430 and 120 or 150
local win=mk("Frame",gui,{Size=U2(0,WW,0,WH),Position=U2(0,math.max(8,(VPS.X-WW)/2),0,70),BackgroundColor3=BG,Active=true,ClipsDescendants=true})
mk("UICorner",win,{CornerRadius=UD(0,10)})
mk("UIStroke",win,{Color=C(52,40,48),Thickness=1})
local uisc=mk("UIScale",win,{Scale=1})
local bar=mk("Frame",win,{Size=U2(1,0,0,40),BackgroundColor3=PN,Active=true})
mk("UICorner",bar,{CornerRadius=UD(0,10)})
mk("Frame",bar,{Size=U2(1,0,0,14),Position=U2(0,0,1,-14),BackgroundColor3=PN})
local dot=mk("Frame",bar,{Size=U2(0,9,0,9),Position=U2(0,14,.5,-4.5),BackgroundColor3=AC})
mk("UICorner",dot,{CornerRadius=UD(1,0)})
mk("TextLabel",bar,{Size=U2(0,220,1,0),Position=U2(0,30,0,0),BackgroundTransparency=1,Text="Reaper Aim",Font=F.GothamSemibold,TextSize=13,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left})
local function barBtn(txt,x)
 local b=mk("TextButton",bar,{Size=U2(0,28,0,26),Position=U2(1,x,.5,-13),BackgroundTransparency=1,Text=txt,Font=F.GothamBold,TextSize=13,TextColor3=MU,ZIndex=4})
 mk("UICorner",b,{CornerRadius=UD(0,6)})
 b.MouseEnter:Connect(function() b.TextColor3=TX b.BackgroundTransparency=.4 end)
 b.MouseLeave:Connect(function() b.TextColor3=MU b.BackgroundTransparency=1 end)
 return b
end
local bMin=barBtn("-",-96) local bMax=barBtn("o",-64) local bClose=barBtn("X",-32)
local mini=mk("TextButton",gui,{Size=U2(0,60,0,60),Position=U2(0,18,0,110),BackgroundColor3=AC,Text="",Visible=false,ZIndex=20})
mk("UICorner",mini,{CornerRadius=UD(1,0)})
mk("UIStroke",mini,{Color=C(255,130,150),Thickness=2})
mk("TextLabel",mini,{Size=U2(1,0,0,18),Position=U2(0,0,0,14),BackgroundTransparency=1,Text="R",Font=F.GothamBold,TextSize=20,TextColor3=C(255,255,255)})
mk("TextLabel",mini,{Size=U2(1,0,0,12),Position=U2(0,0,0,34),BackgroundTransparency=1,Text="Reaper",Font=F.GothamBold,TextSize=8,TextColor3=C(255,235,240)})
local function setMini(on)
 win.Visible=not on
 mini.Visible=on
end
local drag,dS,dP=false,nil,nil
local mDrag,mS,mP,mM=false,nil,nil,0
local function startDrag(i,isMini)
 if isMini then mDrag=true mS=i.Position mP=mini.Position mM=0
 else drag=true dS=i.Position dP=win.Position end
 i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then if isMini then mDrag=false if mM<8 then setMini(false) end else drag=false end end end)
end
bar.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,false) end end)
mini.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,true) end end)
UIS.InputChanged:Connect(function(i) if i.UserInputType~=EIT.MouseMovement and i.UserInputType~=EIT.Touch then return end if drag and dS then local o=i.Position-dS win.Position=U2(dP.X.Scale,dP.X.Offset+o.X,dP.Y.Scale,dP.Y.Offset+o.Y) elseif mDrag and mS then local o=i.Position-mS mM=math.max(mM,o.Magnitude) mini.Position=U2(mP.X.Scale,mP.X.Offset+o.X,mP.Y.Scale,mP.Y.Offset+o.Y) end end)
local zoom=false
bMax.MouseButton1Click:Connect(function() zoom=not zoom if zoom then win.Position=U2(0,6,0,6) win.Size=U2(1,-12,1,-12) else win.Position=U2(0,math.max(8,(VPS.X-WW)/2),0,70) win.Size=U2(0,WW,0,WH) end end)
local side=mk("Frame",win,{Size=U2(0,SW,1,-40),Position=U2(0,0,0,40),BackgroundColor3=PN})
local cont=mk("Frame",win,{Size=U2(1,-SW,1,-40),Position=U2(0,SW,0,40),BackgroundColor3=BG})
local pages,navs={},{}
local NAV={{"Novidades","!"},{"Config","="},{"Home","#"},{"Visuals","*"},{"Aimbot","@"},{"FPS","%"},{"Character","+"},{"Botoes","o"},{"Creditos","i"}}
local ord=0
local function newPage(k)
 local p=mk("ScrollingFrame",cont,{Size=U2(1,-16,1,-16),Position=U2(0,8,0,8),BackgroundTransparency=1,ScrollBarThickness=5,ScrollBarImageColor3=C(90,70,80),CanvasSize=U2(0,0,0,0),Visible=false})
 local ly=mk("UIListLayout",p,{Padding=UD(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
 mk("UIPadding",p,{PaddingTop=UD(0,2),PaddingBottom=UD(0,16),PaddingLeft=UD(0,4),PaddingRight=UD(0,10)})
 local function fit()
 pcall(function() p.CanvasSize=U2(0,0,0,ly.AbsoluteContentSize.Y+20) end)
 end
 pcall(function() ly:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit) end)
 task.spawn(function() for _=1,60 do fit() task.wait(0.1) end end)
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
 local b=mk("TextButton",side,{Size=U2(1,-14,0,32),Position=U2(0,7,0,8+(i-1)*35),BackgroundColor3=PN,Text=""})
 mk("UICorner",b,{CornerRadius=UD(0,7)})
 local bar0=mk("Frame",b,{Size=U2(0,3,0,16),Position=U2(0,-7,.5,-8),BackgroundColor3=AC,Visible=false})
 mk("UICorner",bar0,{CornerRadius=UD(1,0)})
 local gl=mk("TextLabel",b,{Size=U2(0,18,1,0),Position=U2(0,10,0,0),BackgroundTransparency=1,Text=it[2],Font=F.GothamBold,TextSize=13,TextColor3=MU})
 local tx=mk("TextLabel",b,{Size=U2(1,-34,1,0),Position=U2(0,32,0,0),BackgroundTransparency=1,Text=it[1],Font=F.GothamMedium,TextSize=12,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left})
 navs[it[1]]={bg=b,bar=bar0,gl=gl,txt=tx}
 b.MouseButton1Click:Connect(function() show(it[1]) end)
 pcall(newPage,it[1])
end
local chip=mk("Frame",side,{Size=U2(1,-14,0,34),Position=U2(0,7,1,-42),BackgroundTransparency=1})
local av=mk("Frame",chip,{Size=U2(0,24,0,24),Position=U2(0,4,.5,-12),BackgroundColor3=AC})
mk("UICorner",av,{CornerRadius=UD(1,0)})
mk("TextLabel",av,{Size=U2(1,0,1,0),BackgroundTransparency=1,Text=string.sub(LP.Name,1,1):upper(),Font=F.GothamBold,TextSize=12,TextColor3=C(255,255,255)})
mk("TextLabel",chip,{Size=U2(1,-44,1,0),Position=U2(0,36,0,0),BackgroundTransparency=1,Text=LP.Name,Font=F.GothamMedium,TextSize=11,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
local function sect(par,t)
 ord=ord+1
 return mk("TextLabel",par,{Size=U2(1,0,0,22),BackgroundTransparency=1,Text=string.upper(t),Font=F.GothamBold,TextSize=10,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord})
end
local function row(par,h)
 ord=ord+1
 local r=mk("TextButton",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,Text="",LayoutOrder=ord})
 mk("UICorner",r,{CornerRadius=UD(0,7)})
 r.MouseEnter:Connect(function() r.BackgroundColor3=RV end)
 r.MouseLeave:Connect(function() r.BackgroundColor3=RW end)
 return r
end
local function rlab(r,t)
 return mk("TextLabel",r,{Size=U2(1,-70,1,0),Position=U2(0,12,0,0),BackgroundTransparency=1,Text=t,Font=F.GothamMedium,TextSize=12,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
end
local function tog(par,t,k,cb)
 local r=row(par,28)
 rlab(r,t)
 local pill=mk("Frame",r,{Size=U2(0,40,0,19),Position=U2(1,-50,.5,-9.5),BackgroundColor3=C(62,52,58)})
 mk("UICorner",pill,{CornerRadius=UD(1,0)})
 local kn=mk("Frame",pill,{Size=U2(0,15,0,15),BackgroundColor3=C(245,240,244)})
 mk("UICorner",kn,{CornerRadius=UD(1,0)})
 local function paint()
 local on=CFG[k] and true or false
 kn.Position=on and U2(1,-17,.5,-7.5) or U2(0,2,.5,-7.5)
 pill.BackgroundColor3=on and GR or C(62,52,58)
 end
 r.MouseButton1Click:Connect(function() CFG[k]=not CFG[k] paint() if cb then pcall(cb,CFG[k]) end end)
 paint()
end
local function step(par,t,k,st,mn,mx,cb)
 local r=row(par,28)
 rlab(r,t)
 local val=mk("TextLabel",r,{Size=U2(0,46,0,20),Position=U2(1,-100,.5,-10),BackgroundTransparency=1,Text=tostring(CFG[k]),Font=F.GothamBold,TextSize=12,TextColor3=AC})
 local function sb(txt,x,dir)
 local b=mk("TextButton",r,{Size=U2(0,22,0,22),Position=U2(1,x,.5,-11),BackgroundColor3=C(52,41,48),Text=txt,Font=F.GothamBold,TextSize=13,TextColor3=TX})
 mk("UICorner",b,{CornerRadius=UD(0,5)})
 b.MouseButton1Click:Connect(function() CFG[k]=math.clamp(CFG[k]+dir*st,mn,mx) val.Text=tostring(CFG[k]) if cb then pcall(cb) end end)
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
 local r=row(par,28)
 rlab(r,o.t)
 local rg=mk("Frame",r,{Size=U2(0,17,0,17),Position=U2(1,-30,.5,-8.5),BackgroundTransparency=1})
 mk("UICorner",rg,{CornerRadius=UD(1,0)})
 local sk=mk("UIStroke",rg,{Color=C(96,84,92),Thickness=1.5})
 local dt=mk("Frame",rg,{Size=U2(0,7,0,7),Position=U2(.5,-3.5,.5,-3.5),BackgroundColor3=AC,Visible=false})
 mk("UICorner",dt,{CornerRadius=UD(1,0)})
 table.insert(list,{v=o.v,dot=dt,sk=sk})
 r.MouseButton1Click:Connect(function() CFG[k]=o.v paint() if o.cb then pcall(o.cb) end end)
 end
 paint()
end
local function btn(par,t,fn)
 local r=row(par,28)
 rlab(r,t)
 r.MouseButton1Click:Connect(function() local ok,e=pcall(fn) if not ok then warn("[Reaper] "..tostring(e)) end end)
end
local function note(par,t,h)
 local l=mk("TextLabel",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,Text=t,Font=F.Gotham,TextSize=11,TextColor3=MU,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=ord+1})
 mk("UICorner",l,{CornerRadius=UD(0,7)})
 mk("UIPadding",l,{PaddingLeft=UD(0,10),PaddingTop=UD(0,8)})
 ord=ord+1
 return l
end
local function headOf(ch)
 return ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
end
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
local function freeSight(ch)
 local cam=workspace.CurrentCamera
 local pt=headOf(ch)
 if not cam or not pt then return true end
 local rp=RaycastParams.new()
 rp.FilterType=Enum.RaycastFilterType.Exclude
 local ig={cam,ch}
 if LP.Character then table.insert(ig,LP.Character) end
 rp.FilterDescendantsInstances=ig rp.IgnoreWater=true
 local o=cam.CFrame.Position
 return workspace:Raycast(o,pt.Position-o,rp)==nil
end
local function applyESP(ch)
 if not ch or ch==LP.Character or ST.esp[ch] then return end
 local hum=ch:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end
 local pl=P:GetPlayerFromCharacter(ch)
 local isP=pl~=nil
 local nm=isP and pl.Name or ch.Name
 local col=isP and CV or BV
 local hl=mk("Highlight",ch,{Name="ReaperHL",Adornee=ch,FillColor=col,FillTransparency=.62,OutlineColor=C(255,255,255),OutlineTransparency=.3})
 local bb2=mk("BillboardGui",ch,{Name="ReaperBB",Adornee=ch,Size=U2(0,150,0,34),StudsOffset=Vector3.new(0,3.1,0),AlwaysOnTop=true,MaxDistance=0,LightInfluence=0})
 local ant=mk("Frame",bb2,{Size=U2(0,2,0,12),Position=U2(.5,-1,0,0),BackgroundColor3=col,Visible=CFG.Antenna})
 local cap=mk("Frame",ant,{Size=U2(7,0,0,2),Position=U2(.5,0,0,-2),BackgroundColor3=col})
 local lb=mk("TextLabel",bb2,{Size=U2(1,0,0,13),Position=U2(0,0,0,12),BackgroundTransparency=1,Text=nm,Font=F.GothamBold,TextSize=12,TextColor3=col,TextStrokeTransparency=.5})
 local hbg=mk("Frame",bb2,{Size=U2(.62,0,0,3),Position=U2(.19,0,0,27),BackgroundColor3=C(16,12,15)})
 local hpf=mk("Frame",hbg,{Size=U2(1,0,1,0),BackgroundColor3=col,})
 ST.esp[ch]={hl=hl,bb=bb2,label=lb,spike=ant,cap=cap,hp=hpf,isP=isP,pname=nm}
end
local WORDS={"cash","money","coin","gem","diamond","jewel","gold","bar","key","crate","safe","bag","briefcase","vault","atm","register","chest","loot","artifact","relic","prize"}
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
 local b=mk("BillboardGui",pt,{Name="ReaperLoot",Adornee=pt,Size=U2(0,130,0,22),StudsOffset=Vector3.new(0,1.8,0),AlwaysOnTop=true})
 mk("TextLabel",b,{Size=U2(1,0,1,0),BackgroundTransparency=1,Text=d.Name,Font=F.GothamBold,TextSize=11,TextColor3=C(120,255,170),TextStrokeTransparency=.45})
 ST.loot[d]=b n=n+1
 end
 end
 end
 end
end
local function aimPart(ch)
 if CFG.TargetPart=="Body" then
 return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
 or ch:FindFirstChild("HumanoidRootPart")
 end
 return ch:FindFirstChild("Head") or ch:FindFirstChild("UpperTorso")
 or ch:FindFirstChild("HumanoidRootPart")
end
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
 local ig={cam,ch}
 if LP.Character then table.insert(ig,LP.Character) end
 rp.FilterDescendantsInstances=ig rp.IgnoreWater=true
 local o=cam.CFrame.Position
 return workspace:Raycast(o,pt.Position-o,rp)==nil
end
local function sdist(pt)
 local cam=workspace.CurrentCamera
 if not cam then return math.huge end
 local v,on=cam:WorldToViewportPoint(pt.Position)
 if not on or v.Z<=0 then return math.huge end
 local ce=cam.ViewportSize/2
 return (Vector2.new(v.X,v.Y)-ce).Magnitude
end
local function angTo(pt,cam)
 local d=pt.Position-cam.CFrame.Position
 if d.Magnitude<0.1 then return 0 end
 return math.deg(math.acos(math.clamp(d.Unit:Dot(cam.CFrame.LookVector),-1,1)))
end
local function pick()
 local cam=workspace.CurrentCamera
 if not cam then return nil end
 local eye=cam.CFrame.Position
 local cand={}
 local function go(ch)
 if not ch or not ch.Parent or ch==LP.Character or isMate(ch) then return end
 local h=ch:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return end
 local pt=aimPart(ch)
 if not pt or not pt.Parent then return end
 if (pt.Position-eye).Magnitude>CFG.MaxDist then return end
 if angTo(pt,cam)>CFG.MaxAngle then return end
 local d=sdist(pt)
 if d>CFG.FOV*1.3 then return end
 if not canSee(ch,pt) then return end
 table.insert(cand,{char=ch,part=pt,d=d})
 end
 for _,p in ipairs(P:GetPlayers()) do if p~=LP then go(p.Character) end end
 for _,b in ipairs(ST.bots) do if b.char.Parent then go(b.char) end end
 if CFG.Sticky and ST.lock then
 for _,c in ipairs(cand) do
 if c.char==ST.lock.char and c.d<=CFG.FOV*1.3 then return c end
 end
 end
 local best=nil
 for _,c in ipairs(cand) do
 if c.d<=CFG.FOV and (not best or c.d<best.d) then best=c end
 end
 return best
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
 pcall(function() h.WalkSpeed=CFG.WalkSpeed if h.UseJumpPower then h.JumpPower=CFG.JumpPower end end)
end
local fogS={L.FogStart,L.FogEnd,L.FogColor}
local ligS={L.Brightness,L.OutdoorAmbient,L.EnvironmentDiffuseScale,L.EnvironmentSpecularScale,L.GlobalShadows}
local fxS={}
local function setFog(on)
 pcall(function() if on then L.FogStart=0 L.FogEnd=1000000 L.FogColor=C(200,200,200) else L.FogStart=fogS[1] L.FogEnd=fogS[2] L.FogColor=fogS[3] end end)
end
local function setBright(on)
 pcall(function() if on then L.Brightness=3 L.OutdoorAmbient=C(200,200,200) L.EnvironmentDiffuseScale=1 L.GlobalShadows=false else L.Brightness=ligS[1] L.OutdoorAmbient=ligS[2] L.EnvironmentDiffuseScale=ligS[3] L.GlobalShadows=ligS[5] end end)
end
local function setLag(on)
 pcall(function() L.EnvironmentSpecularScale=on and 0 or ligS[4] L.GlobalShadows=not on if on then for _,o in ipairs(L:GetChildren()) do if o:IsA("BloomEffect") or o:IsA("BlurEffect") or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") then if fxS[o]==nil then fxS[o]=o.Enabled end o.Enabled=false end end else for o,w in pairs(fxS) do if o.Parent then o.Enabled=w end end fxS={} end end)
end
local function shutdown()
 pcall(function() RS:UnbindFromRenderStep("ReaperAim") end)
 CFG.Aimbot=false CFG.ESP=false CFG.Fly=false CFG.LootESP=false
 CFG.AutoFire=false CFG.AutoMed=false
 pcall(stopFly) pcall(clearAllESP) pcall(clearLoot)
 pcall(setFog,false) pcall(setBright,false) pcall(setLag,false)
 pcall(function() local ch=LP.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") if h then h.WalkSpeed=16 if h.UseJumpPower then h.JumpPower=50 end end end)
 if tGui then pcall(function() tGui:Destroy() end) end
 gui:Destroy()
end
bClose.MouseButton1Click:Connect(function() shutdown() toast("Reaper Aim","Fechado e desativado.",3) end)
bMin.MouseButton1Click:Connect(function() setMini(true) end)
local circ=mk("Frame",gui,{Name="ReaperFOV",Size=U2(0,CFG.FOV*2,0,CFG.FOV*2),Position=U2(.5,-CFG.FOV,.5,-CFG.FOV),BackgroundTransparency=1,Visible=false})
mk("UICorner",circ,{CornerRadius=UD(1,0)})
mk("UIStroke",circ,{Color=AC,Thickness=1.5,Transparency=.3})
local function reCircle()
 circ.Size=U2(0,CFG.FOV*2,0,CFG.FOV*2)
 circ.Position=U2(.5,-CFG.FOV,.5,-CFG.FOV)
end
local function pressAim(down)
 if down then
 if CFG.ToggleMode then ST.firing=not ST.firing else ST.firing=true end
 elseif not CFG.ToggleMode then
 ST.firing=false
 end
end
local function pressFire() ST.fireUntil=os.clock()+1 fireWeapon() end
local function pressFly(dir,down)
 if dir>0 then ST.flyUp=down else ST.flyDown=down end
end
local function mkBtn(par,txt,w,h,dn,up)
 local b=mk("TextButton",par,{Size=U2(0,w,0,h),BackgroundColor3=C(34,24,29),BackgroundTransparency=.05,Text=txt,Font=F.GothamBold,TextSize=13,TextColor3=TX,ZIndex=3})
 mk("UICorner",b,{CornerRadius=UD(0,9)})
 local st=mk("UIStroke",b,{Color=AC,Transparency=.45,Thickness=1.5})
 b.MouseButton1Down:Connect(function() b.BackgroundColor3=C(110,22,40) st.Transparency=.05 if dn then dn() end end)
 local function rel()
 b.BackgroundColor3=C(34,24,29) st.Transparency=.45
 if up then up() end
 end
 b.MouseButton1Up:Connect(rel)
 b.MouseLeave:Connect(rel)
 return b
end
local function buildTouch(on)
 if on then
 if tGui then return end
 local root=nil
 pcall(function() root=(gethui and gethui()) or game:GetService("CoreGui") end)
 if not root then pcall(function() root=LP:WaitForChild("PlayerGui",5) end) end
 if not root then return end
 tGui=mk("ScreenGui",root,{Name="ReaperTouch",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=99999})
 local a=mkBtn(tGui,"AIM",74,74,function() pressAim(true) end,function() pressAim(false) end)
 a.Position=U2(1,-92,1,-118)
 local f=mkBtn(tGui,"FIRE",58,58,function() pressFire() end,nil)
 f.Position=U2(1,-92,1,-206)
 upBtn=mkBtn(tGui,"^",50,34,function() pressFly(1,true) end,function() pressFly(1,false) end)
 upBtn.Position=U2(1,-180,1,-168)
 downBtn=mkBtn(tGui,"v",50,34,function() pressFly(-1,true) end,function() pressFly(-1,false) end)
 downBtn.Position=U2(1,-180,1,-100)
 upBtn.Visible=CFG.Fly downBtn.Visible=CFG.Fly
 elseif tGui then
 tGui:Destroy() tGui=nil upBtn=nil downBtn=nil
 end
end
local home=pages.Home
sect(home,"Jogador")
local homeName=mk("TextLabel",home,{Size=U2(1,0,0,34),BackgroundColor3=RW,Text="",Font=F.GothamBold,TextSize=12,TextColor3=TX,LayoutOrder=ord+1})
mk("UICorner",homeName,{CornerRadius=UD(0,7)})
ord=ord+1
sect(home,"Atalhos")
btn(home,"Abrir Aimbot",function() show("Aimbot") end)
btn(home,"Abrir Visuals",function() show("Visuals") end)
btn(home,"Abrir Botoes (AIM/FIRE)",function() show("Botoes") end)
sect(home,"Status")
local stLbl=note(home,"",66)
stLbl.Font=F.Code
local vis=pages.Visuals
sect(vis,"ESP")
tog(vis,"ESP Jogadores e Bots","ESP",function(v) if not v then clearAllESP() end end)
tog(vis,"Antena","Antenna")
tog(vis,"ESP de Loot","LootESP",function(v) if not v then clearLoot() else task.spawn(scanLoot) end end)
note(vis,"Vermelho = visivel   Roxo = atras de objeto\nLaranja = bot visivel   Azul = bot atras",44)
sect(vis,"Aviso de perigo")
tog(vis,"Aviso direcional (perigo)","Danger")
step(vis,"Distancia do aviso","DangerDist",10,20,300)
sect(vis,"Ambiente")
tog(vis,"Remover neblina","NoFog",function(v) setFog(v) end)
tog(vis,"Fullbright","Fullbright",function(v) setBright(v) end)
local ap=pages.Aimbot
sect(ap,"Controle")
tog(ap,"Enable Aimbot","Aimbot",function(v) circ.Visible=v end)
tog(ap,"Toggle Mode (Mobile Friendly)","ToggleMode",function(v) if not v then ST.firing=false end end)
tog(ap,"Manter alvo (Sticky)","Sticky")
tog(ap,"Team Check","TeamCheck")
tog(ap,"Visible Check (Wall Check)","WallCheck")
tog(ap,"Prediction","Prediction")
tog(ap,"Atirar automatico","AutoFire")
note(ap,"So trava com alvo perto da mira, dentro do angulo e da distancia. Nao puxa jogador de longe nem das laterais.",40)
sect(ap,"Onde mirar")
radio(ap,"TargetPart",{{t="Cabeca",v="Head"},{t="Corpo",v="Body"}})
sect(ap,"Modo de mira")
radio(ap,"Mode",{{t="Camera",v="Camera"},{t="Mouse",v="Mouse"},{t="Silent",v="Silent"}})
sect(ap,"Ajustes")
step(ap,"FOV (pixels)","FOV",10,30,400,reCircle)
step(ap,"Angulo maximo (graus)","MaxAngle",5,5,90)
step(ap,"Velocidade da mira","Smooth",10,20,100)
step(ap,"Distancia maxima (studs)","MaxDist",25,25,2000)
local fp=pages.FPS
sect(fp,"Desempenho")
tog(fp,"Anti-Lag","AntiLag",function(v) setLag(v) end)
sect(fp,"Medidor")
local fpsLbl=note(fp,"FPS: --",34)
fpsLbl.Font=F.Code
note(fp,"Neblina/Fullbright: aba Visuals.",28)
local chr=pages.Character
sect(chr,"Movimento")
tog(chr,"Voar","Fly",function(v) if not v then stopFly() end if upBtn then upBtn.Visible=v downBtn.Visible=v end end)
step(chr,"Velocidade do voo","FlySpeed",10,20,300)
step(chr,"Speed (WalkSpeed)","WalkSpeed",2,8,300,applyChar)
step(chr,"JumpPower","JumpPower",5,20,300,applyChar)
sect(chr,"Vida")
tog(chr,"Kit medico automatico","AutoMed",function(v) if v then ST.lastMed=0 end end)
step(chr,"Curar abaixo de","MedAt",5,10,95)
local bt=pages.Botoes
sect(bt,"Para que serve")
note(bt,[[
AIM = liga ou segura a mira, sem atirar.
FIRE = dispara a arma e liga a mira por 1 seg.
^ e v = sobem e descem com o voo ligado.
No PC nao precisa: clique ou segure o mouse.
]],86)
sect(bt,"Testar aqui")
local brow=mk("Frame",bt,{Size=U2(1,0,0,76),BackgroundTransparency=1,LayoutOrder=ord+1})
ord=ord+1
local tb1=mkBtn(brow,"AIM",66,64,function() pressAim(true) end,function() pressAim(false) end)
tb1.Position=U2(0,0,0,4)
local tb2=mkBtn(brow,"FIRE",58,58,function() pressFire() end,nil)
tb2.Position=U2(0,80,0,7)
local tb3=mkBtn(brow,"^",46,30,function() pressFly(1,true) end,function() pressFly(1,false) end)
tb3.Position=U2(0,152,0,2)
local tb4=mkBtn(brow,"v",46,30,function() pressFly(-1,true) end,function() pressFly(-1,false) end)
tb4.Position=U2(0,152,0,40)
sect(bt,"Na tela do jogo")
tog(bt,"Mostrar botoes na tela","ShowBtns",function(v) buildTouch(v) end)
note(bt,"Desligado: nada fica por cima do jogo.\nLigado: AIM/FIRE flutuantes no canto da tela.",58)
local cg=pages.Config
sect(cg,"Interface")
step(cg,"Tamanho da interface %","Scale",10,60,180,function() uisc.Scale=CFG.Scale/100 end)
btn(cg,"Restaurar tamanho",function() CFG.Scale=100 uisc.Scale=1 toast("Reaper Aim","Tamanho restaurado (100%).",3) end)
sect(cg,"Servidor")
btn(cg,"Copiar JobId",function() if setclipboard then setclipboard(game.JobId) end toast("Reaper Aim","JobId copiado.",3) end)
btn(cg,"Reconectar neste servidor",function() TPS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end)
sect(cg,"Geral")
btn(cg,"Resetar todas as funcoes",function() for k,v in pairs(CFG) do if type(v)=="boolean" then CFG[k]=false end end CFG.FOV=70 CFG.Smooth=45 CFG.MaxAngle=30 CFG.MaxDist=180 CFG.MedAt=60 CFG.FlySpeed=60 CFG.WalkSpeed=16 CFG.JumpPower=50 CFG.TargetPart="Head" CFG.DangerDist=80 clearAllESP() clearLoot() stopFly() circ.Visible=false reCircle() buildTouch(false) setLag(false) setFog(false) setBright(false) applyChar() toast("Reaper Aim","Tudo resetado.",3) end)
local nv=pages.Novidades
sect(nv,"v23 - atual")
note(nv,[[
* Mira so trava com alvo perto da mira,
  dentro do angulo e da distancia.
* Botao "Manter alvo" (Sticky).
* Aviso de perigo nos lados e atras.
* ESP limpo: nome + barra de vida.
* AIM/FIRE saem da tela: aba Botoes.
* Funcoes duplicadas removidas.
* Abas Novidades e Config no topo.
* Rolagem das abas corrigida.
* Antena do ESP ajustada.
* Menu nao some mais (abas voltaram).
]],200)
sect(nv,"v22")
note(nv,[[
* Mira so trava quando voce atira.
* Ponto do tiro: cabeca/corpo.
* ESP com cor por visibilidade.
* Nome, vida e distancia no ESP.
* Botao redondo Reaper.
* Tamanho da interface ajustavel.
]],96)
local cd=pages.Creditos
sect(cd,"Sobre")
note(cd,[[
Reaper Aim v23
PC: clique ou segure o mouse.
Celular: toque em atirar; AIM segura
a mira e FIRE dispara.
Sem tecla de atalho.
]],110)
show(pages.Home and "Home" or "Novidades")
local dPan={}
local function dPanel(pos,txt)
 local f=mk("Frame",gui,{Size=U2(0,120,0,34),Position=pos,BackgroundColor3=C(190,28,44),BackgroundTransparency=.35,Visible=false,ZIndex=60})
 mk("UICorner",f,{CornerRadius=UD(0,8)})
 mk("UIStroke",f,{Color=C(255,120,140),Thickness=2,Transparency=.1})
 local l=mk("TextLabel",f,{Size=U2(1,-8,1,0),Position=U2(0,4,0,0),BackgroundTransparency=1,Text=txt,Font=F.GothamBold,TextSize=12,TextColor3=C(255,245,247),ZIndex=61})
 return {f=f,l=l}
end
dPan.L=dPanel(U2(0,6,.5,-17),"< PERIGO")
dPan.R=dPanel(U2(1,-126,.5,-17),"PERIGO >")
dPan.B=dPanel(U2(.5,-60,1,-46),"ATRAS")
local function updDanger()
 if not CFG.Danger then
 for _,k in ipairs({"L","R","B"}) do dPan[k].f.Visible=false end
 return
 end
 local near={L=1e9,R=1e9,B=1e9}
 local cnt={L=0,R=0,B=0}
 local cam=workspace.CurrentCamera
 local ch=LP.Character
 local my=ch and ch:FindFirstChild("HumanoidRootPart")
 if cam and my then
 local look=cam.CFrame.LookVector
 look=Vector3.new(look.X,0,look.Z)
 if look.Magnitude>0.01 then
 look=look.Unit
 local right=look:Cross(Vector3.yAxis)
 local eye=my.Position
 local function scan(c)
 if not c or c==ch then return end
 local h=c:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return end
 local pt=headOf(c)
 if not pt then return end
 local d=pt.Position-eye
 local dist=d.Magnitude
 if dist>CFG.DangerDist or dist<1 then return end
 local flat=Vector3.new(d.X,0,d.Z)
 if flat.Magnitude<1 then return end
 local ang=math.deg(math.atan2(flat:Dot(right),flat:Dot(look)))
 local k=nil
 if ang>=145 or ang<=-145 then k="B"
 elseif ang>40 then k="R"
 elseif ang<-40 then k="L" end
 if k then
 cnt[k]=cnt[k]+1
 if dist<near[k] then near[k]=dist end
 end
 end
 for _,p in ipairs(P:GetPlayers()) do
 if p~=LP then scan(p.Character) end
 end
 for _,b in ipairs(ST.bots) do scan(b.char) end
 end
 end
 local pulse=.26+.18*math.sin(os.clock()*7)
 local tags={L="< PERIGO",R="PERIGO >",B="ATRAS"}
 for _,k in ipairs({"L","R","B"}) do
 local p=dPan[k]
 if CFG.Danger and cnt[k]>0 then
 p.f.Visible=true
 p.f.BackgroundTransparency=pulse
 p.l.Text=tags[k].." "..math.floor(near[k]).."m"
 ..(cnt[k]>1 and (" x"..cnt[k]) or "")
 else
 p.f.Visible=false
 end
 end
end
task.spawn(function() while gui.Parent do task.wait(0.15) pcall(updDanger) end end)
local function overPanel()
 if not gui.Parent or not win.Visible then return false end
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
UIS.InputBegan:Connect(function(i) if overPanel() then return end local t=i.UserInputType if t==EIT.MouseButton1 or i.KeyCode==KC.ButtonR2 then if CFG.ToggleMode then ST.firing=not ST.firing else ST.firing=true end pulse() elseif t==EIT.Touch then local v=workspace.CurrentCamera.ViewportSize if i.Position.X>v.X*0.55 and i.Position.Y>v.Y*0.35 then pulse() end end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.KeyCode==KC.ButtonR2 then if not CFG.ToggleMode then ST.firing=false end end end)
local function refreshBots()
 if not (CFG.ESP or CFG.Aimbot or CFG.Danger) then return end
 local out={}
 for _,d in ipairs(workspace:GetDescendants()) do
 if d:IsA("Humanoid") and d.Health>0 then
 local c=d.Parent
 if c and not P:GetPlayerFromCharacter(c) then
 table.insert(out,{char=c,part=headOf(c)})
 end
 end
 end
 ST.bots=out
end
task.spawn(function() while gui.Parent do task.wait(1) pcall(refreshBots) end end)
task.spawn(function() while gui.Parent do task.wait(0.15) if CFG.ESP then for _,p in ipairs(P:GetPlayers()) do if p~=LP then applyESP(p.Character) end end for _,b in ipairs(ST.bots) do applyESP(b.char) end for ch,d in pairs(ST.esp) do local h=ch:FindFirstChildOfClass("Humanoid") if not ch.Parent or not h or h.Health<=0 then clearESP(ch) else local vis=freeSight(ch) local col=d.isP and (vis and CV or CB) or (vis and BV or BB) d.hl.FillColor=col d.label.TextColor3=col d.label.Text=d.pname..(d.isP and "" or " [BOT]") if d.hp then d.hp.Size=U2(math.clamp(h.Health/math.max(h.MaxHealth,1),0,1),0,1,0) d.hp.BackgroundColor3=col end if d.spike then d.spike.Visible=CFG.Antenna d.spike.BackgroundColor3=col end if d.cap then d.cap.Visible=CFG.Antenna d.cap.BackgroundColor3=col end end end elseif next(ST.esp) then clearAllESP() end end end)
task.spawn(function() while gui.Parent do task.wait(3) if CFG.LootESP then pcall(scanLoot) elseif next(ST.loot) then clearLoot() end end end)
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
task.spawn(function() while gui.Parent do task.wait(0.5) if CFG.AutoMed then local ch=LP.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") if h and h.Health>0 and h.Health<=CFG.MedAt and h.MoveDirection.Magnitude<0.1 and os.clock()-ST.lastMed>1.8 then ST.lastMed=os.clock() local t=findMed(ch) if t then if t.Parent~=ch then pcall(function() h:EquipTool(t) end) task.wait(0.3) end if t.Parent==ch then pcall(function() t:Activate() end) task.wait(0.15) pcall(function() t:Activate() end) end end end end end end)
task.spawn(function() while gui.Parent do task.wait(2) if pages.Home.Visible then local ch=LP.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") homeName.Text="  "..LP.Name..(h and ("   |   HP "..math.floor(h.Health)) or "") stLbl.Text=string.format("Aimbot: %s   Modo: %s\nFOV: %d   Ponto: %s\nMira: %s   ESP: %s",CFG.Aimbot and "ON" or "OFF",CFG.Mode,CFG.FOV,CFG.TargetPart=="Head" and "cabeca" or "corpo",holding() and "ATIVA" or "espera",CFG.ESP and "ON" or "OFF") end end end)
local fpsNow=0 local fc=0 local ft0=os.clock()
RS.RenderStepped:Connect(function() fc=fc+1 local n=os.clock() if n-ft0>=0.5 then fpsNow=math.floor(fc/(n-ft0)+.5) fc=0 ft0=n end end)
task.spawn(function() while gui.Parent do task.wait(0.5) if pages.FPS.Visible then fpsLbl.Text=string.format("FPS: %d   Anti-Lag: %s",fpsNow,CFG.AntiLag and "ON" or "OFF") end end end)
RS.Heartbeat:Connect(function() if not gui.Parent then return end if CFG.Fly then local ch=LP.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") local r=ch and ch:FindFirstChild("HumanoidRootPart") if h and r then h.PlatformStand=true local d=Vector3.zero local mv=h.MoveDirection if mv.Magnitude>0.05 then d=Vector3.new(mv.X,0,mv.Z).Unit*CFG.FlySpeed end if UIS:IsKeyDown(KC.Space) or ST.flyUp then d=d+Vector3.new(0,CFG.FlySpeed,0) end if UIS:IsKeyDown(KC.LeftShift) or ST.flyDown then d=d-Vector3.new(0,CFG.FlySpeed,0) end r.AssemblyLinearVelocity=d end else applyChar() end end)
RS:BindToRenderStep("ReaperAim",Enum.RenderPriority.Camera.Value+1,function() if not gui.Parent then return end circ.Visible=CFG.Aimbot if not CFG.Aimbot then ST.lock=nil return end if not holding() or overPanel() then ST.lock=nil return end local ch=LP.Character local h=ch and ch:FindFirstChildOfClass("Humanoid") if not h or h.Health<=0 then ST.lock=nil return end local t=pick() if not t then ST.lock=nil return end ST.lock=t local tp=t.part if not tp or not tp.Parent then ST.lock=nil return end local p=aimPos(t) if CFG.Mode=="Mouse" then mouseTo(p) else camTo(p) end if CFG.AutoFire then fireWeapon() end end)
toast("Reaper Aim v23","Clique ou segure para mirar.",5)
