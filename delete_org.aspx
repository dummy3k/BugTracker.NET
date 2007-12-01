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
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete organization";


	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete orgs where og_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("orgs.aspx");
	}
	else
	{
		sql = @"declare @cnt int
			select @cnt = count(1) from users where us_org = $1;
			select @cnt = @cnt + count(1) from queries where qu_org = $1;
			select og_name, @cnt [cnt] from orgs where og_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["cnt"] > 0)
		{
			Response.Write ("You can't delete organization \""
				+ Convert.ToString(dr["og_name"])
				+ "\" because some users or queries still reference it.");
			Response.End();
		}
		else
		{
			confirm_href.HRef = "delete_org.aspx?confirm=y&id=" + id;

			confirm_href.InnerText = "confirm delete of \""
				+ Convert.ToString(dr["og_name"])
				+ "\"";
		}
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete organization</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=orgs.aspx>back to organizations</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href=""></a>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


