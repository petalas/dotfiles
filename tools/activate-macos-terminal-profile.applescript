on run arguments
    set originalWindowIDs to item 1 of arguments
    tell application "Terminal"
        repeat with attempt from 1 to 50
            set importFinished to false
            if exists settings set "SeaShells" then
                repeat with terminalWindow in windows
                    set windowMarker to "|" & (id of terminalWindow as text) & "|"
                    if originalWindowIDs does not contain windowMarker then
                        set importFinished to true
                        exit repeat
                    end if
                end repeat
            end if
            if importFinished then exit repeat
            delay 0.1
        end repeat
        if not (exists settings set "SeaShells") then error "Terminal did not import the SeaShells profile"
        if not importFinished then error "Terminal did not finish opening the imported SeaShells profile"

        set managedProfile to settings set "SeaShells"
        set default settings to managedProfile
        set startup settings to managedProfile
        repeat with terminalWindow in windows
            set windowMarker to "|" & (id of terminalWindow as text) & "|"
            if originalWindowIDs contains windowMarker then
                repeat with terminalTab in tabs of terminalWindow
                    set current settings of terminalTab to managedProfile
                end repeat
            else
                do script "exit" in selected tab of terminalWindow
                set visible of terminalWindow to false
            end if
        end repeat

        if font name of managedProfile is not "HackNFM-Regular" then
            error "SeaShells did not resolve Hack Nerd Font Mono"
        end if
    end tell
end run
