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
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN_OR_PROJECT_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "users";

	string sql;

	if (security.this_is_admin)
	{
		sql = @"
			select distinct pu_user
			into #t
			from
			project_user_xref
			where pu_admin = 1;

			select u.us_id [id],
			'<a href=edit_user.aspx?id=' + convert(varchar,u.us_id) + '>edit</a>' [$no_sort_edit],
			'<a href=edit_user.aspx?copy=y&id=' + convert(varchar,u.us_id) + '>copy</a>' [$no_sort_add<br>like<br>this],
			'<a href=delete_user.aspx?id=' + convert(varchar,u.us_id) + '>delete</a>' [$no_sort_delete],

			u.us_username [username],
			isnull(u.us_firstname,'') + ' ' + isnull(u.us_lastname,'') [name],
			og_name [org],
			case when u.us_admin = 1 then 'Y' else 'N' end [admin],
			case when pu_user is null then 'N' else 'Y' end [project<br>admin],
			case when u.us_active = 1 then 'Y' else 'N' end [active],
			case when og_external_user = 1 then 'Y' else 'N' end [external],
			isnull(pj_name,'') [forced<br>project],
			isnull(qu_desc,'') [default query],
			case when u.us_enable_notifications = 1 then 'Y' else 'N' end [notif-<br>ications],

			u2.us_username [created<br>by]

			from users u
			inner join orgs on u.us_org = og_id
			left outer join queries on u.us_default_query = qu_id
			left outer join projects on u.us_forced_project = pj_id
			left outer join users u2 on u.us_created_user = u2.us_id
			left outer join #t on u.us_id = pu_user
			where u.us_active in (1 $inactive)
			order by u.us_username;

			drop table #t";
	}
	else
	{
		sql = @"
			select distinct pu_user
			into #t
			from
			project_user_xref
			where pu_admin = 1;

			select u.us_id [id],
			'<a href=edit_user.aspx?id=' + convert(varchar,u.us_id) + '>edit</a>' [$no_sort_edit],
			'<a href=edit_user.aspx?copy=y&id=' + convert(varchar,u.us_id) + '>copy</a>' [$no_sort_add<br>like<br>this],
			'<a href=delete_user.aspx?id=' + convert(varchar,u.us_id) + '>delete</a>' [$no_sort_delete],

			u.us_username [username],
			isnull(u.us_firstname,'') + ' ' + isnull(u.us_lastname,'') [name],
			og_name [org],
			case when u.us_admin = 1 then 'Y' else 'N' end [admin],
			case when pu_user is null then 'N' else 'Y' end [project<br>admin],
			case when u.us_active = 1 then 'Y' else 'N' end [active],
			case when og_external_user = 1 then 'Y' else 'N' end [external],
			isnull(pj_name,'') [forced<br>project],
			isnull(qu_desc,'') [default query],
			case when u.us_enable_notifications = 1 then 'Y' else 'N' end [notif-<br>ications]

			from users u
			inner join orgs on us_org = og_id
			left outer join queries on us_default_query = qu_id
			left outer join projects on us_forced_project = pj_id
			left outer join #t on us_id = pu_user
			where us_created_user = $us
			and us_active in (1 $inactive)
			order by us_username;

			drop table #t";
	}

	if (!IsPostBack)
	{
		HttpCookie cookie = Request.Cookies["hide_inactive_users"];
		if (cookie != null)
		{
			if (cookie.Value == "1")
			{
				hide_inactive_users.Checked = true;
			}
		}
	}

	if (hide_inactive_users.Checked)
	{
		Response.Cookies["hide_inactive_users"].Value = "1";
		sql = sql.Replace("$inactive", "");
	}
	else
	{
		Response.Cookies["hide_inactive_users"].Value = "0";
		sql = sql.Replace("$inactive", ",0");
	}

	sql = sql.Replace("$us", Convert.ToString(security.this_usid));
	ds = dbutil.get_dataset(sql);

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet users</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body>
<% security.write_menu(Response, "admin"); %>

<div class=align>

<table border=0 width=80%><tr>
<td align=left>
	<a href=edit_user.aspx>add new user </a>
<td align=right>
	<form runat="server">
	<span class=lbl>hide inactive users:</span>
	<asp:CheckBox id="hide_inactive_users" runat="server" AutoPostBack="true" OnCheckedChanged="Page_Load"/>
	</form>
</table>

<%

if (ds.Tables[0].Rows.Count > 0)
{
//	SortableHtmlTable.create_from_dataset(
//		Response, ds, "edit_user.aspx?id=", "delete_user.aspx?id=", false);

	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "", false);


}
else
{
	Response.Write ("No users in the database.");
}
%>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>