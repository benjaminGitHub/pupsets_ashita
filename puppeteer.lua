--[[
* Ashita - Copyright (c) 2014 - 2016 atom0s [atom0s@live.com]
*
* This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
* To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to
* Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
*
* By using Ashita, you agree to the above license and its terms.
*
*      Attribution - You must give appropriate credit, provide a link to the license and indicate if changes were
*                    made. You must do so in any reasonable manner, but not in any way that suggests the licensor
*                    endorses you or your use.
*
*   Non-Commercial - You may not use the material (Ashita) for commercial purposes.
*
*   No-Derivatives - If you remix, transform, or build upon the material (Ashita), you may not distribute the
*                    modified material. You are, however, allowed to submit the modified works back to the original
*                    Ashita project in attempt to have it added to the original project.
*
* You may not apply legal terms or technological measures that legally restrict others
* from doing anything the license permits.
*
* No warranties are given.
]]--


----------------------------------------------------------------------------------------------------
-- Variables
----------------------------------------------------------------------------------------------------
local puppeteer          = {};   	-- The overall table this library uses.
puppeteer.queue          = {};   	-- The queue to handle events this library does.
puppeteer.delay          = 0.5; 	-- The delay to prevent spamming packets.
puppeteer.timer          = 0;    	-- The current time used for delaying packets.
puppeteer.mem            = {};   	-- The table holding memory specific data.
puppeteer.mem.offset1    = 0;    	-- The value for the automaton data
puppeteer.EQUIP_OFFSET 	 = 0x2000  	-- The offsets for equipment id's
puppeteer.ATTACH_OFFSET  = 0x2100  	-- The offsets for attachment id's
puppeteer.callback		 = nil
puppeteer.workload		 = 0;
puppeteer.is_retail    = true;      -- true if retail server, false if private server.


----------------------------------------------------------------------------------------------------
-- func: msg
-- desc: Prints out a message with the addon tag at the front.
----------------------------------------------------------------------------------------------------
function msg(s)
    local txt = '\31\200[\31\05' .. _addon.name .. '\31\200]\31\130 ' .. s;
    print(txt);
end


----------------------------------------------------------------------------------------------------
-- func: err
-- desc: Prints out an error message with the addon tag at the front.
----------------------------------------------------------------------------------------------------
function err(s)
    local txt = '\31\200[\31\05' .. _addon.name .. '\31\200]\31\39 ' .. s;
    print(txt);
end


----------------------------------------------------------------------------------------------------
-- func: debugString
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.debugString(node)
	if node == nil then
		reuturn "nil"
	end
	
    local function tab(amt)
        local str = ""
        for i=1,amt do
            str = str .. "\t"
        end
        return str
    end

    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. tab(depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. tab(depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    table.insert(output,output_str)
    output_str = table.concat(output)

    return output_str;
end


----------------------------------------------------------------------------------------------------
-- func: initialize
-- desc: Prepares this library for usage.
----------------------------------------------------------------------------------------------------
function puppeteer.initialize()
    local pointer1 = ashita.memory.findpattern('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);

    if (pointer1 == 0) then
        err('Failed to locate required pattern.');
        return false;
    end
    
    local offset1 = ashita.memory.read_uint32(pointer1);
    if (offset1 == 0) then
        err('Failed to read required pointer value. (1)');
        return false;
    end

    puppeteer.mem.offset1 = offset1;
    puppeteer.is_retail = puppeteer.isRetailServer();
end


----------------------------------------------------------------------------------------------------
-- func: getBits
-- desc: 
----------------------------------------------------------------------------------------------------
function string.getBits(str, offset, length)
	return ashita.bits.unpack_be(str, offset, 0, length)
end


----------------------------------------------------------------------------------------------------
-- func: isPupMain
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.isPupMain()
    return (AshitaCore:GetDataManager():GetPlayer():GetMainJob() == 18);
end


----------------------------------------------------------------------------------------------------
-- func: IsPupSub
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.isPupSub()
    return (AshitaCore:GetDataManager():GetPlayer():GetSubJob() == 18);
end


----------------------------------------------------------------------------------------------------
-- func: IsValidJob
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.isValidJob()
	return (puppeteer.isPupMain() == true);
end


----------------------------------------------------------------------------------------------------
-- func: getAbilityRecast
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getAbilityRecast(name)
	local ability = AshitaCore:GetResourceManager():GetAbilityByName(name, 0);
	if(ability ~= nil) then
		local recastTimer = ashita.ffxi.recast.get_ability_recast_by_id(ability.TimerId);
		return recastTimer > 0 and recastTimer / 60 or 0;
	else
		return -1;
	end
end


----------------------------------------------------------------------------------------------------
-- func: createPacket
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.createPacket()
	local i = 0;
	local packet = string.char(0x02, 0x53, 0x00, 0x00);
	for i = 1, 160 do
		packet = packet .. string.char(0x00);
	end

	packet = packet:totable();
	packet[0x9] = 0x12;
	return packet;
end


----------------------------------------------------------------------------------------------------
-- func: getEquippedItems
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getEquippedItems(data, slot)
	local offset
	if slot == "head" then
		offset = 0x04
	elseif slot == "frame" then
		offset = 0x05
	elseif slot == "attachment" then
		offset = 0x06
	end
	
	if slot ~= "attachment" then
		local itemId = data:getBits(offset, 8) + puppeteer.EQUIP_OFFSET
		return AshitaCore:GetResourceManager():GetItemById(itemId).Name[0]
	end

	attach = data:sub(offset, offset + 0x0C)
	local attArr = {}
	for i=1, #attach-1 do
		local itemId = ashita.bits.unpack_be(attach, i, 0, 8) + puppeteer.ATTACH_OFFSET
		if itemId ~= puppeteer.ATTACH_OFFSET then
			attArr[#attArr+1] = AshitaCore:GetResourceManager():GetItemById(itemId).Name[0]
		end
	end
	return attArr
end


----------------------------------------------------------------------------------------------------
-- func: getAutomatonDataFromMemory
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getAutomatonDataFromMemory()
	if(puppeteer.isValidJob() ~= true) then
		err('You need to be a puppeteer to get automaton data');
        return nil;
	end
	
    if (puppeteer.mem.offset1 == 0) then
        err('Cannot read automaton data; pointer is invalid.');
        return nil;
    end
   
    local pointer = ashita.memory.read_uint32(AshitaCore:GetPointerManager():GetPointer('inventory'));
    if (pointer == 0) then
        return nil;
    end

    pointer = ashita.memory.read_uint32(pointer);
    if (pointer == 0) then
        return nil;
    end

	return ashita.memory.read_literal(pointer + puppeteer.mem.offset1, 0x9C)
end


----------------------------------------------------------------------------------------------------
-- func: getNumberOfEquippedAttachments
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getNumberOfEquippedAttachments(data)
	local attachments = puppeteer.getEquippedItems(data, "attachment");
	return #attachments;
end


----------------------------------------------------------------------------------------------------
-- func: getEquipmentIdOffset
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getEquipmentIdOffset(name)
	local i = 1;
	for i = 1, 255 do
		local item = AshitaCore:GetResourceManager():GetItemById(puppeteer.EQUIP_OFFSET + i);
		if( item ~= nil and item.Name[0] == name ) then
			return i;
		end
	end
	
	return 0;
end


----------------------------------------------------------------------------------------------------
-- func: getAttachmentIdOffset
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getAttachmentIdOffset(name)
	local i = 1;
	for i = 1, 255 do
		local item = AshitaCore:GetResourceManager():GetItemById(puppeteer.ATTACH_OFFSET + i);
		if( item ~= nil and item.Name[0] == name ) then
			return i;
		end
	end
	
	return 0;
end

----------------------------------------------------------------------------------------------------
-- func: ResetAttachments
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.resetAttachments()
	local packet = puppeteer.createPacket();
	packet[0x5] = 0x00;
	for x = 1, 12 do
		packet[0xE + x] = 0x01;
	end
	puppeteer.workload = puppeteer.workload + 1;
	table.insert(puppeteer.queue, { 0x102, packet });
end


--------------------------------------------------------------------------------------------------
-- func: setHead
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.setHead(name)
	local packet = puppeteer.createPacket();
  local equipmentIdOffset = puppeteer.getEquipmentIdOffset(name);
  if (puppeteer.is_retail) then
	  packet[0x5] = equipmentIdOffset; --retail valid
  else
    packet[0x5] = 0x01; --private server valid only
  end
	packet[0xD] = equipmentIdOffset;
	puppeteer.workload = puppeteer.workload + 1;
	table.insert(puppeteer.queue, { 0x102, packet });
end


----------------------------------------------------------------------------------------------------
-- func: setFrame
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.setFrame(name)
	local packet = puppeteer.createPacket();
  local equipmentIdOffset = puppeteer.getEquipmentIdOffset(name);
  if (puppeteer.is_retail) then
	  packet[0x5] = equipmentIdOffset; --retail valid
  else
    packet[0x5] = 0x01; --private server valid only
  end
	packet[0xE] = equipmentIdOffset;
	puppeteer.workload = puppeteer.workload + 1;
	table.insert(puppeteer.queue, { 0x102, packet });
end


----------------------------------------------------------------------------------------------------
-- func: getAttachmentOffsetsFromNames
-- desc: 
----------------------------------------------------------------------------------------------------
function puppeteer.getAttachmentOffsetsFromNames(arrAtt)
	local idOffsets = {};
	
	for k, v in pairs(arrAtt) do
		local n = puppeteer.getAttachmentIdOffset(v);
		if(n ~= nil and n ~= 0) then
			idOffsets[#idOffsets+1] = n;
		end
	end
	return idOffsets;
end


----------------------------------------------------------------------------------------------------
-- func: setAttachments
-- desc: Sets all of the desired attachments at once. Not safe for retail use.
----------------------------------------------------------------------------------------------------
function puppeteer.setAttachments(arrAtt)
	local offsets = puppeteer.getAttachmentOffsetsFromNames(arrAtt);
	local packet = puppeteer.createPacket();
	packet[0x5] = 0x1;
	for k, v in pairs(offsets) do
		if( k <= 12 ) then
			packet[0xE + k] = v;
		end
	end
	puppeteer.workload = puppeteer.workload + 1;
	table.insert(puppeteer.queue, { 0x102, packet });
end

----------------------------------------------------------------------------------------------------
-- func: setAttachmentsRetailSafe 
-- desc: Sets each individual attachment one at a time. Tested on retail by Benjaman.
----------------------------------------------------------------------------------------------------
function puppeteer.setAttachmentsRetailSafe(arrAtt)
  local offsets = puppeteer.getAttachmentOffsetsFromNames(arrAtt);
	for k, v in pairs(offsets) do
		if( k <= 12 ) then
    	local packet = puppeteer.createPacket();
      packet[0x5] = v; --retail version must have key 5 value match v
			packet[0xE + k] = v;
      puppeteer.workload = puppeteer.workload + 1;
	    table.insert(puppeteer.queue, { 0x102, packet });
		end
	end
end


----------------------------------------------------------------------------------------------------
-- func: process_queue
-- desc: Processes the packet queue to be sent.
----------------------------------------------------------------------------------------------------
function puppeteer.processQueue()
    if  (os.time() >= (puppeteer.timer + puppeteer.delay)) then
        puppeteer.timer = os.time();
		
        if (#puppeteer.queue > 0) then
            local data = table.remove(puppeteer.queue, 1);
			if(puppeteer.isValidJob() == true) then
				AddOutgoingPacket(data[1], data[2]);
        --puppeteer.fakeAddOutgoingPacket(data[1], data[2]) --debug with this
			end
			if(puppeteer.workload ~= nil and puppeteer.workload > 0) then
				puppeteer.workload = puppeteer.workload - 1;
				if ( puppeteer.workload == 0 and puppeteer.callback ~= nil ) then
					puppeteer.callback();
				end
			end
        end
    end
end


----------------------------------------------------------------------------------------------------
-- func: fakeAddOutgoingPacket
-- desc: prints out the packet to be sent instead of sending it.
----------------------------------------------------------------------------------------------------
function puppeteer.fakeAddOutgoingPacket(id, packet)
  print('id: '..tostring(id))
  for k,v in ipairs(packet) do
    if tostring(v) ~= '0' then
      print('key:'..k..', value:'..v)
    end
  end
end

----------------------------------------------------------------------------------------------------
-- func: process_queue
-- desc: Processes the packet queue to be sent.
----------------------------------------------------------------------------------------------------
function puppeteer.equipSet(set, onComplete)
	if(puppeteer.workload > 0) then
		msg("Cannot change set, another equipset is in progress");
		return;
	end
	puppeteer.callback = onComplete;
	puppeteer.timer = os.time() + 1;
	puppeteer.resetAttachments();
	puppeteer.setHead(set["head"]);
	puppeteer.setFrame(set["frame"]);
  if (puppeteer.is_retail) then
	  puppeteer.setAttachmentsRetailSafe(set["attachments"]);
  else
    puppeteer.setAttachments(set["attachments"]);
  end
end

----------------------------------------------------------------------------------------------------
-- getPupSet
-- 
----------------------------------------------------------------------------------------------------
function puppeteer.getPupSet()
	local data = puppeteer.getAutomatonDataFromMemory();
	
	if(data == nil) then 
		return nil;
	end
	
	local currentSet = {}
	
	currentSet["head"] = puppeteer.getEquippedItems(data, "head");
	currentSet["frame"] = puppeteer.getEquippedItems(data, "frame");
	currentSet["attachments"] = puppeteer.getEquippedItems(data, "attachment");
	
	return currentSet;
end

----------------------------------------------------------------------------------------------------
-- func: isRetailServer
-- desc: Uses the boot_config to determine whether the player is playing on retail or private
----------------------------------------------------------------------------------------------------
function puppeteer.isRetailServer() 
  local boot_command = AshitaCore:GetConfigurationManager():get_string('boot_config', 'boot_command')
    if (string.find(boot_command, '--server')) then
      return false;
    else
      return true;
    end
  return true;
end

----------------------------------------------------------------------------------------------------
-- Returns the puppeteer table.
----------------------------------------------------------------------------------------------------
return puppeteer;