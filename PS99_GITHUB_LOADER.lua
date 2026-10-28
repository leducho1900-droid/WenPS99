-- PS99 V240 | Public GitHub loader. No source or server secret here.
local API = "https://ps99-key-api.leducho1900.workers.dev"
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then return end

local function requestJSON(path, data)
    local requestFn = (syn and syn.request) or http_request or request
    if type(requestFn) ~= "function" then return nil, "HTTP_UNAVAILABLE" end
    local ok, response = pcall(requestFn, {
        Url=API..path, Method="POST",
        Headers={["Content-Type"]="application/json"},
        Body=HttpService:JSONEncode(data)
    })
    if not ok or type(response)~="table" then return nil,"NETWORK_ERROR" end
    local decodedOk, decoded=pcall(HttpService.JSONDecode,HttpService,response.Body or "")
    if not decodedOk or type(decoded)~="table" then return nil,"BAD_RESPONSE" end
    return decoded, nil
end

-- Executor-specific device identifiers are NOT trustworthy security anchors.
local function deviceID()
    local candidates = {gethwid, get_hwid}
    for _,fn in ipairs(candidates) do
        if type(fn)=="function" then
            local ok,v=pcall(fn)
            if ok and type(v)=="string" and v:match("^[A-Za-z0-9_-]+$") and #v>=24 and #v<=128 then return v end
        end
    end
    return nil
end

local gui=Instance.new("ScreenGui")
gui.Name="PS99_KEY_LOGIN"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.Parent=player:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(330,170)
panel.Position=UDim2.new(.5,-165,.5,-85)
panel.BackgroundColor3=Color3.fromRGB(24,28,43)
panel.Parent=gui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,10)
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,0,0,42)
title.BackgroundTransparency=1
title.Text="PS99 | NHẬP KEY"
title.TextColor3=Color3.new(1,1,1)
title.Font=Enum.Font.GothamBold
title.TextSize=18
title.Parent=panel
local field=Instance.new("TextBox")
field.Size=UDim2.new(1,-32,0,40)
field.Position=UDim2.fromOffset(16,49)
field.BackgroundColor3=Color3.fromRGB(40,46,65)
field.TextColor3=Color3.new(1,1,1)
field.PlaceholderText="Nhập key"
field.Text=""
field.ClearTextOnFocus=false
field.Font=Enum.Font.Gotham
field.TextSize=15
field.Parent=panel
Instance.new("UICorner",field).CornerRadius=UDim.new(0,7)
local login=Instance.new("TextButton")
login.Size=UDim2.new(1,-32,0,38)
login.Position=UDim2.fromOffset(16,99)
login.BackgroundColor3=Color3.fromRGB(65,126,240)
login.TextColor3=Color3.new(1,1,1)
login.Text="ĐĂNG NHẬP"
login.Font=Enum.Font.GothamBold
login.TextSize=15
login.Parent=panel
Instance.new("UICorner",login).CornerRadius=UDim.new(0,7)
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-24,0,25)
status.Position=UDim2.fromOffset(12,142)
status.BackgroundTransparency=1
status.TextColor3=Color3.fromRGB(220,225,240)
status.Font=Enum.Font.Gotham
status.TextSize=12
status.Text=""
status.Parent=panel
local messages={
    INVALID_KEY="Key sai",BLOCKED_KEY="Key bị khóa",
    DELETED_KEY="Key đã bị xóa",DEVICE_MISMATCH="Key đã gắn máy khác",
    DEVICE_REQUIRED="Không xác định được thiết bị",
    EXPIRED_KEY="Key hết hạn",NETWORK_ERROR="Lỗi kết nối",
    SERVER_ERROR="Lỗi máy chủ"
}
local busy=false
login.MouseButton1Click:Connect(function()
    if busy then return end
    local key=field.Text:gsub("^%s+",""):gsub("%s+$","")
    if key=="" then status.Text="Nhập key" return end
    local device=deviceID()
    if not device then status.Text=messages.DEVICE_REQUIRED return end
    busy=true
    login.Text="ĐANG KIỂM TRA..."
    local result,err=requestJSON("/v1/verify",{key=key,device=device})
    if not result then
        status.Text=messages[err] or "Lỗi kết nối"
    elseif result.ok and type(result.token)=="string" then
        local source,sourceErr=requestJSON("/v1/source",{token=result.token,device=device})
        if not source then status.Text=messages[sourceErr] or "Lỗi tải script"; busy=false;login.Text="ĐĂNG NHẬP";return end
        if not source.ok or type(source.script)~="string" then status.Text=messages[source.code] or "Không thể tải script";busy=false;login.Text="ĐĂNG NHẬP";return end
        status.Text="Đăng nhập key thành công"
        local fn,compileErr=loadstring(source.script)
        if fn then
            gui:Destroy()
            local ran,runErr=pcall(fn)
            if not ran then warn("[PS99] Script runtime error",runErr) end
        else
            status.Text="Không thể chạy script"
            warn("[PS99] Compile error",compileErr)
        end
    else
        status.Text=messages[result.code] or "Xác minh thất bại"
    end
    busy=false
    if login.Parent then login.Text="ĐĂNG NHẬP" end
end)
