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
local CFG={ Hud=true,Scale=100,Notify=true,AutoDig=false,AutoSmelt=false,AutoUpgrade=false,AutoNpc=false,AutoMuseum=false,AutoNugget=false,Partner=false,SmeltAt=10,Delay=1.2,TpSpot=true,Esp=false,EspName=true,Fog=false,Full=false,AntiLag=false,Speed=16,Jump=50,InfJump=false,Noclip=false,NoobSize=100,Trails=false,Avatar=false,TpOn=true,}
local ST={esp={},logs={},idx=1,target=LP,dest=nil,status="Pronto",ores=0,bars=0,bp=0,spots=0,session=0,cd={},acc=nil,bc=nil,trail=nil,lastSpot=nil,noobs=0}
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

local function cr(o,a,b)local u=Instance.new("UICorner")u.CornerRadius=UD(a,b)u.Parent=o return u end
local function toast(a,b,d)
 if not CFG.Notify then return end
 pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title=tostring(a),Text=tostring(b),Duration=d or 4}) end)
end
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
mk("TextLabel",bar,{Size=U2(0,250,0,16),Position=U2(0,30,0,6),Text="Reaper Gold",TextSize=13,TextColor3=TX})
mk("TextLabel",bar,{Size=U2(0,250,0,12),Position=U2(0,30,0,23),Text="Gold Hunters 2.0  •  modo parceiro",Font=F.Gotham,TextSize=9,TextColor3=MU})
local function barBtn(txt,x)
 local b=mk("TextButton",bar,{Size=U2(0,28,0,26),Position=U2(1,x,.5,-13),BackgroundTransparency=1,Text=txt,TextSize=13,TextColor3=MU,ZIndex=4})
 mk("UICorner",b,{CornerRadius=UD(0,6)})
 b.MouseEnter:Connect(function() b.TextColor3=TX b.BackgroundTransparency=.4 end)
 b.MouseLeave:Connect(function() b.TextColor3=MU b.BackgroundTransparency=1 end)
 return b
end
local bMin=barBtn("-",-96) local bMax=barBtn("o",-64) local bClose=barBtn("X",-32)
local mini=mk("TextButton",gui,{Size=U2(0,58,0,58),Position=U2(0,16,0,110),BackgroundColor3=AC,Visible=false,ZIndex=20})
mk("UICorner",mini,{CornerRadius=UD(1,0)})
mk("UIStroke",mini,{Color=C(255,140,160),Thickness=2})
mk("TextLabel",mini,{Size=U2(1,0,0,18),Position=U2(0,0,0,13),Text="R",TextSize=20,TextColor3=C(255,255,255),TextXAlignment=Enum.TextXAlignment.Center})
mk("TextLabel",mini,{Size=U2(1,0,0,12),Position=U2(0,0,0,33),Text="Gold",TextSize=8,TextColor3=C(255,240,240),TextXAlignment=Enum.TextXAlignment.Center})
local function setMini(on) win.Visible=not on mini.Visible=on end
local drag,dS,dP=false,nil,nil
local mDrag,mS,mP,mM=false,nil,nil,0
local function startDrag(i,isMini)
 if isMini then mDrag=true mS=i.Position mP=mini.Position mM=0
 else drag=true dS=i.Position dP=win.Position end
 i.Changed:Connect(function() if i.UserInputState~=Enum.UserInputState.End then return end if isMini then mDrag=false if mM<8 then setMini(false) end else drag=false end end)
end
bar.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,false) end end)
mini.InputBegan:Connect(function(i) if i.UserInputType==EIT.MouseButton1 or i.UserInputType==EIT.Touch then startDrag(i,true) end end)
UIS.InputChanged:Connect(function(i) if i.UserInputType~=EIT.MouseMovement and i.UserInputType~=EIT.Touch then return end if drag and dS then local o=i.Position-dS win.Position=U2(dP.X.Scale,dP.X.Offset+o.X,dP.Y.Scale,dP.Y.Offset+o.Y) elseif mDrag and mS then local o=i.Position-mS mM=math.max(mM,o.Magnitude) mini.Position=U2(mP.X.Scale,mP.X.Offset+o.X,mP.Y.Scale,mP.Y.Offset+o.Y) end end)
local zoom=false
bMax.MouseButton1Click:Connect(function() zoom=not zoom if zoom then win.Position=U2(0,6,0,6) win.Size=U2(1,-12,1,-12) else win.Position=U2(0,math.max(8,(VPS.X-WW)/2),0,64) win.Size=U2(0,WW,0,WH) end end)
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
 local gl=mk("TextLabel",b,{Size=U2(0,18,1,0),Position=U2(0,10,0,0),Text=it[2],TextSize=navFS,TextColor3=MU})
 local tx=mk("TextLabel",b,{Size=U2(1,-34,1,0),Position=U2(0,32,0,0),Text=it[1],Font=F.GothamMedium,TextSize=navFS,TextColor3=MU})
 navs[it[1]]={bg=b,bar=bar0,gl=gl,txt=tx}
 b.MouseButton1Click:Connect(function() show(it[1]) end)
 if it[1]~="Automacao" then pcall(newPage,it[1]) end
end
local chip=mk("Frame",side,{Size=U2(1,-14,0,34),Position=U2(0,7,1,-42),BackgroundTransparency=1})
local av=mk("Frame",chip,{Size=U2(0,24,0,24),Position=U2(0,4,.5,-12),BackgroundColor3=GD})
mk("UICorner",av,{CornerRadius=UD(1,0)})
mk("TextLabel",av,{Size=U2(1,0,1,0),Text=string.sub(LP.Name,1,1):upper(),TextSize=12,TextColor3=C(28,22,10),TextXAlignment=Enum.TextXAlignment.Center})
mk("TextLabel",chip,{Size=U2(1,-44,1,0),Position=U2(0,36,0,0),Text=LP.Name,Font=F.GothamMedium,TextSize=11,TextColor3=MU})
local function sect(par,t)
 ord=ord+1
 return mk("TextLabel",par,{Size=U2(1,0,0,20),Text=string.upper(t),TextSize=10,TextColor3=GD,LayoutOrder=ord})
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
 return mk("TextLabel",r,{Size=U2(1,-76,1,0),Position=U2(0,12,0,0),Text=t,Font=F.GothamMedium,TextSize=12,TextColor3=TX})
end
local function tog(par,t,k,cb)
 local r=row(par,30)
 tlab(r,t)
 local pill=mk("Frame",r,{Size=U2(0,44,0,22),Position=U2(1,-54,.5,-11),BackgroundColor3=C(70,64,74)})
 mk("UICorner",pill,{CornerRadius=UD(1,0)})
 local tx=mk("TextLabel",pill,{Size=U2(1,0,1,0),Text="OFF",TextSize=10,TextColor3=C(240,236,241),TextXAlignment=Enum.TextXAlignment.Center})
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
 mk("TextLabel",r,{Size=U2(1,-104,0,15),Position=U2(0,11,0,8),Text=t,TextSize=12,TextColor3=TX})
 mk("TextLabel",r,{Size=U2(1,-104,0,26),Position=U2(0,11,0,25),Text=d,Font=F.Gotham,TextSize=10,TextColor3=MU,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
 local pill=mk("Frame",r,{Size=U2(0,58,0,23),Position=U2(1,-70,.5,-11.5),BackgroundColor3=C(70,64,74)})
 mk("UICorner",pill,{CornerRadius=UD(1,0)})
 local tx=mk("TextLabel",pill,{Size=U2(1,0,1,0),Text="OFF",TextSize=10,TextColor3=C(240,236,241),TextXAlignment=Enum.TextXAlignment.Center})
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
 local val=mk("TextLabel",r,{Size=U2(0,46,0,18),Position=U2(1,-104,.5,-9),Text=tostring(CFG[k]),TextSize=12,TextColor3=GD,ZIndex=3})
 local function sb(txt,x,dir)
 local b=mk("TextButton",r,{Size=U2(0,24,0,24),Position=U2(1,x,.5,-12),BackgroundColor3=C(54,43,50),Text=txt,TextSize=13,TextColor3=TX})
 mk("UICorner",b,{CornerRadius=UD(0,6)})
 b.MouseButton1Click:Connect(function() CFG[k]=math.clamp(CFG[k]+dir*st,mn,mx) val.Text=tostring(CFG[k]) if cb then pcall(cb,CFG[k]) end end)
 end
 sb("-",-58,-1) sb("+",-28,1)
end
local function btn(par,t,fn)
 local r=row(par,30)
 tlab(r,t)
 mk("TextLabel",r,{Size=U2(0,16,1,0),Position=U2(1,-24,0,0),Text=">",TextSize=12,TextColor3=MU})
 r.MouseButton1Click:Connect(function() local ok,e=pcall(fn) if not ok then warn("[Reaper] "..tostring(e)) end end)
end
local function note(par,t,h)
 local l=mk("TextLabel",par,{Size=U2(1,0,0,h),BackgroundColor3=RW,BackgroundTransparency=0,Text=t,Font=F.Gotham,TextSize=10.5,TextColor3=MU,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=ord+1})
 mk("UICorner",l,{CornerRadius=UD(0,8)})
 mk("UIPadding",l,{PaddingLeft=UD(0,10),PaddingRight=UD(0,8),PaddingTop=UD(0,8)})
 ord=ord+1
 return l
end
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
RS.Stepped:Connect(function() if not gui.Parent then return end applyChar() if not CFG.Noclip then return end local c=chr() if not c then return end for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") and d.CanCollide then pcall(function() d.CanCollide=false end) end end end)
local function setSize(pct)
 CFG.NoobSize=pct
 local c=chr()
 if not c then return end
 local ok=pcall(function() c:ScaleTo(pct/100) end)
 if not ok then
 local h=hum()
 if h then
 pcall(function() h.BodyHeightScale=pct/100 h.BodyWidthScale=pct/100 h.BodyDepthScale=pct/100 h.HeadScale=pct/100 end)
 end
 end
end
local function trail(on)
 local r=hrp()
 if ST.trail then pcall(function() ST.trail:Destroy() end) ST.trail=nil end
 if not on or not r then return end
 pcall(function() local a0=Instance.new("Attachment") a0.Position=Vector3.new(0,.7,0) a0.Parent=r local a1=Instance.new("Attachment") a1.Position=Vector3.new(0,-.7,0) a1.Parent=r local t=Instance.new("Trail") t.Attachment0=a0 t.Attachment1=a1 t.Lifetime=.7 t.MinLength=.05 t.Color=ColorSequence.new(GD) t.Transparency=NumberSequence.new(.15,1) t.LightEmission=.4 t.Parent=r ST.trail=t end)
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
 pcall(function() bc.HeadColor3=C(255,204,51) bc.TorsoColor3=C(255,204,51) bc.LeftArmColor3=C(255,204,51) bc.RightArmColor3=C(255,204,51) bc.LeftLegColor3=C(46,140,64) bc.RightLegColor3=C(46,140,64) end)
 end
 toast("Avatar","Modo noob ligado.",3)
 else
 if ST.bc then
 local s=ST.bc
 local bc=c:FindFirstChildOfClass("BodyColors")
 if bc then
 pcall(function() bc.HeadColor3=s[1] bc.TorsoColor3=s[2] bc.LeftArmColor3=s[3] bc.RightArmColor3=s[4] bc.LeftLegColor3=s[5] bc.RightLegColor3=s[6] end)
 end
 ST.bc=nil
 end
 for d,par in pairs(ST.acc or {}) do pcall(function() d.Parent=par or c end) end
 ST.acc=nil
 toast("Avatar","Avatar original.",3)
 end
end
local KEY={ dig={"dig","cav","escav","miner","mine","escava"},smelt={"fund","smelt","forge","process","usina"},up={"melhor","upgrad","equip","aument"},quiz={"quiz","pergunt","answer","respost","trivia","escolh","option"},nug={"nugget","pepita","collect","colet","ouro","gold"},hub={"hub","fundidora","smelt","usina","loja","shop"},}
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
 pcall(function() r.CFrame=base.CFrame*CFrame.new(0,3,-(dist or 5)) end)
 return true
end
local function fireP(p)
 if not p or not p.Parent then return false end
 local ok=false
 if fireproximityprompt then ok=pcall(fireproximityprompt,p) end
 if ok then return true end
 ok=pcall(function() p:InputHoldBegin() task.wait(math.clamp((p.HoldDuration or 0)+0.1,.1,.6)) p:InputHoldEnd() end)
 return ok
end
local function ready(k,sec)
 local n=os.clock()
 if (ST.cd[k] or 0)>n then return false end
 ST.cd[k]=n+sec
 return true
end
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
local function autoDig()
 local sp=findP(KEY.dig,3)
 ST.spots=#sp
 if #sp==0 then ST.status="Nenhum ponto de escavação por perto" return end
 local p=sp[1]
 local base=p.Parent
 if CFG.TpSpot then tpNear(p,5) task.wait(.15) end
 if fireP(p) then
 ST.status="Cavando: "..(base and base.Name or "?")
 ST.lastSpot=base
 ST.ores=ST.ores+1
 ST.session=ST.session+1
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
local function autoNugget()
 local sp=findP(KEY.nug,4)
 if #sp==0 then ST.status="Nenhuma pepita visível" return end
 local p=sp[1]
 if CFG.TpSpot then tpNear(p,4) task.wait(.12) end
 if fireP(p) then ST.status="Coletando: "..(p.Parent and p.Parent.Name or "pepita") end
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
task.spawn(function() while gui.Parent do task.wait(.25) pcall(function() local ore=num(ORE) or ST.ores if CFG.Partner and CFG.AutoDig and ore>=CFG.SmeltAt and ready("partner",3) then ST.status="Saco cheio: voltando ao hub" local back=ST.lastSpot CFG.AutoDig=false local hub=findP(KEY.hub,1) if #hub>0 then tpNear(hub[1],6) task.wait(1) end autoSmelt() task.wait(1) autoUpgrade() task.wait(.6) if back and back.Parent then tpNear(back,5) end CFG.AutoDig=true ST.status="Voltando a cavar" return end if CFG.AutoDig and ready("dig",CFG.Delay) then autoDig() return end if CFG.AutoSmelt and ready("smelt",2.2) then local ore2=num(ORE) or ST.ores if ore2>=CFG.SmeltAt then autoSmelt() else ST.status="Aguardando "..CFG.SmeltAt.." minérios" end return end if CFG.AutoUpgrade and ready("up",6) then autoUpgrade() return end if CFG.AutoNugget and ready("nug",1.6) then autoNugget() return end if CFG.AutoNpc and ready("npc",5) then autoQuiz() return end if CFG.AutoMuseum and ready("mus",7) then autoMuseum() return end end) end end)
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
 local nm=mk("TextLabel",bb,{Size=U2(1,0,1,0),Text=pl.Name,TextSize=12,TextColor3=GD,TextStrokeTransparency=.5})
 ST.esp[c]={hl=hl,bb=bb,nm=nm}
end
task.spawn(function() while gui.Parent do task.wait(.4) if CFG.Esp then for _,p in ipairs(P:GetPlayers()) do if p~=LP then applyESP(p.Character) end end for c,d in pairs(ST.esp) do local h=c:FindFirstChildOfClass("Humanoid") if not c.Parent or not h or h.Health<=0 then clearESP(c) else d.nm.Visible=CFG.EspName end end elseif next(ST.esp) then clearAll() end end end)
local fogS={L.FogStart,L.FogEnd,L.FogColor}
local ligS={L.Brightness,L.OutdoorAmbient,L.GlobalShadows}
local function setFog(on)
 pcall(function() if on then L.FogStart=0 L.FogEnd=1000000 L.FogColor=C(200,200,200) else L.FogStart=fogS[1] L.FogEnd=fogS[2] L.FogColor=fogS[3] end end)
end
local function setFull(on)
 pcall(function() if on then L.Brightness=3 L.OutdoorAmbient=C(200,200,200) L.GlobalShadows=false else L.Brightness=ligS[1] L.OutdoorAmbient=ligS[2] L.GlobalShadows=ligS[3] end end)
end
local fxS={}
local function setLag(on)
 pcall(function() if on then for _,o in ipairs(L:GetChildren()) do if o:IsA("BloomEffect") or o:IsA("BlurEffect") or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") then if fxS[o]==nil then fxS[o]=o.Enabled end o.Enabled=false end end else for o,w in pairs(fxS) do if o.Parent then o.Enabled=w end end fxS={} end end)
end
local Store=(typeof(getgenv)=="function" and getgenv()) or _G
if type(Store.RG_TP_Logs)~="table" then Store.RG_TP_Logs={} end
ST.logs=Store.RG_TP_Logs
local logScroll
local function renderLogs()
 if not logScroll then return end
 for _,c in ipairs(logScroll:GetChildren()) do
 if c:IsA("TextLabel") then c:Destroy() end
 end
 for i,it in ipairs(ST.logs) do
 mk("TextLabel",logScroll,{Size=U2(1,-6,0,14),Position=U2(0,3,0,(i-1)*15),Text="["..it.t.."] "..it.n.." ("..it.c..")",Font=F.Gotham,TextSize=9,TextColor3=C(150,245,175)})
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
local home=pages.Home
sect(home,"Jogador")
local homeName=mk("TextLabel",home,{Size=U2(1,0,0,32),BackgroundColor3=RW,BackgroundTransparency=0,TextSize=12,TextColor3=TX,LayoutOrder=ord+1})
mk("UICorner",homeName,{CornerRadius=UD(0,8)})
ord=ord+1
sect(home,"Atalhos")
btn(home,"Abrir Automação",function() show("Automacao") end)
btn(home,"Abrir TP Hub",function() show("TP Hub") end)
btn(home,"Abrir Info (tutorial)",function() show("Info") end)
sect(home,"Ao vivo")
local homeLive=note(home,"",62)
homeLive.Font=F.Code
local host=mk("Frame",cont,{Size=U2(1,-16,1,-16),Position=U2(0,8,0,8),BackgroundTransparency=1,Visible=false})
pages.Automacao=host
local SEG={"Automação","Painel","Ajustes"}
local segP,segB={},{}
for i,n in ipairs(SEG) do
 local b=mk("TextButton",host,{Size=U2(1/3,-6,0,30),Position=U2((i-1)/3,4,0,0),BackgroundColor3=RW,Text=n,TextSize=10,TextColor3=MU})
 mk("UICorner",b,{CornerRadius=UD(0,8)})
 local p=mkScroll(host,U2(1,0,1,-40),U2(0,0,0,40))
 p.Visible=(i==1)
 segP[n]=p segB[n]=b
 b.MouseButton1Click:Connect(function() for m,q in pairs(segP) do q.Visible=(m==n) end for m,q in pairs(segB) do local on=(m==n) q.BackgroundColor3=on and GD or RW q.TextColor3=on and C(30,23,10) or MU end end)
end
for m,q in pairs(segB) do
 local on=(m=="Automação")
 q.BackgroundColor3=on and GD or RW
 q.TextColor3=on and C(30,23,10) or MU
end
local au=segP["Automação"]
sect(au,"Automação do jogo")
card(au,"Auto Cavar","Escava nos pontos de minério automaticamente",("AutoDig"),function(v) ST.status=v and "Auto cavar ligado" or "Auto cavar desligado" end)
card(au,"Auto Fundir Barras","Smelta quando tiver 10+ minérios de ouro","AutoSmelt")
card(au,"Auto Melhorar","Usa a fundidora/equipamento para melhorar sozinho","AutoUpgrade")
card(au,"Auto NPC Quiz (+1 barra)","Responde o quiz do NPC a cada 2 horas","AutoNpc")
card(au,"Auto Museu (UGC)","Resolve os 6 quizzes do museu para liberar UGC","AutoMuseum")
card(au,"Auto Coletar Pepitas","Coleta os 15 itens do hub a cada reset de 2h","AutoNugget")
card(au,"Modo Parceiro","Cava e, ao encher o saco, volta ao hub para fundir e melhorar","Partner")
sect(au,"Ajustes rápidos")
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
btn(pa,"Escanear prompts do mapa",function() local n=#prompts() ST.status="Prompts encontrados: "..n.."  |  pontos de escavação: "..#findP(KEY.dig,9) end)
btn(pa,"Zerar contadores da sessão",function() ST.session=0 ST.ores=0 ST.bars=0 ST.status="Contadores zerados" end)
local aj=segP["Ajustes"]
sect(aj,"Comportamento")
tog(aj,"Notificações do sistema","Notify")
tog(aj,"Sistema TP ativo","TpOn")
step(aj,"Escala da interface %","Scale",10,60,180,function(v) uisc.Scale=v/100 end)
sect(aj,"Manutenção")
btn(aj,"Resetar toda a configuração",function() CFG.AutoDig=false CFG.AutoSmelt=false CFG.AutoUpgrade=false CFG.AutoNpc=false CFG.AutoMuseum=false CFG.AutoNugget=false CFG.Partner=false CFG.Esp=false CFG.Fog=false CFG.Full=false CFG.AntiLag=false CFG.Speed=16 CFG.Jump=50 CFG.InfJump=false CFG.Noclip=false CFG.SmeltAt=10 CFG.Delay=1.2 CFG.TpSpot=true setFog(false) setFull(false) setLag(false) clearAll() trail(false) toast("Reaper Gold","Configuração resetada.",3) end)
local tp=pages["TP Hub"]
sect(tp,"Alvo")
refreshTarget()
local function tgtTxt() return "Alvo: "..(ST.target and ST.target.Name or "?")..(ST.target==LP and " (você)" or "").."  v" end
local tgtBtn=mk("TextButton",tp,{Size=U2(1,0,0,32),BackgroundColor3=C(36,28,52),TextSize=11,TextColor3=TX,Text=tgtTxt(),LayoutOrder=ord+1})
mk("UICorner",tgtBtn,{CornerRadius=UD(0,8)})
ord=ord+1
tgtBtn.MouseButton1Click:Connect(function() local list=P:GetPlayers() if #list==0 then return end ST.idx=(ST.idx%#list)+1 ST.target=list[ST.idx] tgtBtn.Text=tgtTxt() end)
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
local vs=pages.Visual
sect(vs,"Jogadores")
tog(vs,"ESP (destaque + nome)","Esp",function(v) if not v then clearAll() end end)
tog(vs,"Mostrar nome","EspName")
sect(vs,"Ambiente")
tog(vs,"Remover neblina","Fog",function(v) setFog(v) end)
tog(vs,"Fullbright","Full",function(v) setFull(v) end)
tog(vs,"Anti-lag","AntiLag",function(v) setLag(v) end)
note(vs,"Destaque dourado nos jogadores visíveis. Nome em cima da cabeça.",40)
local cfgP=pages.Config
sect(cfgP,"Interface")
tog(cfgP,"Mostrar HUD no jogo","Hud",function(v) hud.Visible=v end)
step(cfgP,"Escala da interface %","Scale",10,60,180,function(v) uisc.Scale=v/100 end)
btn(cfgP,"Centralizar janela",function() local v=workspace.CurrentCamera.ViewportSize win.Position=U2(0,math.max(8,(v.X-WW)/2),0,64) win.Size=U2(0,WW,0,WH) end)
sect(cfgP,"Servidor")
btn(cfgP,"Copiar JobId",function() if setclipboard then setclipboard(game.JobId) end toast("Reaper Gold","JobId copiado.",3) end)
btn(cfgP,"Reconectar neste servidor",function() pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end) end)
local inf=pages.Info
sect(inf,"Como usar")
note(inf,"1. Abra Automação e ligue o que quiser.\n2. O status aparece no rodapé do painel.\n3. Dúvida de alguma função? Está tudo aqui embaixo.",62)
sect(inf,"Cada função")
note(inf,[[
AUTO CAVAR: acha o ponto de escavação mais perto, teleporta e aciona o prompt.
AUTO FUNDIR: com X minérios (padrão 10), vai à fundidora e transforma em barras.
AUTO MELHORAR: procura prompts de melhoria e aciona sozinho.
AUTO NPC QUIZ: responde o quiz do NPC (o +1 barras a cada 2h).
AUTO MUSEU: resolve os 6 quizzes do museu (tiers de UGC).
AUTO PEPITAS: pega os 15 coletáveis do hub a cada reset.
MODO PARCEIRO: cava, volta ao hub ao encher o saco, funde, melhora e retorna.
HUD: Barras de Ouro / Mina de Ouro / Planos à esquerda e dock à direita.
]],236)
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
local cd=pages.Creditos
sect(cd,"Sobre")
note(cd,"Reaper Gold Hub v1\nEstilo: Reaper Aim\nFeito para PC e celular.\nSem tecla de atalho.",74)
hud=mk("Frame",gui,{Size=U2(1,0,1,0),BackgroundTransparency=1,Visible=CFG.Hud})
local function statCard(y,title)
 local f=mk("Frame",hud,{Size=U2(0,112,0,40),Position=U2(0,12,0,y),BackgroundColor3=C(26,22,30),BackgroundTransparency=.15})
 mk("UICorner",f,{CornerRadius=UD(0,8)})
 mk("UIStroke",f,{Color=C(92,74,92),Thickness=1,Transparency=.5})
 mk("TextLabel",f,{Size=U2(1,0,0,13),Position=U2(0,0,0,4),Text=title,TextSize=10,TextColor3=MU,TextXAlignment=Enum.TextXAlignment.Center})
 local v=mk("TextLabel",f,{Size=U2(1,0,0,18),Position=U2(0,0,0,17),Text="0",TextSize=15,TextColor3=TX,TextXAlignment=Enum.TextXAlignment.Center})
 return v
end
local vBars=statCard(58,"Barras de Ouro")
local vOre=statCard(102,"Mina de Ouro")
local vPlan=statCard(146,"Planos")
local infoB=mk("TextButton",hud,{Size=U2(0,104,0,28),Position=U2(0,150,0,14),BackgroundColor3=C(24,21,30),Text="Informação",TextSize=11,TextColor3=TX})
mk("UICorner",infoB,{CornerRadius=UD(1,0)})
mk("UIStroke",infoB,{Color=C(92,74,92),Thickness=1,Transparency=.5})
infoB.MouseButton1Click:Connect(function() setMini(false) show("Info") end)
local sizes={100,70,130}
local si=1
local function dockBtn(i,txt,fn)
 local b=mk("TextButton",hud,{Size=U2(0,112,0,28),Position=U2(1,-122,0,58+(i-1)*32),BackgroundColor3=C(24,21,30),BackgroundTransparency=.12,Text=txt,TextSize=11,TextColor3=TX})
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
task.spawn(function() while gui.Parent do task.wait(1) pcall(function() vBars.Text=tostring(num(BAR) or ST.bars) vOre.Text=tostring(num(ORE) or ST.ores) vPlan.Text=tostring(num(PLAN) or ST.bp) end) end end)
task.spawn(function() while gui.Parent do task.wait(.6) pcall(function() local ore=num(ORE) or ST.ores local bar=num(BAR) or ST.bars tele.Text=string.format("Barras: %s\nMinério: %s / %d\nSessão: +%d minérios   Pontos: %d",tostring(bar or "-"),tostring(ore or "-"),CFG.SmeltAt,ST.session,ST.spots) stat.Text="Status: "..ST.status lsl.Text=lsLine() end) end end)
task.spawn(function() while gui.Parent do task.wait(2) pcall(function() if pages.Home.Visible then local h=hum() homeName.Text="   "..LP.Name..(h and ("    |    HP "..math.floor(h.Health)) or "") homeLive.Text=string.format("Auto cavar: %s   Auto fundir: %s\nModo parceiro: %s   TP: %s\nStatus: %s",CFG.AutoDig and "ON" or "OFF",CFG.AutoSmelt and "ON" or "OFF",CFG.Partner and "ON" or "OFF",CFG.TpOn and "ON" or "OFF",ST.status) end local ls=LP:FindFirstChild("leaderstats") if ls then for _,v in ipairs(ls:GetChildren()) do if v:IsA("ValueBase") then if has(v.Name,ORE) then ST.ores=tonumber(v.Value) or ST.ores end if has(v.Name,BAR) then ST.bars=tonumber(v.Value) or ST.bars end end end end end) end end)
bClose.MouseButton1Click:Connect(function() pcall(function() clearAll() end) pcall(trail,false) pcall(setFog,false) pcall(setFull,false) pcall(setLag,false) pcall(function() local h=hum() if h then h.WalkSpeed=16 if h.UseJumpPower then h.JumpPower=50 end end end) CFG.AutoDig=false CFG.AutoSmelt=false CFG.AutoUpgrade=false CFG.AutoNpc=false CFG.AutoMuseum=false CFG.AutoNugget=false CFG.Partner=false gui:Destroy() toast("Reaper Gold","Fechado e automações desligadas.",3) end)
bMin.MouseButton1Click:Connect(function() setMini(true) end)
refreshTarget()
renderLogs()
show("Home")
task.spawn(function() for _=1,40 do pcall(function() applyChar() end) task.wait(.4) end end)
toast("Reaper Gold v1","HUD pronta. Abra Automação ou TP Hub.",5)
