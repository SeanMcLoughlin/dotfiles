function pi-find-name --description "Search pi sessions by name"
    rg --json '"type":"session_info"' ~/.pi/agent/sessions/ \
        | rg $argv \
        | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        obj = json.loads(line)
        if obj.get('type') == 'match':
            path = obj['data']['path']['text']
            text = obj['data']['lines']['text']
            entry = json.loads(text)
            name = entry.get('name', '')
            print(f'{name}\t{path}')
    except:
        pass
"
end
