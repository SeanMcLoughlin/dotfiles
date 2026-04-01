function pi-find --description "Search pi session content across all sessions"
    rg $argv ~/.pi/agent/sessions/
end
