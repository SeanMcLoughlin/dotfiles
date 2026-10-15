function tm --description 'Attach to a tmux session on a login server over mosh'
    argparse 's/server=' -- $argv; or return 2
    if test (count $argv) -ne 1
        echo "usage: tm [-s|--server <host>] <session-name>" >&2
        return 2
    end
    set -l name $argv[1]
    set -l server $_flag_server
    test -z "$server"; and set server $DEFAULT_LOGIN_SERVER
    if test -z "$server"
        echo "tm: no server. Pass --server <host> or set DEFAULT_LOGIN_SERVER." >&2
        return 2
    end
    printf '\e]0;%s\a' $name
    while true
        mosh $server -- tmux new-session -A -s $name \; set-option set-titles on \; set-option set-titles-string $name
        test $status -eq 0; and break
        printf '\e]0;%s (reconnecting)\a' $name
        sleep 3
    end
    printf '\e]0;%s\a' $name
end
