<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "dashboard";


	if (security.user.is_admin || security.user.can_use_reports)
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
body {background: #ffffff;}
.panel {background: #ffffff; border: 1px solid #cccccc; padding: 10px;}
</style>
<body>
<% security.write_menu(Response, "admin"); %>
<table border=0 cellspacing=0 cellpadding=10>
<tr>
<td valign=top>&nbsp;<br>

<div class="panel">
<img src=view_report.aspx?id=1&scale=2>
</div>

<p>
<div class="panel">
<img src=view_report.aspx?id=5&scale=2>
</div>

<td valign=top>&nbsp;<br>


<div class="panel">
<img src=view_report.aspx?id=2&scale=2>
</div>

<p>

<div class="panel">
<img src=view_report.aspx?id=4&scale=2>
</div>


<div class="panel">
<iframe width=100% height=300 src=view_report.aspx?id=4&view=data>
</div>


</table>
<% Response.Write(Application["custom_footer"]); %></body>
</body>
</html>