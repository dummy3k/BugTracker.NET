function on_body_unload()
{
	// don't leave stray child windows because it's too confusing which parent/opener they are talking back to
	if (popup_window != null)
	{
		popup_window.close();
	}
}

function set_relationship_cnt(bugid, cnt)
{
	if (bugid == this_bugid) // don't really need this code now that we're closing child windows at unload time
	{
		el = window.document.getElementById("relationship_cnt");
		el.firstChild.nodeValue = cnt;
	}
}

var popup_window = null
function open_popup_window(url, title, bugid, width, height)
{
	var url_and_vars = url + '?id=' + bugid
	
	popup_window = window.open(
		url_and_vars,
		'bug',
		"menubar=0,scrollbars=1,toolbar=0,resizable=1,width=" + width + ",height=" + height)
		
	popup_window.focus()
}


var dirty = false;
function mark_dirty()
{
	dirty = true
}

function my_confirm()
{
	return confirm('You have unsaved changes.  Do you want to leave this page and lose your changes?.')
}

function goto_edit_bug(bugid)
{
	if (!dirty)
	{
		window.location="edit_bug.aspx?id=" + bugid;
	}
	else
	{
		var result = my_confirm()
		if (result)
		{
			window.location="edit_bug.aspx?id=" + bugid;
		}
	}
}

function send_email(id)
{
	if (dirty)
	{
		var result = my_confirm()
		if (result)
		{
			window.document.location = "send_email.aspx?bg_id=" + id;
		}
	}
	else
	{
		window.document.location = "send_email.aspx?bg_id=" + id;
	}
}


var xmlHttp

function GetXmlHttpObject()
{
	var objXMLHttp=null
	if (window.XMLHttpRequest)
	{
		objXMLHttp=new XMLHttpRequest()
	}
	else if (window.ActiveXObject)
	{
		objXMLHttp=new ActiveXObject("Microsoft.XMLHTTP")
	}
	return objXMLHttp
}


function handle_rewrite_posts()
{
	
	if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
	{
		if (xmlHttp.responseText != "")
		{
			var el = document.getElementById("posts")
			el.innerHTML = xmlHttp.responseText;
			get_db_datetime()
			start_animation()
		}
	}

		
}

function rewrite_posts(bugid)
{
	
	var images_inline = get_cookie("images_inline")
	var history_inline = get_cookie("history_inline")

	xmlHttp=GetXmlHttpObject()
	if (xmlHttp==null)
	{
		return
	}
	
	var url = "write_posts.aspx?images_inline=" + images_inline
		+ "&history_inline=" + history_inline
		+ "&id=" + bugid
	
	xmlHttp.onreadystatechange=handle_rewrite_posts
	xmlHttp.open("GET",url,true)
	xmlHttp.send(null)

}

function handle_get_bug_date()
{
	if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
	{
		if (xmlHttp.responseText != "")
		{
			var el = document.getElementById("snapshot_timestamp")
			el.value = xmlHttp.responseText;
		}
	}
}

function get_db_datetime()
{

	xmlHttp=GetXmlHttpObject()
	if (xmlHttp==null)
	{
		return
	}

	var url = "get_db_datetime.aspx"

	xmlHttp.onreadystatechange=handle_get_bug_date
	xmlHttp.open("GET",url,true)
	xmlHttp.send(null)

}


function toggle_notifications(bugid)
{

	var el = document.getElementById("get_stop_notifications");
	var text = el.firstChild.nodeValue;
	
	xmlHttp=GetXmlHttpObject()
	if (xmlHttp==null)
	{
		return
	}

	// build url
	var url = "subscribe.aspx?ses="
		+ get_cookie("se_id")
		+ "&id=" 
		+ bugid
		+ "&actn="
		
	if (text == "get notifications")
		url += "1"
	else
		url += "0"

	xmlHttp.open("GET",url,true)
	xmlHttp.send(null)

	// modify text in web page	
	if (text == "get notifications")
	{
		el.firstChild.nodeValue = "stop notifications"
	}
	else
	{
		el.firstChild.nodeValue = "get notifications"
	}

}


function toggle_images2(bugid)
{

	var images_inline = get_cookie("images_inline")
	if (images_inline == "1")
	{
		images_inline = "0"
		document.getElementById("hideshow_images").firstChild.nodeValue = "show inline images"
	}
	else
	{
		images_inline = "1"
		document.getElementById("hideshow_images").firstChild.nodeValue = "hide inline images"
	}

	set_cookie("images_inline",images_inline)

	rewrite_posts(bugid)

}

function toggle_history2(bugid)
{

	var history_inline = get_cookie("history_inline")
	if (history_inline == "1")
	{
		history_inline = "0"
		document.getElementById("hideshow_history").firstChild.nodeValue = "show change history"
	}
	else
	{
		history_inline = "1"
		document.getElementById("hideshow_history").firstChild.nodeValue = "hide change history"
	}

	set_cookie("history_inline",history_inline)

	rewrite_posts(bugid)

}


function resize_comment(delta)
{
	el = window.document.getElementById("comment");

	if (el.rows + delta < 1)
	{
		el.rows = 1;
	}
	else
	{
		el.rows += delta;
	}

}


function resize_iframe(elid, delta)
{
	var el = window.document.getElementById(elid);

	if (parseInt(el.height) + parseInt(delta) < 20)
	{
		el.height = 20;
	}
	else
	{
		el.height = parseInt(el.height) + parseInt(delta);
	}

}


function resize_image(elid, delta)
{
	var el = window.document.getElementById(elid);
	if (parseFloat(el.height) * parseFloat(delta) < 5
	|| parseFloat(el.width) * parseFloat(delta) < 5)
	{
		// do nothing
	}
	else
	{
		var h = parseInt((parseFloat(el.height) * parseFloat(delta)));
		var w = parseInt((parseFloat(el.width) * parseFloat(delta)));
		el.height = h;
		el.width = w;
	}

}

function maybe_autopostback(eventTarget, eventArgument)
{

	var theForm = document.forms['<% Response.Write(Util.get_form_name()); %>'];

	if (theForm.short_desc.value == "")
	{

		if (!theForm.onsubmit || (theForm.onsubmit() != false))
		{

			theForm.__EVENTTARGET.value = eventTarget;
			theForm.__EVENTARGUMENT.value = eventArgument;
			theForm.submit();
		}
	}
}


// prevent user from hitting "Submit" twice
var cnt = 0
function disable_me()
{
	cnt++
	if (cnt > 1)
	{
		el = window.document.getElementById("sub");
		el.disabled = true;
	}
}

function set_cookie(name,value) {
	var date = new Date();

	// expire in 10 years
	date.setTime(date.getTime()+(3650*24*60*60*1000));

	document.cookie = name +"=" + value
		+ ";expires=" + date.toGMTString();
		+ ";path=/";
}


function get_cookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i=0;i < ca.length;i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}

function save_var(name)
{
	var el = document.getElementById(name)
	if (el != null)
	{
		var val = el.options[el.selectedIndex].text;
		set_cookie(name, val)
	}
}

function get_preset(name)
{
	var el = document.getElementById(name)
	if (el != null)
	{
		val = get_cookie(name)
		
		if (val != null)
		{
			for (i = 0; i < el.options.length; i++)
			{
				if (el.options[i].text == val)
				{
					el.options[i].selected = true
					break
				}
			}
		}
	}
}

function get_presets()
{
	get_preset("category")
	get_preset("priority")
	get_preset("status")
	get_preset("udf")
	get_preset("assigned_to")
//	get_preset("pcd1")
//	get_preset("pcd2")
//	get_preset("pcd3")
	on_body_load() // to change the select styles
}

function set_presets()
{
	save_var("category")
	save_var("priority")
	save_var("status")
	save_var("udf")
	save_var("assigned_to")
//strange side effect with these.  The browser remembers the saved presets even if user doesn't click "use"
//	save_var("pcd1")
//	save_var("pcd2")
//	save_var("pcd3")
}

function clone()
{
	el = document.getElementById("bugid")
	el.firstChild.nodeValue = ""

	el = document.getElementById("bugid_label")
	el.firstChild.nodeValue = ""

	el = document.getElementById("sub")
	el.value = "Create"

	el = document.getElementById("posts")
	el.innerHTML = ""

	el = document.getElementById("clone_ignore_bugid")
	el.value = "1"

	el = document.getElementById("edit_bug_menu")
	el.style.display = "none"

}

var cls = null
var ie = null

function get_text(el)
{
	if (ie) return el.innerText
	else return el.textContent
	
}

function on_body_load()
{

	ie = (navigator.userAgent.indexOf("MSIE") > 0)
	cls = (navigator.userAgent.indexOf("MSIE") > 0) ? "className" : "class";
	
	sels = document.getElementsByTagName("select");
	
	// resize the options, making them all as wide as the widest
	max_width = 0

	for (i = 0; i < sels.length; i++)
	{
		if (sels[i].offsetWidth > max_width)
		{
			max_width = sels[i].offsetWidth;
		}
	}

	max_width += 10; // a little fudge factor, because of the bold text

	for (i = 0; i < sels.length; i++)
	{
		sels[i].style.width = max_width; 
	}
	
	change_dropdown_style();
	

	spans = document.getElementsByTagName("span");

	for (i = 0; i < spans.length; i++)
	{
		if (spans[i].getAttribute(cls) == "static")
		{
			if (get_text(spans[i]).indexOf("[no") > -1)
			{
				spans[i].setAttribute(cls,'edit_bug_static_none')
			}
			else
			{
				spans[i].setAttribute(cls,'edit_bug_static')
			}
		}
	}
	
	dirty = false // reset, because change_dropdown_style dirties the dropdowns

	start_animation()	
}

function change_dropdown_style()
{
	
	sels = document.getElementsByTagName("select");

	// change the select styles depending on whether something has been selected or not
	for (i = 0; i < sels.length; i++)
	{
		if (sels[i].id != "project")
		{
			sels[i].onchange = change_dropdown_style
		}
		si = sels[i].options.selectedIndex;
		if (sels[i].options[si].text.substr(0,3) == "[no")
		{
			sels[i].setAttribute(cls,'edit_bug_option_none')
		}
		else
		{
			sels[i].setAttribute(cls,'edit_bug_option')
		}
	}

	mark_dirty()
	
}

var ren = new RegExp( "\\n", "g" )
var ren2 = new RegExp( "\\n\\n", "g" )

function count_chars(textarea_id, max)
{
	mark_dirty()
	
	var textarea = document.getElementById(textarea_id)
	var count_span = document.getElementById(textarea_id + "_cnt");

	// \n counts as two chars by the time we insert,
	// so double them here for the purpose of counting
	var s = textarea.value.replace(ren,"\n\n")
	var len = s.length

	if (s.length > max)
	{
		// truncate
		var s = s.substr(0,max)
		// convert the \n\n back to \n
		textarea.value = s.replace(ren2,"\n")

		count_span.firstChild.nodeValue = "0 more characters allowed"
	}
	else
	{
		count_span.firstChild.nodeValue = (max - len) + " more characters allowed"
	}

	return true
}


function show_tags() // also in bug_list.js
{
	popup_window = window.open(
		'tags.aspx',
		'tags',
		"menubar=0,scrollbars=1,toolbar=0,resizable=1,width=500,height=400")

	popup_window.focus()

}


function append_tag(s) // also in bug_list.js, different element
{
	el = document.getElementById("tags")

	tags = el.value.split(",")

	for (i = 0; i < tags.length; i++)
	{
		s2 = tags[i].replace(/^\s+|\s+$/g,"") // trim
		if (s == s2)
		{
			return; // already entered
		}
	}

	if (el.value != "")
	{
		el.value += ","
	}

	el.value += s;
}


function done_selecting_tags()
{
	//
}


var color = 128
var timer = null
var new_posts = null
var new_posts_length

function RGB2HTML(red, green, blue)
{
    var decColor = red + 256 * green + 65536 * blue;
    return decColor.toString(16);
}

function timer_callback()
{
	color++
	
	
	for (i = 0; i < new_posts_length; i++)
	{
		new_posts[i].style.background = '#' +  RGB2HTML(color,255,color)
	}
	
	if (color == 255) // if the color is now white
	{
		clearInterval(timer)
	}

}


function getElementsByName_for_ie6_and_ie7(tag, name) {
     
     var elem = document.getElementsByTagName(tag);
     var arr = new Array();
     for(i = 0,iarr = 0; i < elem.length; i++)
     {
          att = elem[i].getAttribute("name");
          if(att == name)
          {
               arr[iarr] = elem[i];
               iarr++;
          }
     }
     return arr;
}	
