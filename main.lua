print("^2Hello from GitHub! The script is working!^7")

-- مثال وظيفة فعلية:
RegisterCommand("githubtest", function(source, args, raw)
    print("^3Command /githubtest triggered from GitHub-loaded script!^7")
end)

local number = {}

-- بداية ضعف صندوق

RegisterServerEvent("cal:shops:server:setduble")
AddEventHandler("cal:shops:server:setduble", function(duble)
  Config.dublebox = duble
  if Config.dublebox == nil then
    Config.dublebox = 1
  end
end)

ESX.RegisterServerCallback('shops:getvar', function(source, cb)
  cb(Config.dublebox)
end)

-- نهاية ضعف صندوق

--get shared config
RegisterNetEvent('esx_acshops:spawned')
AddEventHandler('esx_acshops:spawned', function()
  local _source = source

  TriggerClientEvent('esx_acshops:updateconfig', source, Config)


end)

AddEventHandler('onResourceStart', function(resource)
  if resource == GetCurrentResourceName() then
    Citizen.Wait(5000)
    TriggerClientEvent('esx_acshops:updateconfig', -1, Config)

    local nowDate = os.time()
    local p = MySQL.Sync.fetchAll("SELECT ShopNumber, ending FROM owned_shops", {})
    for m, n in pairs(p) do
      local endingtime = json.decode(n.ending)
      local stationname = n.ShopNumber
      local difference = os.difftime(endingtime, nowDate) / (24*60*60)
      local reelDate = math.floor(difference)
      if reelDate <= 0 then
        local o = "UPDATE owned_shops SET identifier = @identifier, ending = @ending WHERE ShopNumber = @ShopNumber"
        MySQL.Sync.execute(o, {
          ["@ShopNumber"] = n.ShopNumber,
          ["@identifier"] = '0',
          ["@ending"] = 1706852475,
        })
        print('^2 Shop'..stationname..'^1 Has Been Deleted From The Data Base^0')
      else
        print('^2 Shop '..stationname.."^2 Will Be Finished In ^9"..reelDate.."^2 days^0")
      end
    end
  end
end)

function CanCarryItemForBuy(source, item, count)
  local playerId = source
  local xPlayer = ESX.GetPlayerFromId(playerId)
  if xPlayer.canCarryItem(item, count) then
    return true
  end
  return false
end

--GET INVENTORY ITEM
ESX.RegisterServerCallback('esx_kr_shop:getInventory', function(source, cb)
  local xPlayer = ESX.GetPlayerFromId(source)
  local items   = xPlayer.inventory

  cb({items = items})

end)

--Removes item from shop
RegisterNetEvent('esx_kr_shops:RemoveItemFromShop')
AddEventHandler('esx_kr_shops:RemoveItemFromShop', function(number, count, item, plate)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local identifier =  ESX.GetPlayerFromId(src).identifier
  local _source = source

  if plate then
    MySQL.Async.fetchAll('SELECT count, item FROM foodtrucks WHERE item = @item AND plate = @plate', {
      ['@plate'] = plate,
      ['@item'] = item,
    },
    function(data)
      if xPlayer.canCarryItem(item, count) then
        if count <= data[1].count then
          if data[1].count ~= count then
            MySQL.Async.fetchAll("UPDATE foodtrucks SET count = @count WHERE item = @item AND plate = @plate", {
              ['@item'] = item,
              ['@plate'] = plate,
              ['@count'] = data[1].count - count
            },
            function(result)
              xPlayer.addInventoryItem(data[1].item, count)
            end)
          elseif data[1].count == count then
            MySQL.Async.fetchAll("DELETE FROM foodtrucks WHERE item = @name AND plate = @Number", {
              ['@Number'] = plate,
              ['@name'] = data[1].item
            })
            xPlayer.addInventoryItem(data[1].item, count)
          end
        else
          TriggerClientEvent('pNotify:SendNotification', xPlayer.source, {
            text = '<center><b style="color:#ea1f1f;font-size:20px;"> لايمكنك سحب أكثر مما تملك ',
            type = "info",
            timeout = 10000,
            layout = "centerLeft"
          })
        end
      else
        TriggerClientEvent('pNotify:SendNotification', xPlayer.source, {
          text = '<center><b style="color:#ea1f1f;font-size:20px;"> حقيبتك ممتئلة أو لاتملك الكمية الكافية ',
          type = "info",
          timeout = 10000,
          layout = "centerLeft"
        })
      end
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT count, item FROM shops WHERE item = @item AND ShopNumber = @ShopNumber',
    {
      ['@ShopNumber'] = number,
      ['@item'] = item,
    },
    function(data)

      if count > data[1].count then

        TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> لا يمكنك سحب أكثر مما في المتجر')
      else

        if data[1].count ~= count then

          if xPlayer.canCarryItem(data[1].item, count) then
            MySQL.Async.fetchAll("UPDATE shops SET count = @count WHERE item = @item AND ShopNumber = @ShopNumber",
            {
              ['@item'] = item,
              ['@ShopNumber'] = number,
              ['@count'] = data[1].count - count
            }, function(result)
              xPlayer.addInventoryItem(data[1].item, count)
            end)
          else
            xPlayer.showNotification('<font color=red>لا توجد مساحة كافية في الحقيبة</font>')
          end

        elseif data[1].count == count then

          if xPlayer.canCarryItem(data[1].item, count) then
            MySQL.Async.fetchAll("DELETE FROM shops WHERE item = @name AND ShopNumber = @Number",
            {
              ['@Number'] = number,
              ['@name'] = data[1].item
            })
            xPlayer.addInventoryItem(data[1].item, count)
          else
            xPlayer.showNotification('<font color=red>لا توجد مساحة كافية في الحقيبة</font>')
          end
        end
      end
    end)
  end
end)


--Setting selling items.
RegisterNetEvent('esx_kr_shops:setToSell')
AddEventHandler('esx_kr_shops:setToSell', function(id, Item, ItemCount, Price, ItemBox, ItemBoxCount, itemlabel, type, weaponname, levveeelll,plate)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT label, name FROM items WHERE name = @item',
    {
      ['@item'] = Item,
    },
    function(items)

      MySQL.Async.fetchAll(
      'SELECT price, count FROM foodtrucks WHERE item = @items AND plate = @plate',
      {
        ['@items'] = Item,
        ['@plate'] = plate,
      },
      function(data)
        if data[1] == nil then
          if ItemCount <= Config.MaxFoodTrucksItems then
            imgsrc = 'img/'..Item..'.png'

            MySQL.Async.execute('INSERT INTO foodtrucks (plate, src, label, count, item, price) VALUES (@plate, @src, @label, @count, @item, @price)',
            {
              ['@plate']    = plate,
              ['@src']        = imgsrc,
              ['@label']         = items[1].label,
              ['@count']         = ItemCount,
              ['@item']          = items[1].name,
              ['@price']         = Price
            })
            xPlayer.removeInventoryItem(ItemBox, ItemBoxCount)
          else
            TriggerClientEvent('esx:showNotification', xPlayer.source, "<span style='color:#FB8405'>لقد تجاوزت الحد المسموح داخل المتجر المتنقل </span> <br><span  style='color:#FF0E0E;font-size:15'>الحد الإجمالي المسموح به : <span style='color:gray;'>"..Config.MaxFoodTrucksItems.."<br><span  style='color:#FF0E0E;font-size:15'>أنت تمتلك داخل المتجر المتنقل : <span style='color:gray;'>"..data[1].count)
          end
        elseif data[1].price == Price then
          if (data[1].count + ItemCount) <= Config.MaxFoodTrucksItems then
            MySQL.Async.fetchAll("UPDATE foodtrucks SET count = @count WHERE item = @name AND plate = @plate",
            {
              ['@name'] = Item,
              ['@plate'] = plate,
              ['@count'] = data[1].count + ItemCount
            }
          )
          xPlayer.removeInventoryItem(ItemBox, ItemBoxCount)
        else
          TriggerClientEvent('esx:showNotification', xPlayer.source, "<span style='color:#FB8405'>لقد تجاوزت الحد المسموح داخل المتجر المتنقل </span> <br><span  style='color:#FF0E0E;font-size:15'>الحد الإجمالي المسموح به : <span style='color:gray;'>"..Config.MaxFoodTrucksItems.."<br><span  style='color:#FF0E0E;font-size:15'>أنت تمتلك داخل المتجر المتنقل : <span style='color:gray;'>"..data[1].count)
        end
      elseif data ~= nil and data[1].price ~= Price then
        Wait(250)
        TriggerClientEvent('esx:showNotification', xPlayer.source, 'لديك نفس العنصر بالفعل في متجرك معروض مقابل ' .. data[1].price .. ' أما السعر الجديد الذي تريد أن تعرضه به هو ' .. Price)
        Wait(250)
        TriggerClientEvent('esx:showNotification', xPlayer.source, 'قم بتغيير سعر المنتج ومن ثم عرضه مجددا بالسعر الجديد')
      end
    end)
  end)
  --     end
  -- end)

else
  MySQL.Async.fetchAll(
  'SELECT label, name FROM items WHERE name = @item',
  {
    ['@item'] = Item,
  },
  function(items)

    MySQL.Async.fetchAll(
    'SELECT price, count FROM shops WHERE item = @items AND ShopNumber = @ShopNumber',
    {
      ['@items'] = Item,
      ['@ShopNumber'] = id,
    },
    function(data)

      if data[1] == nil then -- اضافة منتج
        imgsrc = 'img/'..Item..'.png'

        if type == 'weapon' then
          MySQL.Async.execute('INSERT INTO shops (ShopNumber, src, label, count, item, price, level) VALUES (@ShopNumber, @src, @label, @count, @item, @price, @level)',
          {
            ['@ShopNumber']    = id,
            ['@src']        = imgsrc,
            ['@label']         = weaponname,
            ['@count']         = ItemCount,
            ['@item']          = Item,
            ['@price']         = Price,
            ['@level']         = levveeelll,
          })
        else
          MySQL.Async.execute('INSERT INTO shops (ShopNumber, src, label, count, item, price) VALUES (@ShopNumber, @src, @label, @count, @item, @price)',
          {
            ['@ShopNumber']    = id,
            ['@src']        = imgsrc,
            ['@label']         = items[1].label,
            ['@count']         = ItemCount,
            ['@item']          = items[1].name,
            ['@price']         = Price
          })
        end

        xPlayer.removeInventoryItem(ItemBox, ItemBoxCount)
        TriggerEvent('napoly_xplevel:updateCurrentPlayerXP', xPlayer.source, 'addnoduble', Config.addXpForBoxDelivery)
        xPlayer.showNotification("<h1><center><font color=green><font size=6px><i>توصيل صندوق</i></font></font></h1></br><p align=right> حصلت على خبرة: "..Config.addXpForBoxDelivery.."</br><font color=orange> مقابل توصيل "..itemlabel..'</font></p>')

      elseif data[1].price == Price then

        MySQL.Async.fetchAll("UPDATE shops SET count = @count WHERE item = @name AND ShopNumber = @ShopNumber",
        {
          ['@name'] = Item,
          ['@ShopNumber'] = id,
          ['@count'] = data[1].count + ItemCount
        }
      )
      xPlayer.removeInventoryItem(ItemBox, ItemBoxCount)
      TriggerEvent('napoly_xplevel:updateCurrentPlayerXP', xPlayer.source, 'addnoduble', Config.addXpForBoxDelivery)
      xPlayer.showNotification("<h1><center><font color=green><font size=6px><i>توصيل صندوق</i></font></font></h1></br><p align=right> حصلت على خبرة: "..Config.addXpForBoxDelivery.."</br><font color=orange> مقابل توصيل "..itemlabel..'</font></p>')

    elseif data ~= nil and data[1].price ~= Price then
      Wait(250)
      TriggerClientEvent('esx:showNotification', xPlayer.source, ' سعر العنصر في المتجر <font color=green>$' .. data[1].price .. '<font color=white> لا يطابق سعرك <font color=red>$' .. Price)
      Wait(250)
      TriggerClientEvent('esx:showNotification', xPlayer.source, 'قم بوضع نفس سعر العنصر أو تعديل سعره ')
    end
  end)
end)
end
end)



function getshoptype(ndndndndndnnd)
  for k,v in pairs(Config.Zones) do
    if v.Pos.number == ndndndndndnnd then
      return v.Type
    end
  end
end

-- BUYING PRODUCT
RegisterNetEvent('esx_kr_shops:Buy')
AddEventHandler('esx_kr_shops:Buy', function(id, Item, ItemCount, token,plate)
  local _source = source
  -- if not exports['esx_misc2']:secureServerEvent(GetCurrentResourceName(), _source, token) then
  --     return false
  -- end
  local src = source
  local identifier = ESX.GetPlayerFromId(src).identifier
  local xPlayer = ESX.GetPlayerFromId(src)
  local ItemLabel = ESX.GetItemLabel(Item)
  local typee = getshoptype(id)
  local ItemCount = tonumber(ItemCount)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM foodtrucks WHERE plate = @Number AND item = @item',
    {
      ['@Number'] = plate,
      ['@item'] = Item,
    }, function(result)


      MySQL.Async.fetchAll(
      'SELECT * FROM owned_foodtrucks WHERE plate = @Number',
      {
        ['@Number'] = plate,
      }, function(result2)

        if xPlayer.getMoney() < ItemCount * result[1].price then
          TriggerClientEvent('pNotify:SendNotification', src, {
            text = '<center><b style="color:#ea1f1f;font-size:26px;"> لا تملك المال الكافي ',
            type = "info",
            timeout = 10000,
            layout = "centerLeft"
          })
        elseif ItemCount <= 0 then
          --TriggerClientEvent('esx:showpNotifyNotification', src, 'invalid quantity.')
          TriggerClientEvent('pNotify:SendNotification', src, {
            text = '<center><b style="color:#ea1f1f;font-size:26px;"> قيمة غير صالحة ',
            type = "info",
            timeout = 10000,
            layout = "centerLeft"
          })
        elseif xPlayer.canCarryItem(Item, ItemCount) then
          xPlayer.removeMoney(ItemCount * result[1].price)
          TriggerClientEvent('pNotify:SendNotification', xPlayer.source, {
            text = '<center><b style="color:#0BAF5F;font-size:26px;"> ملخص عملية الشراء </b></center> <br /><br /><div align="right"> <b style="color:White;font-size:20px">  الكمية : <b style="color:#edb040">' .. ItemCount .. '</b></center> <br /><br /><div align="right"> <b style="color:White;font-size:20px"> الصنف : <b style="color:#edb040">' .. ItemLabel .. '</b></center> <br /><br /><div align="right"> <b style="color:White;font-size:20px"> السعر : <b style="color:#edb040">' .. ItemCount * result[1].price ..'<b style="color:#0BAF5F"> $ ',
            type = "info",
            timeout = 10000,
            layout = "centerLeft"
          })
          xPlayer.addInventoryItem(result[1].item, ItemCount)
          local result3 = (ItemCount * result[1].price)
          MySQL.Async.execute("UPDATE owned_foodtrucks SET money = money + @money, totalachat = totalachat + @money WHERE plate = @Number",
          {
            ['@money']      = result3,
            ['@Number']     = plate,
          })


          if result[1].count ~= ItemCount then
            MySQL.Async.execute("UPDATE foodtrucks SET count = @count WHERE item = @name AND plate = @Number",
            {
              ['@name'] = Item,
              ['@Number'] = plate,
              ['@count'] = result[1].count - ItemCount
            })
          elseif result[1].count == ItemCount then
            MySQL.Async.fetchAll("DELETE FROM foodtrucks WHERE item = @name AND plate = @Number",
            {
              ['@Number'] = plate,
              ['@name'] = result[1].item
            })
          end
        else
          TriggerClientEvent('pNotify:SendNotification', src, {
            text = '<center><b style="color:#ea1f1f;font-size:26px;"> حقيبتك ممتلئة ',
            type = "info",
            timeout = 10000,
            layout = "centerLeft"
          })
        end
      end)
    end)




  else


    MySQL.Async.fetchAll(
    'SELECT * FROM shops WHERE ShopNumber = @Number AND item = @item',
    {
      ['@Number'] = id,
      ['@item'] = Item,
    }, function(result)


      MySQL.Async.fetchAll(
      'SELECT * FROM owned_shops WHERE ShopNumber = @Number',
      {
        ['@Number'] = id,
      }, function(result2)
        local blackm = false
        local weaponn = false
        for i = 1, #Config.Items[typee], 1 do
          if Config.Items[typee][i].itemConvert == Item then
            if Config.Items[typee][i].black == true then
              blackm = true
              break
            end
          end
        end
        for i = 1, #Config.Items[typee], 1 do
          if Config.Items[typee][i].itemConvert == Item then
            if Config.Items[typee][i].type == 'weapon' then
              weaponn = true
              break
            end
          end
        end

        if not blackm and xPlayer.getMoney() < ItemCount * result[1].price then
          TriggerClientEvent('esx:showNotification', src, '<font color=red> النقود لاتكفي لإتمام العملية الشرائية')
        elseif blackm and xPlayer.getAccount('black_money').money < ItemCount * result[1].price then
          TriggerClientEvent('esx:showNotification', src, '<font color=red> لا تملك أموال غير شرعية لإتمام العملية الشرائية')
        elseif ItemCount <= 0 then
          TriggerClientEvent('esx:showNotification', src, '<font color=red> كمية غير صالحة')
        else
          if weaponn or CanCarryItemForBuy(src, result[1].item, ItemCount) then
            if blackm then
              xPlayer.removeAccountMoney('black_money', ItemCount * result[1].price)
              TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم شراء <font color=yellow>' .. ItemCount .. ' <font color=#2C8BAF> ' .. result[1].label .. '<font color=white> بمبلغ <font color=red>$<font color=white>' .. ItemCount * result[1].price.. ' غير شرعي')
            elseif ItemLabel then
              xPlayer.removeMoney(ItemCount * result[1].price)
              xPlayer.showNotification('<center><b style="color:#ffffff;font-size:26px;"> ملخص عملية الشراء </b><br><br></center> <div align="right"> <b style="color:White;font-size:20px">  الصنف : <b style="color:#edb040">' .. ItemLabel .. '</b></center> <div align="right"> <b style="color:White;font-size:20px"> الكمية : <b style="color:#edb040">' .. ItemCount .. '</b></center> <div align="right"> <b style="color:White;font-size:20px"> السعر : <b style="color:#0BAF5F"> $ ' .. ItemCount * result[1].price ..' ')
            else
              xPlayer.removeMoney(ItemCount * result[1].price)
              xPlayer.showNotification('<center><b style="color:#ffffff;font-size:26px;"> ملخص عملية الشراء </b><br><br></center> <div align="right"> <b style="color:White;font-size:20px">  الصنف : <b style="color:#edb040">' .. result[1].label .. '</b></center> <div align="right"> <b style="color:White;font-size:20px"> الكمية : <b style="color:#edb040">' .. ItemCount .. '</b></center> <div align="right"> <b style="color:White;font-size:20px"> السعر : <b style="color:#0BAF5F"> $ ' .. ItemCount * result[1].price ..' ')
            end
            if weaponn then
              xPlayer.addWeapon(result[1].item, 30)
            else
              xPlayer.addInventoryItem(result[1].item, ItemCount)
            end

            MySQL.Async.execute("UPDATE owned_shops SET money = money + @money WHERE ShopNumber = @Number",
            {
              ['@money']      = result[1].price * ItemCount,
              ['@Number']     = id,
            })


            if result[1].count ~= ItemCount then
              MySQL.Async.execute("UPDATE shops SET count = @count WHERE item = @name AND ShopNumber = @Number",
              {
                ['@name'] = Item,
                ['@Number'] = id,
                ['@count'] = result[1].count - ItemCount
              })
            elseif result[1].count == ItemCount then
              MySQL.Async.fetchAll("DELETE FROM shops WHERE item = @name AND ShopNumber = @Number",
              {
                ['@Number'] = id,
                ['@name'] = result[1].item
              })
            end
          else
            xPlayer.showNotification('<font color=red>لا توجد مساحة كافية في الحقيبة</font>')
          end
        end
      end)
    end)
  end
end)

--CALLBACKS
ESX.RegisterServerCallback('esx_kr_shop:getShopList', function(source, cb)
  local identifier = ESX.GetPlayerFromId(source).identifier
  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE identifier = @identifier',
  {
    ['@identifier'] = '0',
  }, function(result)
    -- table.insert(data,result)
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_foodtrucks WHERE identifier = @identifier',
    {
      ['@identifier'] = '0',
    }, function(result2)
      cb(result,result2)
      -- table.insert(data,result2)
    end)
  end)

end)


ESX.RegisterServerCallback('esx_kr_shop:getOwnedBlips', function(source, cb)
  local xPlayer = ESX.GetPlayerFromId(source)
  local identifier = xPlayer.getIdentifier()
  local fetch = 'SELECT * FROM owned_shops WHERE NOT identifier = @identifier'
  if Config.showAllBlips == true then
    fetch = 'SELECT * FROM owned_shops'
  end

  MySQL.Async.fetchAll(fetch, {
    ['@identifier'] = '0',
  }, function(results)

    MySQL.Async.fetchAll('SELECT * FROM owned_shops WHERE identifier = @identifier', {
      ['@identifier'] = identifier,
    }, function(results2)
      if results2 and results2[1] and results2[1].ShopNumber then
        cb(results, results2[1].ShopNumber)
      else
        cb(results)
      end
    end)
  end)
end)

ESX.RegisterServerCallback('esx_kr_shop:getAllShipments', function(source, cb, id,plate)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE plate = @id',
    {
      ['@id'] = plate,
    }, function(result)
      cb(result)
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE id = @id',
    {
      ['@id'] = id,
    }, function(result)
      cb(result)
    end)
  end
end)

ESX.RegisterServerCallback('esx_kr_shop:getTime', function(source, cb)
  cb(os.time())
end)

ESX.RegisterServerCallback('esx_kr_shop:getOwnedShop', function(source, cb, id)

  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
  {
    ['@ShopNumber'] = id,
  }, function(result)
    if result[1] ~= nil then
      cb(result)
    else
      cb(nil)
    end
  end)
end)

ESX.RegisterServerCallback('esx_kr_shop:getOwnedTrucks', function(source, cb, plate)

  MySQL.Async.fetchAll(
  'SELECT * FROM owned_foodtrucks WHERE plate = @plate',
  {
    ['@plate'] = plate,
  }, function(result)

    if result[1] ~= nil then
      cb(result)
    else
      cb(nil)
    end
  end)
end)


ESX.RegisterServerCallback('esx_kr_shop:getOwnerTrucks', function(source, cb, plate)
  local src = source
  local identifier = ESX.GetPlayerFromId(src).identifier
  MySQL.Async.fetchAll(
  'SELECT * FROM owned_foodtrucks WHERE (plate = @plate)',
  {
    ['@plate'] = plate,
  }, function(result)

    if result[1] ~= nil then
      local grade = 0
      if identifier == result[1].identifier then
        grade = 3
      end
      cb(result[1], grade)
    else
      cb(nil)
    end
  end)
end)
ESX.RegisterServerCallback('esx_kr_shop:getShopItems', function(source, cb, number)
  local identifier = ESX.GetPlayerFromId(source).identifier

  MySQL.Async.fetchAll('SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
  {
    ['@ShopNumber'] = number
  }, function(result)
    cb(result)
  end)
end)

ESX.RegisterServerCallback('esx_kr_shop:getTruckItems', function(source, cb, plate)
  MySQL.Async.fetchAll('SELECT * FROM foodtrucks WHERE plate = @plate',
  {
    ['@plate'] = plate
  }, function(result)
    cb(result)
  end)
end)

RegisterNetEvent('esx_kr_shops:GetAllItems')
AddEventHandler('esx_kr_shops:GetAllItems', function(id, item, Command, takeamount,plate)
  local _source = source
  -- if not exports['esx_misc2']:secureServerEvent(GetCurrentResourceName(), _source, token) then
  --     return false
  -- end

  local xPlayer = ESX.GetPlayerFromId(_source)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE plate = @id AND Command = @Command',
    {
      ['@id'] = plate,
      ['@Command'] = Command

    }, function(result)
      if result[1] ~= nil then
        if xPlayer.canCarryItem(item, takeamount) then
          if tonumber(result[1].count) >= takeamount then
            if doubleitems then
              newtakeamount = takeamount*2
            else
              newtakeamount = takeamount
            end
            xPlayer.addInventoryItem(item, newtakeamount)
            local finleamount = result[1].count - takeamount
            if tonumber(finleamount) >= 1 then
              MySQL.Async.execute("UPDATE shipments SET count = @count WHERE id = @id AND Command = @Command",
              {
                ['@count']      = finleamount,
                ['@id']     = id,
                ['@Command'] = Command,
              })
            else
              MySQL.Async.fetchAll("DELETE FROM shipments WHERE id = @id AND Command = @Command",
              {
                ['@id']     = id,
                ['@Command'] = Command,
              })
            end
          else
            xPlayer.showNotification('<font color=red>يجب كتابة عدد صحيح</font>')
          end
        else
          xPlayer.showNotification('<font color=red>لا توجد مساحة كافية في الحقيبة</font>')
        end
      end
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE id = @id AND Command = @Command',
    {
      ['@id'] = id,
      ['@Command'] = Command

    }, function(result)
      if result[1] ~= nil then
        if xPlayer.canCarryItem(item, takeamount) then
          if tonumber(result[1].count) >= takeamount then
            if doubleitems then
              newtakeamount = takeamount*2
            else
              newtakeamount = takeamount
            end
            xPlayer.addInventoryItem(item, newtakeamount)
            local finleamount = result[1].count - takeamount
            if tonumber(finleamount) >= 1 then
              MySQL.Async.execute("UPDATE shipments SET count = @count WHERE id = @id AND Command = @Command",
              {
                ['@count']      = finleamount,
                ['@id']     = id,
                ['@Command'] = Command,
              })
            else
              MySQL.Async.fetchAll("DELETE FROM shipments WHERE id = @id AND Command = @Command",
              {
                ['@id']     = id,
                ['@Command'] = Command,
              })
            end
          else
            xPlayer.showNotification('<font color=red>يجب كتابة عدد صحيح</font>')
          end
        else
          xPlayer.showNotification('<font color=red>لا توجد مساحة كافية في الحقيبة</font>')
        end
      end
    end)
  end
end)


RegisterNetEvent('esx_kr_shops-robbery:UpdateCanRob')
AddEventHandler('esx_kr_shops-robbery:UpdateCanRob', function(id)
  MySQL.Async.fetchAll("UPDATE owned_shops SET LastRobbery = @LastRobbery WHERE ShopNumber = @ShopNumber",{['@ShopNumber'] = id,['@LastRobbery']    = os.time(),})
end)

RegisterNetEvent('esx_kr_shop:MakeShipment')
AddEventHandler('esx_kr_shop:MakeShipment', function(id, item, price, count, label,plate)

  local _source = source
  if plate then
    MySQL.Async.fetchAll('SELECT money FROM owned_foodtrucks WHERE plate = @plate',{['@plate'] = plate,}, function(result)

      if result[1].money >= price * count then

        MySQL.Async.execute('INSERT INTO shipments (id, label, item, price, count ,time,plate) VALUES (@id, @label, @item, @price, @count, @time,@plate)',{['@id']       = id,['@label']      = label,['@item']       = item,['@price']      = price,['@count']      = count,['@time']       = os.time(), ["@plate"] = plate})
        MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET money = @money WHERE plate = @plate",{['@plate'] = plate,['@money']    = result[1].money - price * count,})
        TriggerClientEvent('esx:showNotification', _source, ' لقد طلبت شحنة <font color=yellow>' .. count .. '<font color=#2C8BAF> قطعة <font color=white>' .. label .. ' بمبلغ <font color=green>$<font color=white>' .. price * count)
      else
        TriggerClientEvent('esx:showNotification', _source, '<font color=red> ليس لديك ما يكفي من المال في متجرك')
      end
    end)
  else
    MySQL.Async.fetchAll('SELECT money FROM owned_shops WHERE ShopNumber = @ShopNumber',{['@ShopNumber'] = id,}, function(result)

      if result[1].money >= price * count then

        MySQL.Async.execute('INSERT INTO shipments (id, label, item, price, count, time) VALUES (@id, @label, @item, @price, @count, @time)',{['@id']       = id,['@label']      = label,['@item']       = item,['@price']      = price,['@count']      = count,['@time']       = os.time()})
        MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @ShopNumber",{['@ShopNumber'] = id,['@money']    = result[1].money - price * count,})
        TriggerClientEvent('esx:showNotification', _source, ' لقد طلبت شحنة <font color=yellow>' .. count .. '<font color=#2C8BAF> قطعة <font color=white>' .. label .. ' بمبلغ <font color=green>$<font color=white>' .. price * count)
      else
        TriggerClientEvent('esx:showNotification', _source, '<font color=red> ليس لديك ما يكفي من المال في متجرك')
      end
    end)
  end
end)

--BOSS MENU STUFF
RegisterNetEvent('esx_kr_shops:addMoney')
AddEventHandler('esx_kr_shops:addMoney', function(amount, number,plate)
  local _source = source
  local xPlayer = ESX.GetPlayerFromId(_source)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_foodtrucks WHERE plate = @plate',
    {
      ['@plate'] = plate,
    },
    function(result)

      if os.time() - result[1].LastRobbery <= 900 then
        time = os.time() - result[1].LastRobbery
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم قفل أموال متجرك بسبب السرقة ، يرجى الانتظار <font color=red>' .. math.floor((900 - time) / 60) .. ' دقيقة')
        return
      end

      if xPlayer.getMoney() >= amount then

        MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET money = @money WHERE plate = @plate",
        {
          ['@money']      = result[1].money + amount,
          ['@plate']     = plate,
        })
        xPlayer.removeMoney(amount)
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم إيدع <font color=green>$<font color=white>' .. amount .. ' في متجرك')
      else
        TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> لا يمكنك إيداع أكثر مما تملك')
      end
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE ShopNumber = @Number',
    {
      ['@Number'] = number,
    },
    function(result)

      if os.time() - result[1].LastRobbery <= 900 then
        time = os.time() - result[1].LastRobbery
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم قفل أموال متجرك بسبب السرقة ، يرجى الانتظار <font color=red>' .. math.floor((900 - time) / 60) .. ' دقيقة')
        return
      end

      if xPlayer.getMoney() >= amount then

        MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @Number",
        {
          ['@money']      = result[1].money + amount,
          ['@Number']     = number,
        })
        xPlayer.removeMoney(amount)
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم إيدع <font color=green>$<font color=white>' .. amount .. ' في متجرك')
      else
        TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> لا يمكنك إيداع أكثر مما تملك')
      end
    end)
  end
end)

RegisterNetEvent('esx_kr_shops:takeOutMoney')
AddEventHandler('esx_kr_shops:takeOutMoney', function(amount, number, plate)
  local _source = source
  local src = source
  local identifier = ESX.GetPlayerFromId(src).identifier
  local xPlayer = ESX.GetPlayerFromId(src)

  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_foodtrucks WHERE identifier = @identifier AND plate = @plate',
    {
      ['@identifier'] = identifier,
      ['@plate'] = plate,
    },

    function(result)

      if result[1].money >= amount then
        MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET money = @money, totalwithdraw = @totalwithdraw WHERE identifier = @identifier AND plate = @plate",
        {
          ['@money']      = result[1].money - amount,
          ['@totalwithdraw']      = result[1].totalwithdraw + amount,
          ['@plate']     = plate,
          ['@identifier'] = identifier
        })
        TriggerClientEvent('esx:showNotification', xPlayer.source, 'لقد سحبت ' .. amount .. ' من متجرك')
        xPlayer.addMoney(amount)
      else
        TriggerClientEvent('esx:showNotification', xPlayer.source, 'لايمكنك أن تسحب أكثر مما تملك')
      end

    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE identifier = @identifier AND ShopNumber = @Number',
    {
      ['@identifier'] = identifier,
      ['@Number'] = number,
    },

    function(result)

      if os.time() - result[1].LastRobbery <= 900 then
        time = os.time() - result[1].LastRobbery
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم قفل أموال متجرك بسبب السرقة ، يرجى الانتظار <font color=red>' .. math.floor((900 - time) / 60) .. ' دقيقة')
        return
      end

      if result[1].money >= amount then
        MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE identifier = @identifier AND ShopNumber = @Number",
        {
          ['@money']      = result[1].money - amount,
          ['@Number']     = number,
          ['@identifier'] = identifier
        })
        TriggerClientEvent('esx:showNotification', xPlayer.source, ' تم سحب <font color=green>$<font color=white>' .. amount .. ' من متجرك')
        xPlayer.addMoney(amount)
      else
        TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> لا يمكنك سحب أكثر مما في المتجر')
      end

    end)
  end
end)


RegisterNetEvent('esx_kr_shops:changeName')
AddEventHandler('esx_kr_shops:changeName', function(number, name,plate)
  local identifier = ESX.GetPlayerFromId(source).identifier

  local xPlayer = ESX.GetPlayerFromId(source)
  if  xPlayer.getMoney() >= Config.ChangeNamePrice then
    xPlayer.removeMoney(Config.ChangeNamePrice)
    TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=#F98A1B> تم تغيير اسم المتنقل مقابل: <font color=green>  $<font color=white>25000')
    if plate then
      MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET ShopName = @Name WHERE identifier = @identifier AND plate = @Number",
      {
        ['@Number'] = plate,
        ['@Name']     = name,
        ['@identifier'] = identifier
      })
      TriggerClientEvent('esx_kr_shops:removeBlip', -1)
      TriggerClientEvent('esx_kr_shops:setBlip', -1)
    else
      MySQL.Async.fetchAll("UPDATE owned_shops SET ShopName = @Name WHERE identifier = @identifier AND ShopNumber = @Number",
      {
        ['@Number'] = number,
        ['@Name']     = name,
        ['@identifier'] = identifier
      })
      TriggerClientEvent('esx_kr_shops:removeBlip', -1)
      TriggerClientEvent('esx_kr_shops:setBlip', -1)
    end
  else
    TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> انت لاتملك المبلغ الكافي لتغيير الأسم')
    return
  end

end)

RegisterNetEvent('esx_kr_shops:SellShop')
AddEventHandler('esx_kr_shops:SellShop', function(number, plate)
  local _source = source
  -- if not exports['esx_misc2']:secureServerEvent(GetCurrentResourceName(), _source, token) then
  --     return false
  -- end
  local identifier = ESX.GetPlayerFromId(_source).identifier
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_foodtrucks WHERE identifier = @identifier AND plate = @plate',
    {
      ['@identifier'] = identifier,
      ['@plate'] = plate,
    },
    function(result)
      MySQL.Async.fetchAll(
      'SELECT * FROM foodtrucks WHERE plate = @plate',
      {
        ['@plate'] = plate,
      },
      function(result2)

        if result[1].money == 0 and result2[1] == nil then
          MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET identifier = @identifiers, ShopName = @ShopName , money = @money WHERE identifier = @identifier AND plate = @plate",
          {
            ['@identifiers'] = '0',
            ['@identifier'] = identifier,
            ['@ShopName']    = '0',
            ['@money'] = '0',
            ["@plate"] = plate
          })
          -- MySQL.Async.fetchAll("DELETE FROM owned_foodtrucks WHERE plate = @plate",
          -- {
          --     ['@plate'] = number,
          -- })
          MySQL.Async.execute('UPDATE owned_vehicles WHERE plate = @plate', { ["@plate"] = plate})
          xPlayer.addMoney(result[1].ShopValue / 2)
          -- TriggerClientEvent('esx_kr_shops:removeBlip', -1)
          --TriggerClientEvent('esx_kr_shops:setBlip', -1)
          TriggerClientEvent('esx_kr_shops:deletefoodtruck', -1)
          TriggerClientEvent('esx:showNotification', xPlayer.source, 'لقد قمت ببيع متجرك')
        else
          TriggerClientEvent('esx:showNotification', xPlayer.source, 'لا يمكنك بيع المتجر وأن تملك بضائع أو أموال بداخله')
        end
      end)
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE identifier = @identifier AND ShopNumber = @ShopNumber',
    {
      ['@identifier'] = identifier,
      ['@ShopNumber'] = number,
    },
    function(result)
      MySQL.Async.fetchAll(
      'SELECT * FROM shops WHERE ShopNumber = @ShopNumber',
      {
        ['@ShopNumber'] = number,
      },
      function(result2)
        if result[1] then
          if result[1].money == 0 and result2[1] == nil then
            MySQL.Async.fetchAll("UPDATE owned_shops SET identifier = @identifiers, ShopName = @ShopName WHERE identifier = @identifier AND ShopNumber = @Number",
            {
              ['@identifiers'] = '0',
              ['@identifier'] = identifier,
              ['@ShopName']    = '0',
              ['@Number'] = number,
            })
            xPlayer.addMoney(result[1].ShopValue / 2)
            TriggerClientEvent('esx_kr_shops:removeBlip', -1)
            TriggerClientEvent('esx_kr_shops:setBlip', -1)
            TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=orange> لقد بعت متجرك')
          else
            TriggerClientEvent('esx:showNotification', xPlayer.source, '<font color=red> لا يمكنك بيع متجرك بعناصر أو أموال بداخله')
          end
        end
      end)
    end)
  end
end)

ESX.RegisterServerCallback('esx_kr_shop:getUnBoughtShops', function(source, cb)
  local identifier = ESX.GetPlayerFromId(source).identifier
  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE identifier = @identifier',
  {
    ['@identifier'] = '0',
  },
  function(result)

    cb(result)
  end)
end)

ESX.RegisterServerCallback('esx_kr_shop-robbery:getOnlinePolices', function(source, cb)
  local _source  = source
  local xPlayers = ESX.GetPlayers()
  local cops = 0

  for i=1, #xPlayers, 1 do

    local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
    if xPlayer.job.name == 'police' or xPlayer.job.name == 'agent' then
      cops = cops + 1
    end
  end
  Wait(25)
  cb(cops)
end)

AllCoolDownTimer = 0
CoolDownTimer = {}

function RemoveCooldownTimer(id)
  for k,v in pairs(CoolDownTimer) do
    if v.CoolDownTimer == id then
      table.remove(CoolDownTimer,k)
    end
  end
end

function GetTimeForCooldown(id)
  for k,v in pairs(CoolDownTimer) do
    if v.CoolDownTimer == id then
      return math.ceil(v.time/60000)
    end
  end
end

function CheckCooldownTime(id)
  for k,v in pairs(CoolDownTimer) do
    if v.CoolDownTimer == id then
      return true
    end
  end
  return false
end

function math.percent(percent,maxvalue)
  if tonumber(percent) and tonumber(maxvalue) then
    return (maxvalue*percent)/100
  end
  return false
end

ESX.RegisterServerCallback('esx_kr_shop-robbery:getUpdates', function(source, cb, id)
  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
  {
    ['@ShopNumber'] = id,
  },
  function(result)

    local waitTimer = GetTimeForCooldown(id)
    local theShopName = result[1].ShopName
    local theShopmoneyt = result[1].money
    local theShopmoney = math.percent(30,tonumber(theShopmoneyt))
    if not CheckCooldownTime(id) then
      if AllCoolDownTimer <= 0 then
        table.insert(CoolDownTimer,{CoolDownTimer = id, time = ((Config.RobCooldown * 60000))})
        AllCoolDownTimer = Config.AllRobCooldown * 60000
        TriggerClientEvent('napoly_AllCoolDownTimer', -1, Config.AllRobCooldown)
        cb(true, theShopName, theShopmoney)
      else
        cb(false, math.ceil(AllCoolDownTimer/60000), theShopmoney)
      end
    else
      cb(false, waitTimer)
    end
  end)
end)

RegisterServerEvent("esx_kr_shop-robbery:robshopmoney")
AddEventHandler("esx_kr_shop-robbery:robshopmoney", function(id, theShopmoney)
  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE ShopNumber = @Number',
  {
    ['@Number'] = id,
  },

  function(result)

    MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @Number",
    {
      ['@money']      = result[1].money - theShopmoney,
      ['@Number']     = id
    })
  end)
end)

Citizen.CreateThread(function() -- do not touch this!
  while true do
    Citizen.Wait(1000)
    for k,v in pairs(CoolDownTimer) do
      if v.time <= 0 then
        RemoveCooldownTimer(v.CoolDownTimer)
      else
        v.time = v.time - 1000
      end
    end
  end
end)

Citizen.CreateThread(function() -- do not touch this!
  while true do
    Citizen.Wait(1000)
    if AllCoolDownTimer <= 0 then
      AllCoolDownTimer = 0
    else
      AllCoolDownTimer = AllCoolDownTimer - 1000
    end
  end
end)

RegisterNetEvent('esx_kr_shops-robbery:stopRobb')
AddEventHandler('esx_kr_shops-robbery:stopRobb', function()
  TriggerClientEvent('esx_acshops:RobberyStartLeoJob', -1, 'stop')
end)

RegisterServerEvent('esx_kr_shops-robbery:msg')
AddEventHandler('esx_kr_shops-robbery:msg', function(msg)
  TriggerClientEvent('chatMessage',-1 , msg)
end)

RegisterNetEvent('esx_kr_shops-robbery:GetReward')
AddEventHandler('esx_kr_shops-robbery:GetReward', function(id, token)
  local _source = source
  -- if not exports['esx_misc2']:secureServerEvent(GetCurrentResourceName(), _source, token) then
  --     return false
  -- end
  local xPlayer = ESX.GetPlayerFromId(_source)


  MySQL.Async.fetchAll(
  'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
  {
    ['@ShopNumber'] = id,
  }, function(result)

    id = id
    local totalReward
    if result[1].money <= 0 then
      totalReward = 0
    else
      totalReward = result[1].money / Config.CutOnRobbery
      if totalReward < 0 then
        totalReward = result[1].money
      end
      -- if totalReward > 2000000 then
      --     totalReward = 2000000
      -- else
      -- totalReward = totalReward
      -- end
    end

    MySQL.Async.fetchAll("UPDATE owned_shops SET money = @money WHERE ShopNumber = @ShopNumber",
    {
      ['@ShopNumber'] = id,
      ['@money']     = result[1].money - totalReward,
    })
    id = id

    --xPlayer.addMoney()
    xPlayer.addAccountMoney('black_money', totalReward)
    TriggerClientEvent('esx_acshops:RobberyStartLeoJob', -1, 'stop')
  end)
end)

RegisterNetEvent('esx_kr_shops-robbery:NotifyOwner')
AddEventHandler('esx_kr_shops-robbery:NotifyOwner', function(msg, id, num, name)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local players = ESX.GetPlayers()

  if num == 1 then
    local mes1 = '^1أخبار عــاجل'
    TriggerClientEvent('chatMessage', -1, mes1,  { 128, 0, 0 }, 'سطو مسلح على متجر ^3 '..name)
  end

  for i=1, #players, 1 do
    local identifier = ESX.GetPlayerFromId(players[i])

    if identifier.job.name == 'police' or identifier.job.name == 'agent' or identifier.job.name == 'admin' then
      if num == 1 then
        identifier.triggerEvent('esx_acshops:RobberyStartLeoJob', 'start', xPlayer.getCoords(false))
      else
        identifier.triggerEvent('esx_acshops:RobberyStartLeoJob', 'stop')
      end
    end

    MySQL.Async.fetchAll(
    'SELECT * FROM owned_shops WHERE ShopNumber = @ShopNumber',
    {
      ['@ShopNumber'] = id,
    }, function(result)

      if result[1].identifier == identifier.identifier then
        TriggerClientEvent('esx:showNotification', identifier.source, msg)
      end

    end)
  end
end)


RegisterNetEvent('hamadashops:sendpolicenotif', function(coords, name)
  if coords then
    local players = ESX.GetPlayers()
    Wait(1000)
    for i=1, #players, 1 do
      local xPlayer = ESX.GetPlayerFromId(players[i])
      if xPlayer.job.name == 'police' or xPlayer.job.name == 'agent' or xPlayer.job.name == 'admin' then
        xPlayer.showNotification('<span style="color:red;font-size:1.7em;">تنويه سرقة متجر</span><br><br>يجب على الوحدات الأمنية التوجه إلى موقع السرقة وتحويط المنطقة في أسرع وقت<br><br><span style="color:#dfa43e;font-size:0.8em;"> '..name..'</span><span style="color:#87cbe4;font-size:0.8em;"> : إسم المتجر</span><br><br><center>لتحديد الموقع <FONT COLOR=red>E</FONT> اظغط </center>')
        TriggerClientEvent('hamada:esx_shops:pressToMark', xPlayer.source, coords)
      end
    end
  end
end)

ESX.RegisterServerCallback('esx_acshops:GetOwnShopNumber', function(source, cb, _id)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local owneroremps, owner = false, false
  local shopName
  local number = 0
  if xPlayer then
    local _to_return = {}

    MySQL.Async.fetchAll('SELECT * FROM owned_shops', function(result)
    MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier=@identifier',{
      ['@identifier'] = xPlayer.identifier
    }, function(result2)

      if _id ~= nil then
        local _this_shop = {}
        for i=1, #result, 1 do
          _this_shop[result[i].ShopNumber] = result[i].ShopName

          if result[i].ShopNumber == _id and result[i].identifier == xPlayer.identifier then
            _to_return = { owner = true, owneroremps = true, number = result[i].ShopNumber, name = result[i].ShopName }
            break
          end
        end

        for i=1, #result2, 1 do
          if tonumber(result2[1].shop) == _id then
            _to_return = { owner = false, owneroremps = true, number = tonumber(result2[1].shop), name = _this_shop[tonumber(result2[1].shop)] }
            break
          end
        end
      else
        for i=1, #result, 1 do
          if result[i].identifier == xPlayer.identifier then
            table.insert(_to_return, { owner = true, owneroremps = true, number = result[i].ShopNumber, name = result[i].ShopName })
          end
        end

        for i=1, #result2, 1 do
          if result2[1].shop ~= '0' then
            table.insert(_to_return, { owner = false, owneroremps = true, number = result2[i].ShopNumber, number = result2[i].ShopName })
          end
        end

      end

      cb(_to_return)
    end)
    end)
  end
end)

ESX.RegisterServerCallback('esx_acshops:GetOwnTruckNumber', function(source, cb, _id)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local owneroremps, owner = false, false
  local number = 0
  if xPlayer then
    MySQL.Async.fetchAll('SELECT * FROM owned_foodtrucks WHERE identifier = @identifier',{
      ['@identifier'] = xPlayer.identifier
    }, function(result)
      local _to_return = {}

      if _id ~= nil then
        for i=1, #result, 1 do
          if result[i].ShopNumber == _id and result[i].identifier == xPlayer.identifier then
            _to_return = { owner = true, owneroremps = true, plate = result[i].plate }
            break
          end
        end
      else
        for i=1, #result, 1 do
          if result[i].identifier == xPlayer.identifier then
            table.insert(_to_return, { owner = true, owneroremps = true, plate = result[i].plate })
          end
        end
      end

      cb(_to_return)
    end)
  end
end)


ESX.RegisterServerCallback('esx_acshops:canorder', function(source, cb, id,plate)
  if plate then
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE plate = @id',
    {
      ['@id'] = plaGetOwnShopNumberte,
    }, function(data)
      if data[1] ~= nil then
        local OrdererTotal = 0
        for i = 1, #data, 1 do
          if data[i] then
            OrdererTotal = OrdererTotal + data[i].count
          end
        end
        cb(OrdererTotal)
      else
        cb(0)
      end
    end)
  else
    MySQL.Async.fetchAll(
    'SELECT * FROM shipments WHERE id = @id',
    {
      ['@id'] = id,
    }, function(data)
      if data[1] ~= nil then
        local OrdererTotal = 0
        for i = 1, #data, 1 do
          if data[i] then
            OrdererTotal = OrdererTotal + data[i].count
          end
        end
        cb(OrdererTotal)
      else
        cb(0)
      end
    end)
  end

end)

RegisterNetEvent('esx_kr_shops:resellItem')
AddEventHandler('esx_kr_shops:resellItem', function(number, count, name,plate)
  if plate then
    MySQL.Async.fetchAll("UPDATE foodtrucks SET price = @price WHERE plate = @plate AND item = @item",
    {
      ['@plate'] = plate,
      ['@item'] = name,
      ['@price'] = count,
    })
  else
    MySQL.Async.fetchAll("UPDATE shops SET price = @price WHERE ShopNumber = @ShopNumber AND item = @item",
    {
      ['@ShopNumber'] = number,
      ['@item'] = name,
      ['@price']     = count,
    })
  end
end)

RegisterNetEvent('esx_acshops:setemps')
AddEventHandler('esx_acshops:setemps', function(number, selectedPlayerId)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local xTarget = ESX.GetPlayerFromId(selectedPlayerId)
  MySQL.Async.fetchAll('SELECT * FROM users WHERE shop = @number',
  {
    ['@number'] = number,
  }, function(data)
    if data[2] == nil then
      MySQL.Async.fetchAll("UPDATE users SET shop = @number WHERE identifier = @identifier",
      {
        ['@number'] = number,
        ['@identifier'] = xTarget.identifier,
      })
      xPlayer.showNotification('<font color=green>تم توظيف </font>'..xTarget.getName()..' في المتجر')
      xTarget.showNotification('قام '..xPlayer.getName()..' <font color=green>بتوظيفك </font> في متجره')
    else
      xPlayer.showNotification('<font color=red> الحد الأعلى للموظفين هو </font>2')
    end
  end)
end)

RegisterNetEvent('esx_acshops:removeemps')
AddEventHandler('esx_acshops:removeemps', function(number, identifier)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  local xTarget = ESX.GetPlayerFromIdentifier(identifier)
  MySQL.Async.fetchAll("UPDATE users SET shop = @number WHERE identifier = @identifier",
  {
    ['@number'] = 0,
    ['@identifier'] = identifier,
  })

  MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier',
  {
    ['@identifier'] = identifier,
  }, function(data)
    if data[1] then
      local namme = data[1].firstname.. ' ' ..data[1].lastname
      xPlayer.showNotification('<font color=red>تم طرد </font>'..namme..' من المتجر')
      if xTarget then
        xTarget.showNotification('قام '..xPlayer.getName()..' <font color=red>بطردك </font> من متجره')
      end
    end
  end)
end)

ESX.RegisterServerCallback('esx_acshops:getempslist', function(source, cb, number)

  MySQL.Async.fetchAll('SELECT * FROM users WHERE shop = @number',
  {
    ['@number'] = number,
  }, function(data)
    cb(data)
  end)
end)

--===================== MAZAD ===============--

local PlayersInMazad = {}

--[[
PlayersInMazad[iden] = { money = 100, shop = 2 }
]]

local Mazad = {}

function returnmoneytoplayers(number)
  for k,v in pairs(PlayersInMazad) do
    if PlayersInMazad[k] and PlayersInMazad[k].shop == number then
      local xPlayer = ESX.GetPlayerFromIdentifier(k)
      if xPlayer then
        xPlayer.addMoney(PlayersInMazad[k].money)
        PlayersInMazad[k] = nil
      else
        MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier',
        {
          ['@identifier'] = k,
        }, function(data)
          local accounts = json.decode(data[1].accounts)
          MySQL.Async.fetchAll("UPDATE users SET accounts = @accounts WHERE identifier = @identifier",
          {
            ['@accounts'] = json.encode({black_money = accounts.black_money, bank = accounts.bank, money = accounts.money + PlayersInMazad[k].money }),
            ['@identifier'] = k,
          })
          PlayersInMazad[k] = nil
        end)
      end
    end
  end
end

RegisterNetEvent('esx_acshops:mazaddd')
AddEventHandler('esx_acshops:mazaddd', function(data, label, label2, amount, type, truck)
  local _source = source
  -- if not exports['esx_misc2']:secureServerEvent(GetCurrentResourceName(), _source, token) then
  --     return false
  -- end
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)

  local moneyL = Config.Mazad.L
  if truck then
    if xPlayer then
      if type == 'add' then
        TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " بدأ المزاد على  متجر متنقل رقم ^3 "..data.plate.." ^7 | السعر الأساسي".." ^2"..ESX.Math.GroupDigits(data.ShopValue).."$".." ^7 ")
        xPlayer.showNotification('<font color=green>تم عرض '..label2..' في المزاد</font>')
        --sendToDisc2(" يوجد مزاد ")
        Mazad[data.plate] = {player = nil, money = 0}
      elseif type == 'remove' then
        TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " تم إلغاء المزاد على  "..label2.." رقم ^3 "..data.plate.." ")
        xPlayer.showNotification('<font color=red>تم إزالة ال'..label..' من المزاد بنجاح</font>')
        returnmoneytoplayers(data.plate)
        Mazad[data.plate] = nil
      elseif type == 'playermazad' then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_foodtrucks WHERE identifier = @identifier',
        {
          ['@identifier'] = xPlayer.identifier,
        }, function(data222222)
          if data222222[1] == nil then
            if Mazad[data.plate] ~= nil then
              local shopValue = tonumber(data.ShopValue)

              if Mazad[data.plate].player ~= xPlayer.identifier then
                if PlayersInMazad[xPlayer.identifier] == nil or PlayersInMazad[xPlayer.identifier].shop == data.plate then
                  if PlayersInMazad[xPlayer.identifier] == nil then
                    if xPlayer.getMoney() >= amount + shopValue then
                      if amount >= Config.Mazad.L and amount <= Config.Mazad.H then
                        if Mazad[data.plate].money == shopValue then
                          Mazad[data.plate] = { oldmoney = Mazad[data.plate].money , player = xPlayer.identifier, money = Mazad[data.plate].money + amount }
                          xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(shopValue)..'</font>')
                          xPlayer.removeMoney(amount + shopValue)
                          PlayersInMazad[xPlayer.identifier] = { money = amount, shop = data.plate }
                        else
                          xPlayer.removeMoney(amount + Mazad[data.plate].money + shopValue)
                          Mazad[data.plate] = { oldmoney = Mazad[data.plate].money , player = xPlayer.identifier, money = Mazad[data.plate].money + amount }
                          xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(Mazad[data.plate].money + shopValue)..'</font>')
                          PlayersInMazad[xPlayer.identifier] = { money = amount, shop = data.plate }
                        end
                      else
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=orange>الحد الأدنى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.L)..'</br>'..'<font color=orange>الحد الأعلى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.H))
                      end
                    else
                      xPlayer.showNotification('<font color=red>لا تملك نقود كاش للمزايدة</font>')
                    end
                  else
                    local chakatest = (Mazad[data.plate].money - Mazad[data.plate].oldmoney ) + amount
                    if xPlayer.getMoney() >= chakatest then
                      if amount >= Config.Mazad.L and amount <= Config.Mazad.H then
                        xPlayer.removeMoney(chakatest)
                        Mazad[data.plate] = {oldmoney = Mazad[data.plate].money , player = xPlayer.identifier, money = Mazad[data.plate].money + amount }
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount ).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(Mazad[data.plate].money + shopValue)..'</font>')
                        PlayersInMazad[xPlayer.identifier] = { money = PlayersInMazad[xPlayer.identifier].money + chakatest, shop = data.plate }
                      else
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=orange>الحد الأدنى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.L)..'</br>'..'<font color=orange>الحد الأعلى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.H))
                      end
                    else
                      xPlayer.showNotification('<font color=red>لا تملك نقود كاش للمزايدة</font>')
                    end
                  end
                else
                  xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على أكثر من متجر في وقت واحد</font>')
                end
              else
                xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على نفسك</font>')
              end
            end
          else
            xPlayer.showNotification('<font color=red>أنت مالك متجر ولا يمكنك المزايدة</font>')
          end
        end)
        -- elseif type == 'playermazad' then
        --     MySQL.Async.fetchAll(
        --         'SELECT * FROM owned_foodtrucks WHERE identifier = @identifier',
        --         {
        --             ['@identifier'] = xPlayer.identifier,
        --         }, function(data222222)
        --             if data222222[1] == nil then
        --                 if Mazad[data.plate] ~= nil then
        --                     if Mazad[data.plate].player ~= xPlayer.identifier then
        --                         if PlayersInMazad[xPlayer.identifier] == nil or PlayersInMazad[xPlayer.identifier].shop == data.plate then
        --                             if xPlayer.getMoney() >= data222222.money +amount then
        --                                 if amount >= Config.Mazad.L and amount <= Config.Mazad.H then
        --                                     xPlayer.showNotification('<font color=green>تم المزايدة على '..label..' رقم '..data.plate..'</font>')
        --                                     xPlayer.removeMoney(data222222.money +amount)
        --                                     Mazad[data.plate] = { player = xPlayer.identifier, money = Mazad[data.plate].money + amount }
        --                                     if PlayersInMazad[xPlayer.identifier] == nil then
        --                                         PlayersInMazad[xPlayer.identifier] = { money = amount, shop = data.plate }
        --                                     else
        --                                         PlayersInMazad[xPlayer.identifier] = { money = PlayersInMazad[xPlayer.identifier].money + amount, shop = data.plate }
        --                                     end
        --                                 else
        --                                     xPlayer.showNotification('<font color=orange>الحد الأدنى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.L)..'</br>'..'<font color=orange>الحد الأعلى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.H))
        --                                 end
        --                             else
        --                                 xPlayer.showNotification('<font color=red>لا تملك نقود كاش للمزايدة</font>')
        --                             end
        --                         else
        --                             xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على أكثر من متجر في وقت واحد</font>')
        --                         end
        --                     else
        --                         xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على نفسك</font>')
        --                     end
        --                 end
        --             else
        --                 xPlayer.showNotification('<font color=red>أنت مالك متجر ولا يمكنك المزايدة</font>')
        --             end
        --         end)
      elseif type == 'close' then
        if Mazad[data.plate].player ~= nil then
          xPlayer.showNotification('<font color=green>تم إنهاء المزاد وتسليم ال'..label2..'</font> ل'..ESX.GetPlayerFromIdentifier(Mazad[data.plate].player).getName())
          TriggerClientEvent("esx_misc:controlSystemScaleform_WinnerMZAD", xPlayer.source, label)
          TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " الفائز في مزاد "..label2.." رقم ".." ^3"..data.plate.." ^0| ^3"..ESX.GetPlayerFromIdentifier(Mazad[data.plate].player).getName().." ^0| سعر البيع ".." ^2"..Mazad[data.plate].money.."$")
          PlayersInMazad[Mazad[data.plate].player] = nil
          -------------------------
          -------------------------
          local endingTime = os.time() + 2629743

          MySQL.Async.fetchAll("UPDATE owned_foodtrucks SET identifier = @identifier, ShopName = @ShopName, ending = @ending WHERE plate = @plate",{['@identifier'] = Mazad[data.plate].player, ['@plate'] = data.plate, ['@ShopName'] = 'متجر', ['@ending'] = endingTime })
          MySQL.Async.fetchAll("SELECT * FROM owned_vehicles WHERE plate = @plate",
          {
            ['@plate'] = data.plate
          },function(result)
            if result and result[1] then
              MySQL.Async.fetchAll("UPDATE owned_vehicles SET owner = @owner WHERE plate = @plate",{['@owner'] = Mazad[data.plate].player,['@plate'] = data.plate})
            else
              MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, priceold, category, levelold, trunkkg, higherprice, lowerprice, name) VALUES (@owner, @plate, @vehicle, @type, @job, @priceold, @category, @levelold, @trunkkg, @higherprice, @lowerprice, @name)', {
                ['@owner'] = Mazad[data.plate].player,
                ['@plate'] = data.plate,
                ['@vehicle'] = json.encode({model = GetHashKey(Config.FoodTruckVehicleName), plate = data.plate, engineHealth = 1000.0, bodyHealth = 1000.0}),
                ['@type'] = 'truck',
                ['@job'] = 'civ',
                ['@priceold'] = '2000000',
                ['@category'] = '13',
                ['@levelold'] = '10',
                ['@trunkkg'] = '20',
                ['@higherprice'] = '4000000',
                ['@lowerprice'] = '1000000',
                ['@name'] = 'متجر متنقل',
              })
            end
            Mazad[data.plate] = nil
            returnmoneytoplayers(data.plate)
          end)

          -- MySQL.Async.fetchAll("UPDATE owned_shops SET identifier = @identifier, ShopName = @ShopName WHERE ShopNumber = @ShopNumber",{['@identifier'] = Mazad[data.ShopNumber].player, ['@ShopNumber'] = data.ShopNumber, ['@ShopName'] = 'متجر'})
          -- TriggerClientEvent('esx_kr_shops:removeBlip', -1)
          -- TriggerClientEvent('esx_kr_shops:setBlipMZAD', -1)

          -------------------------
          -------------------------

        else
          xPlayer.showNotification('<font color=orange>تم إنهاء المزاد ولم يزايد به أحد</font>')
        end
      end
    end
  else
    if xPlayer then
      if type == 'add' then
        TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " بدأ المزاد على  "..label2.." رقم ^3 "..data.ShopNumber.." ^7 | السعر الأساسي".." ^2"..data.ShopValue.."$".." ^7 | مدة الاستثمار ".." ^3 30 ^7 يوم")
        xPlayer.showNotification('<font color=green>تم عرض '..label2..' في المزاد</font>')
        --sendToDisc2(" يوجد مزاد ")
        Mazad[data.ShopNumber] = {player = nil, money = 0}
      elseif type == 'remove' then
        TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " تم إلغاء المزاد على  "..label2.." رقم ^3 "..data.ShopNumber.." ")
        xPlayer.showNotification('<font color=red>تم إزالة ال'..label..' من المزاد بنجاح</font>')
        returnmoneytoplayers(data.ShopNumber)
        Mazad[data.ShopNumber] = nil
      elseif type == 'playermazad' then
        MySQL.Async.fetchAll(
        'SELECT * FROM owned_shops WHERE identifier = @identifier',
        {
          ['@identifier'] = xPlayer.identifier,
        }, function(data222222)
          if data222222[1] == nil then
            if Mazad[data.ShopNumber] ~= nil then
              local shopValue = tonumber(data.ShopValue)

              if Mazad[data.ShopNumber].player ~= xPlayer.identifier then
                if PlayersInMazad[xPlayer.identifier] == nil or PlayersInMazad[xPlayer.identifier].shop == data.ShopNumber then
                  if PlayersInMazad[xPlayer.identifier] == nil then
                    if xPlayer.getMoney() >= amount + shopValue then
                      if amount >= Config.Mazad.L and amount <= Config.Mazad.H then
                        if Mazad[data.ShopNumber].money == shopValue then
                          Mazad[data.ShopNumber] = { oldmoney = Mazad[data.ShopNumber].money , player = xPlayer.identifier, money = Mazad[data.ShopNumber].money + amount }
                          xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(shopValue)..'</font>')
                          xPlayer.removeMoney(amount + shopValue)
                          PlayersInMazad[xPlayer.identifier] = { money = amount, shop = data.ShopNumber }
                        else
                          xPlayer.removeMoney(amount + Mazad[data.ShopNumber].money + shopValue)
                          Mazad[data.ShopNumber] = { oldmoney = Mazad[data.ShopNumber].money , player = xPlayer.identifier, money = Mazad[data.ShopNumber].money + amount }
                          xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(Mazad[data.ShopNumber].money + shopValue)..'</font>')
                          PlayersInMazad[xPlayer.identifier] = { money = amount, shop = data.ShopNumber }
                        end
                      else
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=orange>الحد الأدنى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.L)..'</br>'..'<font color=orange>الحد الأعلى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.H))
                      end
                    else
                      xPlayer.showNotification('<font color=red>لا تملك نقود كاش للمزايدة</font>')
                    end
                  else
                    local chakatest = (Mazad[data.ShopNumber].money - Mazad[data.ShopNumber].oldmoney ) + amount
                    if xPlayer.getMoney() >= chakatest then
                      if amount >= Config.Mazad.L and amount <= Config.Mazad.H then
                        xPlayer.removeMoney(chakatest)
                        Mazad[data.ShopNumber] = {oldmoney = Mazad[data.ShopNumber].money , player = xPlayer.identifier, money = Mazad[data.ShopNumber].money + amount }
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=white>تم المزايدة على ال'..label2..' بمبلغ <font color=green>$'..ESX.Math.GroupDigits(amount ).. '<font color=white> سعر  ال'..label2..' الحالي : <font color=#d5a000>$'..ESX.Math.GroupDigits(Mazad[data.ShopNumber].money + shopValue)..'</font>')
                        PlayersInMazad[xPlayer.identifier] = { money = PlayersInMazad[xPlayer.identifier].money + chakatest, shop = data.ShopNumber }
                      else
                        xPlayer.showNotification('<span style="font-size: 0.9em;"> <font color=orange>الحد الأدنى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.L)..'</br>'..'<font color=orange>الحد الأعلى للمزايدة هو</font><font color=green> $</font>'..ESX.Math.GroupDigits(Config.Mazad.H))
                      end
                    else
                      xPlayer.showNotification('<font color=red>لا تملك نقود كاش للمزايدة</font>')
                    end
                  end
                else
                  xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على أكثر من متجر في وقت واحد</font>')
                end
              else
                xPlayer.showNotification('<font color=red>لا يمكنك المزايدة على نفسك</font>')
              end
            end
          else
            xPlayer.showNotification('<font color=red>أنت مالك متجر ولا يمكنك المزايدة</font>')
          end
        end)
      elseif type == 'close' then
        if Mazad[data.ShopNumber].player ~= nil then
          xPlayer.showNotification('<font color=green>تم إنهاء المزاد وتسليم ال'..label2..'</font> ل'..ESX.GetPlayerFromIdentifier(Mazad[data.ShopNumber].player).getName())
          TriggerClientEvent("esx_misc:controlSystemScaleform_WinnerMZAD", xPlayer.source, label)
          TriggerClientEvent('chatMessage', -1, " إدارة المتاجر 🏪 " ,  { 178, 102, 255 } , " الفائز في مزاد "..label2.." رقم ".." ^3"..data.ShopNumber.." ^0| ^3"..ESX.GetPlayerFromIdentifier(Mazad[data.ShopNumber].player).getName().." ^0| سعر البيع ".." ^2"..Mazad[data.ShopNumber].money.."$")
          PlayersInMazad[Mazad[data.ShopNumber].player] = nil
          -------------------------
          -------------------------
          local endingTime = os.time() + 2629743

          MySQL.Async.fetchAll("UPDATE owned_shops SET identifier = @identifier, ShopName = @ShopName, ending = @ending WHERE ShopNumber = @ShopNumber",{['@identifier'] = Mazad[data.ShopNumber].player, ['@ShopNumber'] = data.ShopNumber, ['@ShopName'] = 'متجر', ['@ending'] = endingTime })

          -- MySQL.Async.fetchAll("UPDATE owned_shops SET identifier = @identifier, ShopName = @ShopName WHERE ShopNumber = @ShopNumber",{['@identifier'] = Mazad[data.ShopNumber].player, ['@ShopNumber'] = data.ShopNumber, ['@ShopName'] = 'متجر'})
          -- TriggerClientEvent('esx_kr_shops:removeBlip', -1)
          -- TriggerClientEvent('esx_kr_shops:setBlipMZAD', -1)

          TriggerClientEvent('esx_kr_shops:refreshBlips', xPlayer.source)
          -------------------------
          -------------------------
          Mazad[data.ShopNumber] = nil
          returnmoneytoplayers(data.ShopNumber)
        else
          xPlayer.showNotification('<font color=orange>تم إنهاء المزاد ولم يزايد به أحد</font>')
        end
      end
    end
  end
end)

ESX.RegisterServerCallback('esx_acshops:checkmazadstartornot', function(source, cb, number, foodtruck, money)
  local xPlayer = ESX.GetPlayerFromId(source)
  if Mazad[number] == nil then
    cb({done = true})
  else
    if Mazad[number].player == nil then
      cb({done = false, data = { money = Mazad[number].money, name = xPlayer.getName() }})
    else
      MySQL.Async.fetchAll(
      'SELECT * FROM users WHERE identifier = @identifier',
      {
        ['@identifier'] = Mazad[number].player,
      }, function(data222222)
        if data222222[1] ~= nil then
          local playername = data222222[1].firstname..' '..data222222[1].lastname
          cb({done = false, data = { money = Mazad[number].money, name = playername }})
        end
      end)
    end
  end
end)

ESX.RegisterServerCallback('esx_acshops:checkmzadshops', function(source, cb, shopss,shopss2)
  local xPlayer = ESX.GetPlayerFromId(source)
  for i=1, #shopss, 1 do
    if Mazad[shopss[i].ShopNumber] ~= nil then
      shopss[i].isMazad = true
      shopss[i].chakaMoney = tonumber(Mazad[shopss[i].ShopNumber].money)
    end
  end
  for i=1, #shopss2, 1 do
    if Mazad[shopss2[i].plate] ~= nil then
      shopss2[i].isMazad = true
      shopss2[i].chakaMoney = tonumber(Mazad[shopss2[i].plate].money)
    end
  end
  cb(shopss,shopss2)
end)


ESX.RegisterServerCallback('esx_acshops:CraftWeap9923ons', function(source, cb, data)
  local _source = source
  local xPlayer = ESX.GetPlayerFromId(_source)
  if xPlayer then
    if xPlayer.getInventoryItem('weaponcrafting').count >= 1 then
      if xPlayer.canCarryItem(data, 2) then
        cb(true)
        xPlayer.removeInventoryItem('weaponcrafting', 1)
        Citizen.Wait(Config.WeaponCraftTime)
        xPlayer.addInventoryItem(data, 2)
      else
        cb(false)
        xPlayer.showNotification('<font color=red>لا توجد مساحة كافية </br></font> سوف تحصل على 2 صندوق سلاح مقابل عدة تصنيع')
      end
    else
      cb(false)
      xPlayer.showNotification('<font color=red>لا تملك '.. xPlayer.getInventoryItem('weaponcrafting').label..' لتصنيع السلاح</font>')
    end
  else
    cb(false)
  end
end)

ESX.RegisterServerCallback('esx_acshops:CraftWeap9923ons2', function(source, cb)
  local _source = source
  local xPlayer = ESX.GetPlayerFromId(_source)
  if xPlayer then
    MySQL.Async.fetchAll('SELECT * FROM owned_shops WHERE identifier = @identifier',
    {
      ['@identifier'] = xPlayer.identifier,
    }, function(result)
      MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier',
      {
        ['@identifier'] = xPlayer.identifier,
      }, function(result2)
        if result[1] then
          if result2[1] then
            if Config.Zones[result[1].ShopNumber].Type == 'weapons' or Config.Zones[result2[1].shop].Type == 'weapons' then
              cb(true)
            else
              cb(false)
            end
          else
            cb(false)
          end
        else
          if result2[1] then
            if Config.Zones[result2[1].shop] and Config.Zones[result2[1].shop].Type == 'weapons' then
              cb(true)
            else
              cb(false)
            end
          else
            cb(false)
          end
        end
      end)
    end)
  else
    cb(false)
  end
end)

doubleitems = false

RegisterNetEvent('esx_acshops:togglePromotion', function()
  if doubleitems == false then
    doubleitems = true
    TriggerClientEvent("esx_misc:watermark_promotion", -1, 'doubleStoreBoxQty', true)
  else
    TriggerClientEvent("esx_misc:watermark_promotion", -1, 'doubleStoreBoxQty', false)
    doubleitems = false
  end
end)
