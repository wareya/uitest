tool
extends Container
class_name Document

var calculated_props = {
    "flow_dir": "h-lr",
    "display": "block",
    "padding_left": 0,
    "padding_right": 0,
    "padding_top": 0,
    "padding_bottom": 0,
    "margin_left": 0,
    "margin_right": 0,
    "margin_top": 0,
    "margin_bottom": 0,
    "offset_x" : 0,
    "offset_y" : 0,
    "vertical_align": "bottom",
    "font_family": preload("res://font/Andika-Regular.ttf"),
    "font_size": 24,
}

var font_cache = {}

func make_font(data : DynamicFontData, size : float):
    if [data, size] in font_cache:
        return font_cache[[data, size]]
    var font = DynamicFont.new()
    font.font_data = data
    font.size = size
    font_cache[[data, size]] = font
    return font

var assigned_props = {
    
}

var doc_name = "root"
var doc_id = ""
var doc_class = []
var id_to_node = {}

export var style = ""

var markup = """
there <span> once </span> was a man from <img src='res://icon.png'/> who knew all     too well of the <big>danger</big> <b> and so he ran </b>
"""

var stylesheet = """
span {
    display: inline;
    font_size: 32;
}
big {
    display: inline;
    font_size: 32;
}
b {
    display: inline;
    font_family: "res://font/Andika-Bold.ttf";
}
"""

var style_data = []

const _inherited_props = ["font_family", "font_size"]
func calculate_style(parent_props, style_data : Array, _font_cache):
    font_cache = _font_cache
    if parent_props:
        for i in _inherited_props:
            calculated_props[i] = parent_props[i]
    
    for ruleset in style_data:
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
            if rule.values.size() == 1:
                var val = rule.values[0]
                calculated_props[rule.prop] = val
            #print("!%*@: ", rule.values)
    
    for k in assigned_props.keys():
        calculated_props[k] = assigned_props[k]
    
    for child in get_children():
        if child.has_method("calculate_style"):
            child.calculate_style(calculated_props, style_data, font_cache)
        elif child is Label:
            var font = make_font(calculated_props.font_family, calculated_props.font_size)
            child.add_font_override("font", font)

func _init():
    anchor_right = 1
    anchor_bottom = 1
    
    if is_connected("sort_children", self, "reflow"):
        disconnect("sort_children", self, "reflow")
    # warning-ignore:return_value_discarded
    connect("sort_children", self, "reflow")

var asdf = 0
func _process(_delta):
    if Input.is_action_just_pressed("ui_accept") and is_inside_tree() and self == get_tree().current_scene:
        var style_data = DocumentHelpers.parse_style(stylesheet)
        var scene = from_xml(markup)
        get_tree().current_scene.queue_free()
        get_tree().get_root().add_child(scene)
        get_tree().current_scene = scene
        scene.queue_sort()
        scene.style_data = style_data

func from_xml(xml : String):
    return DocumentHelpers.from_xmlnode(DocumentHelpers.parse_document(xml), get_script())

var max_descent = 0
var max_ascent = 0
func _reflow_row(row : Array, top : float, bottom : float):
    max_descent = 0
    max_ascent = 0
    for pair in row:
        var child : Control = pair[0]
        if child is Label:
            var font = (child as Label).get_font("font")
            max_ascent  = max(max_ascent , font.get_ascent())
            max_descent = max(max_descent, font.get_descent())
        elif "calculated_props" in child:
            max_ascent  = max(max_ascent , child.max_ascent)
            max_descent = max(max_descent, child.max_descent)
    
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
                
        #child.set_global_position(Vector2(x + offset.x, y) - origin)
        child.rect_position = Vector2(x, y) + offset
    pass

func reflow():
    #print("reflow of ", doc_name)
    font_cache = {}
    if doc_name == "root":
        calculate_style(null, style_data, font_cache)
    #print("sort...")
    if calculated_props.flow_dir == "h-lr":
        var parent_size = get_parent_area_size()
        var size = Vector2()
        size.x = parent_size.x * (anchor_right - anchor_left)
        size.y = parent_size.y * (anchor_bottom - anchor_top)
        var x_limit = size.x - calculated_props.padding_right
        var x_cursor = calculated_props.padding_left
        var y_cursor = calculated_props.padding_top
        var y_cursor_next = 0
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
            else:
                process_nodes.push_back([child, self])
        
        for _data in process_nodes:
            var child : Control = _data[0]
            var parent : Control = _data[1]
            #print(child)
            
            var child_size = child.get_combined_minimum_size()
            if "calculated_props" in child:
                #print("  >>")
                child.reflow() # prevents size flickering when resized
                #print("  <<")
                child_size.x = max(child_size.x, child.rect_size.x)
                child_size.y = max(child_size.y, child.rect_size.y)
            var offset = Vector2()
            if "calculated_props" in child:
                child_size.x += child.calculated_props.margin_left
                child_size.x += child.calculated_props.margin_right
                
                child_size.y += child.calculated_props.margin_top
                child_size.y += child.calculated_props.margin_bottom
                
                offset = Vector2(child.calculated_props.padding_left, child.calculated_props.padding_top)
                offset.x += child.calculated_props.offset_x
                offset.y += child.calculated_props.offset_y
                print(offset)
            
            #print(child, " ", child_size, " ", x_cursor, " ", y_cursor, "->", y_cursor_next, " ", x_limit)
            
            
            if doc_name != "root" and calculated_props.display == "inline":
                continue
            #print("--test")
            if row.size() > 0 and (x_cursor + child_size.x > x_limit or child.size_flags_horizontal & SIZE_EXPAND):
                #print("--onto next row ", y_cursor, " ", y_cursor_next)
                _reflow_row(row, y_cursor, y_cursor_next)
                row = []
                y_cursor = y_cursor_next
                x_cursor = 0
            
            y_cursor_next = max(y_cursor_next, y_cursor + child_size.y)
            
            row.push_back([child, x_cursor, child_size, offset])
            max_x = max(max_x, x_cursor + child_size.x)
            
            x_cursor += child_size.x
        if row.size() > 0:
            #print("fallback ", y_cursor, " ", y_cursor_next)
            _reflow_row(row, y_cursor, y_cursor_next)
            row = []
        
        rect_size.x = max_x + calculated_props.margin_right
        rect_size.y = y_cursor_next + calculated_props.margin_bottom
        
