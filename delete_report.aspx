<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

String sql;
DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	if (security.this_is_admin || security.this_can_edit_reports)
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete report";

	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request["confirm"];

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete reports where rp_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("reports.aspx");
	}
	else
	{
		confirm_href.HRef = "delete_report.aspx?confirm=y&id=" + id;

		sql = @"select rp_desc from reports where rp_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		confirm_href.InnerText = "confirm delete of report: "
				+ Convert.ToString(dr["rp_desc"]);


	}


}




</script>

<html>
<head>
<title id="titl" runat="server">btnet delete report</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "reports"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=reports.aspx>back to reports</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
</body>
</html>


