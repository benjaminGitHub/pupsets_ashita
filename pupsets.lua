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


--################################
--  CONFIGURATION
--################################
	local auto_deus = true;
	local auto_activate = false;
--################################

_addon.author   = 'DivByZero'; -- Retail addition added by Benjaman --
_addon.name     = 'pupsets';
_addon.version  = '1.0.1';

require 'common'
require 'ffxi.recast'
pup = require 'puppeteer'

----------------------------------------------------------------------------------------------------
-- func: print_help
-- desc: Displays a help block for proper command usage.
----------------------------------------------------------------------------------------------------
local function print_help(cmd, help)
    -- Print the invalid format header..
    print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01 ' .. '\30\68Invalid format for command:\30\02 ' .. cmd .. '\30\01'); 

    -- Loop and print the help commands..
    for k, v in pairs(help) do
        print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01 ' .. '\30\68Syntax:\30\02 ' .. v[1] .. '\30\71 ' .. v[2]);
    end
end

----------------------------------------------------------------------------------------------------
-- func: load
-- desc: Event called when the addon is being loaded.
----------------------------------------------------------------------------------------------------
ashita.register_event('load', function()
    -- Initialize the Puppeteer library..
    if (pup.initialize() == false) then
        err('Failed to initialize required library.');
        return;
    end
end);

----------------------------------------------------------------------------------------------------
-- func: render
-- desc: Event called when the addon is being rendered.
----------------------------------------------------------------------------------------------------
ashita.register_event('render', function()
    -- Process the pup packet queue..
    pup.processQueue();
end);

----------------------------------------------------------------------------------------------------
-- func: command
-- desc: Event called when a command was entered.
----------------------------------------------------------------------------------------------------
ashita.register_event('command', function(command, ntype)
    -- Get the command arguments..
    local args = command:args();
    local commands = { '/pupsets', '/pupset', '/ps' };

    -- Ensure this is a valid command this addon should handle..
    if (table.hasvalue(commands, args[1]) == false) then
        return false;
    end
	
	if(pup.isValidJob() ~= true) then
		err('You need to be a puppeteer to use this addon');
	end

    -- List - Lists all available saved sets.
    ----------------------------------------------------------------------------------------------------
    if (#args >= 2 and args[2] == 'list') then
        local files = ashita.file.get_dir(_addon.path .. '/sets/', '*.txt', false);
        if (files ~= nil and #files > 0) then
            for _, v in pairs(files) do
                msg('Found pup set file: \31\04' .. v:gsub('.txt', ''));
            end
        else
            msg('No saved pup sets found.');
        end
        return true;
    end

    -- Load - Loads a saved pup set from disk.
    ----------------------------------------------------------------------------------------------------
    if (#args >= 3 and args[2] == 'load') then
        local name = command:gsub('([\/%w]+) ', '', 2):trim();
        if (name:endswith('.txt') == false) then
            name = name .. '.txt';
        end

        if (ashita.file.file_exists(_addon.path .. '/sets/' .. name) == false) then
            msg('Cannot load pup set, file does not exist: \31\04' .. name);
            return true;
        end
		
		if(pup.workload > 0) then
			msg('Cannot load pup set, a set is already being loaded');
            return true;
		end

        local data = ashita.settings.load(_addon.path .. '/sets/' .. name);
		
		if(data == nil) then
			msg('Cannot load pup set, file loading failed: \31\04' .. name);
			return true;
		end
		
		local player = GetPlayerEntity();
		local pet = nil;
		if(player ~= nil and player.PetTargetIndex ~= nil) then
			pet = GetEntity(player.PetTargetIndex);
		end
		
		if (pet ~= nil) then
			if(pup.getAbilityRecast("Deactivate") == 0 and (pet.HealthPercent >= 100 or pup.getAbilityRecast("Activate") == 0)) then
				AshitaCore:GetChatManager():QueueCommand('/pet "Deactivate" <me>', 0);
			else
				msg("You can't modify youre pup set while you have a pet active");
				return true;
			end
		end
		
		if(data["head"] ~= nil and data["frame"] ~= nil and data["attachments"] ~= nil) then
			pup.equipSet(data, function()
				msg('Loaded pup set: \31\04' .. name);
				if(auto_deus == true and pup.getAbilityRecast("Deus Ex Automata") == 0) then
					AshitaCore:GetChatManager():QueueCommand('/ja "Deus Ex Automata" <me>', 0);
				elseif(auto_activate == true and pup.getAbilityRecast("Activate") == 0) then
					AshitaCore:GetChatManager():QueueCommand('/ja "Activate" <me>', 0);
				end
			end);
		else
			msg('Cannot load pup set, the set is missing equipment: \31\04' .. name);
		end

        return true;
    end

    -- Save - Saves youre current pup set to disk.
    ----------------------------------------------------------------------------------------------------
    if (#args >= 3 and args[2] == 'save') then
        local name = command:gsub('([\/%w]+) ', '', 2):trim();
        if (name:endswith('.txt') == false) then
            name = name .. '.txt';
        end

		local pupData = pup.getPupSet();
        local data = ashita.settings.JSON:encode_pretty(pupData, nil, { pretty = true, align_keys = false, indent = '    ' });

        ashita.file.create_dir(_addon.path .. '/sets/');

        local f = io.open(_addon.path .. '/sets/' .. name, 'w');
        if (f == nil) then
            err('Failed to save pup set.');
            return true;
        end

        f:write(data);
        f:close();

        msg('Saved pup set: \31\04' .. name);
        return true;
    end

    -- Delete - Deletes a saved pup set from disk.
    ----------------------------------------------------------------------------------------------------
    if (#args >= 3 and args[2] == 'delete') then
        local name = command:gsub('([\/%w]+) ', '', 2):trim();
        if (name:endswith('.txt') == false) then
            name = name .. '.txt';
        end
        
        if (ashita.file.file_exists(_addon.path .. '/sets/' .. name) == false) then
            msg('Cannot delete pup set, file does not exist: \31\04' .. name);
            return true;
        end

        os.remove(_addon.path .. '/sets/' .. name);
        msg('Deleted pup set: \31\04' .. name);
        return true;
    end

    -- Prints the addon help..
    print_help('/pupsets', {
        { '/pupsets list',                  '- Lists all the known sets saved to disk.' },
        { '/pupsets load [name]',           '- Loads a pup set from the given file name.' },
        { '/pupsets save [name]',           '- Saves the current pup set to the given file name.' },
        { '/pupsets delete [name]',         '- Deletes the given saved pup set.' },
    });
    return true;
end);