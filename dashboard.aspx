<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;
DataSet ds = null;

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

	string sql = @"
select ds.*, rp_desc
from dashboard_items ds
inner join reports on rp_id = ds_report
order by ds_col, ds_row";

	ds = dbutil.get_dataset(sql);

}

void write_column(int col)
{

	foreach (DataRow dr in ds.Tables[0].Rows)
	{
		if ((int) dr["ds_col"] == col)
		{
			if ((string) dr["ds_chart_type"] == "data")
			{
				Response.Write("\n<div class=panel>");
				Response.Write("\n<iframe src=view_report.aspx?view=data&id=" + dr["ds_report"] + "></iframe>");
				Response.Write("\n</div>");
			}
			else
			{
				Response.Write("\n<div class=panel>");
				Response.Write("\n<img src=view_report.aspx?scale=2&view=" + dr["ds_chart_type"] + "&id=" + dr["ds_report"] + ">");
				Response.Write("\n</div>");
			}
		}
	}

}

</script>

<html>
<title id="titl" runat="server">btnet dashboard</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<style>

body {background: #ffffff;}

.panel {
	background: #ffffff;
	border: 3px solid #cccccc;
	padding: 10px;
	margin-bottom: 10px;
}

iframe {
	border: 1px solid white;
	width: 100%;
	height:300px;
}

</style>
<body>
<% security.write_menu(Response, "admin"); %>

<a href=edit_dashboard.aspx>edit dashboard</a>

<table border=0 cellspacing=0 cellpadding=10>
<tr>

<td valign=top>&nbsp;<br>

<% write_column(1); %>

<td valign=top>&nbsp;<br>

<% write_column(2); %>



</table>
<% Response.Write(Application["custom_footer"]); %></body>
</body>
</html>