local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local localPlayer=Players.LocalPlayer
local isFiring=false
local currentTool=nil
local fireRate=0.001
local rapidFireEnabled=true
local function removeDelays(tool)
if tool then
local success,connections=pcall(getconnections,tool.Activated)
if success and connections then
for _,v in ipairs(connections) do
local success,funcinfo=pcall(debug.getinfo,v.Function)
if success and funcinfo then
for i=1,math.min(funcinfo.nups or 0,10) do
local success,c=pcall(debug.getupvalue,v.Function,i)
if success and type(c)=="number" then
pcall(debug.setupvalue,v.Function,i,0)
end
end
end
end
end
end
end
local function startRapidFire()
if not currentTool then return end
if not rapidFireEnabled then return end
isFiring=true
while isFiring and currentTool and currentTool.Parent and rapidFireEnabled do
pcall(function()
currentTool:Activate()
end)
task.wait(fireRate)
end
end
local function toggleRapidFire()
rapidFireEnabled=not rapidFireEnabled
if not rapidFireEnabled then
isFiring=false
end
end
UserInputService.InputBegan:Connect(function(input,gameProcessed)
if gameProcessed then return end
if input.KeyCode==Enum.KeyCode.M then
toggleRapidFire()
end
if input.UserInputType==Enum.UserInputType.MouseButton1 and rapidFireEnabled then
if isFiring then return end
task.spawn(startRapidFire)
end
end)
UserInputService.InputEnded:Connect(function(input)
if input.UserInputType==Enum.UserInputType.MouseButton1 then
isFiring=false
end
end)
local function onCharacterAdded(character)
task.wait(0.5)
local function checkTools()
if not character or not character.Parent then return end
local tool=character:FindFirstChildOfClass("Tool")
if tool and tool~=currentTool then
currentTool=tool
pcall(function()
removeDelays(tool)
end)
elseif not tool then
currentTool=nil
end
end
checkTools()
character.ChildAdded:Connect(function(child)
if child:IsA("Tool") then
task.wait(0.1)
currentTool=child
pcall(function()
removeDelays(child)
end)
end
end)
character.ChildRemoved:Connect(function(child)
if child:IsA("Tool") and child==currentTool then
currentTool=nil
isFiring=false
end
end)
end
if localPlayer.Character then
onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)
