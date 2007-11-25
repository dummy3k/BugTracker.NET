<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DataSet ds;
DbUtil dbutil;
Security security;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);


	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "queries";

	string sql = "";


	if (security.this_is_admin || security.this_can_edit_sql)
	{
		// allow admin to edit all queries

		sql =  @"select
			qu_desc [query],
			case
				when isnull(qu_user,0) = 0 and isnull(qu_role,0) is null then 'everybody'
				when isnull(qu_user,0) <> 0 then 'user:' + us_username
				when isnull(qu_role,0) <> 0 then 'role:' + rl_name
				else ' '
				end [visibility],
			'<a href=bugs.aspx?qu_id=' + convert(varchar,qu_id) + '>view list</a>' [view list],
			'<a target=_blank href=print_bugs.aspx?qu_id=' + convert(varchar,qu_id) + '>print list</a>' [print list],
			'<a target=_blank href=print_bugs.aspx?format=excel&qu_id=' + convert(varchar,qu_id) + '>export as excel</a>' [export as excel],
			'<a target=_blank href=print_bugs2.aspx?qu_id=' + convert(varchar,qu_id) + '>print detail</a>' [print list<br>with detail],
			'<a href=edit_query.aspx?id=' + convert(varchar,qu_id) + '>edit</a>' [edit],
			'<a href=delete_query.aspx?id=' + convert(varchar,qu_id) + '>delete</a>' [delete],
			qu_sql [sql]
			from queries
			left outer join users on qu_user = us_id
			left outer join roles on qu_role = rl_id
			where isnull(qu_user,0) = $us
			or isnull(qu_user,0) = 0
			order by qu_desc";
	}
	else
	{
		// allow editing for users own queries

		sql =  @"select
			qu_desc [query],
			'<a href=bugs.aspx?qu_id=' + convert(varchar,qu_id) + '>view list</a>' [view list],
			'<a target=_blank href=print_bugs.aspx?qu_id=' + convert(varchar,qu_id) + '>print list</a>' [print list],
			'<a target=_blank href=print_bugs.aspx?format=excel&qu_id=' + convert(varchar,qu_id) + '>export as excel</a>' [export as excel],
			'<a target=_blank href=print_bugs2.aspx?qu_id=' + convert(varchar,qu_id) + '>print detail</a>' [print list<br>with detail],
			'<a href=edit_query.aspx?id=' + convert(varchar,qu_id) + '>rename</a>' [rename],
			'<a href=delete_query.aspx?id=' + convert(varchar,qu_id) + '>delete</a>' [delete]
			from queries
			inner join users on qu_user = us_id
			where isnull(qu_user,0) = $us
			order by qu_desc";
	}

	if (Util.get_setting("HideSql", "0") == "1")
	{
		sql = sql.Replace("qu_sql [sql],","");
	}
	sql = sql.Replace("$us",Convert.ToString(security.this_usid));
	ds = dbutil.get_dataset(sql);

}



</script>

<html>
<head>
<title id="titl" runat="server">btnet queries</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body>
<% security.write_menu(Response, "queries"); %>

<div class=align>

<% if (security.this_is_admin || security.this_can_edit_sql) { %>
<a href=edit_query.aspx>add new query</a>
<% } %>
<p>

<%


if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "", false);
}
else
{
	Response.Write ("No queries in the database.");
}

%>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>