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

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete query";

	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete queries where qu_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("queries.aspx");
	}
	else
	{
		confirm_href.HRef = "delete_query.aspx?confirm=y&id=" + id;

		sql = @"select qu_desc, isnull(qu_user,0) qu_user from queries where qu_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["qu_user"] != security.this_usid)
		{
			if (security.this_is_admin || security.this_can_edit_sql)
			{
				// can do anything
			}
			else
			{
				Response.Write ("You are not allowed to delete this item");
				Response.End();
			}
		}

		confirm_href.InnerText = "confirm delete of query: "
				+ Convert.ToString(dr["qu_desc"]);


	}


}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete query</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "queries"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=queries.aspx>back to queries</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


