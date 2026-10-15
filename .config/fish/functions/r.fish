function r --description 'Run a command on the login server over ssh, through its fish; -k reconnects'
    argparse --stop-nonopt 's/server=' 'k/keep' -- $argv; or return 2
    set -l server $_flag_server
    test -z "$server"; and set server $DEFAULT_LOGIN_SERVER
    if test -z "$server"
        echo "r: no server. Pass --server <host> or set DEFAULT_LOGIN_SERVER." >&2
        return 2
    end
    if test (count $argv) -eq 0
        ssh -t $server
        return
    end
    set -l payload (string replace -a "'" "'\\''" -- (string join ' ' -- (string escape -- $argv)))
    while true
        ssh -t -o ServerAliveInterval=5 -o ServerAliveCountMax=3 $server "fish -ic '$payload'"
        set -l rc $status
        if not set -q _flag_keep; or test $rc -ne 255
            return $rc
        end
        sleep 3
    end
end
