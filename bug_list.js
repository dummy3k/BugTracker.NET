function on_page(page) {
	var frm =  document.getElementById(asp_form_id);
	frm.actn.value = "page";
	frm.new_page.value = page
	frm.submit();
}

function on_sort(col) {
	var frm = document.getElementById(asp_form_id);
	frm.actn.value = "sort";
	frm.sort.value = col;
	frm.submit();
}

function on_filter() {

	var filter_condition = "66 = 66 "; // a dummy condition, just so I can start all the following with "and"

	// look for filter selects
	selects = document.getElementsByTagName("SELECT")
	for (var i = 0; i < selects.length; i++)
	{
		sel = selects[i]
		
		if (sel.id.indexOf("sel_[") == 0)
		{
			if (sel.options[sel.selectedIndex].text != "[no filter]")
			{
				if (sel.options[sel.selectedIndex].text == "[none]")
				{
					filter_condition += " and " + sel.id.substr(4) + " =$$$";
					filter_condition += sel.options[sel.selectedIndex].value; // value, not text
					filter_condition += "$$$";
				}
				else if (sel.options[sel.selectedIndex].text == "[any]")
				{
					filter_condition += " and " + sel.id.substr(4) + "<>$$$";  // not equal
					filter_condition += sel.options[sel.selectedIndex].value; // value, not text
					filter_condition += "$$$";
				}
				else
				{
					filter_condition += " and " + sel.id.substr(4) + " =$$$";
					filter_condition += sel.options[sel.selectedIndex].text;
					filter_condition += "$$$";
				}
			}

		}
	}
	var frm = document.getElementById(asp_form_id);
	
	frm.new_page.value = "0"
	frm.actn.value = "filter";
	frm.filter.value = filter_condition;
	frm.submit();
}

var current_element
var current_bug

function get_bug_comment(bugid)
{
	var url = "ajax.aspx?bugid=" + bugid
	$.get(url, "", handle_popup)
}

function handle_popup(data, status)
{
	if (current_element != null)
	{
		if (data != "")
		{
			display_popup(data)
		}
	}
}

function display_popup(s)
{ 
	if (s.indexOf("zeroposts") > 0)
		return;

	var popup = document.getElementById("popup");
	popup.innerHTML = s

	//viewport_height = $(document).height()  doesn't work
	viewport_height = get_viewport_size()[1] // does this factor in scrollbar?
	
	mytop = $(current_element).offset().top + $(current_element).height() + 4
	scroll_offset_y = $(document).scrollTop()
	y_in_viewport = mytop - scroll_offset_y
	
	if (y_in_viewport < viewport_height) // are we even visible?
	{
		// Display the popup, but truncate it if it overflows	
		// to prevent scrollbar, which shifts element under mouse
		// which leads to flicker...

		popup.style.height= ""
		popup.style.display = "block";

		if (y_in_viewport + popup.offsetHeight > viewport_height)
		{
			overflow = (y_in_viewport + popup.offsetHeight) - viewport_height

			newh = popup.offsetHeight -  overflow
			newh -= 10 // not sure why i need the margin..
			
			if (newh > 0)
			{
				popup.style.height = newh 
			}
			else
			{
				popup.style.display = "none";
			}
		}
		popup.style.left = $(current_element).offset().left + 40
		popup.style.top = mytop
	}
}

function maybe_get_bug_comment(bug)
{
	// if they have already moved to another bug,
	// ignore where they HAD been hovering
	if (bug == current_bug)
	{
		get_bug_comment(current_bug)
	}
}

function on_mouse_over(el)
{
	if (enable_popups)
	{
		current_element = el;
		pos = el.href.indexOf("=")
		pos++ // start with char after the =
		current_bug = el.href.substr(pos)
		// get comment if the user keeps hovering over this
		setTimeout('maybe_get_bug_comment(' + current_bug + ')', 250)
	}
}

function on_mouse_out()
{
	var popup = document.getElementById("popup");
	popup.style.display = "none";
	current_element = null
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


var cls = (navigator.userAgent.indexOf("MSIE") > 0) ? "className" : "class";
function flag(el, bugid)
{
	var which = el.getAttribute(cls)
	var which_int = 0;

	if (which == 'wht') 
	{
		which = 'red'
		which_int = 1;
	}
	else if (which == 'red')
	{
		which = 'grn'
		which_int = 2;
	}
	else if (which == 'grn')
	{
		which = 'wht';
		which_int = 0;
	}

	el.setAttribute(cls,which)
	
	var url = "flag.aspx?ses=" + get_cookie("se_id") +  "&bugid=" + bugid + "&flag=" + which_int
	$.get(url)
}

function seen(el, bugid)
{
	var which = el.getAttribute(cls)
	var which_int = 0;

	if (which == 'new') 
	{
		which = 'old'
		which_int = 1;
	}
	else 
	{
		which = 'new'; 
		which_int = 0;
	}

	el.setAttribute(cls,which)
	
	var url = "seen.aspx?ses=" + get_cookie("se_id") +  "&bugid=" + bugid + "&seen=" + which_int
	$.get(url)
}

function show_tags()
{
	popup_window = window.open(
		'tags.aspx',
		'tags',
		"menubar=0,scrollbars=1,toolbar=0,resizable=1,width=500,height=400")

	popup_window.focus()
}

function append_tag(s)
{
	el = document.getElementById("tags_input")

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

function on_tags_change()
{
	el = document.getElementById("tags_input")
	var frm = document.getElementById(asp_form_id)
	frm.tags.value = el.value
	on_filter()
}

function done_selecting_tags()
{
	on_tags_change()
}

function get_viewport_size()
{
  var myWidth = 0, myHeight = 0;
  
  if( typeof( window.innerWidth ) == 'number' )
  {
    //Non-IE
    myWidth = window.innerWidth;
    myHeight = window.innerHeight;
  }
  else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) )
  {
    //IE 6+ in 'standards compliant mode'
    myWidth = document.documentElement.clientWidth;
    myHeight = document.documentElement.clientHeight;
  }
  else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) )
  {
    //IE 4 compatible
    myWidth = document.body.clientWidth;
    myHeight = document.body.clientHeight;
  }
  
  return [myWidth, myHeight];
}