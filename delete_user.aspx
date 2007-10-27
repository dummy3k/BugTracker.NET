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
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN_OR_PROJECT_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete user";

	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (!security.this_is_admin)
	{
		sql = @"select us_created_user, us_admin from users where us_id = $us";
		sql = sql.Replace("$us", id);
		DataRow dr = dbutil.get_datarow(sql);

		if (security.this_usid != (int) dr["us_created_user"])
		{
			Response.Write ("You not allowed to delete this user, because you didn't create it.");
			Response.End();
		}
		else if ((int) dr["us_admin"] == 1)
		{
			Response.Write ("You not allowed to delete this user, because it is an admin.");
			Response.End();
		}
	}

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete users where us_id = $us";
		sql = sql.Replace("$us", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("users.aspx");
	}
	else
	{
		sql = @"declare @cnt int
			select @cnt = count(1) from bugs where bg_reported_user = $us or bg_assigned_to_user = $us
			select us_username, @cnt [cnt] from users where us_id = $us";
		sql = sql.Replace("$us", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["cnt"] > 0)
		{
			Response.Write ("You can't delete user \""
				+ Convert.ToString(dr["us_username"])
				+ "\" because some bugs still reference it.");
			Response.End();
		}
		else
		{
			confirm_href.HRef = "delete_user.aspx?confirm=y&id=" + id;

			confirm_href.InnerText = "confirm delete of \""
				+ Convert.ToString(dr["us_username"])
				+ "\"";
		}

	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete user</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=users.aspx>back to users</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
</body>
</html>


