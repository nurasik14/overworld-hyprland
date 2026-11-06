# projects.jq — the one place that knows how ~/.config/overworld/projects.json changes.
# Used by projects-write.sh (and through it by ProjectsService.qml and `overworld projects`), so the shell, the chat and the CLI cannot disagree.
#   {"items": [{"id", "title", "note"?, "status": "progress"|"built", "created": ISO, "built_at"?: ISO}]}
# --arg  op id title note status now newid      --argjson delta at item
# Order shown everywhere (card, `overworld projects list`, /project list numbers): in progress in file order, then built, newest first.
def inprogress: [.items[] | select(.status != "built")];
def built: [.items | to_entries[] | select(.value.status == "built")] | sort_by([.value.built_at // "", .key]) | reverse | map(.value);
def ordered: inprogress + built;
def swap($i; $j): .[$i] as $a | .[$j] as $b | .[$i] = $b | .[$j] = $a;
def mark($st): if $st == "built" then .status = "built" | .built_at = $now else .status = "progress" | del(.built_at) end;

(if type == "object" then . else {} end)
| .items = ((.items // []) | if type == "array" then map(select(type == "object" and (.id | type) == "string")) else [] end)
| if $op == "add" then
    .items += [ { id: $newid, title: $title }
                + (if $note != "" then { note: $note } else {} end)
                + { status: (if $status == "built" then "built" else "progress" end), created: $now }
                + (if $status == "built" then { built_at: $now } else {} end) ]
  elif $op == "toggle" then
    .items |= map(if .id == $id then mark(if .status == "built" then "progress" else "built" end) else . end)
  elif $op == "set" then
    .items |= map(if .id == $id and (.status == "built") != ($status == "built") then mark($status) else . end)
  elif $op == "remove" then
    .items |= map(select(.id != $id))
  elif $op == "edit" then
    .items |= map(if .id == $id then (.title = $title | if $note == "" then del(.note) else .note = $note end) else . end)
  elif $op == "move" then
    .items as $it | ($it | map(.id) | index($id)) as $i
    | if $i == null then .
      else ($it[$i].status == "built") as $b
        | [range(0; $it | length) | select(($it[.].status == "built") == $b)] as $same
        | ($same | index($i) + $delta) as $q
        | if $q < 0 or $q >= ($same | length) then . else .items |= swap($i; $same[$q]) end
      end
  elif $op == "clearbuilt" then
    .items |= map(select(.status != "built"))
  elif $op == "ordered" then ordered
  elif $op == "insert" then
    .items |= (if any(.[]; .id == $item.id) then . else .[0:$at] + [$item] + .[$at:] end)
  else error("unknown op " + $op) end
