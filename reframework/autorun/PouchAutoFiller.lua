local saveDataManager = sdk.get_managed_singleton("app.SaveDataManager")
local cUserSaveParam = saveDataManager:call("getCurrentUserSaveData")
local ItemUtil = sdk.find_type_definition("app.ItemUtil")
local configPath = "PouchAutoFiller/config.json"
local lastError = nil

config = { 
    mySetIndex = 1 
}

local function saveConfig()
    json.dump_file(configPath, config)
end

local function loadConfig()
    local loadFile = json.load_file(configPath)
    if loadFile then
        config = json.load_file(configPath)
    end
end

if not cUserSaveParam then
    lastError = "存档数据未初始化"
    return
else
    loadConfig()
end

local function validateMySet(index)
    local gameIndex = index - 1 
    local ItemMySetUtil = sdk.find_type_definition("app.ItemMySetUtil")

    if not ItemMySetUtil then
        lastError = "预设未找到"
        return false
    end

    local isValidMethod = ItemMySetUtil:get_method("isValidData(System.Int32)")
    if isValidMethod then
        local isValidData = isValidMethod:call(nil, sdk.to_ptr(gameIndex))
        if not isValidData then
            lastError = "预设 "..index.." 不存在"
            return false
        end
        return true
    end
    return false
end

local function autoFillCurrentPouch()
    local cItemParam = cUserSaveParam:get_field("_Item")
    cItemParam:call("fillPouchItems")
    local fillShellPouchItems = ItemUtil:get_method("fillShellPouchItems")
    fillShellPouchItems(nil)
end

-- 自动补充
local function autoFill()  
    if validateMySet(config.mySetIndex) then
        local ItemMySetUtil = sdk.find_type_definition("app.ItemMySetUtil") 
        local applyMySetToPouch = ItemMySetUtil:get_method("applyMySetToPouch(System.Int32)")
        local cItemParam = cUserSaveParam:get_field("_Item")
        local fillShellPouchItems = ItemUtil:get_method("fillShellPouchItems")   

        applyMySetToPouch:call(nil, sdk.to_ptr(config.mySetIndex - 1))        
        fillShellPouchItems(nil) 
    else
        autoFillCurrentPouch()       
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("自动补给设置") then
        local changed, newIndex = imgui.slider_int("预设组合编号", config.mySetIndex, 1, 80)        
        local saveIndexAsDefault = imgui.button("将当前组合设为默认")

        if changed and newIndex >=1 and newIndex <=80 then
            config.mySetIndex = newIndex                
        end

        if saveIndexAsDefault then
            saveConfig()
        end

        if lastError then
            imgui.text("错误: "..lastError)
        end
        
        imgui.tree_pop()
    end
end)


local function returnQuest(retval)
    autoFill()
    return retval
end

local function returnCamp(retval)
    autoFill()
    return retval
end

sdk.hook(
    sdk.find_type_definition("app.cQuestClearEnd"):get_method("enter"),
    nil, 
    returnQuest
)

sdk.hook(
    sdk.find_type_definition("app.cCampManager"):get_method("tentGetIn"), 
    nil, 
    returnCamp
)