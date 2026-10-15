function tm --description 'Attach to a tmux session on a login server; --new creates it'
    argparse 's/server=' 'm/mosh' 'n/new' -- $argv; or return 2
    if test (count $argv) -ne 1
        echo "usage: tm [-s|--server <host>] [-m|--mosh] [-n|--new] <session-name>" >&2
        return 2
    end
    set -l name $argv[1]
    set -l server $_flag_server
    test -z "$server"; and set server $DEFAULT_LOGIN_SERVER
    if test -z "$server"
        echo "tm: no server. Pass --server <host> or set DEFAULT_LOGIN_SERVER." >&2
        return 2
    end
    if not set -q _flag_new
        ssh -o ConnectTimeout=10 $server tmux has-session -t =$name 2>/dev/null
        switch $status
            case 0
            case 1
                echo "tm: no tmux session '$name' on $server. Use --new to create one." >&2
                return 1
            case '*'
                echo "tm: cannot reach $server." >&2
                return 1
        end
    end
    printf '\e]0;%s\a' $name
    while true
        if set -q _flag_mosh
            mosh $server -- tmux new-session -A -s $name \; set-option set-titles on \; set-option set-titles-string $name
        else
            ssh -t -o ServerAliveInterval=5 -o ServerAliveCountMax=3 $server tmux new-session -A -s $name '\;' set-option set-titles on '\;' set-option set-titles-string $name
        end
        test $status -eq 0; and break
        printf '\e]0;%s (reconnecting)\a' $name
        sleep 3
    end
    printf '\e]0;%s\a' $name
end
