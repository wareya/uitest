tool
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

#class DocScrollContents extends Control:
#    func _init():
#        anchor_right = 1
#        anchor_bottom = 1
#    var show_self
#    pass

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
            #print("trying to spawn a ", _xml.name)
            if not "type" in _xml.attributes:
                return null
            node = ClassDB.instance(_xml.attributes.type)
            if !node:
                return null
            node.anchor_right = 1
            node.anchor_bottom = 1
            for a_name in _xml.attributes:
                #print("setting... ", a_name)
                if a_name == "type" or not a_name in node:
                    continue
                var a_val = _xml.attributes[a_name]
                #print(a_val)
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
                var rules = parse_style_rules(_xml.attributes.style, 0, 1)
                var style = StyleRuleset.new()
                style.targets = [":inline"]
                style.rules = rules
                node.custom_style_data = style
            # FIXME apply built-in attributes (style, class, id, etc)
        
        #var contents = DocScrollContents.new()
        #node.add_child(contents)
        
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
    var priority : Array = [0, 0, 0, 0]
    
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

static func _process_style_rule_string(rule_string, do_numeric_conversion):
    rule_string = rule_string.strip_edges()
    if do_numeric_conversion and rule_string.is_valid_float():
        rule_string = rule_string.to_float()
    elif rule_string == "false":
        rule_string = false
    elif rule_string == "true":
        rule_string = true
    elif rule_string == "none":
        rule_string = null
    return rule_string

static func parse_style_rule(text : String, i : int, first_priority):
    var mode = "name"
    var in_string = ""
    var in_escape = false
    var start = i
    var rule_name : String = ""
    var rule_data = []
    var rule_string = ""
    var end_of_ruleset = false
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
                        rule_string = _process_style_rule_string(rule_string, true)
                        rule_data.push_back(rule_string)
                        rule_string = ""
                        
                        if c == ",":
                            rule_data.push_back(",")
                    if c == "}":
                        end_of_ruleset = true
                    if c == "}" or c == ";":
                        break
                else:
                    rule_string += c
    
    if rule_string != "":
        rule_string = _process_style_rule_string(rule_string, in_string == "")
        rule_data.push_back(rule_string)
        rule_string = ""
    
    if mode == "values":
        var ret = StyleRule.new()
        if first_priority:
            ret.priority[0] += 1
        ret.prop = rule_name
        ret.values = rule_data
        if ret.values.size() > 0 and ret.values[-1] is String and ret.values[-1] == "!important":
            ret.values.pop_back()
            ret.priority[0] += 1
        for j in ret.values.size():
            var val = ret.values[j]
            if val is String and val.begins_with("res://"):
                ret.values[j] = load(val)
        return [ret, i, end_of_ruleset]
    else:
        return null


static func parse_style_rules(text : String, i : int, first_priority = 0):
    var rules = []
    while i < text.length():
        var rule = parse_style_rule(text, i, first_priority)
        if rule != null:
            #print("got rule ", rule[0].prop, rule[0].values, rule[1])
            rules.push_back(rule[0])
            i = rule[1]
            if rule[2]: # end of ruleset
                break
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
        var targets = Array(target_str.split(","))
        for j in targets.size():
            var t = targets[j]
            t = t.strip_edges()
            t = t.replace("\n", " ")
            t = t.replace("\t", " ")
            t = t.split(" ", false)
            if t.size() == 1:
                targets[j] = t[0]
            else:
                t.invert()
                targets[j] = t
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
    #for s in styles:
    #    print(s.to_string())
    return styles

const _colors = {
    "aliceblue": "#f0f8ff",
    "antiquewhite": "#faebd7",
    "aqua": "#00ffff",
    "aquamarine": "#7fffd4",
    "azure": "#f0ffff",
    "beige": "#f5f5dc",
    "bisque": "#ffe4c4",
    "black": "#000000",
    "blanchedalmond": "#ffebcd",
    "blue": "#0000ff",
    "blueviolet": "#8a2be2",
    "brown": "#a52a2a",
    "burlywood": "#deb887",
    "cadetblue": "#5f9ea0",
    "chartreuse": "#7fff00",
    "chocolate": "#d2691e",
    "coral": "#ff7f50",
    "cornflowerblue": "#6495ed",
    "cornsilk": "#fff8dc",
    "crimson": "#dc143c",
    "cyan": "#00ffff",
    "darkblue": "#00008b",
    "darkcyan": "#008b8b",
    "darkgoldenrod": "#b8860b",
    "darkgray": "#a9a9a9",
    "darkgreen": "#006400",
    "darkgrey": "#a9a9a9",
    "darkkhaki": "#bdb76b",
    "darkmagenta": "#8b008b",
    "darkolivegreen": "#556b2f",
    "darkorange": "#ff8c00",
    "darkorchid": "#9932cc",
    "darkred": "#8b0000",
    "darksalmon": "#e9967a",
    "darkseagreen": "#8fbc8f",
    "darkslateblue": "#483d8b",
    "darkslategray": "#2f4f4f",
    "darkslategrey": "#2f4f4f",
    "darkturquoise": "#00ced1",
    "darkviolet": "#9400d3",
    "deeppink": "#ff1493",
    "deepskyblue": "#00bfff",
    "dimgray": "#696969",
    "dimgrey": "#696969",
    "dodgerblue": "#1e90ff",
    "firebrick": "#b22222",
    "floralwhite": "#fffaf0",
    "forestgreen": "#228b22",
    "fuchsia": "#ff00ff",
    "gainsboro": "#dcdcdc",
    "ghostwhite": "#f8f8ff",
    "gold": "#ffd700",
    "goldenrod": "#daa520",
    "gray": "#808080",
    "green": "#008000",
    "greenyellow": "#adff2f",
    "grey": "#808080",
    "honeydew": "#f0fff0",
    "hotpink": "#ff69b4",
    "indianred": "#cd5c5c",
    "indigo": "#4b0082",
    "ivory": "#fffff0",
    "khaki": "#f0e68c",
    "lavender": "#e6e6fa",
    "lavenderblush": "#fff0f5",
    "lawngreen": "#7cfc00",
    "lemonchiffon": "#fffacd",
    "lightblue": "#add8e6",
    "lightcoral": "#f08080",
    "lightcyan": "#e0ffff",
    "lightgoldenrodyellow": "#fafad2",
    "lightgray": "#d3d3d3",
    "lightgreen": "#90ee90",
    "lightgrey": "#d3d3d3",
    "lightpink": "#ffb6c1",
    "lightsalmon": "#ffa07a",
    "lightseagreen": "#20b2aa",
    "lightskyblue": "#87cefa",
    "lightslategray": "#778899",
    "lightslategrey": "#778899",
    "lightsteelblue": "#b0c4de",
    "lightyellow": "#ffffe0",
    "lime": "#00ff00",
    "limegreen": "#32cd32",
    "linen": "#faf0e6",
    "magenta": "#ff00ff",
    "maroon": "#800000",
    "mediumaquamarine": "#66cdaa",
    "mediumblue": "#0000cd",
    "mediumorchid": "#ba55d3",
    "mediumpurple": "#9370db",
    "mediumseagreen": "#3cb371",
    "mediumslateblue": "#7b68ee",
    "mediumspringgreen": "#00fa9a",
    "mediumturquoise": "#48d1cc",
    "mediumvioletred": "#c71585",
    "midnightblue": "#191970",
    "mintcream": "#f5fffa",
    "mistyrose": "#ffe4e1",
    "moccasin": "#ffe4b5",
    "navajowhite": "#ffdead",
    "navy": "#000080",
    "oldlace": "#fdf5e6",
    "olive": "#808000",
    "olivedrab": "#6b8e23",
    "orange": "#ffa500",
    "orangered": "#ff4500",
    "orchid": "#da70d6",
    "palegoldenrod": "#eee8aa",
    "palegreen": "#98fb98",
    "paleturquoise": "#afeeee",
    "palevioletred": "#db7093",
    "papayawhip": "#ffefd5",
    "peachpuff": "#ffdab9",
    "peru": "#cd853f",
    "pink": "#ffc0cb",
    "plum": "#dda0dd",
    "powderblue": "#b0e0e6",
    "purple": "#800080",
    "red": "#ff0000",
    "rosybrown": "#bc8f8f",
    "royalblue": "#4169e1",
    "saddlebrown": "#8b4513",
    "salmon": "#fa8072",
    "sandybrown": "#f4a460",
    "seagreen": "#2e8b57",
    "seashell": "#fff5ee",
    "sienna": "#a0522d",
    "silver": "#c0c0c0",
    "skyblue": "#87ceeb",
    "slateblue": "#6a5acd",
    "slategray": "#708090",
    "slategrey": "#708090",
    "snow": "#fffafa",
    "springgreen": "#00ff7f",
    "steelblue": "#4682b4",
    "tan": "#d2b48c",
    "teal": "#008080",
    "thistle": "#d8bfd8",
    "tomato": "#ff6347",
    "turquoise": "#40e0d0",
    "violet": "#ee82ee",
    "wheat": "#f5deb3",
    "white": "#ffffff",
    "whitesmoke": "#f5f5f5",
    "yellow": "#ffff00",
    "yellowgreen": "#9acd32",
    
    "transparent": Color(0, 0, 0, 0),
}
