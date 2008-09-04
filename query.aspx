<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DataSet ds;
DbUtil dbutil;
Security security;

string exception_message;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();

	// If there is a users table, then authenticate this page
	try
	{
		dbutil.execute_nonquery("select count(1) from users");
		security = new Security();
		security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);
	}
	catch (Exception)
	{
	}

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "run query";


	if (IsPostBack)
	{
		if (query.Value != "")
		{
			try
			{
				ds = dbutil.get_dataset(Server.HtmlDecode(query.Value));
			}
			catch (Exception e2)
			{
				exception_message = e2.Message;
				//exception_message = e2.ToString();  // uncomment this if you need more error info.
			}
		}
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet query</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>
<body>

<div class=align>
<table border=0>

<tr><td style="border: red solid 2px;
	background: yellow; color: #ff0000;
	font-weight: bold;
	font-size: 8pt;
	padding: 4px;">

This page is not safe on a public web server.
After you install BugTracker.NET on a public web server, please delete it.

<tr><td align=right>
<script>
var shown = true;

function showhide_form()
{
	var frm =  document.getElementById("<% Response.Write(Util.get_form_name()); %>");
	if (shown)
	{
		frm.style.display = "none";
		shown = false;
		showhide.firstChild.nodeValue = "show form";
	}
	else
	{
		frm.style.display = "block";
		shown = true;
		showhide.firstChild.nodeValue = "hide form";
	}
}
</script>
<a href='javascript:showhide_form()' id='showhide'>hide form</a>

<tr><td>

<form class=frm action="query.aspx" method="POST" runat="server">
	<span class=smallnote>Enter SQL:</span>
	<br>
	<textarea rows=15 cols=70 runat="server" id="query"></textarea>
	<p>
	<input runat="server" type=submit value="Execute SQL">
</form>

</td></tr></table></div>

<%

Response.Write ("<span class=err>" + exception_message + "</span><br>");

if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "");

}
else
{
	Response.Write ("No Rows");
}
%>
</body>
</html>


