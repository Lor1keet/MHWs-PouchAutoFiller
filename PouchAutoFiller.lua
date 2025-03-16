local saveDataManager = sdk.get_managed_singleton("app.SaveDataManager")
local cUserSaveParam = saveDataManager:call("getCurrentUserSaveData")
local lastError = nil
local config = require("PouchAutoFiller.config")

if not cUserSaveParam then
    lastError = "存档数据未初始化"
    return
end

local function autoFillCurrentPouch()
    local cItemParam = cUserSaveParam:get_field("_Item")
    cItemParam:call("fillPouchItems")
end

local function validateMySet(index)
    local gameIndex = index - 1     
    local ItemMySetUtil = sdk.find_type_define("app.ItemMySetUtil")
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

local function autoFill()  
    if validateMySet(config.mySetIndex) then
        local ItemMySetUtil = sdk.find_type_define("app.ItemMySetUtil") 
        local applyMySetToPouch = ItemMySetUtil:get_method("applyMySetToPouch(System.Int32)")
        applyMySetToPouch:call(nil, sdk.to_ptr(config.mySetIndex - 1))
    else
        autoFillCurrentPouch()       
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("自动补给设置") then
        local changed, newIndex = imgui.slider_int("预设配置编号", config.mySetIndex, 1, 80)
        if changed then
            if newIndex >=1 and newIndex <=80 then
                config.mySetIndex = newIndex
            end
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
    returnCamp)
