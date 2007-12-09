function on_page(page) {
	var frm =  document.getElementById(asp_form_id);
	frm.action.value = "page";
	frm.new_page.value = page
	frm.submit();
}

function on_sort(col) {
	var frm = document.getElementById(asp_form_id);
	frm.action.value = "sort";
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
	frm.action.value = "filter";
	frm.filter.value = filter_condition;
	frm.submit();
}

// ajax stuff

var xmlHttp
var ajax_url="ajax.aspx?bugid="
var current_element
var current_bug

function find_position(obj) {
	var curleft = curtop = 0;
	curleft = obj.offsetLeft
	curtop = obj.offsetTop

	if (obj.offsetParent) {
		while (obj = obj.offsetParent) {
			curleft += obj.offsetLeft
			curtop += obj.offsetTop
		}
	}
	return [curleft,curtop];
}

function get_bug_comment(bugid)
{
	xmlHttp=GetXmlHttpObject()
	if (xmlHttp==null)
	{
		return
	}

}

function stateChanged()
{
	if (current_element != null)
	{
		if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
		{

			var popup = document.getElementById("popup");
			if (xmlHttp.responseText != "")
			{
				popup.innerHTML = current_bug + ": " + xmlHttp.responseText
				var pos = find_position(current_element)

				popup.style.left = pos[0] + 30;
				popup.style.top = pos[1] + 30;
				popup.style.display = "block";

			}
		}
	}
}

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
		setTimeout('maybe_get_bug_comment(' + current_bug + ')', 400)
	}
}

function on_mouse_out()
{
	var popup = document.getElementById("popup");
	popup.style.display = "none";
	current_element = null
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
	
	var url = "flag.aspx?bugid=" + bugid + "&flag=" + which_int
	xmlHttp = GetXmlHttpObject();
	xmlHttp.open("GET",url,true)
	xmlHttp.send(null)

}
