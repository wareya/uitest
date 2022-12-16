tool
extends Container
class_name DocumentHelpers

static func can_break(c : String):
    if c == " " or c == "\n" or c == "\t":
        return true
    var codepoint = c.ord_at(0)
    if codepoint < 0x2000:
        return false
    return (
        (codepoint >= 0x02E08 and codepoint <= 0x09FFF) or
        (codepoint >= 0x0AC00 and codepoint <= 0x0D7FF) or
        (codepoint >= 0x0F900 and codepoint <= 0x0FAFF) or
        (codepoint >= 0x0FE30 and codepoint <= 0x0FE4F) or
        (codepoint >= 0x0FF65 and codepoint <= 0x0FF9F) or
        (codepoint >= 0x0FFA0 and codepoint <= 0x0FFDC) or
        (codepoint >= 0x20000 and codepoint <= 0x2FA1F) or
        (codepoint >= 0x30000 and codepoint <= 0x3134F)
    )

static func can_break_after(c : String):
    if c in "—-":
        return true
    else:
        return false

static func _to_val(val, node, name):
    if val is String and val.begins_with("res://"):
        val = load(val)
    elif not node.get(name) is String:
        val = str2var(val)
    return val

static func from_xmlnode(_xml : DocumentHelpers.XMLNode, default_script : Script):
    if _xml.text != "":
        var words = []
        var word = ""
        var prev_breakable = false
        for c in _xml.text:
            if c == "\n" or c == "\t":
                c = " "
            var breakable = can_break(c)
            if breakable and !prev_breakable:
                words.push_back(word)
                word = ""
            word += c
            if breakable:
                words.push_back(word)
                word = ""
            elif can_break_after(c):
                words.push_back(word)
                word = ""
            prev_breakable = breakable
        # strip spaces
        var i = 0
        while i < words.size():
            var new_word = words[i]
            var new_chunk = new_word.strip_edges()
            if new_chunk == "" and new_chunk != new_word:
                new_chunk = " "
            words[i] = new_chunk
            i += 1
        # weld spaces together
        i = 0
        while i+1 < words.size():
            if words[i] == " " and words[i+1] == " ":
                words.remove(i+1)
            elif words[i] == "":
                words.remove(i)
            else:
                i += 1
        # weld spaces to previous word
        i = 0
        while i+1 < words.size():
            if words[i+1] == " ":
                words[i] += " "
                words.remove(i+1)
            i += 1
        
        if word != "":
            words.push_back(word)
        
        var nodes = []
        for chunk in words:
            var n = Label.new()
            n.text = chunk
            nodes.push_back(n)
        
        return nodes
    elif _xml.name.to_lower() == "img":
        var n = TextureRect.new()
        n.stretch_mode = TextureRect.STRETCH_KEEP
        if "src" in _xml.attributes:
            n.texture = load(_xml.attributes.src)
        elif _xml.children.size() > 0 and _xml.children[0].text != "":
            n.texture = load(_xml.children[0].text)
        return n
    else:
        var node
        if _xml.name.to_lower() == "node":
            print("trying to spawn a ", _xml.name)
            if not "type" in _xml.attributes:
                return null
            node = ClassDB.instance(_xml.attributes.type)
            if !node:
                return null
            for a_name in _xml.attributes:
                print("setting... ", a_name)
                if a_name == "type" or not a_name in node:
                    continue
                var a_val = _xml.attributes[a_name]
                if a_val is Array:
                    var array = []
                    for val in a_val:
                        val = _to_val(val, node, a_name)
                        array.push_back(val)
                    node.set(a_name, array)
                else:
                    a_val = _to_val(a_val, node, a_name)
                    node.set(a_name, a_val)
        else:
            node = default_script.new()
            node.doc_name = _xml.name
            if "id" in _xml.attributes:
                node.doc_id = _xml.attributes.id
            if "class" in _xml.attributes:
                node.doc_class = _xml.attributes.class.split(" ", false)
            if "style" in _xml.attributes:
                node.custom_style_data = parse_style(_xml.attributes.style)
            # FIXME apply built-in attributes (style, class, id, etc)
        
        for c in _xml.children:
            var cs = from_xmlnode(c, default_script)
            if cs is Array:
                for cd in cs:
                    node.add_child(cd)
            else:
                node.add_child(cs)
        return node

static func preprocess_style(text : String):
    var i = 0
    var in_string = ""
    var in_escape = false
    var in_comment = false
    var open_stack = []
    var text_out = ""
    while i < text.length():
        var c = text[i]
        i += 1
        if in_comment:
            if c == "\n":
                in_comment = false
                text_out += c
        elif in_escape:
            in_escape = false
            text_out += c
        elif c == "\\":
            in_escape = true
            text_out += c
        elif c == in_string:
            in_string = ""
            text_out += c
        elif c == "'" or c == '"':
            in_string = c
            text_out += c
        elif in_string:
            text_out += c
        elif c == "/" and i < text.length() and text[i] == "/":
            in_comment = true
        else:
            text_out += c
    return text_out
    
static func preprocess_xml(text : String):
    var i = 0
    var in_string = ""
    var in_escape = false
    var open_stack = []
    while i < text.length():
        var c = text[i]
        i += 1
        if in_escape:
            in_escape = false
        elif c == "\\":
            in_escape = true
        elif c == in_string:
            in_string = ""
        elif c == "'" or c == '"':
            in_string = c
        elif c == "<":
            open_stack.push_back(i-1)
        elif c == ">":
            var compensation = 0
            open_stack.pop_back()
            for j in open_stack:
                var a = text.substr(0, j+compensation)
                var b = text.substr(j+1+compensation)
                text = a + "&lt;" + b
                compensation += 3
            open_stack = []
            i += compensation
    return text


class XMLNode extends Reference:
    var name : String = "root"
    var attributes : Dictionary = {}
    var children : Array = []
    var text : String = ""
    func to_string(indent = ""):
        var c = ""
        for child in children:
            var s = "{}\n".format([child.to_string(indent+" ")], "{}")
            c += s
        
        if text == "":
            return "{indent}<{name} {attrib}>\n{c}{indent}</{name}>".format({"name":name, "attrib":attributes, "c":c, "indent":indent})
        else:
            return indent + "<text>" + text + "</text>"


static func parse_document(doc : String):
    doc = preprocess_xml(doc)
    #print(doc)
    var root = XMLNode.new()
    
    var bytes = doc.to_utf8()
    var xml = XMLParser.new()
    xml.open_buffer(bytes)
    
    var err = 0
    var stack = [root]
    var current = root
    var a = 10000000
    var previous_text = ""
    while err == 0:
        err = xml.read()
        if err != 0:
            #print_debug("termination: ", err)
            break
        
        a -= 1
        if a <= 0:
            break
        
        var type = xml.get_node_type()
        
        var node = null
        if type == XMLParser.NODE_ELEMENT:
            node = XMLNode.new()
            for i in xml.get_attribute_count():
                var k = xml.get_attribute_name(i)
                var v = xml.get_attribute_value(i)
                node.attributes[k] = v
            
            if xml.is_empty():
                var name = xml.get_node_name()
                node.name = name
                current.children.push_back(node)
                continue
            
        match type:
            XMLParser.NODE_NONE:
                break
            XMLParser.NODE_ELEMENT:
                var name = xml.get_node_name()
                node.name = name
                current.children.push_back(node)
                if name != "br": # special case
                    stack.push_back(current)
                    current = node
                if name == "node":
                    previous_text = ""
            XMLParser.NODE_ELEMENT_END:
                var name = xml.get_node_name()
                if (name == "ruby" and current.name == "rt"
                    and stack.size() >= 2
                    and stack.back().name == "ruby"): # special case
                    current = stack.pop_back()
                    current = stack.pop_back()
                elif name == "" or name == current.name:
                    current = stack.pop_back()
                else:
                    print_debug("parse error; non-matching closing tag (" + name + " vs " + current.name + ")")
                if name == "node":
                    previous_text = ""
            XMLParser.NODE_TEXT:
                var text = xml.get_node_data()
                node = XMLNode.new()
                var new_text = text.strip_edges(true, false)
                if new_text != text:
                    if !previous_text.ends_with(" "):
                        new_text = " " + new_text
                text = new_text
                new_text = text.strip_edges(false, true)
                if new_text != text and new_text != "":
                    text += " "
                node.text = text
                if text != "": # FIXME: ?????
                    previous_text = text # FIXME: ?????
                current.children.push_back(node)
            _:
                continue
    
    #print(root.to_string())
    return root

class StyleRule extends Reference:
    var prop : String = ""
    var values : Array = []
    
    func to_string():
        var c = ""
        for v in values:
            c += " {}".format([str(v)], "{}")
        return "{prop}:{c};\n".format({"prop":prop, "c":c})

class StyleRuleset extends Reference:
    var targets = []
    var rules = []
    
    func to_string():
        var c = ""
        for v in rules:
            c += "    {}".format([v.to_string()], "{}")
        var t = ""
        for v in targets:
            t += "{} ".format([v], "{}")
        return "{t}{\n{c}}\n".format({"t":t, "c":c})

static func parse_style_rule(text : String, i : int):
    var mode = "name"
    var in_string = ""
    var in_escape = false
    var start = i
    var rule_name : String = ""
    var rule_data = []
    var rule_string = ""
    while i < text.length():
        var c = text[i]
        i += 1
        if mode == "name":
            if c == "}":
                return null
            elif c == ":":
                rule_name = text.substr(start, i-start-1)
                rule_name = rule_name.replace("-", "_").strip_edges()
                start = i+1
                mode = "values"
            elif c.is_valid_identifier() or c == "-":
                pass
        else:
            if in_escape:
                if c == "n":
                    rule_string += "\n"
                elif c == "t":
                    rule_string += "\t"
                else:
                    rule_string += c
                in_escape = false
            elif in_string != "":
                if c == "\\":
                    in_escape = true
                elif c == in_string:
                    in_string = ""
                    rule_string = rule_string.strip_edges()
                    if rule_string != "":
                        rule_data.push_back(rule_string)
                        rule_string = ""
                else:
                    rule_string += c
            else:
                if c == "'" or c == '"':
                    in_string = c
                elif c.strip_edges() == "" or c == ";" or c == "}" or c == ",":
                    if rule_string != "":
                        rule_string = rule_string.strip_edges()
                        if rule_string.is_valid_float():
                            rule_string = rule_string.to_float()
                        elif rule_string == "false":
                            rule_string = false
                        elif rule_string == "true":
                            rule_string = true
                        rule_data.push_back(rule_string)
                        rule_string = ""
                    if c == "}" or c == ";":
                        break
                else:
                    rule_string += c
    
    if rule_string != "":
        rule_string = rule_string.strip_edges()
        if !in_string and rule_string.is_valid_float():
            rule_string = rule_string.to_float()
        elif rule_string == "false":
            rule_string = false
        elif rule_string == "true":
            rule_string = true
        rule_data.push_back(rule_string)
        rule_string = ""
    
    if mode == "values":
        var ret = StyleRule.new()
        ret.prop = rule_name
        ret.values = rule_data
        for j in ret.values.size():
            var val = ret.values[j]
            if val is String and val.begins_with("res://"):
                ret.values[j] = load(val)
        return [ret, i]
    else:
        return null


static func parse_style_rules(text : String, i : int):
    var rules = []
    while i < text.length():
        var rule = parse_style_rule(text, i)
        if rule != null:
            #print("got rule ", rule[0].prop, rule[0].values, rule[1])
            rules.push_back(rule[0])
            i = rule[1]
        else:
            #print("no rule")
            var f = text.find("}", i)
            if f >= 0:
                i = f+1
            break
    return [rules, i]

static func parse_style_target(text : String, i : int):
    var f = text.find("{", i)
    if f > 0:
        var target_str : String = text.substr(i, f-i)
        var targets = target_str.split(",")
        for j in targets.size():
            targets[j] = targets[j].strip_edges()
        i = f+1
        
        var data = parse_style_rules(text, i)
        var rules = data[0]
        i = data[1]
        
        
        var ret = StyleRuleset.new()
        ret.targets = targets
        ret.rules = rules
        return [ret, i]
    else:
        return null

static func parse_style(text : String):
    text = preprocess_style(text)
    var styles = []
    var i = 0
    while i < text.length():
        var data = parse_style_target(text, i)
        if data:
            styles.push_back(data[0])
            i = data[1]
        else:
            break
    for s in styles:
        print(s.to_string())
    return styles
