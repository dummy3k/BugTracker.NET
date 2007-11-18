var iframe_doc;
var dirty = false;

function set_relationship_cnt(cnt)
{
	el = window.document.getElementById("relationship_cnt");
	el.firstChild.nodeValue = cnt;
}

function open_popup_window(url, title, bugid)
{
	w = window.open(url + '?id=' + bugid, title + bugid, "menubar=0, scrollbars=1, toolbar=0, resizable=1,width=750,height=550")
	w.focus()
}

function add_attachment(id)
{
	if (prompt == "1")
	{
		var result = confirm('Go to "Add Attachment" page?  Changes here will not be saved.');
		if (result)
		{
			window.document.location = "add_attachment.aspx?id=" + id;
		}
	}
	else
	{
		window.document.location = "add_attachment.aspx?id=" + id;
	}
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


function toggle_images(id)
{
	if (prompt == "1")
	{
		var result = confirm('Toggle inline display of images?  Changes here will not be saved.');
		if (result)
		{
			window.document.location = "toggle_images.aspx?id=" + id;
		}
	}
	else
	{
		window.document.location = "toggle_images.aspx?id=" + id;
	}
}

function toggle_history(id)
{
	if (prompt == "1")
	{
		var result = confirm('Toggle inline display of history?  Changes here will not be saved.');
		if (result)
		{
			window.document.location = "toggle_history.aspx?id=" + id;
		}
	}
	else
	{
		window.document.location = "toggle_history.aspx?id=" + id;
	}
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
}

function set_presets()
{
	save_var("category")
	save_var("priority")
	save_var("status")
	save_var("udf")
	save_var("assigned_to")
}