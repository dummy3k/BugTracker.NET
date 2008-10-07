<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;
DataSet ds = null;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	if (btnet.Util.get_setting("EnableWhatsNewPage","0") != "1")
	{
		Response.End();
	}

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "what's new?";

	if (security.user.is_admin || security.user.can_use_reports) ////////////////////////////////  change org
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}

}

</script>

<html>
<title id="titl" runat="server">btnet dashboard</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<style>



</style>

<script>

var cnt = 0
var internal_id = 0

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

function stateChanged()
{
	if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
	{

		el = document.getElementById("whatsnew")
		el.innerHTML = xmlHttp.responseText
	}
}


function get_whats_new()
{
	xmlHttp=GetXmlHttpObject()
	if (xmlHttp==null)
	{
		return
	}

	xmlHttp.onreadystatechange=stateChanged
	xmlHttp.open("GET", "whatsnew.aspx",true)
	xmlHttp.send(null)
}

function do_onload()
{
	get_whats_new()
	interval = 1000 * <% Response.Write(btnet.Util.get_setting("WhatsNewPageIntervalInSeconds","30")); %>
	interval_id = setInterval(get_whats_new, interval)
}

</script>

<body onload=do_onload()>
<% security.write_menu(Response, "reports"); %>

<table border=0 cellspacing=0 cellpadding=10>
<tr>
<td valign=top>

Recent updates:<p>

<div id=whatsnew>&nbsp;</div>

</table>

</body>
</html>