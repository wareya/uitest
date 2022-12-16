tool
extends Container
class_name Document

var calculated_props = {
    "display": "inline-block", # or block, or inline, or float
    # NOTE: float DOES NOT work ANYTHING like how float:left/right work in HTML/CSS.
    # float just removes the element from flow layout so that it can be positioned
    # relative to the layout cursor with offset_x and offset_y.
    # NOTE2: inline elements are not rendered, only their children. their children are treated
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
    
    # bottom, middle, top
    "vertical_align": "bottom",
    "font_family": [preload("res://font/Andika-Regular.ttf"), preload("res://font/SawarabiGothic-Regular.ttf")],
    "background": null,
    "background_9patch" : false,
    "background_9patch_top": 0,
    "background_9patch_bottom": 0,
    "background_9patch_left": 0,
    "background_9patch_right": 0,
    
    "background_offset_top": 0,
    "background_offset_bottom": 0,
    "background_offset_left": 0,
    "background_offset_right": 0,
    
    "font_size": 16,
    
    "layout": "flow_h_lr", # TODO: implement other flow models
    
    # left, right, center, or justified
    "justify": "left",
    
    # number or percent, e.g. 512 or "50%". no units.
    "width": null,
    "max_width": null,
    "min_width": null,
}

var font_cache = {}

func make_font(data : Array, size : float):
    var font_data : DynamicFontData = data[0]
    var font_name = str(data) + " size: " + str(size)
    if font_name in font_cache:
        return font_cache[font_name]
    var font = DynamicFont.new()
    font.font_data = font_data
    font.size = size
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
}
rt {
    justify: center;
    display: float;
    font_size: 65%;
    width: 100%;
    offset_y: -4;
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
}
fun {
    background: "res://9PatchGradient2.tres";
}
"""

var default_style_data = []
var style_data = []
var custom_style_data = []

func _ready():
    custom_style_data = DocumentHelpers.parse_style(custom_stylesheet)

var visible_characters : float = -1.0 # TODO implement

export var _inherited_props = ["font_family", "font_size", "justify"]
var _always_array_props = ["font_family"]
func calculate_style(parent_props, fed_style_data : Array, _font_cache):
    fed_style_data += style_data
    font_cache = _font_cache
    if parent_props:
        for i in _inherited_props:
            calculated_props[i] = parent_props[i]
    
    for ruleset in default_style_data + fed_style_data + custom_style_data:
        var valid_target = false
        for target in ruleset.targets:
            if target == doc_name:
                valid_target = true
            if target == "#" + doc_id:
                valid_target = true
            for _class in doc_class:
                if target == "." + _class:
                    valid_target = true
                    break
        if !valid_target:
            continue
        for _rule in ruleset.rules:
            var rule : DocumentHelpers.StyleRule = _rule
            if rule.values == ["inherit"] and parent_props:
                calculated_props[rule.prop] = parent_props[rule.prop]
            if rule.values.size() > 1 or rule.prop in _always_array_props:
                calculated_props[rule.prop] = rule.values
                pass
            else:
                calculated_props[rule.prop] = rule.values[0]
                pass
            #print("!%*@: ", rule.values)
    
    for k in assigned_props.keys():
        calculated_props[k] = assigned_props[k]
    
    var fs = calculated_props.font_size
    if fs is String and fs.ends_with("%"):
        print(fs)
        var percent = fs.substr(0, fs.length()-1).to_float()
        calculated_props.font_size = parent_props.font_size * percent * 0.01
    else:
        print(fs)
    
    for child in get_children():
        if child.has_method("calculate_style"):
            child.calculate_style(calculated_props, fed_style_data + custom_style_data, font_cache)
        elif child is Label or child is Button:
            #print(calculated_props.font_family)
            if calculated_props.font_family is Array and calculated_props.font_family.size() > 0:
                var fonts = []
                var base_font : DynamicFont = null
                var latest_font_data : DynamicFontData = null
                for font_data in calculated_props.font_family:
                    if base_font == null:
                        base_font = make_font(calculated_props.font_family, calculated_props.font_size)
                    else:
                        base_font.add_fallback(font_data)
                    latest_font_data = font_data
                child.add_font_override("font", base_font)

func _init():
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
    #    print("asdf")
    #    anchor_right = lerp(0.25, 1.0, tri(time)/2+0.5)

func from_xml(xml : String):
    return DocumentHelpers.from_xmlnode(DocumentHelpers.parse_document(xml), get_script())

signal rejustify

var to_rejustify = []
func do_rejustify(real_width):
    pass

var max_descent = 0
var max_ascent = 0
func _reflow_row(row : Array, top : float, bottom : float, x_limit : float, wrapped):
    max_descent = 0
    max_ascent = 0
    var min_x = 0
    var max_x = 0
    for pair in row:
        var child : Control = pair[0]
        if child is Label:
            var font = (child as Label).get_font("font")
            max_ascent  = max(max_ascent , font.get_ascent())
            max_descent = max(max_descent, font.get_descent())
        elif "calculated_props" in child:
            max_ascent  = max(max_ascent , child.max_ascent)
            max_descent = max(max_descent, child.max_descent)
        var cursor = pair[1]
        var size = pair[2]
        var offset = pair[3]
        if pair == row[0]:
            min_x = cursor
            max_x = cursor+size.x
        else:
            max_x = max(max_x, cursor + size.x)
    
    var base_offset = 0
    var gap_offset = 0
    
    var justify = calculated_props.justify
    if !wrapped and justify == "justified":
        justify = "left"
    
    if justify == "left":
        pass
    elif justify == "right":
        base_offset = x_limit - max_x
    elif justify == "center":
        base_offset = (x_limit - max_x)*0.5
        print(x_limit, " ", max_x)
    elif justify == "justified":
        gap_offset += (x_limit - max_x)/row.size()
    
    var i = 0
    for pair in row:
        var child : Control = pair[0]
        var x : float = pair[1]
        var child_size : Vector2 = pair[2]
        var offset : Vector2 = pair[3]
        var y = bottom - child_size.y
        if calculated_props.vertical_align == "middle":
            y = bottom/2 + top/2 + child_size.y/2
        elif calculated_props.vertical_align == "top":
            y = top
        if child is Label:
            var font = (child as Label).get_font("font")
            if calculated_props.vertical_align == "middle":
                offset.y += max_ascent/2 + max_descent/-2
                offset.y -= font.get_ascent()/2 + font.get_descent()/-2
            elif calculated_props.vertical_align == "top":
                offset.y += max_ascent
                offset.y -= font.get_ascent()
            else:
                offset.y -= max_descent
                offset.y += font.get_descent()
        elif "calculated_props" in child:
            if calculated_props.vertical_align == "middle":
                offset.y += max_ascent/2 + max_descent/-2
                offset.y -= child.max_ascent/2 + child.max_descent/-2
            elif calculated_props.vertical_align == "top":
                offset.y += max_ascent
                offset.y -= child.max_ascent
            else:
                offset.y -= max_descent
                offset.y += child.max_descent
        
        offset.x += gap_offset*i
        
        var origin = get_global_rect().position
        child.set_global_position(Vector2(x + base_offset, y) + offset + origin)
        i += 1
        #child.rect_position = Vector2(x, y) + offset
    pass

func calc_prop_x(child, property : String, x_limit : float):
    var text = child.calculated_props[property]
    if !text:
        return null
    if text.is_valid_float():
        return text.to_float()
    elif text.ends_with("%"):
        return text.substr(0, text.length()-1).to_float()/100.0 * x_limit
    return null
    
func calc_prop_width(child, default, x_limit : float):
    var width = calc_prop_x(child, "width", x_limit)
    if width == null:
        width = default
    var adjust = calc_prop_x(child, "max_width", x_limit)
    if adjust != null:
        width = max(width, adjust)
    adjust = calc_prop_x(child, "min_width", x_limit)
    if adjust != null:
        width = min(width, adjust)
    return width

var layout_parent = null # FIXME prevent stale
var show_self = true
func reflow():
    #print("reflow of ", doc_name)
    font_cache.clear()
    if doc_name == "root":
        calculate_style(null, default_style_data + style_data, font_cache)
        layout_parent = null
    #print("sort...")
    
    if calculated_props.layout == "flow_h_lr":
        var parent_size = get_parent_area_size()
        var size = Vector2()
        size.x = parent_size.x * (anchor_right - anchor_left)
        size.y = parent_size.y * (anchor_bottom - anchor_top)
        size.x -= calculated_props.margin_left + calculated_props.margin_right
        size.y -= calculated_props.margin_top + calculated_props.margin_bottom
        var x_limit = size.x - calculated_props.padding_right
        var x_cursor = calculated_props.padding_left
        var y_cursor = calculated_props.padding_top
        var y_cursor_next = 0
        var rows = []
        var row = []
        var process_nodes = []
        var check_queue = get_children()
        
        var max_x = 0
        
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
            var child : Control = _child
            
            if "calculated_props" in child and child.calculated_props.display == "inline":
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
                child_size.x = calc_prop_width(child, child_size.x, x_limit)
                
                if child.calculated_props.width != null:
                    print(child_size)
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
            
            if doc_name != "root" and calculated_props.display == "inline":
                continue
            
            if "calculated_props" in child and child.calculated_props.display == "float":
                var origin = get_global_rect().position
                child.set_global_position(offset + origin)
                continue
            
            #print("--test")
            var new_row = false
            var force_next_row_new = false
            if row.size() > 0 and (x_cursor + child_size.x > x_limit or child.size_flags_horizontal & SIZE_EXPAND):
                new_row = true
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
        
        rect_size.x = max_x + calculated_props.padding_right
        if layout_parent:
            rect_size.x = layout_parent.calc_prop_width(self, rect_size.x, x_limit)
        #print(rect_size.x)
        rect_size.y = y_cursor_next + calculated_props.padding_bottom
        if doc_name == "root":
            rect_position = Vector2(calculated_props.margin_left, calculated_props.margin_top)
        
        for data in rows:
            var r_row = data[0]
            var r_y_cursor = data[1]
            var r_y_cursor_next = data[2]
            var r_wrapped = data[3]
            _reflow_row(r_row, r_y_cursor, r_y_cursor_next, rect_size.x - calculated_props.padding_right, r_wrapped)
        

func _draw():
    # TODO: track the styles of inlined nodes and apply them here, using canvas_item_set_custom_rect
    if !show_self:
        return
    var bg : Texture = calculated_props.background
    if bg:
        var canvas = get_canvas()
        var canvas_item = get_canvas_item()
        var bg_size = bg.get_size()
        var bg_rect_start = Vector2()
        var bg_rect_end = rect_size
        
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
            VisualServer.canvas_item_add_nine_patch(canvas_item, bg_rect, Rect2(Vector2(), bg_size), bg.get_rid(), Vector2(left, top), Vector2(right, bottom))
        else:
            VisualServer.canvas_item_add_texture_rect(canvas_item, bg_rect, bg.get_rid(), true)
    pass
