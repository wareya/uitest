tool
extends Container
class_name Document

#### TODO LIST ####
# other flow models
# fit/fill background modes + background alignment
# make sure inline styles work
# DOM API (at least queries)
# style transitions
# background color
# text outline and shadow control
# width/height model settings (padding/margin included or not)
# css calc (including referencing core properties) (OR, a system of units, like 10em etc)

var default_props = {
    "display": "inline-block", # or block, or inline, or detached
    # NOTE: inline elements are not rendered, only their children. their children are treated
    # by layout algorithms as existing within the parent of the inline element.
    
    # numbers only
    "padding_left": 0,
    "padding_right": 0,
    "padding_top": 0,
    "padding_bottom": 0,
    
    "margin_left": 0,
    "margin_right": 0,
    "margin_top": 0,
    "margin_bottom": 0,
    
    "offset_x": 0,
    "offset_y": 0,
    
    "overflow": "visible", # "visible", "hidden", "scroll_h", "scroll_v", and "scroll"
    "wrap" : "auto", # "auto", "never"
    
    # bottom, middle, top
    "row_align": "bottom",
    
    # FOR VERTICAL LAYOUT MODES ONLY
    # left, middle, right
    "column_align": "left",
    
    "font_family": [preload("res://font/Andika-Regular.ttf"), preload("res://font/SawarabiGothic-Regular.ttf")],
    "color": "white",
    "font_size": 16,
    "text_shadow_color": Color.transparent,
    
    "background": null,
    "background_9patch" : false, # FIXME change to "mode" with "tile", "9patch", "fit", "fill", "stretch", etc (and add alignment options)
    "background_9patch_top": 0,
    "background_9patch_bottom": 0,
    "background_9patch_left": 0,
    "background_9patch_right": 0,
    
    "background_offset_top": 0,
    "background_offset_bottom": 0,
    "background_offset_left": 0,
    "background_offset_right": 0,
    
    "layout": "flow",
    # lr_tb, rl_tb, lr_br, rl_bt
    # WARNING: text with rl directions is buggy! no, I'm not going to fix it!
    # godot 3 doesn't expose low-enough-level text-related stuff to do it properly
    # only us it for inline block layout! (or grids)
    "layout_direction": "lr_tb",
    
    # start, end, center, or justified
    "justify": "start",
    
    # number or percent, e.g. 512 or "50%". no units.
    "width": null,
    "max_width": null,
    "min_width": null,
    
    "height": null,
    "max_height": null,
    "min_height": null,
}

var calculated_props = default_props.duplicate()
var calculated_props_priority = []

var font_cache = {}

func make_font(font_list : Array, size : float):
    #if size < 16:
    #    print(font_list + [size])
    if font_list.size() < 0:
        return null
    var base_data = font_list[0]
    for font_data in calculated_props.font_family:
        if not font_data is DynamicFontData:
            continue
        base_data = font_data
        break
    var font_data : DynamicFontData = base_data
    var font_name = str(font_list) + " size: " + str(size)
    if font_name in font_cache:
        return font_cache[font_name]
    var font = DynamicFont.new()
    font.font_data = font_data
    font.size = size
    
    for data in font_list:
        if not font_data is DynamicFontData:
            continue
        if data == font.font_data:
            continue
        else:
            font.add_fallback(data)
            #print("adding a fallback of ", data, " ", data.font_path)
    
    font_cache[font_name] = font
    return font

var assigned_props = {
    
}

var doc_name = "root"
var doc_id = ""
var doc_class = []
var id_to_node = {}

export(String, MULTILINE) var custom_stylesheet = ""

export(String, MULTILINE) var markup = \
"""there <span> once </span> was <fun>a man</fun> from <img src="res://icon.png"/> who knew-it-all     too well of the <big>danger to us ALL</big> <b> and<br>so he <node type="Button" text="Look! A button!"></node> ran </b>
<br>
<br>
A silence as <ruby>everlasting<rt>permanent</ruby> as the realm in which we live—which is to say, not <ruby>everlasting<rt>permanent</ruby> in the slightest.
<br>
ここから何をしたら<ruby>最後<rt>エンド</ruby>まで歩きつづけるのでしょうか。
<node type="GridContainer" columns="2"><a>a</a> <b>b</b> <a>c</a> <b>d</b> <a>e</a> <b>f</b></node>
<br>
<bruh>asdf</bruh>
<br>
<bruh><fun>wow oh MY</fun></bruh>
<br>
<bruh><a><fun>fun for the WHOLE FAMILY</fun></a></bruh>
<br>
<big><ruby>終わり<rt><ruby>最後<rt>エンド</ruby></ruby></big>
<br>
<ruby>smol<rt>long ruby text above big text</ruby>
<br>
<span style="color: red;">(leading text to prevent overflow) </span><ruby>smol<rt>long ruby text above big text</ruby>
<br>
<span style="color: red;">(leading text to prevent overflow) </span><ruby>smol<rt>long ruby text above big text</ruby>
"""

var default_stylesheet = """
span {
    display: inline;
}
big {
    display: inline;
    font_size: 150%;
}
b {
    display: inline;
    font_family: "res://font/Andika-Bold.ttf", "res://font/SawarabiGothic-Regular.ttf";
}
br {
    display: block;
}
ruby {
    justify: center;
    display: inline-block;
    padding_top: 4;
    wrap: never;
}
rt {
    justify: center;
    display: detached;
    font_size: var(--rubysize);
    font_family: var(--rubyfont);
    width: 100%;
    offset_y: -4;
    wrap: never;
}
"""

export(String, MULTILINE) var root_stylesheet = \
"""root {
    background: "res://9PatchGradient.tres";
    margin_left: 5;
    margin_right: 5;
    margin_top: 5;
    margin_bottom: 5;
    padding_top: 8;
    padding_left: 8;
    padding_bottom: 8;
    padding_right: 8;
    background_9patch: true;
    background_9patch_top: 4.5;
    background_9patch_bottom: 6.5;
    background_9patch_left: 6;
    background_9patch_right: 6;
    
    overflow: scroll;
    
    max_height: 400;
    
    layout_direction: lr_tb;
}
:vars {
    --white: "#FFFFFF";
    --rubysize: 65%;
    --rubyfont: var(--englishfont) var(--japanesefont);
    --japanesefont: "res://font/SawarabiGothic-Regular.ttf";
    --englishfont: "res://font/Andika-Regular.ttf";
}
fun {
    background: "res://9PatchGradient2.tres";
    text_shadow_color: orange;
    text_shadow_offset: 0 0;
    display: inline-block;
}
bruh fun {
    color: yellow;
}
root bruh > fun {
    color: cyan;
}
bruh > fun {
    background: none;
    color: orange;
}
"""

var default_style_data = []
var style_data = []
var custom_style_data = []

func _update_v_scroll(value : float):
    var origin = get_global_rect().position
    #child.set_global_position(Vector2(x + base_offset, y) + offset + origin)
    #i += 1
    #_content_memo[child] = child.get_global_rect().position - origin
    var x_scroll = _h_scrollbar.value
    var y_scroll = _v_scrollbar.value
    for child in _content_memo:
        var bluh = _content_memo[child]
        child.set_global_position(origin + bluh - Vector2(x_scroll, y_scroll))
        child.update()

var _v_scrollbar = VScrollBar.new()
var _h_scrollbar = HScrollBar.new()
func _ready():
    custom_style_data = DocumentHelpers.parse_style(custom_stylesheet)
    add_child(_v_scrollbar)
    add_child(_h_scrollbar)
    _v_scrollbar.visible = false
    _h_scrollbar.visible = false
    
    _v_scrollbar.connect("value_changed", self, "_update_v_scroll")

export var visible_characters : float = -1.0 setget set_visible_characters

func _get_children_recursively(parent : Node, detached_filter = false):
    if detached_filter and "calculated_props" in parent and parent.calculated_props.display == "detached":
        return []
    var children = []
    for child in parent.get_children():
        children.push_back(child)
        children.append_array(_get_children_recursively(child, detached_filter))
    return children

func get_logical_characters():
    var count = 0
    for child in _get_children_recursively(self, true):
        if child is Label or child is RichTextLabel:
            var char_count = child.get_total_character_count()
            if child is Label and child.text.ends_with(" "):
                char_count += 1
            count += char_count
        elif child is CanvasItem:
            # FIXME: count the roots of groups of nodes with no labels as 1 characters
            pass

var _prev_int_visible_now = -100
func set_visible_characters(new_visible : float):
    visible_characters = new_visible
    var visible_now = int(floor(visible_characters))
    if _prev_int_visible_now == visible_now:
        return
    _prev_int_visible_now = visible_now
    var all_visible = visible_now < 0
    for child in _get_children_recursively(self, true):
        if child is Label or child is RichTextLabel:
            if all_visible:
                child.visible_characters = -1
            elif visible_now >= 0:
                child.visible_characters = visible_now
                var char_count = child.get_total_character_count()
                if child is Label and child.text.ends_with(" "):
                    char_count += 1
                visible_now -= char_count
            else:
                child.visible_characters = 0
        elif child is CanvasItem:
            if all_visible:
                child.modulate.a = 1.0
            elif visible_now >= 0:
                child.modulate.a = 1.0
                # FIXME: count the roots of groups of nodes with no labels as 1 characters
            else:
                child.modulate.a = 0.0


func _is_var(val, vars : Dictionary):
    return val is String and val.begins_with("var(") and val.ends_with(")")

func _flatten_style_var(values : Array, vars : Dictionary):
    values = values.duplicate()
    var max_insertions = 16
    var i = 0
    var seen_names_at = {}
    while i < values.size() and max_insertions > 0:
        if not i in seen_names_at:
            seen_names_at[i] = {}
        var name = ""
        var val = values[i]
        var found_var = false
        if _is_var(val, vars):
            val = val.substr(4, val.length()-5).replace("-", "_")
            name = val
            if not val in vars:
                break
            if val in seen_names_at[i]:
                break
            val = vars[val]
            found_var = true
        
        if found_var:
            max_insertions -= 1
            max_insertions -= 1
            if val is Array:
                var oldvalues = values
                values.remove(i)
                var begin = values.slice(0, i-1)
                var end = values.slice(i, values.size()-1)
                values = begin + val + end
                #print("performing insertion lookup for ", name, "\n", oldvalues, "\n", values, "\n", begin, " - ", end, " - ", i)
            else:
                values[i] = val
                #print("performing replacement lookup for ", name)
        else:
            if _is_var(val, vars):
                #print("skipping lookup for ", name)
                pass
            i += 1
    #if max_insertions < 16:
    #    print("\nfinal ", values)
    #    pass
    return values

func _get_color(color):
    if color is String:
        color = color.to_lower()
    if color in DocumentHelpers._colors:
        color = DocumentHelpers._colors[color]
    if not color is Color:
        color = Color(color)
    return color

func _target_matches(target : String) -> bool:
    if target == doc_name:
        return true
    if target == "#" + doc_id:
        return true
    for _class in doc_class:
        if target == "." + _class:
            return true
    return false

# target list is inverted, i.e. 0 is leaf and end is parent
func _target_list_matches(target_list : Array) -> bool:
    if !_target_matches(target_list[0]):
        return false
    var parent = get_parent()
    var i = 1
    var must_be_direct = false
    var failed = false
    while i < target_list.size() and parent != null:
        if target_list[i] == ">":
            must_be_direct = true
            i += 1
            continue
        elif parent._target_matches(target_list[i]):
            must_be_direct = false
            i += 1
        elif must_be_direct:
            failed = true
            break
        elif parent == null:
            break
        
        while parent != null:
            parent = parent.get_parent()
            #if parent is DocumentHelpers.DocScrollContents:
            #    parent = parent.get_parent()
            if parent != null and "calculated_props" in parent:
                break
    
    return !failed and i == target_list.size()

func _calculate_priority(target_list):
    if not target_list is Array and not target_list is PoolStringArray:
        target_list = [target_list]
    var n = [0, 0, 0, 0]
    for target in target_list:
        if target == ">":
            continue
        elif target.begins_with("#"):
            n[1] += 1
        elif target.begins_with("."):
            n[2] += 1
        else:
            n[3] += 1
    return n

func _compare_priority(a : Array, b : Array):
    if a[0] > b[0]: return true
    elif a[1] > b[1]: return true
    elif a[2] > b[2]: return true
    elif a[3] > b[3]: return true
    
    elif a[0] < b[0]: return false
    elif a[1] < b[1]: return false
    elif a[2] < b[2]: return false
    elif a[3] < b[3]: return false
    
    return true

export var _inherited_props = ["font_family", "font_size", "justify", "color"]
var _always_array_props = ["font_family"]
func calculate_style(parent_props, fed_style_data : Array, _font_cache):
    calculated_props_priority = {}
    
    fed_style_data += style_data
    font_cache = _font_cache
    if parent_props:
        for i in _inherited_props:
            calculated_props[i] = parent_props[i]
    
    var vars = {}
    
    for ruleset in default_style_data + fed_style_data + custom_style_data:
        var valid_target = false
        for target in ruleset.targets:
            #print(target)
            if target is String and target == ":vars":
                for rule in ruleset.rules:
                    vars[rule.prop] = rule.values
    
    for ruleset in default_style_data + fed_style_data + custom_style_data:
        var valid_target = false
        var highest_priority = [0, 0, 0, 0]
        for target in ruleset.targets:
            var is_match = false
            if target is String:
                is_match = _target_matches(target)
            else:
                is_match = _target_list_matches(target)
            
            if is_match:
                valid_target = true
                var priority = _calculate_priority(target)
                if _compare_priority(priority, highest_priority):
                    highest_priority = priority
        
        if !valid_target:
            continue
        
        for _rule in ruleset.rules:
            var rule : DocumentHelpers.StyleRule = _rule
            var values = _flatten_style_var(rule.values, vars)
            var to_assign
            if values == ["inherit"] and parent_props:
                to_assign = parent_props[rule.prop]
            elif values.size() > 1 or rule.prop in _always_array_props:
                to_assign = values
            else:
                to_assign = values[0]
            
            if not rule.prop in calculated_props_priority:
                calculated_props_priority[rule.prop] = highest_priority
            
            if _compare_priority(highest_priority, calculated_props_priority[rule.prop]):
                calculated_props[rule.prop] = to_assign
                calculated_props_priority[rule.prop] = highest_priority
    
    for k in assigned_props.keys():
        calculated_props[k] = assigned_props[k]
    
    var fs = calculated_props.font_size
    if fs is String and fs.ends_with("%"):
        var percent = fs.substr(0, fs.length()-1).to_float()
        if parent_props:
            calculated_props.font_size = parent_props.font_size * percent * 0.01
        else:
            calculated_props.font_size = default_props.font_size * percent * 0.01
    
    rect_clip_content = calculated_props.overflow != "visible"
    
    for child in get_children():
        if child.has_method("calculate_style"):
            child.calculate_style(calculated_props, fed_style_data + custom_style_data, font_cache)
        elif child is Label or child is Button or child is RichTextLabel:
            #print(calculated_props.font_family)
            if calculated_props.font_family is Array and calculated_props.font_family.size() > 0:
                var font : DynamicFont = make_font(calculated_props.font_family, calculated_props.font_size)
                if not child is RichTextLabel:
                    child.add_font_override("font", font)
                else:
                    child.add_font_override("font", font)
                #print(base_font)
                #for i in base_font.get_fallback_count():
                #    print(base_font.get_fallback(i))
            
            var color = _get_color(calculated_props.color)
            var shadow_color = _get_color(calculated_props.text_shadow_color)
            
            child.add_color_override("font_color", color)

func _init():
    #scroll_horizontal_enabled = false
    #scroll_vertical_enabled = false
    anchor_right = 1
    anchor_bottom = 1
    
    if is_connected("sort_children", self, "reflow"):
        disconnect("sort_children", self, "reflow")
    # warning-ignore:return_value_discarded
    connect("sort_children", self, "reflow")

func tri(x):
    x /= 4
    return abs(x - floor(x)-0.5)*4-1

var asdf = 0
var time = 0
func _process(delta):
    time += delta
    if Input.is_action_just_pressed("ui_accept") and is_inside_tree() and self == get_tree().current_scene:
        var default_style_data = DocumentHelpers.parse_style(default_stylesheet)
        var style_data = DocumentHelpers.parse_style(root_stylesheet)
        var scene = from_xml(markup)
        get_tree().current_scene.queue_free()
        get_tree().get_root().add_child(scene)
        get_tree().current_scene = scene
        scene.queue_sort()
        scene.default_style_data = default_style_data
        scene.style_data = style_data
    # performance test
    #if is_inside_tree() and self == get_tree().current_scene:
    #    anchor_right = lerp(0.25, 1.0, tri(time)/2+0.5)

func from_xml(xml : String):
    return DocumentHelpers.from_xmlnode(DocumentHelpers.parse_document(xml), get_script())

signal rejustify

var to_rejustify = []
func do_rejustify(real_width):
    pass

var _content_memo = {}

var max_descent = 0
var max_ascent = 0
func _reflow_row(row : Array, top : float, bottom : float, x_limit : float, wrapped : bool):
    var right_to_left = calculated_props.layout_direction.find("rl") >= 0
    max_descent = 0
    max_ascent = 0
    var min_x = 0
    var max_x = 0
    var prev_label_text = ""
    for i in row.size():
        var info = row[i]
        var child : Control = info[0]
        
        if child is Label:
            var font = (child as Label).get_font("font")
            max_ascent  = max(max_ascent , font.get_ascent())
            max_descent = max(max_descent, font.get_descent())
            if right_to_left and child.text.ends_with(" "):
                info[3].x += font.get_char_size(ord(" ")).x # offset
            prev_label_text = child.text
            #    child.text = " " + child.text.substr(0, -1)
        elif "calculated_props" in child:
            max_ascent  = max(max_ascent , child.max_ascent)
            max_descent = max(max_descent, child.max_descent)
            prev_label_text = ""
        else:
            prev_label_text = ""
        
        var cursor = info[1]
        var size = info[2]
        var offset = info[3]
        
        if i == 0:
            min_x = cursor
            max_x = cursor+size.x
        else:
            max_x = max(max_x, cursor + size.x)
    
    
    var base_offset = 0
    var gap_offset = 0
    
    var justify = calculated_props.justify
    if !wrapped and justify == "justified":
        justify = "start"
    
    
    if justify == "start":
        pass
    elif justify == "end":
        base_offset = x_limit - max_x
    elif justify == "center":
        base_offset = (x_limit - max_x)*0.5
        #print(x_limit, " ", max_x)
    elif justify == "justified":
        gap_offset += (x_limit - max_x)/row.size()
    
    var i = 0
    for info in row:
        var child : Control = info[0]
        var x : float = info[1]
        var child_size : Vector2 = info[2]
        var offset : Vector2 = info[3]
        var y = bottom - child_size.y
        if calculated_props.row_align == "middle":
            y = bottom/2 + top/2 + child_size.y/2
        elif calculated_props.row_align == "top":
            y = top
        if child is Label:
            var font = (child as Label).get_font("font")
            if calculated_props.row_align == "middle":
                offset.y += max_ascent/2 + max_descent/-2
                offset.y -= font.get_ascent()/2 + font.get_descent()/-2
            elif calculated_props.row_align == "top":
                offset.y += max_ascent
                offset.y -= font.get_ascent()
            else:
                offset.y -= max_descent
                offset.y += font.get_descent()
        elif "calculated_props" in child:
            if calculated_props.row_align == "middle":
                offset.y += max_ascent/2 + max_descent/-2
                offset.y -= child.max_ascent/2 + child.max_descent/-2
            elif calculated_props.row_align == "top":
                offset.y += max_ascent
                offset.y -= child.max_ascent
            else:
                offset.y -= max_descent
                offset.y += child.max_descent
        
        offset.x += gap_offset*i
        
        # mirroring
        if right_to_left:
            var left_x = x
            var right_x = x + child_size.x
            left_x = x_limit - left_x
            right_x = x_limit - right_x
            x = right_x
            #offset.x = right_x - x
        
        var origin = get_global_rect().position
        child.set_global_position(Vector2(x + base_offset, y) + offset + origin)
        i += 1
        _content_memo[child] = child.get_global_rect().position - origin
        #child.rect_position = Vector2(x, y) + offset
    pass

func calc_prop_percent(property : String, limit : float):
    var text = calculated_props[property]
    if !text:
        return null
    if text is float:
        return text
    if text.is_valid_float():
        return text.to_float()
    elif text.ends_with("%"):
        return text.substr(0, text.length()-1).to_float()/100.0 * limit
    return null
    
func calc_prop_width(default, x_limit : float):
    var width = calc_prop_percent("width", x_limit)
    if width == null:
        width = default
    var adjust = calc_prop_percent("max_width", x_limit)
    if adjust != null:
        width = min(width, adjust)
    adjust = calc_prop_percent("min_width", x_limit)
    if adjust != null:
        width = max(width, adjust)
    return width

func calc_prop_height(default, y_limit : float):
    var height = calc_prop_percent("height", y_limit)
    if height == null:
        height = default
    var adjust = calc_prop_percent("max_height", y_limit)
    if adjust != null:
        height = min(height, adjust)
    adjust = calc_prop_percent("min_height", y_limit)
    if adjust != null:
        height = max(height, adjust)
    return height

var layout_parent = null # FIXME prevent stale
var show_self = true
func reflow():
    _content_memo = {}
    
    #print("reflow of ", doc_name)
    font_cache.clear()
    if doc_name == "root":
        calculate_style(null, default_style_data + style_data, font_cache)
        layout_parent = null
    #print("sort...")
    
    #rect_min_size = Vector2()
    
    _h_scrollbar.visible = false
    _v_scrollbar.visible = false
    rect_clip_content = false
    var overflow = calculated_props.overflow
    if overflow == "scroll":
        _h_scrollbar.visible = true
        _v_scrollbar.visible = true
        rect_clip_content = true
    if overflow == "scroll_h":
        _h_scrollbar.visible = true
        rect_clip_content = true
    if overflow == "scroll_v":
        print("showing vsb")
        _v_scrollbar.visible = true
        rect_clip_content = true
    
    var parent_size = get_parent_area_size()
    if layout_parent:
        parent_size = layout_parent.rect_size
    
    var size = Vector2()
    size.x = parent_size.x * (anchor_right - anchor_left)
    size.y = parent_size.y * (anchor_bottom - anchor_top)
    size.x -= calculated_props.margin_left + calculated_props.margin_right
    size.y -= calculated_props.margin_top + calculated_props.margin_bottom
    var total_padding = Vector2(calculated_props.padding_right + calculated_props.padding_left, calculated_props.padding_top + calculated_props.padding_bottom)
    var x_limit = size.x - calculated_props.padding_right
    var y_limit = size.y - calculated_props.padding_bottom
    var x_buffer = 0
    var y_buffer = 0
    var x_scroll_pad = 0
    var y_scroll_pad = 0
    if _v_scrollbar.visible:
        var extra_pad = calculated_props.padding_right + _v_scrollbar.rect_size.x
        x_scroll_pad = _v_scrollbar.rect_size.x
        x_limit -= extra_pad
        x_buffer += extra_pad
    if _h_scrollbar.visible:
        var extra_pad = calculated_props.padding_bottom + _h_scrollbar.rect_size.y
        y_scroll_pad = _h_scrollbar.rect_size.y
        y_limit -= extra_pad
        y_buffer += extra_pad
    
    if calculated_props.layout == "flow":
        #var left_to_right = calculated_props.layout_direction.find("lr") >= 0
        
        var x_cursor = calculated_props.padding_left# if left_to_right else x_limit - calculated_props.padding_right
        var y_cursor = calculated_props.padding_top# if top_to_bottom else y_limit - calculated_props.padding_bottom
        var y_cursor_next = y_cursor
        var rows = []
        var row = []
        var process_nodes = []
        
        var start = Vector2(x_cursor, y_cursor)
        
        #var intended_interior_size = Vector2(x_limit, y_limit) - start
        
        var max_x = 0
        
        rect_size = Vector2(x_limit, y_limit) - Vector2(calculated_props.padding_left, calculated_props.padding_top)
        #rect_size.x -= calculated_props.padding_left
        #rect_size.x -= calculated_props.padding_right
        
        var check_queue = []
        if doc_name == "root" or calculated_props.display != "inline":
            check_queue = get_children()
        
        while check_queue.size() > 0:
            var _child = check_queue.pop_front()
            var _parent = self
            if _child is Array:
                _parent = _child[1]
                _child = _child[0]
            if not _child is Control:
                continue
            if not _child.is_visible_in_tree():
                continue
            if _child == _v_scrollbar or _child == _h_scrollbar:
                continue
            var child : Control = _child
            
            var do_inline = false
            if "calculated_props" in child and child.calculated_props.display == "inline":
                do_inline = true
            #elif child is DocumentHelpers.DocScrollContents:
            #    do_inline = true
            if do_inline:
                child.rect_clip_content = false
                var etc = []
                for c in child.get_children():
                    etc.push_back([c, child])
                check_queue = etc + check_queue
                child.show_self = false
            else:
                if "show_self" in child: child.show_self = true
                process_nodes.push_back([child, self])
        
        for _data in process_nodes:
            var child : Control = _data[0]
            var parent : Control = _data[1]
            #print(child)
            
            var child_size = child.get_combined_minimum_size()
            var offset = Vector2()
            if "calculated_props" in child:
                child.layout_parent = self
                child.reflow() # prevents size flickering when resized
                child_size.x = max(child_size.x, child.rect_size.x)
                child_size.y = max(child_size.y, child.rect_size.y)
                child_size.x = child.calc_prop_width(child_size.x, x_limit)
                
                #if child.calculated_props.width != null:
                #    print(child_size)
                child.rect_size = child_size
                
                child_size.x += child.calculated_props.margin_left
                child_size.x += child.calculated_props.margin_right
                
                child_size.y += child.calculated_props.margin_top
                child_size.y += child.calculated_props.margin_bottom
                
                #offset = Vector2(child.calculated_props.padding_left, child.calculated_props.padding_top)
                offset = Vector2(child.calculated_props.padding_left, 0)
                offset.x += child.calculated_props.offset_x
                offset.y += child.calculated_props.offset_y
                #print(offset)
            
            #print(child, " ", child_size, " ", x_cursor, " ", y_cursor, "->", y_cursor_next, " ", x_limit)
            
            #if doc_name != "root" and calculated_props.display == "inline":
            #    continue
            
            if "calculated_props" in child and child.calculated_props.display == "detached":
                var origin = get_global_rect().position
                child.set_global_position(offset + origin)
                continue
            
            #print("--test")
            var new_row = false
            var force_next_row_new = false
            if row.size() > 0 and (x_cursor + child_size.x > x_limit or child.size_flags_horizontal & SIZE_EXPAND):
                new_row = true
            if calculated_props.wrap == "never":
                new_row = false
            if "calculated_props" in child and child.calculated_props.display == "block":
                new_row = true
                force_next_row_new = true
            if new_row:
                #print("--onto next row ", y_cursor, " ", y_cursor_next)
                #_reflow_row(row, y_cursor, y_cursor_next, x_limit)
                rows.push_back([row, y_cursor, y_cursor_next, !force_next_row_new])
                row = []
                y_cursor = y_cursor_next
                x_cursor = calculated_props.padding_left
                if force_next_row_new:
                    x_cursor = x_limit
            
            y_cursor_next = max(y_cursor_next, y_cursor + child_size.y)
            
            # skip adding label if it's just a space and is at the beginning of the line
            if row.size() == 0 and child is Label and child.text == " ":
                pass
            else:
                row.push_back([child, x_cursor, child_size, offset])
                max_x = max(max_x, x_cursor + child_size.x)
                x_cursor += child_size.x
        if row.size() > 0:
            #print("fallback ", y_cursor, " ", y_cursor_next)
            #_reflow_row(row, y_cursor, y_cursor_next, x_limit)
            rows.push_back([row, y_cursor, y_cursor_next, false])
            row = []
        
        var new_size = Vector2()
        
        var interior_size = Vector2(max_x, y_cursor_next) - start
        
        print("--", doc_name, "-", max_x, "-", x_limit, "-", parent_size.x)
        
        new_size.x = max_x + calculated_props.padding_right + x_buffer
        new_size.x = calc_prop_width(new_size.x, x_limit)
        new_size.y = y_cursor_next + calculated_props.padding_bottom + y_buffer
        new_size.y = calc_prop_height(new_size.y, y_limit)
        #if _v_scrollbar.visible:
        #    print(new_size.y)
        #    print(y_limit)
        
        var visible_interior_size = new_size - total_padding - Vector2(x_buffer, y_buffer)
        
        rect_size = new_size
        
        if doc_name == "root":
            rect_position = Vector2(calculated_props.margin_left, calculated_props.margin_top)
        
        # prevent thrashing by parent Container nodes
        if doc_name != "root" and get_parent() and not "calculated_props" in get_parent():
            var min_size = new_size
            min_size.x = min(min_size.x, interior_size.x)
            min_size.y = min(min_size.y, interior_size.y)
            rect_min_size = min_size
        
        if _v_scrollbar.visible:
            _v_scrollbar.rect_position = (rect_size - _v_scrollbar.rect_size) * Vector2(1, 0)
            _v_scrollbar.rect_position -= Vector2(calculated_props.padding_right, 0)
            _v_scrollbar.rect_position += Vector2(0, calculated_props.padding_top)
            _v_scrollbar.rect_size = rect_size * Vector2(0, 1)
            _v_scrollbar.rect_size.y -= calculated_props.padding_top + calculated_props.padding_bottom
            #if _h_scrollbar.visible:
            #    _v_scrollbar.rect_size.y -= _h_scrollbar.rect_size.y
            _v_scrollbar.max_value = interior_size.y
            _v_scrollbar.page = visible_interior_size.y
        
        if _h_scrollbar.visible:
            _h_scrollbar.rect_position = (rect_size - _h_scrollbar.rect_size) * Vector2(0, 1)
            _h_scrollbar.rect_position -= Vector2(0, calculated_props.padding_top)
            _h_scrollbar.rect_position += Vector2(calculated_props.padding_right, 0)
            _h_scrollbar.rect_size = rect_size * Vector2(1, 0)
            _h_scrollbar.rect_size.x -= calculated_props.padding_left + calculated_props.padding_right
            if _v_scrollbar.visible:
                _h_scrollbar.rect_size.x -= _v_scrollbar.rect_size.x
            _h_scrollbar.max_value = interior_size.x
            _h_scrollbar.page = visible_interior_size.x
        
        # FIXME: this doesn't clip child inputs properly
        _custom_rect = Rect2(start, visible_interior_size + Vector2(x_buffer, y_buffer))
        #_custom_rect = Rect2(start, visible_interior_size)
        
        var bottom_to_top = calculated_props.layout_direction.find("bt") >= 0
        if bottom_to_top:
            var bottom = visible_interior_size.y
            for data in rows:
                var r_y_cursor_next = data[2]
                bottom = max(bottom, r_y_cursor_next)
            bottom += y_scroll_pad
            for i in rows.size():
                var data = rows[i]
                var r_y_cursor = data[1]
                var r_y_cursor_next = data[2]
                data[1] = bottom - r_y_cursor_next
                data[2] = bottom - r_y_cursor
                
            rows.invert()
        for data in rows:
            var r_row = data[0]
            var r_y_cursor = data[1]
            var r_y_cursor_next = data[2]
            var r_wrapped = data[3]
            #if !left_to_right:
            #    r_row.invert()
            _reflow_row(r_row, r_y_cursor, r_y_cursor_next, visible_interior_size.x + x_buffer, r_wrapped)
        
        _update_v_scroll(0) # passed value is ignored


var _custom_rect = null

var _bg_item = null
var _crop_item = null
func _draw():
    if !show_self:
        return
    
    var canvas = get_canvas()
    var canvas_item = get_canvas_item()
    
    var p = get_parent()
    while p and not p is Control:
        p = p.get_parent()
    if p and p is Control:
        p = p.get_canvas_item()
    else:
        p = canvas
    
    if !_bg_item:
        _bg_item = VisualServer.canvas_item_create()
        VisualServer.canvas_item_set_visible(_bg_item, true)
        VisualServer.canvas_item_set_parent(_bg_item, p)
        VisualServer.canvas_item_set_draw_behind_parent(_bg_item, true)
    
    if !_crop_item:
        _crop_item = VisualServer.canvas_item_create()
        VisualServer.canvas_item_set_visible(_crop_item, true)
        VisualServer.canvas_item_set_clip(_crop_item, true)
        VisualServer.canvas_item_set_parent(_crop_item, canvas_item)
    
    if _custom_rect != null:
        VisualServer.canvas_item_set_custom_rect(canvas_item, true, _custom_rect)
        #VisualServer.canvas_item_set_custom_rect(_crop_item, true, _custom_rect)
    
    for _child in get_children():
        if _child == _h_scrollbar or _child == _v_scrollbar:
            continue
        #if _child is CanvasItem:
        #    var child : Control = _child
        #    var c = child.get_canvas_item()
        #    VisualServer.canvas_item_set_parent(c, _crop_item)
    
    var bg : Texture = calculated_props.background
    if bg:
        VisualServer.canvas_item_clear(_bg_item)
        var bg_size = bg.get_size()
        var bg_rect_start = Vector2()
        var bg_rect_end = rect_size
        
        bg_rect_start.x += rect_position.x
        bg_rect_start.y += rect_position.y
        bg_rect_start.x += calculated_props.background_offset_left
        bg_rect_start.y += calculated_props.background_offset_top
        bg_rect_end.x   += calculated_props.background_offset_right
        bg_rect_end.y   += calculated_props.background_offset_bottom
        
        var bg_rect = Rect2(bg_rect_start, bg_rect_end)
        if calculated_props.background_9patch:
            var top    = calculated_props.background_9patch_top
            var bottom = calculated_props.background_9patch_bottom
            var left   = calculated_props.background_9patch_left
            var right  = calculated_props.background_9patch_right
            VisualServer.canvas_item_add_nine_patch(_bg_item, bg_rect, Rect2(Vector2(), bg_size), bg.get_rid(), Vector2(left, top), Vector2(right, bottom))
        else:
            VisualServer.canvas_item_add_texture_rect(_bg_item, bg_rect, bg.get_rid(), true)

func _notification(what):
    if what == NOTIFICATION_PREDELETE:
        if _bg_item:
            VisualServer.free_rid(_bg_item)
            _bg_item = null
        pass
