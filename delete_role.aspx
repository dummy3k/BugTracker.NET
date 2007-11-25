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
		+ "delete role";


	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete roles where rl_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("roles.aspx");
	}
	else
	{
		sql = @"declare @cnt int
			select @cnt = count(1) from users where us_role = $1;
			select @cnt = @cnt + count(1) from queries where qu_role = $1;
			select rl_name, @cnt [cnt] from roles where rl_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["cnt"] > 0)
		{
			Response.Write ("You can't delete role \""
				+ Convert.ToString(dr["rl_name"])
				+ "\" because some users or queries still reference it.");
			Response.End();
		}
		else
		{
			confirm_href.HRef = "delete_role.aspx?confirm=y&id=" + id;

			confirm_href.InnerText = "confirm delete of \""
				+ Convert.ToString(dr["rl_name"])
				+ "\"";
		}
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete role</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=roles.aspx>back to roles</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href=""></a>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


