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

function maybe_rewrite_posts(bugid, updated_something)
{
	if (bugid == this_bugid && updated_something == 1)
	{
		rewrite_posts(bugid)
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


function send_email(id)
{
	if (prompt == "1")
	{
		var result = confirm('Go to "Send Email" page?  Changes here will not be saved.');
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


function stateToggleImages()
{
	if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
	{
		if (xmlHttp.responseText != "")
		{
			var el = document.getElementById("posts")
			el.innerHTML = xmlHttp.responseText;
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

	xmlHttp.onreadystatechange=stateToggleImages
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
		+ "&action="
		
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
	on_body_load() // to change the select styles
}

function set_presets()
{
	save_var("category")
	save_var("priority")
	save_var("status")
	save_var("udf")
	save_var("assigned_to")
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

function on_body_load()
{
	var cls = (navigator.userAgent.indexOf("MSIE") > 0) ? "className" : "class";
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

	for (i = 0; i < sels.length; i++)
	{
		sels[i].style.width = max_width
	}

	// change the select styles depending on whether something has been selected or not
	for (i = 0; i < sels.length; i++)
	{
		if (sels[i].id != "project")
		{
			sels[i].onchange = on_body_load
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
}

var ren = new RegExp( "\\n", "g" )
var ren2 = new RegExp( "\\n\\n", "g" )

function count_chars(textarea_id, max)
{
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

